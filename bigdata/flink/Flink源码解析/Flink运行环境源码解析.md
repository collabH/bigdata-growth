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

