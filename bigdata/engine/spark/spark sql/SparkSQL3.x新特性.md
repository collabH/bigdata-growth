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
