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

