# Checkpoint模块分配

* checkpoint
  * channel:数据管道，包含checkpoint的读写
  * hooks:钩子函数
  * metadata:元数据

## Channel模块

### 核心对象

#### inputChannelInfo

```java
/**
 * 最终的物理执行层inputchannel信息，包含一个inputgate index和inputchannel index，gate和channel 1对多
 * 标识inputChannel给定的一个子任务
 * Identifies {@link org.apache.flink.runtime.io.network.partition.consumer.InputChannel} in a given subtask.
 * Note that {@link org.apache.flink.runtime.io.network.partition.consumer.InputChannelID InputChannelID}
 * can not be used because it is generated randomly.
 */
@Internal
public class InputChannelInfo implements Serializable {
	private static final long serialVersionUID = 1L;

	// inputgate index
	private final int gateIdx;
	// inputChannel index
	private final int inputChannelIdx;

	public InputChannelInfo(int gateIdx, int inputChannelIdx) {
		this.gateIdx = gateIdx;
		this.inputChannelIdx = inputChannelIdx;
	}

	public int getGateIdx() {
		return gateIdx;
	}

	public int getInputChannelIdx() {
		return inputChannelIdx;
	}

	@Override
	public boolean equals(Object o) {
		if (this == o) {
			return true;
		}
		if (o == null || getClass() != o.getClass()) {
			return false;
		}
		final InputChannelInfo that = (InputChannelInfo) o;
		return gateIdx == that.gateIdx && inputChannelIdx == that.inputChannelIdx;
	}

	@Override
	public int hashCode() {
		return Objects.hash(gateIdx, inputChannelIdx);
	}

	@Override
	public String toString() {
		return "InputChannelInfo{" + "gateIdx=" + gateIdx + ", inputChannelIdx=" + inputChannelIdx + '}';
	}
}
```

#### ResultSubpartitionInfo

```java
@Internal
public class ResultSubpartitionInfo implements Serializable {
	private static final long serialVersionUID = 1L;

	// partition index 一般一个并行度一个
	private final int partitionIdx;
	// sub partition index 一般为上游和下游并行度的乘积
	private final int subPartitionIdx;

	public ResultSubpartitionInfo(int partitionIdx, int subPartitionIdx) {
		this.partitionIdx = partitionIdx;
		this.subPartitionIdx = subPartitionIdx;
	}

	public int getPartitionIdx() {
		return partitionIdx;
	}

	public int getSubPartitionIdx() {
		return subPartitionIdx;
	}

	@Override
	public boolean equals(Object o) {
		if (this == o) {
			return true;
		}
		if (o == null || getClass() != o.getClass()) {
			return false;
		}
		final ResultSubpartitionInfo that = (ResultSubpartitionInfo) o;
		return partitionIdx == that.partitionIdx && subPartitionIdx == that.subPartitionIdx;
	}

	@Override
	public int hashCode() {
		return Objects.hash(partitionIdx, subPartitionIdx);
	}

	@Override
	public String toString() {
		return "ResultSubpartitionInfo{" + "partitionIdx=" + partitionIdx + ", subPartitionIdx=" + subPartitionIdx + '}';
	}
}
```



### state reader

* 读取状态的数据管道，用于判断管道内是否还有状态，读取输入/输出数据。

```java
@Internal
public interface ChannelStateReader extends AutoCloseable {

	/**
	 * Status of reading result.
	 * 读取状态的结果
	 */
	enum ReadResult { HAS_MORE_DATA, NO_MORE_DATA }

	/**
	 * Return whether there are any channel states to be read.
	 */
	boolean hasChannelStates();

	/**
	 * Put data into the supplied buffer to be injected into
	 * {@link org.apache.flink.runtime.io.network.partition.consumer.InputChannel InputChannel}.
	 */
	ReadResult readInputData(InputChannelInfo info, Buffer buffer) throws IOException;

	/**
	 * Put data into the supplied buffer to be injected into
	 * {@link org.apache.flink.runtime.io.network.partition.ResultSubpartition ResultSubpartition}.
	 */
	ReadResult readOutputData(ResultSubpartitionInfo info, BufferBuilder bufferBuilder) throws IOException;

	@Override
	void close() throws Exception;

	/**
	 * 不进行操作
	 */
	ChannelStateReader NO_OP = new ChannelStateReader() {

		@Override
		public boolean hasChannelStates() {
			return false;
		}

		@Override
		public ReadResult readInputData(InputChannelInfo info, Buffer buffer) {
			return ReadResult.NO_MORE_DATA;
		}

		@Override
		public ReadResult readOutputData(ResultSubpartitionInfo info, BufferBuilder bufferBuilder) {
			return ReadResult.NO_MORE_DATA;
		}

		@Override
		public void close() {
		}
	};
}

public class ChannelStateReaderImpl implements ChannelStateReader {
	private static final Logger log = LoggerFactory.getLogger(ChannelStateReaderImpl.class);


	/**
	 * 俩个结果集更执行图有关，最终执行图从task-》ResultSubpartition-》inputchannel
	 */
	// 输出管道处理器
	private final Map<InputChannelInfo, ChannelStateStreamReader> inputChannelHandleReaders;
	// 结果子分区处理器
	private final Map<ResultSubpartitionInfo, ChannelStateStreamReader> resultSubpartitionHandleReaders;
	// 是否关闭
	private boolean isClosed = false;

	public ChannelStateReaderImpl(TaskStateSnapshot snapshot) {
		this(snapshot, new ChannelStateSerializerImpl());
	}

	ChannelStateReaderImpl(TaskStateSnapshot snapshot, ChannelStateSerializer serializer) {
		RefCountingFSDataInputStreamFactory streamFactory = new RefCountingFSDataInputStreamFactory(serializer);
		final HashMap<InputChannelInfo, ChannelStateStreamReader> inputChannelHandleReadersTmp = new HashMap<>();
		final HashMap<ResultSubpartitionInfo, ChannelStateStreamReader> resultSubpartitionHandleReadersTmp = new HashMap<>();
		for (Map.Entry<OperatorID, OperatorSubtaskState> e : snapshot.getSubtaskStateMappings()) {
			addReaders(inputChannelHandleReadersTmp, e.getValue().getInputChannelState(), streamFactory);
			addReaders(resultSubpartitionHandleReadersTmp, e.getValue().getResultSubpartitionState(), streamFactory);
		}
		inputChannelHandleReaders = inputChannelHandleReadersTmp; // memory barrier to allow another thread call clear()
		resultSubpartitionHandleReaders = resultSubpartitionHandleReadersTmp; // memory barrier to allow another thread call clear()
	}

	private <T> void addReaders(
			Map<T, ChannelStateStreamReader> readerMap,
			Collection<? extends AbstractChannelStateHandle<T>> handles,
			RefCountingFSDataInputStreamFactory streamFactory) {
		for (AbstractChannelStateHandle<T> handle : handles) {
			checkState(!readerMap.containsKey(handle.getInfo()), "multiple states exist for channel: " + handle.getInfo());
			readerMap.put(handle.getInfo(), new ChannelStateStreamReader(handle, streamFactory));
		}
	}

	@Override
	public boolean hasChannelStates() {
		return !(inputChannelHandleReaders.isEmpty() && resultSubpartitionHandleReaders.isEmpty());
	}

	@Override
	public ReadResult readInputData(InputChannelInfo info, Buffer buffer) throws IOException {
		Preconditions.checkState(!isClosed, "reader is closed");
		log.debug("readInputData, resultSubpartitionInfo: {} , buffer {}", info, buffer);
		ChannelStateStreamReader reader = inputChannelHandleReaders.get(info);
		// 数据放入Buffer
		return reader == null ? ReadResult.NO_MORE_DATA : reader.readInto(buffer);
	}

	@Override
	public ReadResult readOutputData(ResultSubpartitionInfo info, BufferBuilder bufferBuilder) throws IOException {
		Preconditions.checkState(!isClosed, "reader is closed");
		log.debug("readOutputData, resultSubpartitionInfo: {} , bufferBuilder {}", info, bufferBuilder);
		ChannelStateStreamReader reader = resultSubpartitionHandleReaders.get(info);
		return reader == null ? ReadResult.NO_MORE_DATA : reader.readInto(bufferBuilder);
	}

	@Override
	public void close() throws Exception {
		isClosed = true;
		try (Closer closer = Closer.create()) {
			for (Map<?, ChannelStateStreamReader> map : asList(inputChannelHandleReaders, resultSubpartitionHandleReaders)) {
				for (ChannelStateStreamReader reader : map.values()) {
					closer.register(reader);
				}
				map.clear();
			}
		}
	}

}
```

### state writer

* checkpoint/savepoint写入器

```java
public interface ChannelStateWriter extends Closeable {

	/**
	 * Channel state write result.
	 */
	class ChannelStateWriteResult {
		final CompletableFuture<Collection<InputChannelStateHandle>> inputChannelStateHandles;
		final CompletableFuture<Collection<ResultSubpartitionStateHandle>> resultSubpartitionStateHandles;

		ChannelStateWriteResult() {
			this(new CompletableFuture<>(), new CompletableFuture<>());
		}

		ChannelStateWriteResult(
				CompletableFuture<Collection<InputChannelStateHandle>> inputChannelStateHandles,
				CompletableFuture<Collection<ResultSubpartitionStateHandle>> resultSubpartitionStateHandles) {
			this.inputChannelStateHandles = inputChannelStateHandles;
			this.resultSubpartitionStateHandles = resultSubpartitionStateHandles;
		}

		public CompletableFuture<Collection<InputChannelStateHandle>> getInputChannelStateHandles() {
			return inputChannelStateHandles;
		}

		public CompletableFuture<Collection<ResultSubpartitionStateHandle>> getResultSubpartitionStateHandles() {
			return resultSubpartitionStateHandles;
		}

		public static final ChannelStateWriteResult EMPTY = new ChannelStateWriteResult(
			CompletableFuture.completedFuture(Collections.emptyList()),
			CompletableFuture.completedFuture(Collections.emptyList())
		);

		public void fail(Throwable e) {
			inputChannelStateHandles.completeExceptionally(e);
			resultSubpartitionStateHandles.completeExceptionally(e);
		}

		boolean isDone() {
			return inputChannelStateHandles.isDone() && resultSubpartitionStateHandles.isDone();
		}
	}

	/**
	 * Sequence number for the buffers that were saved during the previous execution attempt; then restored; and now are
	 * to be saved again (as opposed to the buffers received from the upstream or from the operator).
	 */
	int SEQUENCE_NUMBER_RESTORED = -1;

	/**
	 * Signifies that buffer sequence number is unknown (e.g. if passing sequence numbers is not implemented).
	 */
	int SEQUENCE_NUMBER_UNKNOWN = -2;

	/**
	 * Initiate write of channel state for the given checkpoint id.
	 */
	void start(long checkpointId, CheckpointOptions checkpointOptions);

	/**
	 * Add in-flight buffers from the {@link org.apache.flink.runtime.io.network.partition.consumer.InputChannel InputChannel}.
	 * Must be called after {@link #start} (long)} and before {@link #finishInput(long)}.
	 * Buffers are recycled after they are written or exception occurs.
	 * @param startSeqNum sequence number of the 1st passed buffer.
	 *                    It is intended to use for incremental snapshots.
	 *                    If no data is passed it is ignored.
	 * @param data zero or more <b>data</b> buffers ordered by their sequence numbers
	 * @see org.apache.flink.runtime.checkpoint.channel.ChannelStateWriter#SEQUENCE_NUMBER_RESTORED
	 * @see org.apache.flink.runtime.checkpoint.channel.ChannelStateWriter#SEQUENCE_NUMBER_UNKNOWN
	 */
	void addInputData(long checkpointId, InputChannelInfo info, int startSeqNum, CloseableIterator<Buffer> data);

	/**
	 * Add in-flight buffers from the {@link org.apache.flink.runtime.io.network.partition.ResultSubpartition ResultSubpartition}.
	 * Must be called after {@link #start} and before {@link #finishOutput(long)}.
	 * Buffers are recycled after they are written or exception occurs.
	 * @param startSeqNum sequence number of the 1st passed buffer.
	 *                    It is intended to use for incremental snapshots.
	 *                    If no data is passed it is ignored.
	 * @param data zero or more <b>data</b> buffers ordered by their sequence numbers
	 * @throws IllegalArgumentException if one or more passed buffers {@link Buffer#isBuffer()  isn't a buffer}
	 * @see org.apache.flink.runtime.checkpoint.channel.ChannelStateWriter#SEQUENCE_NUMBER_RESTORED
	 * @see org.apache.flink.runtime.checkpoint.channel.ChannelStateWriter#SEQUENCE_NUMBER_UNKNOWN
	 */
	void addOutputData(long checkpointId, ResultSubpartitionInfo info, int startSeqNum, Buffer... data) throws IllegalArgumentException;

	/**
	 * Finalize write of channel state data for the given checkpoint id.
	 * Must be called after {@link #start(long, CheckpointOptions)} and all of the input data of the given checkpoint added.
	 * When both {@link #finishInput} and {@link #finishOutput} were called the results can be (eventually) obtained
	 * using {@link #getAndRemoveWriteResult}
	 */
	void finishInput(long checkpointId);

	/**
	 * Finalize write of channel state data for the given checkpoint id.
	 * Must be called after {@link #start(long, CheckpointOptions)} and all of the output data of the given checkpoint added.
	 * When both {@link #finishInput} and {@link #finishOutput} were called the results can be (eventually) obtained
	 * using {@link #getAndRemoveWriteResult}
	 */
	void finishOutput(long checkpointId);

	/**
	 * Aborts the checkpoint and fails pending result for this checkpoint.
	 * @param cleanup true if {@link #getAndRemoveWriteResult(long)} is not supposed to be called afterwards.
	 */
	void abort(long checkpointId, Throwable cause, boolean cleanup);

	/**
	 * Must be called after {@link #start(long, CheckpointOptions)} once.
	 * @throws IllegalArgumentException if the passed checkpointId is not known.
	 */
	ChannelStateWriteResult getAndRemoveWriteResult(long checkpointId) throws IllegalArgumentException;

	ChannelStateWriter NO_OP = new NoOpChannelStateWriter();

	/**
	 * No-op implementation of {@link ChannelStateWriter}.
	 */
	class NoOpChannelStateWriter implements ChannelStateWriter {
		@Override
		public void start(long checkpointId, CheckpointOptions checkpointOptions) {
		}

		@Override
		public void addInputData(long checkpointId, InputChannelInfo info, int startSeqNum, CloseableIterator<Buffer> data) {
		}

		@Override
		public void addOutputData(long checkpointId, ResultSubpartitionInfo info, int startSeqNum, Buffer... data) {
		}

		@Override
		public void finishInput(long checkpointId) {
		}

		@Override
		public void finishOutput(long checkpointId) {
		}

		@Override
		public void abort(long checkpointId, Throwable cause, boolean cleanup) {
		}

		@Override
		public ChannelStateWriteResult getAndRemoveWriteResult(long checkpointId) {
			return new ChannelStateWriteResult(
				CompletableFuture.completedFuture(Collections.emptyList()),
				CompletableFuture.completedFuture(Collections.emptyList()));
		}

		@Override
		public void close() {
		}
	}
}

// 实现类
public class ChannelStateWriterImpl implements ChannelStateWriter {

	private static final Logger LOG = LoggerFactory.getLogger(ChannelStateWriterImpl.class);
	private static final int DEFAULT_MAX_CHECKPOINTS = 1000; // includes max-concurrent-checkpoints + checkpoints to be aborted (scheduled via mailbox)

	private final String taskName;
	private final ChannelStateWriteRequestExecutor executor;
	private final ConcurrentMap<Long, ChannelStateWriteResult> results;
	private final int maxCheckpoints;

	/**
	 * Creates a {@link ChannelStateWriterImpl} with {@link #DEFAULT_MAX_CHECKPOINTS} as {@link #maxCheckpoints}.
	 */
	public ChannelStateWriterImpl(String taskName, CheckpointStorageWorkerView streamFactoryResolver) {
		this(taskName, streamFactoryResolver, DEFAULT_MAX_CHECKPOINTS);
	}

	/**
	 * Creates a {@link ChannelStateWriterImpl} with {@link ChannelStateSerializerImpl default} {@link ChannelStateSerializer},
	 * and a {@link ChannelStateWriteRequestExecutorImpl}.
	 *  @param taskName
	 * @param streamFactoryResolver a factory to obtain output stream factory for a given checkpoint
	 * @param maxCheckpoints        maximum number of checkpoints to be written currently or finished but not taken yet.
	 */
	ChannelStateWriterImpl(String taskName, CheckpointStorageWorkerView streamFactoryResolver, int maxCheckpoints) {
		this(
			taskName,
			new ConcurrentHashMap<>(maxCheckpoints),
			new ChannelStateWriteRequestExecutorImpl(taskName, new ChannelStateWriteRequestDispatcherImpl(streamFactoryResolver, new ChannelStateSerializerImpl())),
			maxCheckpoints);
	}

	ChannelStateWriterImpl(
			String taskName,
			ConcurrentMap<Long, ChannelStateWriteResult> results,
			ChannelStateWriteRequestExecutor executor,
			int maxCheckpoints) {
		this.taskName = taskName;
		this.results = results;
		this.maxCheckpoints = maxCheckpoints;
		this.executor = executor;
	}

	@Override
	public void start(long checkpointId, CheckpointOptions checkpointOptions) {
		LOG.debug("{} starting checkpoint {} ({})", taskName, checkpointId, checkpointOptions);
		ChannelStateWriteResult result = new ChannelStateWriteResult();
		// 发送checkpoint开启请求
		ChannelStateWriteResult put = results.computeIfAbsent(checkpointId, id -> {
			Preconditions.checkState(results.size() < maxCheckpoints, String.format("%s can't start %d, results.size() > maxCheckpoints: %d > %d", taskName, checkpointId, results.size(), maxCheckpoints));
			// 发送请求
			enqueue(new CheckpointStartRequest(checkpointId, result, checkpointOptions.getTargetLocation()), false);
			return result;
		});
		Preconditions.checkArgument(put == result, taskName + " result future already present for checkpoint " + checkpointId);
	}

	@Override
	public void addInputData(long checkpointId, InputChannelInfo info, int startSeqNum, CloseableIterator<Buffer> iterator) {
		LOG.debug(
			"{} adding input data, checkpoint {}, channel: {}, startSeqNum: {}",
			taskName,
			checkpointId,
			info,
			startSeqNum);
		// 将inputChannel信息写入buffer迭代器
		enqueue(write(checkpointId, info, iterator), false);
	}

	@Override
	public void addOutputData(long checkpointId, ResultSubpartitionInfo info, int startSeqNum, Buffer... data) {
		LOG.debug(
			"{} adding output data, checkpoint {}, channel: {}, startSeqNum: {}, num buffers: {}",
			taskName,
			checkpointId,
			info,
			startSeqNum,
			data == null ? 0 : data.length);
		// 发送写请求
		enqueue(write(checkpointId, info, data), false);
	}

	@Override
	public void finishInput(long checkpointId) {
		LOG.debug("{} finishing input data, checkpoint {}", taskName, checkpointId);
		// 发送完成请求input
		enqueue(completeInput(checkpointId), false);
	}

	@Override
	public void finishOutput(long checkpointId) {
		LOG.debug("{} finishing output data, checkpoint {}", taskName, checkpointId);
		enqueue(completeOutput(checkpointId), false);
	}

	@Override
	public void abort(long checkpointId, Throwable cause, boolean cleanup) {
		LOG.debug("{} aborting, checkpoint {}", taskName, checkpointId);
		// 中断开始的checkpoint和未开始的
		enqueue(ChannelStateWriteRequest.abort(checkpointId, cause), true); // abort already started
		enqueue(ChannelStateWriteRequest.abort(checkpointId, cause), false); // abort enqueued but not started
		if (cleanup) {
			results.remove(checkpointId);
		}
	}

	@Override
	public ChannelStateWriteResult getAndRemoveWriteResult(long checkpointId) {
		LOG.debug("{} requested write result, checkpoint {}", taskName, checkpointId);
		ChannelStateWriteResult result = results.remove(checkpointId);
		Preconditions.checkArgument(result != null, taskName + " channel state write result not found for checkpoint " + checkpointId);
		return result;
	}

	public void open() {
		executor.start();
	}

	@Override
	public void close() throws IOException {
		LOG.debug("close, dropping checkpoints {}", results.keySet());
		results.clear();
		executor.close();
	}

	private void enqueue(ChannelStateWriteRequest request, boolean atTheFront) {
		// state check and previous errors check are performed inside the worker
		try {
			if (atTheFront) {
				executor.submitPriority(request);
			} else {
				// 提交checkpount请求
				executor.submit(request);
			}
		} catch (Exception e) {
			RuntimeException wrapped = new RuntimeException("unable to send request to worker", e);
			try {
				request.cancel(e);
			} catch (Exception cancelException) {
				wrapped.addSuppressed(cancelException);
			}
			throw wrapped;
		}
	}

	private static String buildBufferTypeErrorMessage(Buffer buffer) {
		try {
			AbstractEvent event = EventSerializer.fromBuffer(buffer, ChannelStateWriterImpl.class.getClassLoader());
			return String.format("Should be buffer but [%s] found", event);
		}
		catch (Exception ex) {
			return "Should be buffer";
		}
	}
}
```

### writer requset dispatcher

```java
/**
 * 状态写请求分发器
 */
interface ChannelStateWriteRequestDispatcher {

	// 分发请求
	void dispatch(ChannelStateWriteRequest request) throws Exception;

	// 错误
	void fail(Throwable cause);

	ChannelStateWriteRequestDispatcher NO_OP = new ChannelStateWriteRequestDispatcher() {
		@Override
		public void dispatch(ChannelStateWriteRequest request) {
		}

		@Override
		public void fail(Throwable cause) {
		}
	};
}
```

## Hooks模块

* 核心执行checkpoint模块，包含触发ck，恢复ck等等

### triggerHook

* 触发checkpoint

### restoreMasterHooks

* 恢复checkpoint状态

## Metadata模块

* 反序列化checkpoint元数据，提供多种反序列化器

### CheckpointMetadata

* checkpoint元数据数据模型

```java
public class CheckpointMetadata implements Disposable {

	/** The checkpoint ID. */
	private final long checkpointId;

	/** The operator states. */
	// 算子状态
	private final Collection<OperatorState> operatorStates;

	/** The states generated by the CheckpointCoordinator. */
	// checkpoint协调器生成的状态
	private final Collection<MasterState> masterStates;

	public CheckpointMetadata(long checkpointId, Collection<OperatorState> operatorStates, Collection<MasterState> masterStates) {
		this.checkpointId = checkpointId;
		this.operatorStates = operatorStates;
		this.masterStates = checkNotNull(masterStates, "masterStates");
	}

	public long getCheckpointId() {
		return checkpointId;
	}

	public Collection<OperatorState> getOperatorStates() {
		return operatorStates;
	}

	public Collection<MasterState> getMasterStates() {
		return masterStates;
	}

	@Override
	public void dispose() throws Exception {
		for (OperatorState operatorState : operatorStates) {
			operatorState.discardState();
		}
		operatorStates.clear();
		masterStates.clear();
	}

	@Override
	public String toString() {
		return "Checkpoint Metadata";
	}
}
```

### MetadataSerializer

* 统一元数据序列化器，提供savepoint反序列化接口

```java
public interface MetadataSerializer extends Versioned {

	/**
	 * 根据输入流反序列化savepoint
	 * Deserializes a savepoint from an input stream.
	 *
	 * @param dis Input stream to deserialize savepoint from
	 * @param  userCodeClassLoader the user code class loader
	 * @param externalPointer the external pointer of the given checkpoint
	 * @return The deserialized savepoint
	 * @throws IOException Serialization failures are forwarded
	 */
	CheckpointMetadata deserialize(DataInputStream dis, ClassLoader userCodeClassLoader, String externalPointer) throws IOException;
}
```

### MetadataV2V3SerializerBase

* 基本checkpoint元数据布局

```
 *  +--------------+---------------+-----------------+
 *  | checkpointID | master states | operator states |
 *  +--------------+---------------+-----------------+
```

* master state

```
 * +--------------+---------------------+---------+------+---------------+
 *  | magic number | num remaining bytes | version | name | payload bytes |
 *  +--------------+---------------------+---------+------+---------------+
```

* 主要用来序列化、反序列化基本checkpoint metadata和master state、operator state等

# checkpoint配置转换

## StreamExecutionEnvironment配置

### Checkpoint从StreamNode传递到JobGraph

```
-->StreamExecutionEnvironment#enableCheckpointing
	-->PipelineExecutor#execute
		-->FlinkPipelineTranslationUtil#getJobGraph
			-->StreamGraphTranslator#translateToJobGraph
				-->StreamGraph#getJobGraph
					-->StreamingJobGraphGenerator#createJobGraph
						-->StreamingJobGraphGenerator#configureCheckpointing
```

* 最终将streamGraph的CheckpointConfig转换为`jobGraph`的`SnapshotSettings(JobCheckpointingSettings)`

### Checkpoint从JobGraph传递到ExecutionGraph

```
-->ExecutionGraphBuilder#buildGraph
	-->ExecutionGraph#enableCheckpointing
```

# Checkpoint机制

## 恢复状态流程

* 生成`ExecutionGraph`时会尝试恢复历史状态

```java
private ExecutionGraph createAndRestoreExecutionGraph(
		JobManagerJobMetricGroup currentJobManagerJobMetricGroup,
		ShuffleMaster<?> shuffleMaster,
		JobMasterPartitionTracker partitionTracker,
		ExecutionDeploymentTracker executionDeploymentTracker) throws Exception {

		ExecutionGraph newExecutionGraph = createExecutionGraph(currentJobManagerJobMetricGroup, shuffleMaster, partitionTracker, executionDeploymentTracker);

		final CheckpointCoordinator checkpointCoordinator = newExecutionGraph.getCheckpointCoordinator();

		// 恢复checkpoint状态
		if (checkpointCoordinator != null) {
			// check whether we find a valid checkpoint
			if (!checkpointCoordinator.restoreLatestCheckpointedStateToAll(
				new HashSet<>(newExecutionGraph.getAllVertices().values()),
				false)) {

				// check whether we can restore from a savepoint
				// 检查恢复状态
				tryRestoreExecutionGraphFromSavepoint(newExecutionGraph, jobGraph.getSavepointRestoreSettings());
			}
		}

		return newExecutionGraph;
	}

// 恢复savepoint
private void tryRestoreExecutionGraphFromSavepoint(ExecutionGraph executionGraphToRestore, SavepointRestoreSettings savepointRestoreSettings) throws Exception {
		if (savepointRestoreSettings.restoreSavepoint()) {
			final CheckpointCoordinator checkpointCoordinator = executionGraphToRestore.getCheckpointCoordinator();
			if (checkpointCoordinator != null) {
				// 恢复savepoint
				checkpointCoordinator.restoreSavepoint(
					savepointRestoreSettings.getRestorePath(),
					savepointRestoreSettings.allowNonRestoredState(),
					executionGraphToRestore.getAllVertices(),
					userCodeLoader);
			}
		}
	}
```

* 恢复savepoint

```java
public boolean restoreSavepoint(
			String savepointPointer,
			boolean allowNonRestored,
			Map<JobVertexID, ExecutionJobVertex> tasks,
			ClassLoader userClassLoader) throws Exception {

		Preconditions.checkNotNull(savepointPointer, "The savepoint path cannot be null.");

		LOG.info("Starting job {} from savepoint {} ({})",
				job, savepointPointer, (allowNonRestored ? "allowing non restored state" : ""));

		// 解析checkpoint path
		final CompletedCheckpointStorageLocation checkpointLocation = checkpointStorage.resolveCheckpoint(savepointPointer);

		// Load the savepoint as a checkpoint into the system
		// 加载校验checkpoint
		CompletedCheckpoint savepoint = Checkpoints.loadAndValidateCheckpoint(
				job, tasks, checkpointLocation, userClassLoader, allowNonRestored);

		// 添加到完成的checkpoint存储，底层存储为双端队列
		completedCheckpointStore.addCheckpoint(savepoint);

		// Reset the checkpoint ID counter
		long nextCheckpointId = savepoint.getCheckpointID() + 1;
		// 设置下次checkpointid
		checkpointIdCounter.setCount(nextCheckpointId);

		LOG.info("Reset the checkpoint ID of job {} to {}.", job, nextCheckpointId);

		// 恢复最后checkpoint状态
		return restoreLatestCheckpointedStateInternal(new HashSet<>(tasks.values()), true, true, allowNonRestored);
	}
```

* 恢复最新的checkpoint状态

```java
private boolean restoreLatestCheckpointedStateInternal(
		final Set<ExecutionJobVertex> tasks,
		final boolean restoreCoordinators,
		final boolean errorIfNoCheckpoint,
		final boolean allowNonRestoredState) throws Exception {

		synchronized (lock) {
			if (shutdown) {
				throw new IllegalStateException("CheckpointCoordinator is shut down");
			}

			// We create a new shared state registry object, so that all pending async disposal requests from previous
			// runs will go against the old object (were they can do no harm).
			// This must happen under the checkpoint lock.
			sharedStateRegistry.close();
			sharedStateRegistry = sharedStateRegistryFactory.create(executor);

			// Recover the checkpoints, TODO this could be done only when there is a new leader, not on each recovery
			// 恢复checkpoint
			completedCheckpointStore.recover();

			// Now, we re-register all (shared) states from the checkpoint store with the new registry
			for (CompletedCheckpoint completedCheckpoint : completedCheckpointStore.getAllCheckpoints()) {
				// 注册共享状态之后恢复
				completedCheckpoint.registerSharedStatesAfterRestored(sharedStateRegistry);
			}

			LOG.debug("Status of the shared state registry of job {} after restore: {}.", job, sharedStateRegistry);

			// Restore from the latest checkpoint
			// 获取最后的checkpoint
			CompletedCheckpoint latest = completedCheckpointStore.getLatestCheckpoint(isPreferCheckpointForRecovery);

			if (latest == null) {
				if (errorIfNoCheckpoint) {
					throw new IllegalStateException("No completed checkpoint available");
				} else {
					LOG.debug("Resetting the master hooks.");
					MasterHooks.reset(masterHooks.values(), LOG);

					return false;
				}
			}

			LOG.info("Restoring job {} from latest valid checkpoint: {}.", job, latest);

			// re-assign the task states
			final Map<OperatorID, OperatorState> operatorStates = latest.getOperatorStates();

			// 用于恢复savepoint和恢复checkpoint
			StateAssignmentOperation stateAssignmentOperation =
					new StateAssignmentOperation(latest.getCheckpointID(), tasks, operatorStates, allowNonRestoredState);

			// 分配状态
			stateAssignmentOperation.assignStates();

			// call master hooks for restore. we currently call them also on "regional restore" because
			// there is no other failure notification mechanism in the master hooks
			// ultimately these should get removed anyways in favor of the operator coordinators

			MasterHooks.restoreMasterHooks(
					masterHooks,
					latest.getMasterHookStates(),
					latest.getCheckpointID(),
					allowNonRestoredState,
					LOG);

			if (restoreCoordinators) {
				restoreStateToCoordinators(operatorStates);
			}

			// update metrics

			if (statsTracker != null) {
				long restoreTimestamp = System.currentTimeMillis();
				RestoredCheckpointStats restored = new RestoredCheckpointStats(
					latest.getCheckpointID(),
					latest.getProperties(),
					restoreTimestamp,
					latest.getExternalPointer());

				statsTracker.reportRestoredCheckpoint(restored);
			}

			return true;
		}
	}
```

## CheckpointCoordinator机制

### 初始化CheckpointCoordinator

```java
public CheckpointCoordinator(
			JobID job,
			CheckpointCoordinatorConfiguration chkConfig,
			ExecutionVertex[] tasksToTrigger,
			ExecutionVertex[] tasksToWaitFor,
			ExecutionVertex[] tasksToCommitTo,
			Collection<OperatorCoordinatorCheckpointContext> coordinatorsToCheckpoint,
			CheckpointIDCounter checkpointIDCounter,
			CompletedCheckpointStore completedCheckpointStore,
			StateBackend checkpointStateBackend,
			Executor executor,
			ScheduledExecutor timer,
			SharedStateRegistryFactory sharedStateRegistryFactory,
			CheckpointFailureManager failureManager,
			Clock clock) {

		// sanity checks
		checkNotNull(checkpointStateBackend);

		// max "in between duration" can be one year - this is to prevent numeric overflows
		// 获取最小checkpoint暂停间隔
		long minPauseBetweenCheckpoints = chkConfig.getMinPauseBetweenCheckpoints();
		if (minPauseBetweenCheckpoints > 365L * 24 * 60 * 60 * 1_000) {
			minPauseBetweenCheckpoints = 365L * 24 * 60 * 60 * 1_000;
		}

		// it does not make sense to schedule checkpoints more often then the desired
		// time between checkpoints
		// 获取基础间隔
		long baseInterval = chkConfig.getCheckpointInterval();
		// 如果基础间隔小雨最小checkpoint暂停间隔则基础间隔等于最小暂停
		if (baseInterval < minPauseBetweenCheckpoints) {
			baseInterval = minPauseBetweenCheckpoints;
		}

		this.job = checkNotNull(job);
		this.baseInterval = baseInterval;
		this.checkpointTimeout = chkConfig.getCheckpointTimeout();
		this.minPauseBetweenCheckpoints = minPauseBetweenCheckpoints;
		this.tasksToTrigger = checkNotNull(tasksToTrigger);
		this.tasksToWaitFor = checkNotNull(tasksToWaitFor);
		this.tasksToCommitTo = checkNotNull(tasksToCommitTo);
		this.coordinatorsToCheckpoint = Collections.unmodifiableCollection(coordinatorsToCheckpoint);
		this.pendingCheckpoints = new LinkedHashMap<>();
		this.checkpointIdCounter = checkNotNull(checkpointIDCounter);
		this.completedCheckpointStore = checkNotNull(completedCheckpointStore);
		this.executor = checkNotNull(executor);
		this.sharedStateRegistryFactory = checkNotNull(sharedStateRegistryFactory);
		this.sharedStateRegistry = sharedStateRegistryFactory.create(executor);
		this.isPreferCheckpointForRecovery = chkConfig.isPreferCheckpointForRecovery();
		this.failureManager = checkNotNull(failureManager);
		this.clock = checkNotNull(clock);
		this.isExactlyOnceMode = chkConfig.isExactlyOnce();
		this.unalignedCheckpointsEnabled = chkConfig.isUnalignedCheckpointsEnabled();

		this.recentPendingCheckpoints = new ArrayDeque<>(NUM_GHOST_CHECKPOINT_IDS);
		this.masterHooks = new HashMap<>();

		this.timer = timer;

		// 解析checkpoint参数
		this.checkpointProperties = CheckpointProperties.forCheckpoint(chkConfig.getCheckpointRetentionPolicy());

		try {
			// 创建checkpoint存储
			this.checkpointStorage = checkpointStateBackend.createCheckpointStorage(job);
			// 初始化checkpoint
			checkpointStorage.initializeBaseLocations();
		} catch (IOException e) {
			throw new FlinkRuntimeException("Failed to create checkpoint storage at checkpoint coordinator side.", e);
		}

		try {
			// Make sure the checkpoint ID enumerator is running. Possibly
			// issues a blocking call to ZooKeeper.
			// 启动checkpointId计数器，提供基于Atomic内存计数器和Zookeeper计数器
			checkpointIDCounter.start();
		} catch (Throwable t) {
			throw new RuntimeException("Failed to start checkpoint ID counter: " + t.getMessage(), t);
		}
		this.requestDecider = new CheckpointRequestDecider(
			chkConfig.getMaxConcurrentCheckpoints(),
			this::rescheduleTrigger,
			this.clock,
			this.minPauseBetweenCheckpoints,
			this.pendingCheckpoints::size);
	}
```

### 触发savepoint

```java
public CompletableFuture<CompletedCheckpoint> triggerSavepoint(@Nullable final String targetLocation) {
		// 是否不对齐checkpoint
		final CheckpointProperties properties = CheckpointProperties.forSavepoint(!unalignedCheckpointsEnabled);
		// 触发savepoint
		return triggerSavepointInternal(properties, false, targetLocation);
	}


private CompletableFuture<CompletedCheckpoint> triggerSavepointInternal(
			final CheckpointProperties checkpointProperties,
			final boolean advanceToEndOfEventTime,
			@Nullable final String targetLocation) {

		checkNotNull(checkpointProperties);

		// TODO, call triggerCheckpoint directly after removing timer thread
		// for now, execute the trigger in timer thread to avoid competition
		// 记录结果，异步调用
		final CompletableFuture<CompletedCheckpoint> resultFuture = new CompletableFuture<>();
		// 触发checkpoint
		timer.execute(() -> triggerCheckpoint(
			checkpointProperties,
			targetLocation,
			false,
			advanceToEndOfEventTime)
		.whenComplete((completedCheckpoint, throwable) -> {
			if (throwable == null) {
				resultFuture.complete(completedCheckpoint);
			} else {
				resultFuture.completeExceptionally(throwable);
			}
		}));
		return resultFuture;
	}

	public CompletableFuture<CompletedCheckpoint> triggerCheckpoint(
			CheckpointProperties props,
			@Nullable String externalSavepointLocation,
			boolean isPeriodic,
			boolean advanceToEndOfTime) {

		if (advanceToEndOfTime && !(props.isSynchronous() && props.isSavepoint())) {
			return FutureUtils.completedExceptionally(new IllegalArgumentException(
				"Only synchronous savepoints are allowed to advance the watermark to MAX."));
		}

		// 创建checkpoint请求
		CheckpointTriggerRequest request = new CheckpointTriggerRequest(props, externalSavepointLocation, isPeriodic, advanceToEndOfTime);
		// 关闭请求并且执行
		chooseRequestToExecute(request).ifPresent(this::startTriggeringCheckpoint);
		return request.onCompletionPromise;
	}
```

### snapshotTaskState

```java
private void snapshotTaskState(
		long timestamp,
		long checkpointID,
		CheckpointStorageLocation checkpointStorageLocation,
		CheckpointProperties props,
		Execution[] executions,
		boolean advanceToEndOfTime) {

		final CheckpointOptions checkpointOptions = new CheckpointOptions(
			props.getCheckpointType(),
			checkpointStorageLocation.getLocationReference(),
			isExactlyOnceMode,
			props.getCheckpointType() == CheckpointType.CHECKPOINT && unalignedCheckpointsEnabled);

		// send the messages to the tasks that trigger their checkpoint
		for (Execution execution: executions) {
			// 如果是同步
			if (props.isSynchronous()) {
				execution.triggerSynchronousSavepoint(checkpointID, timestamp, checkpointOptions, advanceToEndOfTime);
			} else {
				// 否则触发checkpoint
				execution.triggerCheckpoint(checkpointID, timestamp, checkpointOptions);
			}
		}
	}
```

### checkpoint生命周期管理

* 发送ack消息通知checkpoint完成

```java
private void sendAcknowledgeMessages(long checkpointId, long timestamp) {
		// commit tasks
		// 通知checkpoint完成
		for (ExecutionVertex ev : tasksToCommitTo) {
			Execution ee = ev.getCurrentExecutionAttempt();
			if (ee != null) {
				ee.notifyCheckpointComplete(checkpointId, timestamp);
			}
		}

		// commit coordinators，提交对应的coordinators
		for (OperatorCoordinatorCheckpointContext coordinatorContext : coordinatorsToCheckpoint) {
			coordinatorContext.checkpointComplete(checkpointId);
		}
	}
```

* 发送中断消息，通知checkpoint中断

```java
private void sendAbortedMessages(long checkpointId, long timeStamp) {
		// send notification of aborted checkpoints asynchronously.
		executor.execute(() -> {
			// send the "abort checkpoint" messages to necessary vertices.
			for (ExecutionVertex ev : tasksToCommitTo) {
				Execution ee = ev.getCurrentExecutionAttempt();
				if (ee != null) {
					ee.notifyCheckpointAborted(checkpointId, timeStamp);
				}
			}
		});
	}
```

