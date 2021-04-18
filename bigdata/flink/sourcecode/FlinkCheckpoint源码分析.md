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

