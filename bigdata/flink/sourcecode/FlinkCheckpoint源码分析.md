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

# Checkpoint恢复机制

* 生成`ExecutionGraph`时会尝试恢复历史状态

## 恢复状态流程

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

