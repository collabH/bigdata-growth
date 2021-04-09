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

