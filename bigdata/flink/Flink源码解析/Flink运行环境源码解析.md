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

## 执行环境创建

### 根据运行环境创建对应执行环境

```java
	public static StreamExecutionEnvironment getExecutionEnvironment() {
		// 解析执行环境创建工程，如果不存在则创建本地执行环境，根据任务运行环境区分
		return Utils.resolveFactory(threadLocalContextEnvironmentFactory, contextEnvironmentFactory)
			.map(StreamExecutionEnvironmentFactory::createExecutionEnvironment)
			.orElseGet(StreamExecutionEnvironment::createLocalEnvironment);
	}
```

### 本地执行环境

```java
public static LocalStreamEnvironment createLocalEnvironment(int parallelism, Configuration configuration) {
		final LocalStreamEnvironment currentEnvironment;

		// 创建本地执行环境，传入空配置，并将execution.target设置为local
		currentEnvironment = new LocalStreamEnvironment(configuration);
		currentEnvironment.setParallelism(parallelism);

		return currentEnvironment;
	}

## 本地运行环境webUI
  	public static StreamExecutionEnvironment createLocalEnvironmentWithWebUI(Configuration conf) {
		checkNotNull(conf, "conf");

		if (!conf.contains(RestOptions.PORT)) {
			// explicitly set this option so that it's not set to 0 later
			conf.setInteger(RestOptions.PORT, RestOptions.PORT.defaultValue());
		}

		return createLocalEnvironment(defaultLocalParallelism, conf);
	}
```

### 远程执行环境

```java
	private static Configuration getEffectiveConfiguration(
			final Configuration baseConfiguration,
			final String host,
			final int port,
			final String[] jars,
			final List<URL> classpaths,
			final SavepointRestoreSettings savepointRestoreSettings) {

		// 将客户端传入配置合并
		final Configuration effectiveConfiguration = new Configuration(baseConfiguration);

		// 设置jobManager配置
		RemoteEnvironmentConfigUtils.setJobManagerAddressToConfig(host, port, effectiveConfiguration);
		// 设置执行jar包路径
		RemoteEnvironmentConfigUtils.setJarURLsToConfig(jars, effectiveConfiguration);
		ConfigUtils.encodeCollectionToConfig(effectiveConfiguration, PipelineOptions.CLASSPATHS, classpaths, URL::toString);

		if (savepointRestoreSettings != null) {
			// 设置savepoint配置
			SavepointRestoreSettings.toConfiguration(savepointRestoreSettings, effectiveConfiguration);
		} else {
			SavepointRestoreSettings.toConfiguration(SavepointRestoreSettings.none(), effectiveConfiguration);
		}

		// these should be set in the end to overwrite any values from the client config provided in the constructor.
		effectiveConfiguration.setString(DeploymentOptions.TARGET, "remote");
		effectiveConfiguration.setBoolean(DeploymentOptions.ATTACHED, true);

		return effectiveConfiguration;
	}
```

## 注册分布式缓存文件

### registerCachedFile

* 将本地文件或者分布式文件注册到分布式缓存中，如果需要，运行时会将文件临时复制到本地缓存中。
* 可以通过RuntimeContext#getDistibutedCache读取

```
	public void registerCachedFile(String filePath, String name, boolean executable) {
		// 文件映射存储Tuple2元组
		this.cacheFile.add(new Tuple2<>(name, new DistributedCache.DistributedCacheEntry(filePath, executable)));
	}
```

# ExecutionEnvironment

## 环境属性相关配置

```java
private static ExecutionEnvironmentFactory contextEnvironmentFactory = null;

	/** The ThreadLocal used to store {@link ExecutionEnvironmentFactory}. */
	private static final ThreadLocal<ExecutionEnvironmentFactory> threadLocalContextEnvironmentFactory = new ThreadLocal<>();

	/** The default parallelism used by local environments. */
	private static int defaultLocalDop = Runtime.getRuntime().availableProcessors();


	// sink算子数组
	private final List<DataSink<?>> sinks = new ArrayList<>();

	private final List<Tuple2<String, DistributedCacheEntry>> cacheFile = new ArrayList<>();

	private final ExecutionConfig config = new ExecutionConfig();

	/** Result from the latest execution, to make it retrievable when using eager execution methods. */
	protected JobExecutionResult lastJobExecutionResult;

	/** Flag to indicate whether sinks have been cleared in previous executions. */
	private boolean wasExecuted = false;

	private final PipelineExecutorServiceLoader executorServiceLoader;

	private final Configuration configuration;

	private final ClassLoader userClassloader;

	private final List<JobListener> jobListeners = new ArrayList<>();
```

## 任务执行

* dataSinks->Plan->JobGraph(这里和Stream一致，最终都需要转换成JobGraph提交给对应的集群环境)

```java
# dataSinks转换Plan
public Plan createProgramPlan(String jobName, boolean clearSinks) {
		checkNotNull(jobName);

		if (this.sinks.isEmpty()) {
			if (wasExecuted) {
				throw new RuntimeException("No new data sinks have been defined since the " +
						"last execution. The last execution refers to the latest call to " +
						"'execute()', 'count()', 'collect()', or 'print()'.");
			} else {
				throw new RuntimeException("No data sinks have been created yet. " +
						"A program needs at least one sink that consumes data. " +
						"Examples are writing the data set or printing it.");
			}
		}

		final PlanGenerator generator = new PlanGenerator(
				sinks, config, getParallelism(), cacheFile, jobName);
		final Plan plan = generator.generate();

		// clear all the sinks such that the next execution does not redo everything
		if (clearSinks) {
			this.sinks.clear();
			wasExecuted = true;
		}

		return plan;
	}
```

### PlanGenerator

```java
public class PlanGenerator {

	private static final Logger LOG = LoggerFactory.getLogger(PlanGenerator.class);

	private final List<DataSink<?>> sinks;
	private final ExecutionConfig config;
	private final int defaultParallelism;
	private final List<Tuple2<String, DistributedCache.DistributedCacheEntry>> cacheFile;
	private final String jobName;

	public PlanGenerator(
			List<DataSink<?>> sinks,
			ExecutionConfig config,
			int defaultParallelism,
			List<Tuple2<String, DistributedCache.DistributedCacheEntry>> cacheFile,
			String jobName) {
		this.sinks = checkNotNull(sinks);
		this.config = checkNotNull(config);
		this.cacheFile = checkNotNull(cacheFile);
		this.jobName = checkNotNull(jobName);
		this.defaultParallelism = defaultParallelism;
	}

	public Plan generate() {
		final Plan plan = createPlan();
		registerGenericTypeInfoIfConfigured(plan);
		registerCachedFiles(plan);

		logTypeRegistrationDetails();
		return plan;
	}

	/**
	 * Create plan.
	 *
	 * @return the generated plan.
	 */
	private Plan createPlan() {
		final OperatorTranslation translator = new OperatorTranslation();
		final Plan plan = translator.translateToPlan(sinks, jobName);

		if (defaultParallelism > 0) {
			plan.setDefaultParallelism(defaultParallelism);
		}
		plan.setExecutionConfig(config);
		return plan;
	}

	/**
	 * Check plan for GenericTypeInfo's and register the types at the serializers.
	 *
	 * @param plan the generated plan.
	 */
	private void registerGenericTypeInfoIfConfigured(Plan plan) {
		if (!config.isAutoTypeRegistrationDisabled()) {
			plan.accept(new Visitor<Operator<?>>() {

				private final Set<Class<?>> registeredTypes = new HashSet<>();
				private final Set<org.apache.flink.api.common.operators.Operator<?>> visitedOperators = new HashSet<>();

				@Override
				public boolean preVisit(org.apache.flink.api.common.operators.Operator<?> visitable) {
					if (!visitedOperators.add(visitable)) {
						return false;
					}
					OperatorInformation<?> opInfo = visitable.getOperatorInfo();
					Serializers.recursivelyRegisterType(opInfo.getOutputType(), config, registeredTypes);
					return true;
				}

				@Override
				public void postVisit(org.apache.flink.api.common.operators.Operator<?> visitable) {
				}
			});
		}
	}

	private void registerCachedFiles(Plan plan) {
		try {
			registerCachedFilesWithPlan(plan);
		} catch (Exception e) {
			throw new RuntimeException("Error while registering cached files: " + e.getMessage(), e);
		}
	}

	/**
	 * Registers all files that were registered at this execution environment's cache registry of the
	 * given plan's cache registry.
	 *
	 * @param p The plan to register files at.
	 * @throws IOException Thrown if checks for existence and sanity fail.
	 */
	private void registerCachedFilesWithPlan(Plan p) throws IOException {
		for (Tuple2<String, DistributedCache.DistributedCacheEntry> entry : cacheFile) {
			p.registerCachedFile(entry.f0, entry.f1);
		}
	}

	private void logTypeRegistrationDetails() {
		int registeredTypes = getNumberOfRegisteredTypes();
		int defaultKryoSerializers = getNumberOfDefaultKryoSerializers();

		LOG.info("The job has {} registered types and {} default Kryo serializers", registeredTypes, defaultKryoSerializers);

		if (config.isForceKryoEnabled() && config.isForceAvroEnabled()) {
			LOG.warn("In the ExecutionConfig, both Avro and Kryo are enforced. Using Kryo serializer for serializing POJOs");
		} else if (config.isForceKryoEnabled()) {
			LOG.info("Using KryoSerializer for serializing POJOs");
		} else if (config.isForceAvroEnabled()) {
			LOG.info("Using AvroSerializer for serializing POJOs");
		}

		if (LOG.isDebugEnabled()) {
			logDebuggingTypeDetails();
		}
	}

	private int getNumberOfRegisteredTypes() {
		return config.getRegisteredKryoTypes().size() +
				config.getRegisteredPojoTypes().size() +
				config.getRegisteredTypesWithKryoSerializerClasses().size() +
				config.getRegisteredTypesWithKryoSerializers().size();
	}

	private int getNumberOfDefaultKryoSerializers() {
		return config.getDefaultKryoSerializers().size() +
				config.getDefaultKryoSerializerClasses().size();
	}

	private void logDebuggingTypeDetails() {
		LOG.debug("Registered Kryo types: {}", config.getRegisteredKryoTypes().toString());
		LOG.debug("Registered Kryo with Serializers types: {}",
				config.getRegisteredTypesWithKryoSerializers().entrySet().toString());
		LOG.debug("Registered Kryo with Serializer Classes types: {}",
				config.getRegisteredTypesWithKryoSerializerClasses().entrySet().toString());
		LOG.debug("Registered Kryo default Serializers: {}",
				config.getDefaultKryoSerializers().entrySet().toString());
		LOG.debug("Registered Kryo default Serializers Classes {}",
				config.getDefaultKryoSerializerClasses().entrySet().toString());
		LOG.debug("Registered POJO types: {}", config.getRegisteredPojoTypes().toString());

		// print information about static code analysis
		LOG.debug("Static code analysis mode: {}", config.getCodeAnalysisMode());
	}
}
```

* 执行环境创建于Stream类似