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
```

