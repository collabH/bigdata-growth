# StreamExecutionEnvironment

## 环境属性相关配置

```java
  public static final String DEFAULT_JOB_NAME = "Flink Streaming Job";
	private static final TimeCharacteristic DEFAULT_TIME_CHARACTERISTIC = TimeCharacteristic.ProcessingTime;
	private static final long DEFAULT_NETWORK_BUFFER_TIMEOUT = 100L;
	/**上下文环境*/
	private static StreamExecutionEnvironmentFactory contextEnvironmentFactory = null;
	private static final ThreadLocal<StreamExecutionEnvironmentFactory> threadLocalContextEnvironmentFactory = new ThreadLocal<>();
	// 默认本地并行度为当前机器core数
	private static int defaultLocalParallelism = Runtime.getRuntime().availableProcessors();
	// 当前环境执行配置，包含并行度、序列化方式等
	private final ExecutionConfig config = new ExecutionConfig();
	// 配置控制checkpoint行为
	private final CheckpointConfig checkpointCfg = new CheckpointConfig();
	/**transformation算子集合，记录从基础的transformations到最终transforms的逻辑集合*/
	protected final List<Transformation<?>> transformations = new ArrayList<>();
	// buffer刷新的频率
	private long bufferTimeout = DEFAULT_NETWORK_BUFFER_TIMEOUT;
	// 是否开启任务链优化，相同并行度的one-to-one算子会放在同一个task slot中，优化网络io
	protected boolean isChainingEnabled = true;
	// 默认状态后端，用于存储kv状态和状态快照
	private StateBackend defaultStateBackend;
	/** 默认时间语义：processing time**/
	private TimeCharacteristic timeCharacteristic = DEFAULT_TIME_CHARACTERISTIC;
	// 分布式缓存文件
	protected final List<Tuple2<String, DistributedCache.DistributedCacheEntry>> cacheFile = new ArrayList<>();
	/*executor服务加载器，加载yarn、local、k8s等相关执行器*/
	private final PipelineExecutorServiceLoader executorServiceLoader;
	private final Configuration configuration;
	// 用户指定的累加载器
	private final ClassLoader userClassloader;
	/**任务监听器，监听job状态的变化*/
	private final List<JobListener> jobListeners = new ArrayList<>();
```

## 数据流相关操作

### 读取文件操作

* 底层依赖于文件的修改时间做的checkpoint，记录文件修改时间，读取大于最后文件修改时间的文件

## StreamEnv执行

* Transformations->StreamGraph->JobGraph
* 核型类方法

```java
	public JobClient executeAsync(StreamGraph streamGraph) throws Exception {
		checkNotNull(streamGraph, "StreamGraph cannot be null.");
		checkNotNull(configuration.get(DeploymentOptions.TARGET), "No execution.target specified in your configuration file.");

		final PipelineExecutorFactory executorFactory =
			executorServiceLoader.getExecutorFactory(configuration);

		checkNotNull(
			executorFactory,
			"Cannot find compatible factory for specified execution.target (=%s)",
			configuration.get(DeploymentOptions.TARGET));

		// 通过executorFactory得到特定配置的executor
		CompletableFuture<JobClient> jobClientFuture = executorFactory
			.getExecutor(configuration)
			.execute(streamGraph, configuration);

		try {
			JobClient jobClient = jobClientFuture.get();
			jobListeners.forEach(jobListener -> jobListener.onJobSubmitted(jobClient, null));
			return jobClient;
		} catch (ExecutionException executionException) {
			final Throwable strippedException = ExceptionUtils.stripExecutionException(executionException);
			jobListeners.forEach(jobListener -> jobListener.onJobSubmitted(null, strippedException));

			throw new FlinkException(
				String.format("Failed to execute job '%s'.", streamGraph.getJobName()),
				strippedException);
		}
	}
```

