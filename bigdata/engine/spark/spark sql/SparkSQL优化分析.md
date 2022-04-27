# AQE(Adaptive Query Execution )

* 3.0.0之后特性，3.2.0默认开启，通过`spark.sql.adaptive.enabled`设置，默认优化合并shuffle write分区小文件、转换sort-merge join为broadcast join，join倾斜优化。

## 合并shuffle后的分区

* 通过设置`spark.sql.adaptive.enabled` 和`spark.sql.adaptive.coalescePartitions.enabled`为`true`开启shuffle分区合并，基于map端输出分析合并shuffle后的分区。不需要在通过`spark.shuffle.partition`设置特定的分区数，只需要设置`spark.sql.adaptive.coalescePartitions.initialPartitionNum`初始化分区配置spark就可以找到他合适的分区数。

| Property Name                                               | Default | Meaning                                                      | Since Version |
| :---------------------------------------------------------- | :------ | :----------------------------------------------------------- | :------------ |
| `spark.sql.adaptive.coalescePartitions.enabled`             | true    | 当和`spark.sql.adaptive.enabled`都设置为`true`时，Spark将会按照目标的`spark.sql.adaptive.advisoryPartitionSizeInBytes`配置的大小缩减分区 | 3.0.0         |
| `spark.sql.adaptive.coalescePartitions.parallelismFirst`    | true    | 设置为true时会忽略`spark.sql.adaptive.advisoryPartitionSizeInBytes`配置去合并分区，而是根据`spark.sql.adaptive.coalescePartitions.minPartitionSize`去合并分区并按照最大并行度，建议设置为false | 3.2.0         |
| `spark.sql.adaptive.coalescePartitions.minPartitionSize`    | 1MB     | 最多为`spark.sql.adaptive.advisoryPartitionSizeInBytes`的百分之20 | 3.2.0         |
| `spark.sql.adaptive.coalescePartitions.initialPartitionNum` | (none)  | 合并前的初始shuffle分区数。如果没有设置，它等于' spark.sql.shuffle.partitions '。此配置仅在spark.sql.adaptive`和`spark.sql.adaptive.coalescePartitions`启用时生效。 | 3.0.0         |
| `spark.sql.adaptive.advisoryPartitionSizeInBytes`           | 64 MB   | 在spark.sql.adaptive`和`spark.sql.adaptive.coalescePartitions`启用时生效。 | 3.0.0         |

## sort-merge join转换为broadcast join

* 当分析出运行时任何join方小于broadcast hash join设置的阈值则会转换为broadcast join。这不是表示broadcast hash join最高效，但是它优于sort-merge join，因为我们可以保证链接俩端排序并且能够本地读shuffle文件通过`spark.sql.adaptive.localShuffleReader.enabled`设置为`true`，`spark.sql.adaptive.autoBroadcastJoinThreshold`是转换为broadcast join的阈值，如果小于则可以将merge-sort join转换为broadcast join

## 转换sort-merge join转换为shuffled hash join

* 当shuffle分区数小于设置的阈值则会将sort-merge join转换为hash join,阈值通过` spark.sql.adaptive.maxShuffledHashJoinLocalMapThreshold`配置

## 优化倾斜join

* 数据倾斜会严重降低join查询的性能。该特性通过将倾斜的任务拆分(如果需要，还可以复制)为大小大致相同的任务来动态处理sort-merge join中的倾斜。当`spark.sql.adaptive.enabled` 和 `spark.sql.adaptive.skewJoin.enabled`配置同时启用时生效。
* `spark.sql.adaptive.skewJoin.enabled`当和`spark.sql.adaptive.enabled`同时为true时，spark会通过分裂(必要时复制)倾斜分区来动态处理sort-merge join的倾斜分区。
* `spark.sql.adaptive.skewJoin.skewedPartitionFactor`，如果一个分区的大小大于这个因子乘以分区中值大小，并且大于`spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes`，则认为该分区是倾斜的。
* `spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes`,如果分区的字节大小大于这个阈值，并且大于spark.sql.adaptive.skewJoin.skewedPartitionFactor乘以分区大小中值，则认为分区是倾斜的。理想情况下，这个配置应该设置比`spark.sql.adaptive.advisoryPartitionSizeInBytes`大。

# RBO(Rule-base Optimization)

* 在将`Resolved Logical`转换为`Optimized Resolved Logical`时会基于Rule进行优化。
  * 每个优化以 Rule 的形式存在，每条 Rule 都是对 Analyzed Plan 的等价转换
  * RBO 设计良好，易于扩展，新的规则可以非常方便地嵌入进 Optimizer
  * RBO 目前已经足够好，但仍然需要更多规则来 cover 更多的场景
  * 优化思路主要是减少参与计算的数据量以及计算本身的代价

## PushDownPredicate

* 算子下推优化，如果俩个表进行join可以先进行filter后再去进行join，这个优化输入LogicalPlan的优化，从逻辑上保证了将Filter下推后由于参与Join的数据量变少而提高性能。
* 在物理层面，Filter 下推后，对于支持 Filter 下推的 Storage，并不需要将表的全量数据扫描出来再过滤，而是直接只扫描符合 Filter 条件的数据，从而在物理层面极大减少了扫描表的开销，提高了执行速度。

## ConstantFolding

* 如果Project包含对于常量的计算比如`select 100+20 from xx`类似操作，如果记录过多就会进行多次操作，可以通过`ConstantFolding`进行常量合并，从而减少不必要的计算，提高执行速度。

## ColumnPruning

* Filter 与 Join 操作会保留两边所有字段，然后在 Project 操作中筛选出需要的特定列。`ColumnPruning`规则能将 Project 下推，在扫描表时就只筛选出满足后续操作的最小字段集，则能大大减少 Filter 与 Project 操作的中间结果集数据量，从而极大提高执行速度。从物理层面在Project下推后，对于列式存储，扫描表时就只扫描需要的列减少IO消耗。

# CBO(Cost-Based Optimizer)

* 基于代价优化考虑了数据本身的特点（如大小、分布）以及操作算子的特点（中间结果集的分布及大小）及代价，从而更好的选择执行代价最小的物理执行计划，即 SparkPlan(物理执行计划)。
