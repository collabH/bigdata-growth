# 心跳接收器HeartbeatReceiver

* 运行在Driver上，用来接受各个Executor的心跳消息，对各个Executor的"状态"进行监控。

## HeartbeatReceiver属性

```scala
private[spark] class HeartbeatReceiver(sc: SparkContext, clock: Clock)
  extends SparkListener with ThreadSafeRpcEndpoint with Logging {

  def this(sc: SparkContext) {
    this(sc, new SystemClock)
  }

  sc.listenerBus.addToManagementQueue(this)

  override val rpcEnv: RpcEnv = sc.env.rpcEnv

  private[spark] var scheduler: TaskScheduler = null

  // executor ID -> timestamp of when the last heartbeat from this executor was received
  // 维护executorId和这个executor最后接收hearbeat的时间
  private val executorLastSeen = new mutable.HashMap[String, Long]

  // "spark.network.timeout" uses "seconds", while `spark.storage.blockManagerSlaveTimeoutMs` uses
  // "milliseconds"
  // executor 超时时间，根据 spark.network.timeout 和 spark.storage.blockManagerSlaveTimeoutMs决定
  private val executorTimeoutMs =
    sc.conf.getTimeAsMs("spark.storage.blockManagerSlaveTimeoutMs",
      s"${sc.conf.getTimeAsSeconds("spark.network.timeout", "120s")}s")

  // "spark.network.timeoutInterval" uses "seconds", while
  // "spark.storage.blockManagerTimeoutIntervalMs" uses "milliseconds"
  // 超时间隔
  private val timeoutIntervalMs =
    sc.conf.getTimeAsMs("spark.storage.blockManagerTimeoutIntervalMs", "60s")

  // 检查超时的间隔（单位为ms）。可通过spark.network.time-outInterval属性配置，默认采用timeoutIntervalMs的值。
  private val checkTimeoutIntervalMs =
    sc.conf.getTimeAsSeconds("spark.network.timeoutInterval", s"${timeoutIntervalMs}ms") * 1000

  // 超时校验线程
  private var timeoutCheckingTask: ScheduledFuture[_] = null

  // "eventLoopThread" is used to run some pretty fast actions. The actions running in it should not
  // block the thread for a long time.
  // 循环处理事件线程
  private val eventLoopThread =
    ThreadUtils.newDaemonSingleThreadScheduledExecutor("heartbeat-receiver-event-loop-thread")

  // kill executor 线程
  private val killExecutorThread = ThreadUtils.newDaemonSingleThreadExecutor("kill-executor-thread")
```

## 相关方法

### 注册Executor

```scala
	// 调用addExecutor(executorAdded.executorId)
 override def onExecutorAdded(executorAdded: SparkListenerExecutorAdded): Unit = {
    // 维护executor
    addExecutor(executorAdded.executorId)
  }
  def addExecutor(executorId: String): Option[Future[Boolean]] = {
    // 发送ExecutorRegistered消息
    Option(self).map(_.ask[Boolean](ExecutorRegistered(executorId)))
  }

// 处理ExecutorRegistered事件
executorLastSeen(executorId) = clock.getTimeMillis()
      context.reply(true)
```

### 移除Executor

```scala
// 发送ExecutorRemoved消息
def removeExecutor(executorId: String): Option[Future[Boolean]] = {
    Option(self).map(_.ask[Boolean](ExecutorRemoved(executorId)))
  }
  
  case ExecutorRemoved(executorId) =>
  executorLastSeen.remove(executorId)
  context.reply(true)
```

# Executor分析

## 相关属性

```scala
private[spark] class Executor(
    executorId: String,
    executorHostname: String,
    env: SparkEnv,
    userClassPath: Seq[URL] = Nil, // 用户指定的类路径。可通过spark.executor.extraClassPath属性进行配置。如果有多个类路径，可以在配置时用英文逗号分隔。
    isLocal: Boolean = false,
    uncaughtExceptionHandler: UncaughtExceptionHandler = new SparkUncaughtExceptionHandler //spark捕获异常处理器
                             )
  extends Logging {

  logInfo(s"Starting executor ID $executorId on host $executorHostname")

  // Application dependencies (added through SparkContext) that we've fetched so far on this node.
  // Each map holds the master's timestamp for the version of that file or JAR we got.
  // 当前执行的Task所需要的文件。
  private val currentFiles: HashMap[String, Long] = new HashMap[String, Long]()
  // 当前执行的Task所需要的Jar包。
  private val currentJars: HashMap[String, Long] = new HashMap[String, Long]()

  private val EMPTY_BYTE_BUFFER = ByteBuffer.wrap(new Array[Byte](0))

  private val conf = env.conf

  // No ip or host:port - just hostname
  Utils.checkHost(executorHostname)
  // must not have port specified.
  assert (0 == Utils.parseHostPort(executorHostname)._2)

  // Make sure the local hostname we report matches the cluster scheduler's name for this host
  Utils.setCustomHostname(executorHostname)

  if (!isLocal) {
    // Setup an uncaught exception handler for non-local mode.
    // Make any thread terminations due to uncaught exceptions kill the entire
    // executor process to avoid surprising stalls.
    Thread.setDefaultUncaughtExceptionHandler(uncaughtExceptionHandler)
  }

  // Start worker thread pool
  // 启动worker线程池
  private val threadPool = {
    val threadFactory = new ThreadFactoryBuilder()
      .setDaemon(true)
      .setNameFormat("Executor task launch worker-%d")
      .setThreadFactory(new ThreadFactory {
        override def newThread(r: Runnable): Thread =
          // Use UninterruptibleThread to run tasks so that we can allow running codes without being
          // interrupted by `Thread.interrupt()`. Some issues, such as KAFKA-1894, HADOOP-10622,
          // will hang forever if some methods are interrupted.
          new UninterruptibleThread(r, "unused") // thread name will be set by ThreadFactoryBuilder
      })
      .build()
    Executors.newCachedThreadPool(threadFactory).asInstanceOf[ThreadPoolExecutor]
  }
  // 采集executor worker线程池运行相关状态信息
  private val executorSource = new ExecutorSource(threadPool, executorId)
  // Pool used for threads that supervise task killing / cancellation
  // 用于监督任务的kill和取消
  private val taskReaperPool = ThreadUtils.newDaemonCachedThreadPool("Task reaper")
  // For tasks which are in the process of being killed, this map holds the most recently created
  // TaskReaper. All accesses to this map should be synchronized on the map itself (this isn't
  // a ConcurrentHashMap because we use the synchronization for purposes other than simply guarding
  // the integrity of the map's internal state). The purpose of this map is to prevent the creation
  // of a separate TaskReaper for every killTask() of a given task. Instead, this map allows us to
  // track whether an existing TaskReaper fulfills the role of a TaskReaper that we would otherwise
  // create. The map key is a task id.
  // 用户缓存正在被kill的Task的身份标识与执行kill工作的任务收割者（TaskReaper）之间的映射关系。
  private val taskReaperForTask: HashMap[Long, TaskReaper] = HashMap[Long, TaskReaper]()

  if (!isLocal) {
    env.blockManager.initialize(conf.getAppId)
    env.metricsSystem.registerSource(executorSource)
    env.metricsSystem.registerSource(env.blockManager.shuffleMetricsSource)
  }

  // Whether to load classes in user jars before those in Spark jars
  // 是否先加载用户jar中的类，然后再加载Spark jar中的类
  private val userClassPathFirst = conf.getBoolean("spark.executor.userClassPathFirst", false)

  // Whether to monitor killed / interrupted tasks
  // 是否监控kill和中断的任务
  private val taskReaperEnabled = conf.getBoolean("spark.task.reaper.enabled", false)

  // Create our ClassLoader
  // do this after SparkEnv creation so can access the SecurityManager
  //Task需要的类加载器。
  private val urlClassLoader = createClassLoader()
  // spark-shell/spark-sql使用的类加载器
  private val replClassLoader = addReplClassLoaderIfNeeded(urlClassLoader)

  // Set the classloader for serializer
  env.serializer.setDefaultClassLoader(replClassLoader)
  // SPARK-21928.  SerializerManager's internal instance of Kryo might get used in netty threads
  // for fetching remote cached RDD blocks, so need to make sure it uses the right classloader too.
  env.serializerManager.setDefaultClassLoader(replClassLoader)

  /**
   * executor插件
   */
  private val executorPlugins: Seq[ExecutorPlugin] = {
    val pluginNames = conf.get(EXECUTOR_PLUGINS)
    if (pluginNames.nonEmpty) {
      logDebug(s"Initializing the following plugins: ${pluginNames.mkString(", ")}")

      // Plugins need to load using a class loader that includes the executor's user classpath
      val pluginList: Seq[ExecutorPlugin] =
        Utils.withContextClassLoader(replClassLoader) {
          val plugins = Utils.loadExtensions(classOf[ExecutorPlugin], pluginNames, conf)
          plugins.foreach { plugin =>
            plugin.init()
            logDebug(s"Successfully loaded plugin " + plugin.getClass().getCanonicalName())
          }
          plugins
        }

      logDebug("Finished initializing plugins")
      pluginList
    } else {
      Nil
    }
  }

  // Max size of direct result. If task result is bigger than this, we use the block manager
  // to send the result back.
  //直接结果的最大大小。取spark.task.maxDirectResultSize属性（默认为1L << 20，即1048 576）
  // 与spark.rpc.message.maxSize属性（默认为128MB）之间的最小值。
  private val maxDirectResultSize = Math.min(
    conf.getSizeAsBytes("spark.task.maxDirectResultSize", 1L << 20),
    RpcUtils.maxMessageSizeBytes(conf))

  // 结果的最大限制。此属性通过调用Utils工具类的getMaxResultSize方法获得，默认为1GB。Task运行的结果如果超过maxResultSize，则会被删除。Task运行的结果如果小于等于maxResultSize且大于maxDirectResultSize，则会写入本地存储体系。Task运行的结果如果小于等于maxDirectResultSize，则会直接返回给Driver。
  private val maxResultSize = conf.get(MAX_RESULT_SIZE)

  // Maintains the list of running tasks.
  // 用于维护正在运行的Task的身份标识与TaskRunner之间的映射关系。
  private val runningTasks = new ConcurrentHashMap[Long, TaskRunner]

  /**
   * Interval to send heartbeats, in milliseconds
   */
  private val HEARTBEAT_INTERVAL_MS = conf.get(EXECUTOR_HEARTBEAT_INTERVAL)

  // Executor for the heartbeat task.
  // 心跳线程池
  private val heartbeater: ScheduledExecutorService = ThreadUtils.newDaemonSingleThreadScheduledExecutor("driver-heartbeater")

  // must be initialized before running startDriverHeartbeat()
  // executor心跳接收器 rpc应用
  private val heartbeatReceiverRef =
    RpcUtils.makeDriverRef(HeartbeatReceiver.ENDPOINT_NAME, conf, env.rpcEnv)

  /**
   * 心跳最大失败次数
   * When an executor is unable to send heartbeats to the driver more than `HEARTBEAT_MAX_FAILURES`
   * times, it should kill itself. The default value is 60. It means we will retry to send
   * heartbeats about 10 minutes because the heartbeat interval is 10s.
   */
  private val HEARTBEAT_MAX_FAILURES = conf.getInt("spark.executor.heartbeat.maxFailures", 60)

  /**
   * Count the failure times of heartbeat. It should only be accessed in the heartbeat thread. Each
   * successful heartbeat will reset it to 0.
   */
  private var heartbeatFailures = 0
```

## Executor心跳报告

* 初始化Executor的过程中，Executor会调用自己的startDriverHeartbeater方法启动心跳报告的定时任务。

```scala
private def startDriverHeartbeater(): Unit = {
    // 心跳间隔
    val intervalMs = HEARTBEAT_INTERVAL_MS

    // Wait a random interval so the heartbeats don't end up in sync
    // 初始化时间，心跳间隔+0～1 * 心跳间隔
    val initialDelay = intervalMs + (math.random * intervalMs).asInstanceOf[Int]

    // 心跳任务
    val heartbeatTask = new Runnable() {
      override def run(): Unit = Utils.logUncaughtExceptions(reportHeartBeat())
    }
    // 启动心跳定时调度
    heartbeater.scheduleAtFixedRate(heartbeatTask, initialDelay, intervalMs, TimeUnit.MILLISECONDS)
  }
```

### 报告心跳

```scala
private def reportHeartBeat(): Unit = {
    // list of (task id, accumUpdates) to send back to the driver
    val accumUpdates = new ArrayBuffer[(Long, Seq[AccumulatorV2[_, _]])]()
    val curGCTime = computeTotalGcTime()
  //遍历runningTasks中正在运行的Task，将每个Task的度量信息更新到数组缓冲accumUpdates中。
    for (taskRunner <- runningTasks.values().asScala) {
      if (taskRunner.task != null) {
        taskRunner.task.metrics.mergeShuffleReadMetrics()
        taskRunner.task.metrics.setJvmGCTime(curGCTime - taskRunner.startGCTime)
        accumUpdates += ((taskRunner.taskId, taskRunner.task.metrics.accumulators()))
      }
    }

      // 保证心跳消息
    val message: Heartbeat = Heartbeat(executorId, accumUpdates.toArray, env.blockManager.blockManagerId)
    try {
      //向HeartbeatReceiver发送Heartbeat消息，并接收HeartbeatReceiver的响应消息HeartbeatResponse。
      val response = heartbeatReceiverRef.askSync[HeartbeatResponse](
          message, new RpcTimeout(HEARTBEAT_INTERVAL_MS.millis, EXECUTOR_HEARTBEAT_INTERVAL.key))
      if (response.reregisterBlockManager) {
        logInfo("Told to re-register on heartbeat")
        env.blockManager.reregister()
      }
      //将heartbeatFailures置为0。
      heartbeatFailures = 0
    } catch {
      case NonFatal(e) =>
        logWarning("Issue communicating with driver in heartbeater", e)
        heartbeatFailures += 1
        if (heartbeatFailures >= HEARTBEAT_MAX_FAILURES) {
          logError(s"Exit as unable to send heartbeats to driver " +
            s"more than $HEARTBEAT_MAX_FAILURES times")
          System.exit(ExecutorExitCode.HEARTBEAT_FAILURE)
        }
    }
  }
```

## 运行Task

```scala
def launchTask(context: ExecutorBackend, taskDescription: TaskDescription): Unit = {
    // 创建任务线程
    val tr = new TaskRunner(context, taskDescription)
    // 任务id添加进runningTasks集合
    runningTasks.put(taskDescription.taskId, tr)
    // 线程池异步执行task
    threadPool.execute(tr)
  }
```