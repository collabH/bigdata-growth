# Blink Planner

## runtime

### data

* binary：blink中将原生planner的Row格式修改为BinaryRow，减少序列化和让数据存储更加紧凑。

#### MemorySegment

* 底层存储二进制数据的抽象类，分为HybridMemorySegment（混合型存储）和HeapMemorySegment（堆内存储）实现

#### BinaryRowData

* 分为定长数据和可变数据，底层Row存储格式

#### UpdatableRowData

* 可修改的行记录，记录读取的行记录，和修改后的记录

```java
	// 行记录
	private RowData row;
	// 记录修改过后的值
	private final Object[] fields;
	// 是否updated
	private final boolean[] updated;
	
	public void setField(int pos, Object value) {
		updated[pos] = true;
		fields[pos] = value;
	}
```

#### JoinedRowData

* 存储Join后的RowData

```java
	// sql的行种类
	private RowKind rowKind = RowKind.INSERT;
	// 俩个join的rowData
	private RowData row1;
	private RowData row2;
```

#### ColumnarRowData

* 按照列存储的方式存储数据

```java
	private RowKind rowKind = RowKind.INSERT;
	//Verctor列批处理，存储每个列的数据，根据rowId来获取对应行的这列值，理解为列存储
	private VectorizedColumnBatch vectorizedColumnBatch;
	// 行id，记录处理的行数
	private int rowId;
```

#### ColumnarArrayData

* 数组方式存储列的全部数据，根据对应的offset和pos获取对应行的列的值

```java
 // 存储每列的数据
	private final ColumnVector data;
	// 偏移量，offset+pos获取指定行的数据
	private final int offset;
	// 元素总数
	private final int numElements;
```

#### BoxedWrapperRowData

* 装箱包装RowData，数据存储在Object数组中

```java
// sql操作类型
	private RowKind rowKind = RowKind.INSERT; // INSERT as default

	protected final Object[] fields;
```

#### BinaryWriter

* 二进制数据写入器，主要负责将Row，Array等类型按照二进制格式写入

```java
/**
 * Writer to write a composite data format, like row, array.
 * 1. Invoke {@link #reset()}.
 * // 通过writeXx或者setNullAt写入每个字段，相同字段不能重复写入
 * 2. Write each field by writeXX or setNullAt. (Same field can not be written repeatedly.)
 * 3. Invoke {@link #complete()}.
 */
@Internal
public interface BinaryWriter 
```

### filesystem

#### PartitionCommitTrigger

* 分区提交触发器，触发何时提交分区

```java
public interface PartitionCommitTrigger {

	String PARTITION_TIME = "partition-time";
	String PROCESS_TIME = "process-time";

	/**
	 * Add a pending partition.
	 */
	void addPartition(String partition);

	/**
	 * 获取可提交的分区，并清理无用的水印和分区
	 * Get committable partitions, and cleanup useless watermarks and partitions.
	 */
	List<String> committablePartitions(long checkpointId) throws IOException;

	/**
	 * End input, return committable partitions and clear.
	 */
	List<String> endInput();

	/**
	 * Snapshot state.
	 */
	void snapshotState(long checkpointId, long watermark) throws Exception;

	static PartitionCommitTrigger create(
			boolean isRestored,
			OperatorStateStore stateStore,
			Configuration conf,
			ClassLoader cl,
			List<String> partitionKeys,
			ProcessingTimeService procTimeService) throws Exception {
		// 获取`sink.partition-commit.trigger`配置，默认为process-time触发器
		String trigger = conf.get(SINK_PARTITION_COMMIT_TRIGGER);
		switch (trigger) {
			case PARTITION_TIME:
				return new PartitionTimeCommitTigger(
						isRestored, stateStore, conf, cl, partitionKeys);
			case PROCESS_TIME:
				return new ProcTimeCommitTigger(
						isRestored, stateStore, conf, procTimeService);
			default:
				throw new UnsupportedOperationException(
						"Unsupported partition commit trigger: " + trigger);
		}
	}
}
```

#### PartitionTimeCommitTigger

* partition-time分区提交触发器，用于提交基于分区时间的分区

```java
public class PartitionTimeCommitTigger implements PartitionCommitTrigger {
	// 记录等待提交的分区
	private static final ListStateDescriptor<List<String>> PENDING_PARTITIONS_STATE_DESC =
			new ListStateDescriptor<>(
					"pending-partitions",
					new ListSerializer<>(StringSerializer.INSTANCE));
	// 记录checkpointid对应的watermark
	private static final ListStateDescriptor<Map<Long, Long>> WATERMARKS_STATE_DESC =
			new ListStateDescriptor<>(
					"checkpoint-id-to-watermark",
					new MapSerializer<>(LongSerializer.INSTANCE, LongSerializer.INSTANCE));

	private final ListState<List<String>> pendingPartitionsState;
	// 等待中的分区
	private final Set<String> pendingPartitions;

	// watermarker状态，mapkey为checkpointid，value为watermark
	private final ListState<Map<Long, Long>> watermarksState;
	// 记录watermark
	private final TreeMap<Long, Long> watermarks;
	// 分区时间提取器
	private final PartitionTimeExtractor extractor;
	// 提交延迟时间
	private final long commitDelay;
	// 分区key
	private final List<String> partitionKeys;

	public PartitionTimeCommitTigger(
			boolean isRestored,
			OperatorStateStore stateStore,
			Configuration conf,
			ClassLoader cl,
			List<String> partitionKeys) throws Exception {
		// 初始化等待提交分区状态
		this.pendingPartitionsState = stateStore.getListState(PENDING_PARTITIONS_STATE_DESC);
		this.pendingPartitions = new HashSet<>();
		// 是否为恢复状态
		if (isRestored) {
			// 将从状态后端中获取的带提交分区放入内存中
			pendingPartitions.addAll(pendingPartitionsState.get().iterator().next());
		}

		this.partitionKeys = partitionKeys;
		// 获取"sink.partition-commit.delay"延迟，默认为0ms
		this.commitDelay = conf.get(SINK_PARTITION_COMMIT_DELAY).toMillis();
		// 根据指定配置实例化出分区时间提交器
		this.extractor = PartitionTimeExtractor.create(
				cl,
				// 指定分区时间提交器类型，默认为 default，可以选择custom
				conf.get(PARTITION_TIME_EXTRACTOR_KIND),
				// 指定自定义的分区时间提取器
				conf.get(PARTITION_TIME_EXTRACTOR_CLASS),
				// 提取时间匹配的格式
				conf.get(PARTITION_TIME_EXTRACTOR_TIMESTAMP_PATTERN));

		// 获取watermark状态
		this.watermarksState = stateStore.getListState(WATERMARKS_STATE_DESC);
		this.watermarks = new TreeMap<>();
		if (isRestored) {
			// 恢复状态
			watermarks.putAll(watermarksState.get().iterator().next());
		}
	}

	@Override
	public void addPartition(String partition) {
		if (!StringUtils.isNullOrWhitespaceOnly(partition)) {
			this.pendingPartitions.add(partition);
		}
	}

	@Override
	public List<String> committablePartitions(long checkpointId) {
		// 判断提交的分区是否一件checkpoint完毕
		if (!watermarks.containsKey(checkpointId)) {
			throw new IllegalArgumentException(String.format(
					"Checkpoint(%d) has not been snapshot. The watermark information is: %s.",
					checkpointId, watermarks));
		}
		// 获取其watermarker
		long watermark = watermarks.get(checkpointId);

		watermarks.headMap(checkpointId, true).clear();

		List<String> needCommit = new ArrayList<>();
		Iterator<String> iter = pendingPartitions.iterator();
		while (iter.hasNext()) {
			String partition = iter.next();
			// 从指定分区key中提取分区时间
			LocalDateTime partTime = extractor.extract(
					partitionKeys, extractPartitionValues(new Path(partition)));
			// 如果watermarker大于分区时间+延迟时间，则可以提交，提交后移除
			if (watermark > toMills(partTime) + commitDelay) {
				needCommit.add(partition);
				iter.remove();
			}
		}
		return needCommit;
	}

	/**
	 * 快照状态
	 * @param checkpointId
	 * @param watermark
	 * @throws Exception
	 */
	@Override
	public void snapshotState(long checkpointId, long watermark) throws Exception {
		pendingPartitionsState.clear();
		// 将内存中数据加入state
		pendingPartitionsState.add(new ArrayList<>(pendingPartitions));

		watermarks.put(checkpointId, watermark);
		watermarksState.clear();
		watermarksState.add(new HashMap<>(watermarks));
	}

	@Override
	public List<String> endInput() {
		ArrayList<String> partitions = new ArrayList<>(pendingPartitions);
		pendingPartitions.clear();
		return partitions;
	}
}
```

#### ProcTimeCommitTigger

* processTime提交触发器

```java
public class ProcTimeCommitTigger implements PartitionCommitTrigger {

	private static final ListStateDescriptor<Map<String, Long>> PENDING_PARTITIONS_STATE_DESC =
			new ListStateDescriptor<>(
					"pending-partitions-with-time",
					new MapSerializer<>(StringSerializer.INSTANCE, LongSerializer.INSTANCE));
	// 等待的分区和创建时process时间
	private final ListState<Map<String, Long>> pendingPartitionsState;
	private final Map<String, Long> pendingPartitions;
	private final long commitDelay;
	private final ProcessingTimeService procTimeService;

	public ProcTimeCommitTigger(
			boolean isRestored,
			OperatorStateStore stateStore,
			Configuration conf,
			ProcessingTimeService procTimeService) throws Exception {
		this.pendingPartitionsState = stateStore.getListState(PENDING_PARTITIONS_STATE_DESC);
		this.pendingPartitions = new HashMap<>();
		if (isRestored) {
			pendingPartitions.putAll(pendingPartitionsState.get().iterator().next());
		}

		this.procTimeService = procTimeService;
		this.commitDelay = conf.get(SINK_PARTITION_COMMIT_DELAY).toMillis();
	}

	@Override
	public void addPartition(String partition) {
		if (!StringUtils.isNullOrWhitespaceOnly(partition)) {
			this.pendingPartitions.putIfAbsent(partition, procTimeService.getCurrentProcessingTime());
		}
	}

	@Override
	public List<String> committablePartitions(long checkpointId) {
		List<String> needCommit = new ArrayList<>();
		// 获取当前processTime
		long currentProcTime = procTimeService.getCurrentProcessingTime();
		Iterator<Map.Entry<String, Long>> iter = pendingPartitions.entrySet().iterator();
		while (iter.hasNext()) {
			Map.Entry<String, Long> entry = iter.next();
			long creationTime = entry.getValue();
			// 如果提交延迟为0或者当前process时间大于创建时间+提交延迟则提交分区
			if (commitDelay == 0 || currentProcTime > creationTime + commitDelay) {
				needCommit.add(entry.getKey());
				iter.remove();
			}
		}
		return needCommit;
	}

	@Override
	public void snapshotState(long checkpointId, long watermark) throws Exception {
		pendingPartitionsState.clear();
		pendingPartitionsState.add(new HashMap<>(pendingPartitions));
	}

	@Override
	public List<String> endInput() {
		ArrayList<String> partitions = new ArrayList<>(pendingPartitions.keySet());
		pendingPartitions.clear();
		return partitions;
	}
}

```

### runtime

#### TableFunctionCollector

* 表函数收集器，收集表函数计算的最终结果传递至下游