# StreamExecutionEnvironment

## 环境属性相关配置

```java
 // 一个迭代器，迭代一个查询作业的结果。
    private final List<CollectResultIterator<?>> collectIterators = new ArrayList<>();

    @Internal
    public void registerCollectIterator(CollectResultIterator<?> iterator) {
        collectIterators.add(iterator);
    }
    /**
     * The default name to use for a streaming job if no other name has been specified.
     *
     * @deprecated This constant does not fit well to batch runtime mode.
     */
    @Deprecated
    public static final String DEFAULT_JOB_NAME = StreamGraphGenerator.DEFAULT_STREAMING_JOB_NAME;

    /** The time characteristic that is used if none other is set. */
    private static final TimeCharacteristic DEFAULT_TIME_CHARACTERISTIC =
            TimeCharacteristic.EventTime;

    /**
     * The environment of the context (local by default, cluster if invoked through command line).
     */
    private static StreamExecutionEnvironmentFactory contextEnvironmentFactory = null;

    /** The ThreadLocal used to store {@link StreamExecutionEnvironmentFactory}. */
    private static final ThreadLocal<StreamExecutionEnvironmentFactory>
            threadLocalContextEnvironmentFactory = new ThreadLocal<>();

    /** The default parallelism used when creating a local environment. */
    private static int defaultLocalParallelism = Runtime.getRuntime().availableProcessors();

    /** The execution configuration for this environment. */
    // 当前环境执行配置，包含并行度、序列化方式等
    protected final ExecutionConfig config = new ExecutionConfig();

    /** Settings that control the checkpointing behavior. */
    // ck配置
    protected final CheckpointConfig checkpointCfg = new CheckpointConfig();

    /**transformation算子集合，记录从基础的transformations到最终transforms的逻辑集合*/
    protected final List<Transformation<?>> transformations = new ArrayList<>();

    // cacheStream实现逻辑
    private final Map<AbstractID, CacheTransformation<?>> cachedTransformations = new HashMap<>();
    // buffer刷新的频率
    private long bufferTimeout = ExecutionOptions.BUFFER_TIMEOUT.defaultValue().toMillis();

    // 是否开启opeartor chain优化
    protected boolean isChainingEnabled = true;

    /** The state backend used for storing k/v state and state snapshots. */
    // 默认状态后端
    private StateBackend defaultStateBackend;

    /** Whether to enable ChangelogStateBackend, default value is unset. */
    // 是否开启changelog ck
    private TernaryBoolean changelogStateBackendEnabled = TernaryBoolean.UNDEFINED;

    /** The default savepoint directory used by the job. */
    private Path defaultSavepointDirectory;

    /** The time characteristic used by the data streams. */
    private TimeCharacteristic timeCharacteristic = DEFAULT_TIME_CHARACTERISTIC;

    protected final List<Tuple2<String, DistributedCache.DistributedCacheEntry>> cacheFile =
            new ArrayList<>();
    /*executor服务加载器，加载yarn、local、k8s等相关执行器*/
    private final PipelineExecutorServiceLoader executorServiceLoader;

    /**
     * Currently, configuration is split across multiple member variables and classes such as {@link
     * ExecutionConfig} or {@link CheckpointConfig}. This architecture makes it quite difficult to
     * handle/merge/enrich configuration or restrict access in other APIs.
     *
     * <p>In the long-term, this {@link Configuration} object should be the source of truth for
     * newly added {@link ConfigOption}s that are relevant for DataStream API. Make sure to also
     * update {@link #configure(ReadableConfig, ClassLoader)}.
     */
    protected final Configuration configuration;

    private final ClassLoader userClassloader;

    private final List<JobListener> jobListeners = new ArrayList<>();

    // Records the slot sharing groups and their corresponding fine-grained ResourceProfile
    private final Map<String, ResourceProfile> slotSharingGroupResources = new HashMap<>();
```

## 数据流相关操作

### 读取文件操作

* 底层依赖于文件的修改时间做的checkpoint，记录文件修改时间，读取大于最后文件修改时间的文件

## StreamEnv执行

* Transformations->StreamGraph->JobGraph
* 核心类方法

```java
 public JobClient executeAsync(StreamGraph streamGraph) throws Exception {
        checkNotNull(streamGraph, "StreamGraph cannot be null.");
        // 根据execution.target配置获取执行器
        final PipelineExecutor executor = getPipelineExecutor();

        // streamGraph提交转换成jobGraph-》executionGraph-》物理执行图
        CompletableFuture<JobClient> jobClientFuture =
                executor.execute(streamGraph, configuration, userClassloader);

        try {
            // 获取job客户端
            JobClient jobClient = jobClientFuture.get();
            // 触发监听器螺距
            jobListeners.forEach(jobListener -> jobListener.onJobSubmitted(jobClient, null));
            // job执行结果放入collectIterators
            collectIterators.forEach(iterator -> iterator.setJobClient(jobClient));
            collectIterators.clear();
            return jobClient;
        } catch (ExecutionException executionException) {
            final Throwable strippedException =
                    ExceptionUtils.stripExecutionException(executionException);
            jobListeners.forEach(
                    jobListener -> jobListener.onJobSubmitted(null, strippedException));

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
                .map(factory -> factory.createExecutionEnvironment(configuration))
                .orElseGet(() -> StreamExecutionEnvironment.createLocalEnvironment(configuration));
	}
```

### 本地执行环境

```java
  public static LocalStreamEnvironment createLocalEnvironment(Configuration configuration) {
        if (configuration.getOptional(CoreOptions.DEFAULT_PARALLELISM).isPresent()) {
            return new LocalStreamEnvironment(configuration);
        } else {
            Configuration copyOfConfiguration = new Configuration();
            copyOfConfiguration.addAll(configuration);
            copyOfConfiguration.set(CoreOptions.DEFAULT_PARALLELISM, defaultLocalParallelism);
            return new LocalStreamEnvironment(copyOfConfiguration);
        }
    }

// 本地运行环境webUI
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
// RemoteStreamEnvironment类下	
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

```java
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

* `dataSinks->Plan->JobGraph`(这里和Stream一致，最终都需要转换成JobGraph提交给对应的集群环境)

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
// 将dataSink转换称plan
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

# TableEnvironment

* 链接外部系统
* 通过catalog注册和检索其他元数据对象 
* 执行SQL语句
* 设置配置参数

## 接口方法

```java
public interface TableEnvironment {
  // 创建Table执行环境，入参配置使用的执行器和流/批模式
  static TableEnvironment create(EnvironmentSettings settings) {
		return TableEnvironmentImpl.create(settings);
	}
  // 通过Configuration配置创建table执行环境
    static TableEnvironment create(Configuration configuration) {
        return TableEnvironmentImpl.create(configuration);
    }
  /**
  使用方式，从传入对象构造Table对象
  *	 <pre>{@code
	 *  tEnv.fromValues(
	 *      row(1, "ABC"),
	 *      row(2L, "ABCDE")
	 *  )
	 * }</pre>
  */
	Table fromValues(Expression... values);
  
  /*  tEnv.fromValues(
	 *      DataTypes.ROW(
	 *          DataTypes.FIELD("id", DataTypes.DECIMAL(10, 2)),
	 *          DataTypes.FIELD("name", DataTypes.STRING())
	 *      ),
	 *      row(1, "ABC"),
	 *      row(2L, "ABCDE")
	  )
   */  
	Table fromValues(AbstractDataType<?> rowType, Expression... values);
  
  // 传递迭代器
  Table fromValues(Iterable<?> values);
  Table fromValues(AbstractDataType<?> rowType, Iterable<?> values);
  // 注册catalog
  void registerCatalog(String catalogName, Catalog catalog);
  // 根据catalogName获取catalog
  Optional<Catalog> getCatalog(String catalogName);
  // 根据moduleName记载一个Module，会根据顺序加载Module，如果已经存在抛出异常，module主要记录一些catalog函数和flink内置函数
  void loadModule(String moduleName, Module module);
  void unloadModule(String moduleName);
  // 注册临时UDF函数
  void createTemporarySystemFunction(String name, Class<? extends UserDefinedFunction> functionClass);
  void createTemporarySystemFunction(String name, UserDefinedFunction functionInstance);
  boolean dropTemporarySystemFunction(String name);
  void createFunction(String path, Class<? extends UserDefinedFunction> functionClass);
	void createFunction(String path, Class<? extends UserDefinedFunction> functionClass, boolean ignoreIfExists);
  boolean dropFunction(String path);
  void createTemporaryFunction(String path, Class<? extends UserDefinedFunction> functionClass);
  boolean dropTemporaryFunction(String path);
  void createTemporaryView(String path, Table view);
  Table from(String path);
  String[] listCatalogs();
  String[] listModules();
  String[] listDatabases();
  String[] listTables();
  String[] listViews();
  // 分析sql执行计划
  String explainSql(String statement, ExplainDetail... extraDetails);
  Table sqlQuery(String query);
  TableResult executeSql(String statement);
  String getCurrentCatalog();
  void useCatalog(String catalogName);
  String getCurrentDatabase();
  void useDatabase(String databaseName);
  TableConfig getConfig();
  StatementSet createStatementSet();
}
```

## TableEnvironmentInternal

* 表环境内部接口

```java
public interface TableEnvironmentInternal extends TableEnvironment {

	Parser getParser();

	CatalogManager getCatalogManager();

	TableResult executeInternal(List<ModifyOperation> operations);

	TableResult executeInternal(QueryOperation operation);

	String explainInternal(List<Operation> operations, ExplainDetail... extraDetails);

	void registerTableSourceInternal(String name, TableSource<?> tableSource);

	void registerTableSinkInternal(String name, TableSink<?> configuredSink);
}
```

## 核心方法实现

### FromValues

```java
// 底层调用createTable方法
public Table fromValues(AbstractDataType<?> rowType, Expression... values) {
		// 将rowType解析成dataType
		final DataType resolvedDataType = catalogManager.getDataTypeFactory().createDataType(rowType);
		// 将表达式转换成QueryOperation
		return createTable(operationTreeBuilder.values(resolvedDataType, values));
	}
```

### registerCatalog

```java
  public void registerCatalog(String catalogName, Catalog catalog) {
		catalogManager.registerCatalog(catalogName, catalog);
	}
	
	public void registerCatalog(String catalogName, Catalog catalog) {
		// 校验catalogname是否合法
		checkArgument(!StringUtils.isNullOrWhitespaceOnly(catalogName), "Catalog name cannot be null or empty.");
		// 校验catalog
		checkNotNull(catalog, "Catalog cannot be null");

		// 判断catalog是否已经存在
		if (catalogs.containsKey(catalogName)) {
			throw new CatalogException(format("Catalog %s already exists.", catalogName));
		}

		// 将catalog放入catalogs linkedHashMap有序链表map中
		catalogs.put(catalogName, catalog);
		// 初始化catalog链接
		catalog.open();
	}
```

### loadModule

```java
public void loadModule(String moduleName, Module module) {
		moduleManager.loadModule(moduleName, module);
	}
	
		public void loadModule(String name, Module module) {
		checkArgument(!StringUtils.isNullOrWhitespaceOnly(name), "name cannot be null or empty string");
		checkNotNull(module, "module cannot be null");

		// 类似于catalog操作
		if (!modules.containsKey(name)) {
			modules.put(name, module);

			LOG.info("Loaded module {} from class {}", name, module.getClass().getName());
		} else {
			throw new ValidationException(
				String.format("A module with name %s already exists", name));
		}
	}
```

### createTemporarySystemFunction

```java
	public void createTemporarySystemFunction(String name, UserDefinedFunction functionInstance) {
		// 注册临时系统函数
		functionCatalog.registerTemporarySystemFunction(
			name,
			functionInstance,
			false);
	}

private void registerTemporarySystemFunction(
			String name,
			CatalogFunction function,
			boolean ignoreIfExists) {
		// 将functionName转换为全小写
		final String normalizedName = FunctionIdentifier.normalizeName(name);

		try {
			// 校验函数
			validateAndPrepareFunction(function);
		} catch (Throwable t) {
			throw new ValidationException(
				String.format(
					"Could not register temporary system function '%s' due to implementation errors.",
					name),
				t);
		}

		if (!tempSystemFunctions.containsKey(normalizedName)) {
			tempSystemFunctions.put(normalizedName, function);
		} else if (!ignoreIfExists) {
			throw new ValidationException(
				String.format(
					"Could not register temporary system function. A function named '%s' does already exist.",
					name));
		}
	}
```

### createFunction

```java
	public void createFunction(String path, Class<? extends UserDefinedFunction> functionClass, boolean ignoreIfExists) {
		final UnresolvedIdentifier unresolvedIdentifier = parser.parseIdentifier(path);
		functionCatalog.registerCatalogFunction(
			unresolvedIdentifier,
			functionClass,
			ignoreIfExists);
	}
	
		public void registerCatalogFunction(
			UnresolvedIdentifier unresolvedIdentifier,
			Class<? extends UserDefinedFunction> functionClass,
			boolean ignoreIfExists) {
		final ObjectIdentifier identifier = catalogManager.qualifyIdentifier(unresolvedIdentifier);
		final ObjectIdentifier normalizedIdentifier = FunctionIdentifier.normalizeObjectIdentifier(identifier);

		try {
			UserDefinedFunctionHelper.validateClass(functionClass);
		} catch (Throwable t) {
			throw new ValidationException(
				String.format(
					"Could not register catalog function '%s' due to implementation errors.",
					identifier.asSummaryString()),
				t);
		}

		final Catalog catalog = catalogManager.getCatalog(normalizedIdentifier.getCatalogName())
			.orElseThrow(IllegalStateException::new);
		final ObjectPath path = identifier.toObjectPath();

		// we force users to deal with temporary catalog functions first
		// 判断内存中是否存在
		if (tempCatalogFunctions.containsKey(normalizedIdentifier)) {
			if (ignoreIfExists) {
				return;
			}
			throw new ValidationException(
				String.format(
					"Could not register catalog function. A temporary function '%s' does already exist. " +
						"Please drop the temporary function first.",
					identifier.asSummaryString()));
		}

		// 判断该catalog是否存在
		if (catalog.functionExists(path)) {
			if (ignoreIfExists) {
				return;
			}
			throw new ValidationException(
				String.format(
					"Could not register catalog function. A function '%s' does already exist.",
					identifier.asSummaryString()));
		}

		final CatalogFunction catalogFunction = new CatalogFunctionImpl(
			functionClass.getName(),
			FunctionLanguage.JAVA);
		try {
			// 调用catalog创建函数
			catalog.createFunction(path, catalogFunction, ignoreIfExists);
		} catch (Throwable t) {
			throw new TableException(
				String.format(
					"Could not register catalog function '%s'.",
					identifier.asSummaryString()),
				t);
		}
	}
```

### dropFunction

```java
public boolean dropCatalogFunction(
			UnresolvedIdentifier unresolvedIdentifier,
			boolean ignoreIfNotExist) {
		final ObjectIdentifier identifier = catalogManager.qualifyIdentifier(unresolvedIdentifier);
		final ObjectIdentifier normalizedIdentifier = FunctionIdentifier.normalizeObjectIdentifier(identifier);

		final Catalog catalog = catalogManager.getCatalog(normalizedIdentifier.getCatalogName())
			.orElseThrow(IllegalStateException::new);
		final ObjectPath path = identifier.toObjectPath();

		// we force users to deal with temporary catalog functions first
		// 优先处理内存中的临时catalog函数
		if (tempCatalogFunctions.containsKey(normalizedIdentifier)) {
			throw new ValidationException(
				String.format(
					"Could not drop catalog function. A temporary function '%s' does already exist. " +
						"Please drop the temporary function first.",
					identifier.asSummaryString()));
		}

		if (!catalog.functionExists(path)) {
			if (ignoreIfNotExist) {
				return false;
			}
			throw new ValidationException(
				String.format(
					"Could not drop catalog function. A function '%s' doesn't exist.",
					identifier.asSummaryString()));
		}

		try {
			catalog.dropFunction(path, ignoreIfNotExist);
		} catch (Throwable t) {
			throw new TableException(
				String.format(
					"Could not drop catalog function '%s'.",
					identifier.asSummaryString()),
				t);
		}
		return true;
	}
```

### createTemporaryFunction

```java
public void registerTemporaryCatalogFunction(
			UnresolvedIdentifier unresolvedIdentifier,
			CatalogFunction catalogFunction,
			boolean ignoreIfExists) {
		// 处理函数标识符
		final ObjectIdentifier identifier = catalogManager.qualifyIdentifier(unresolvedIdentifier);
		final ObjectIdentifier normalizedIdentifier = FunctionIdentifier.normalizeObjectIdentifier(identifier);

		try {
			// 校验和前置处理函数
			validateAndPrepareFunction(catalogFunction);
		} catch (Throwable t) {
			throw new ValidationException(
				String.format(
					"Could not register temporary catalog function '%s' due to implementation errors.",
					identifier.asSummaryString()),
				t);
		}

		// 放入tempCatalogFunctions内存map中
		if (!tempCatalogFunctions.containsKey(normalizedIdentifier)) {
			tempCatalogFunctions.put(normalizedIdentifier, catalogFunction);
		} else if (!ignoreIfExists) {
			throw new ValidationException(
				String.format(
					"Could not register temporary catalog function. A function '%s' does already exist.",
					identifier.asSummaryString()));
		}
	}
```

### from

```java
//from->scanInternal
public Optional<TableLookupResult> getTable(ObjectIdentifier objectIdentifier) {
		Preconditions.checkNotNull(schemaResolver, "schemaResolver should not be null");
		// 获取临时表不存在从catalog中获取
		CatalogBaseTable temporaryTable = temporaryTables.get(objectIdentifier);
		if (temporaryTable != null) {
			TableSchema resolvedSchema = resolveTableSchema(temporaryTable);
			return Optional.of(TableLookupResult.temporary(temporaryTable, resolvedSchema));
		} else {
			return getPermanentTable(objectIdentifier);
		}
	}
```

### sqlQuery

```java
@Override
	public Table sqlQuery(String query) {
		// 解析query sql语句转换为Operation集合
		List<Operation> operations = parser.parse(query);

		if (operations.size() != 1) {
			throw new ValidationException(
				"Unsupported SQL query! sqlQuery() only accepts a single SQL query.");
		}

		Operation operation = operations.get(0);

		// 判断是否为QueryOperation
		if (operation instanceof QueryOperation && !(operation instanceof ModifyOperation)) {
			// 创建Table
			return createTable((QueryOperation) operation);
		} else {
			throw new ValidationException(
				"Unsupported SQL query! sqlQuery() only accepts a single SQL query of type " +
					"SELECT, UNION, INTERSECT, EXCEPT, VALUES, and ORDER_BY.");
		}
	}
	
		protected TableImpl createTable(QueryOperation tableOperation) {
		return TableImpl.createTable(
			this,
			tableOperation,
			operationTreeBuilder,
			functionCatalog.asLookup(parser::parseIdentifier));
	}
```

### executeSql

```java
public TableResult executeSql(String statement) {
		List<Operation> operations = parser.parse(statement);

		if (operations.size() != 1) {
			throw new TableException(UNSUPPORTED_QUERY_IN_EXECUTE_SQL_MSG);
		}
		// 根据不同的算子执行不同的操作
		return executeOperation(operations.get(0));
	}
```

# Blink Planner

## TableFactory

```java
public interface TableFactory {

 // 必须的属性配置，比如connector.type， format.type等
	Map<String, String> requiredContext();

/**
* 支持的属性配置
*   - schema.#.type
*   - schema.#.name
*   - connector.topic
*   - format.line-delimiter
*   - format.ignore-parse-errors
*   - format.fields.#.type
*   - format.fields.#.name
* 表示值的数组，其中“#”表示一个或多个数字
* 在某些情况下，声明通配符“ *”可能很有用。通配符只能在属性键的末尾声明。
*/
	List<String> supportedProperties();
}

```

## Factory

* 组件的工厂接口，如果存在多个匹配的实现，则可以进一步进行歧义消除

```java
public interface Factory {

    /**
     * Returns a unique identifier among same factory interfaces.
     *
     * <p>For consistency, an identifier should be declared as one lower case word (e.g. {@code
     * kafka}). If multiple factories exist for different versions, a version should be appended
     * using "-" (e.g. {@code elasticsearch-7}).
     */
    String factoryIdentifier();

    /**
     * Returns a set of {@link ConfigOption} that an implementation of this factory requires in
     * addition to {@link #optionalOptions()}.
     *
     * <p>See the documentation of {@link Factory} for more information.
     */
    Set<ConfigOption<?>> requiredOptions();

    /**
     * Returns a set of {@link ConfigOption} that an implementation of this factory consumes in
     * addition to {@link #requiredOptions()}.
     *
     * <p>See the documentation of {@link Factory} for more information.
     */
    Set<ConfigOption<?>> optionalOptions();
}
```

## ExecutorFactory

* 执行器工厂

```java
public interface ExecutorFactory extends Factory {

    String DEFAULT_IDENTIFIER = "default";

    /** Creates a corresponding {@link Executor}. */
    Executor create(Configuration configuration);
}
```

## DefaultExecutorFactory

* 默认执行器工厂

```java
public final class DefaultExecutorFactory implements StreamExecutorFactory {

    @Override
    public Executor create(Configuration configuration) {
        return create(StreamExecutionEnvironment.getExecutionEnvironment(configuration));
    }

    @Override
    public Executor create(StreamExecutionEnvironment executionEnvironment) {
        return new DefaultExecutor(executionEnvironment);
    }

    @Override
    public String factoryIdentifier() {
        return ExecutorFactory.DEFAULT_IDENTIFIER;
    }

    @Override
    public Set<ConfigOption<?>> requiredOptions() {
        return Collections.emptySet();
    }

    @Override
    public Set<ConfigOption<?>> optionalOptions() {
        return Collections.emptySet();
    }
}
```

### Executor

* createPipeline(List<Transformation<?>> transformations,TableConfig tableConfig,String jobName);
  * 将给定的transformations转换成Pipeline
* execute(Pipeline pipeline) throws Exception;
* executeAsync(Pipeline pipeline) throws Exception;

### DefaultExecutor

* 支持流批一体

```java
public class DefaultExecutor implements Executor {

   // 默认作业名
    private static final String DEFAULT_JOB_NAME = "Flink Exec Table Job";

  // 作业执行环境
    private final StreamExecutionEnvironment executionEnvironment;

    public DefaultExecutor(StreamExecutionEnvironment executionEnvironment) {
        this.executionEnvironment = executionEnvironment;
    }

    public StreamExecutionEnvironment getExecutionEnvironment() {
        return executionEnvironment;
    }

    @Override
    public ReadableConfig getConfiguration() {
        return executionEnvironment.getConfiguration();
    }

  // 创建pipeline
    @Override
    public Pipeline createPipeline(
            List<Transformation<?>> transformations,
            ReadableConfig tableConfiguration,
            @Nullable String defaultJobName) {

        // reconfigure before a stream graph is generated
        executionEnvironment.configure(tableConfiguration);

        // create stream graph
        final RuntimeExecutionMode mode = getConfiguration().get(ExecutionOptions.RUNTIME_MODE);
        switch (mode) {
            case BATCH:
            // 配置批执行属性
                configureBatchSpecificProperties();
                break;
            case STREAMING:
                break;
            case AUTOMATIC:
            default:
                throw new TableException(String.format("Unsupported runtime mode: %s", mode));
        }

      // 生成streamGraph
        final StreamGraph streamGraph = executionEnvironment.generateStreamGraph(transformations);
        setJobName(streamGraph, defaultJobName);
        return streamGraph;
    }

    @Override
    public JobExecutionResult execute(Pipeline pipeline) throws Exception {
      // 执行任务
        return executionEnvironment.execute((StreamGraph) pipeline);
    }

    @Override
    public JobClient executeAsync(Pipeline pipeline) throws Exception {
        return executionEnvironment.executeAsync((StreamGraph) pipeline);
    }

    @Override
    public boolean isCheckpointingEnabled() {
        return executionEnvironment.getCheckpointConfig().isCheckpointingEnabled();
    }

    private void configureBatchSpecificProperties() {
        executionEnvironment.getConfig().enableObjectReuse();
    }

    private void setJobName(StreamGraph streamGraph, @Nullable String defaultJobName) {
        final String adjustedDefaultJobName =
                StringUtils.isNullOrWhitespaceOnly(defaultJobName)
                        ? DEFAULT_JOB_NAME
                        : defaultJobName;
        final String jobName =
                getConfiguration().getOptional(PipelineOptions.NAME).orElse(adjustedDefaultJobName);
        streamGraph.setJobName(jobName);
    }
}
```

# Parser

* 用于将SQL字符串解析成SQL对象
* List<Operation> parse(String statement);
* UnresolvedIdentifier parseIdentifier(String identifier);
* ResolvedExpression parseSqlExpression(String sqlExpression, TableSchema inputSchema);

## ParserImpl

```java

    // catalog管理器
    private final CatalogManager catalogManager;

    // we use supplier pattern here in order to use the most up to
    // date configuration. Users might change the parser configuration in a TableConfig in between
    // multiple statements parsing
    // 校验器
    private final Supplier<FlinkPlannerImpl> validatorSupplier;
    // calcite解析器
    private final Supplier<CalciteParser> calciteParserSupplier;
    // 用于将sql解析成RexNode
    private final RexFactory rexFactory;
    // 扩展解析器主要涉及help、set、reset、CLEAR、quit等命令处理
    private static final ExtendedParser EXTENDED_PARSER = ExtendedParser.INSTANCE;

    public ParserImpl(
            CatalogManager catalogManager,
            Supplier<FlinkPlannerImpl> validatorSupplier,
            Supplier<CalciteParser> calciteParserSupplier,
            RexFactory rexFactory) {
        this.catalogManager = catalogManager;
        this.validatorSupplier = validatorSupplier;
        this.calciteParserSupplier = calciteParserSupplier;
        this.rexFactory = rexFactory;
    }

    /**
     * When parsing statement, it first uses {@link ExtendedParser} to parse statements. If {@link
     * ExtendedParser} fails to parse statement, it uses the {@link CalciteParser} to parse
     * statements.
     *
     * @param statement input statement.
     * @return parsed operations.
     */
    @Override
    public List<Operation> parse(String statement) {
        CalciteParser parser = calciteParserSupplier.get();
        FlinkPlannerImpl planner = validatorSupplier.get();

        // 处理扩展语法，help、set、reset、CLEAR、quit等命令处理
        Optional<Operation> command = EXTENDED_PARSER.parse(statement);
        if (command.isPresent()) {
            return Collections.singletonList(command.get());
        }

        // parse the sql query
        // use parseSqlList here because we need to support statement end with ';' in sql client.
        // 解析sql为SqlNode
        SqlNodeList sqlNodeList = parser.parseSqlList(statement);
        List<SqlNode> parsed = sqlNodeList.getList();
        Preconditions.checkArgument(parsed.size() == 1, "only single statement supported");
        // 将sqlNode转换成flink的operation对象
        return Collections.singletonList(
                SqlNodeToOperationConversion.convert(planner, catalogManager, parsed.get(0))
                        .orElseThrow(() -> new TableException("Unsupported query: " + statement)));
    }

    @Override
    public UnresolvedIdentifier parseIdentifier(String identifier) {
        CalciteParser parser = calciteParserSupplier.get();
        SqlIdentifier sqlIdentifier = parser.parseIdentifier(identifier);
        return UnresolvedIdentifier.of(sqlIdentifier.names);
    }

    @Override
    public ResolvedExpression parseSqlExpression(
            String sqlExpression, RowType inputRowType, @Nullable LogicalType outputType) {
        try {
            final SqlToRexConverter sqlToRexConverter =
                    rexFactory.createSqlToRexConverter(inputRowType, outputType);
            // 将sql表达式转换成RexNode，例如`my_catalog`.`my_database`.`my_udf`(`f0`) + 1
            final RexNode rexNode = sqlToRexConverter.convertToRexNode(sqlExpression);
            final LogicalType logicalType = FlinkTypeFactory.toLogicalType(rexNode.getType());
            // expand expression for serializable expression strings similar to views
            final String sqlExpressionExpanded = sqlToRexConverter.expand(sqlExpression);
            return new RexNodeExpression(
                    rexNode,
                    TypeConversions.fromLogicalToDataType(logicalType),
                    sqlExpression,
                    sqlExpressionExpanded);
        } catch (Throwable t) {
            throw new ValidationException(
                    String.format("Invalid SQL expression: %s", sqlExpression), t);
        }
    }

    public String[] getCompletionHints(String statement, int cursor) {
        List<String> candidates =
                new ArrayList<>(
                        Arrays.asList(EXTENDED_PARSER.getCompletionHints(statement, cursor)));

        // use sql advisor
        SqlAdvisorValidator validator = validatorSupplier.get().getSqlAdvisorValidator();
        SqlAdvisor advisor =
                new SqlAdvisor(validator, validatorSupplier.get().config().getParserConfig());
        String[] replaced = new String[1];

        List<String> sqlHints =
                advisor.getCompletionHints(statement, cursor, replaced).stream()
                        .map(item -> item.toIdentifier().toString())
                        .collect(Collectors.toList());

        candidates.addAll(sqlHints);

        return candidates.toArray(new String[0]);
    }

    public CatalogManager getCatalogManager() {
        return catalogManager;
    }
```

# Planner

* 转换一个SQL字符串为table api指定的对象，如Operation
* 关系型执行器，提供了一种计划，优化和将ModifyOperation的树转换为可运行形式Transformation

```java
public interface Planner {
	Parser getParser();

	// 将ModifyOperation的关系树转换为一组可运行的Transformation 。
//此方法接受ModifyOperation的列表，以允许重用多个关系查询的公共子树。 每个查询的顶部节点应该是ModifyOperation ，以便传递输出Transformation的预期属性，例如输出模式（追加，撤回，向上插入）或预期的输出类型。
	List<Transformation<?>> translate(List<ModifyOperation> modifyOperations);
	// 执行计划
	String explain(List<Operation> operations, ExplainDetail... extraDetails);

  // 在给定的光标位置返回给定语句的完成提示。 完成不区分大小写。
	String[] getCompletionHints(String statement, int position);
}
```

