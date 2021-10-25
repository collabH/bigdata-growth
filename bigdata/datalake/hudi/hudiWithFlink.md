* `Configuration`:`$FLINK_HOME/conf/flink-conf.yaml`修改相关配置
* `Writing Data`:Flink支持[Bulk Insert](https://hudi.apache.org/docs/flink-quick-start-guide#bulk-insert), [Index Bootstrap](https://hudi.apache.org/docs/flink-quick-start-guide#index-bootstrap), [Changelog Mode](https://hudi.apache.org/docs/flink-quick-start-guide#changelog-mode), [Insert Mode](https://hudi.apache.org/docs/flink-quick-start-guide#insert-mode) 和 [Offline Compaction](https://hudi.apache.org/docs/flink-quick-start-guide#offline-compaction).
* `Querying Data`:Flink支持[Hive Query](https://hudi.apache.org/docs/flink-quick-start-guide#hive-query), [Presto Query](https://hudi.apache.org/docs/flink-quick-start-guide#presto-query).
* `Optimization`:对于写/读任务，提供了 [Memory Optimization](https://hudi.apache.org/docs/flink-quick-start-guide#memory-optimization)和 [Write Rate Limit](https://hudi.apache.org/docs/flink-quick-start-guide#write-rate-limit).

# 快速开始

## 设置

* 下载1.11.2或1.12.2版本的flink
* 启动Flink集群
  * `flink-conf.yaml`中添加`taskmanager.numberOfTaskSlots: 4`

```shell
bash start-cluster.sh
```

* 启动Flink SQL客户端

```shell
bash sql-client.sh embedded -j ~/Downloads/hudi-flink-bundle_2.11-0.9.0.jar shell
```

## Insert Data

```sql
-- sets up the result mode to tableau to show the results directly in the CLI
set execution.result-mode=tableau;

CREATE TABLE t1(
  uuid VARCHAR(20),
  name VARCHAR(10),
  age INT,
  ts TIMESTAMP(3),
  `partition` VARCHAR(20)
)
PARTITIONED BY (`partition`)
WITH (
  'connector' = 'hudi',
  'path' = 'schema://base-path',
  'table.type' = 'MERGE_ON_READ' -- this creates a MERGE_ON_READ table, by default is COPY_ON_WRITE
);

-- insert data using values
INSERT INTO t1 VALUES
  ('id1','Danny',23,TIMESTAMP '1970-01-01 00:00:01','par1'),
  ('id2','Stephen',33,TIMESTAMP '1970-01-01 00:00:02','par1'),
  ('id3','Julian',53,TIMESTAMP '1970-01-01 00:00:03','par2'),
  ('id4','Fabian',31,TIMESTAMP '1970-01-01 00:00:04','par2'),
  ('id5','Sophia',18,TIMESTAMP '1970-01-01 00:00:05','par3'),
  ('id6','Emma',20,TIMESTAMP '1970-01-01 00:00:06','par3'),
  ('id7','Bob',44,TIMESTAMP '1970-01-01 00:00:07','par4'),
  ('id8','Han',56,TIMESTAMP '1970-01-01 00:00:08','par4');
```

## Update data

```sql
-- 主键相同为修改
insert into t1 values
  ('id1','Danny',27,TIMESTAMP '1970-01-01 00:00:01','par1');
```

## Streaming Query

* 可以通过提交的时间戳去流式消费数据

```sql
CREATE TABLE t1(
  uuid VARCHAR(20),
  name VARCHAR(10),
  age INT,
  ts TIMESTAMP(3),
  `partition` VARCHAR(20)
)
PARTITIONED BY (`partition`)
WITH (
  'connector' = 'hudi',
  'path' = 'oss://vvr-daily/hudi/t1',
  'table.type' = 'MERGE_ON_READ',
  'read.streaming.enabled' = 'true',  -- this option enable the streaming read
  'read.streaming.start-commit' = '20210316134557' -- specifies the start commit instant time
  'read.streaming.check-interval' = '4' -- specifies the check interval for finding new source commits, default 60s.
);

-- Then query the table in stream mode
select * from t1;
```

# Table Option

* 通过Flink SQL WITH配置的表配置

## Memory

| Option Name              | Description                                                  | Default | Remarks                                                      |
| ------------------------ | ------------------------------------------------------------ | ------- | ------------------------------------------------------------ |
| `write.task.max.size`    | 写任务的最大内存(以MB为单位)，当达到阈值时，它刷新最大大小的数据桶以避免OOM。默认1024 mb | `1024D` | 为写缓冲区预留的内存为write.task.max.size - compact .max_memory。当写任务的总缓冲区达到阈值时，将刷新内存中最大的缓冲区 |
| `write.batch.size`       | 为了提高写的效率，Flink写任务会根据写桶将数据缓存到缓冲区中，直到内存达到阈值。当达到阈值时，数据缓冲区将被清除。默认64 mb | `64D`   | 推荐使用默认值                                               |
| `write.log_block.size`   | hudi的日志写入器接收到消息后不会立刻flush数据，写入器以LogBlock为单位将数据刷新到磁盘。在LogBlock达到阈值之前，记录将以序列化字节的形式在写入器中进行缓冲。默认128 mb | `128`   | 推荐使用默认值                                               |
| `write.merge.max_memory` | 如果写入类型是`COPY_ON_WRITE`，Hudi将会合并增量数据和base文件数据。增量数据将会被缓存和溢写磁盘。这个阈值控制可使用的最大堆大小。默认100 mb | `100`   | 推荐使用默认值                                               |
| `compaction.max_memory`  | 与write.merge.max内存相同，但在压缩期间发生。默认100 mb      | `100`   | 如果是在线压缩，则可以在资源足够时打开它，例如设置为1024MB   |

## Parallelism

| Option Name                  | Description                                                  | Default                                                      | Remarks                                                      |
| ---------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| `write.tasks`                | 写入器任务的并行度，每个写任务依次向1到N个桶写。默认的4      | `4`                                                          | 增加并行度对小文件的数量没有影响                             |
| `write.bucket_assign.tasks`  | 桶分配操作符的并行性。无默认值，使用Flink parallelism.default | [`parallelism.default`](https://hudi.apache.org/docs/flink-quick-start-guide#parallelism) | 增加并行度也会增加桶的数量，从而增加小文件(小桶)的数量。     |
| `write.index_boostrap.tasks` | index bootstrap的并行度，增加并行度可以提高bootstarp阶段的效率。因此，需要设置更多的检查点容错时间。默认使用Flink并行 | [`parallelism.default`](https://hudi.apache.org/docs/flink-quick-start-guide#parallelism) | 只有当index. bootstrap .enabled为true时才生效                |
| `read.tasks`                 | Default `4`读操作的并行度(批和流)                            | `4`                                                          |                                                              |
| `compaction.tasks`           | 实时compaction的并行度，默认为10                             | `10`                                                         | `Online compaction` 会占用写任务的资源，推荐使用offline compaction`](https://hudi.apache.org/docs/flink-quick-start-guide#offline-compaction) |

## Compaction

* 以下配置近支持实时compaction
* 通过设置`compaction.async.enabled = false`关闭在线压缩，但我们仍然建议对写作业启用`compaction.schedule.enable`。然后，您可以通过脱机压缩来执行压缩计划。

| Option Name                   | Description                                             | Default       | Remarks                                                      |
| ----------------------------- | ------------------------------------------------------- | ------------- | ------------------------------------------------------------ |
| `compaction.schedule.enabled` | 是否定期生成compaction计划                              | `true`        | 即使compaction.async.enabled = false，也建议打开它           |
| `compaction.async.enabled`    | 异步压缩，MOR默认启用                                   | `true`        | 通过关闭此选项来关闭`online compaction`                      |
| `compaction.trigger.strategy` | 触发compaction的策略                                    | `num_commits` | Options are `num_commits`: 当达到N个delta提交时触发压缩; `time_elapsed`: 当距离上次压缩时间> N秒时触发压缩; `num_and_time`: 当满足`NUM_COMMITS`和`TIME_ELAPSED`时，进行rigger压缩;`num_or_time`: 在满足`NUM_COMMITS`或`TIME_ELAPSED`时触发压缩。 |
| `compaction.delta_commits`    | 触发压缩所需的最大delte提交，默认为5次提交              | `5`           | --                                                           |
| `compaction.delta_seconds`    | 触发压缩所需的最大增量秒数，默认为1小时                 | `3600`        | --                                                           |
| `compaction.max_memory`       | `compaction`溢出映射的最大内存(以MB为单位)，默认为100MB | `100`         | 如果您有足够的资源，建议调整到1024MB                         |
| `compaction.target_io`        | 每次压缩的目标IO(读和写)，默认为5GB                     | `5120`        | `offline compaction` 的默认值是500GB                         |

# Memory Optimization

## MOR

* 设置Flink状态后端为`RocksDB`(默认为`in memory`状态后端)
* 如果有足够的内存，`compaction.max_memory`可以设置大于100MB建议调整至1024MB。
* 注意taskManager分配给每个写任务的内存，确保每个写任务都能分配到所需的内存大小`write.task.max.size`。例如，taskManager有4GB内存运行两个streamWriteFunction，所以每个写任务可以分配2GB内存。请保留一些缓冲区，因为taskManager上的网络缓冲区和其他类型的任务(如bucketAssignFunction)也会占用内存。
* 注意compaction的内存变化，`compaction.max_memory`控制在压缩任务读取日志时可以使用每个任务的最大内存。`compaction.tasks`控制压缩任务的并行性。

## COW

* 设置Flink状态后端为`RocksDB`(默认为`in memory`状态后端)
* 增大`write.task.max.size`和`write.merge.max_memory`(默认1024MB和100MB，调整为2014MB和1024MB)
* 注意taskManager分配给每个写任务的内存，确保每个写任务都能分配到所需的内存大小`write.task.max.size`。例如，taskManager有4GB内存运行两个streamWriteFunction，所以每个写任务可以分配2GB内存。请保留一些缓冲区，因为taskManager上的网络缓冲区和其他类型的任务(如bucketAssignFunction)也会占用内存。

# Bulk Insert

* 用于快照数据导入。如果快照数据来自其他数据源，可以使用bulk_insert模式将快照数据快速导入到Hudi中。
* Bulk_insert消除了序列化和数据合并。用户无需重复数据删除，因此需要保证数据的唯一性。
* Bulk_insert在批处理执行模式下效率更高。默认情况下，批处理执行方式根据分区路径对输入记录进行排序，并将这些记录写入Hudi，避免了频繁切换文件句柄导致的写性能下降。有序写入一个分区中不会频繁写换对应的数据分区
* bulk_insert的并行度由write.tasks指定。并行度会影响小文件的数量。从理论上讲，bulk_insert的并行性是bucket的数量(特别是，当每个bucket写到最大文件大小时，它将转到新的文件句柄。最后，文件的数量>= write.bucket_assign.tasks)。

| Option Name                              | Required | Default  | Remarks                                                      |
| ---------------------------------------- | -------- | -------- | ------------------------------------------------------------ |
| `write.operation`                        | `true`   | `upsert` | Setting as `bulk_insert` to open this function               |
| `write.tasks`                            | `false`  | `4`      | The parallelism of `bulk_insert`, `the number of files` >= [`write.bucket_assign.tasks`](https://hudi.apache.org/docs/flink-quick-start-guide#parallelism) |
| `write.bulk_insert.shuffle_by_partition` | `false`  | `true`   | 写入前是否根据分区字段进行shuffle。启用此选项将减少小文件的数量，但可能存在数据倾斜的风险 |
| `write.bulk_insert.sort_by_partition`    | `false`  | `true`   | 写入前是否根据分区字段对数据进行排序。启用此选项将在写任务写多个分区时减少小文件的数量 |
| `write.sort.memory`                      | `false`  | `128`    | Available managed memory of sort operator. default `128` MB  |

# Index Bootstrap

* 用于`snapshot data`+`incremental data`导入的需求。如果`snapshot data`已经通过`bulk insert`插入到Hudi中。通过`Index Bootstrap`功能，用户可以实时插入`incremental data`，保证数据不重复。
* 如果您认为这个过程非常耗时，可以在写入快照数据的同时增加资源以流模式写入，然后减少资源以写入增量数据(或打开速率限制函数)。

| Option Name               | Required | Default | Remarks                                                      |
| ------------------------- | -------- | ------- | ------------------------------------------------------------ |
| `index.bootstrap.enabled` | `true`   | `false` | 开启index.bootstrap.enabled时，Hudi表中的剩余记录将一次性加载到Flink状态 |
| `index.partition.regex`   | `false`  | `*`     | 优化选择。设置正则表达式来过滤分区。默认情况下，所有分区都被加载到flink状态 |

## 使用方式

1. `CREATE TABLE`创建一条与Hudi表对应的语句。注意这个`table.type`必须正确。
2. 设置`index.bootstrao.enabled`为true开启index bootstrap。
3. 设置`execution.checkpointing.tolerable-failed-checkpoints = n`
4. 等待第一次ck成功则index boostrap执行完毕。
5. 等待index boostrap完成，用户可以退出并保存保存点(或直接使用外部化检查点)。
6. 重启job, 设置 `index.bootstrap.enable` 为 `false`.

# Changelog Mode

* Hudi可以保留消息的所有中间变化(I / -U / U / D)，然后通过flink的状态计算消费，从而拥有一个接近实时的数据仓库ETL管道(增量计算)。Hudi MOR表以行的形式存储消息，支持保留所有更改日志(格式级集成)。所有的更新日志记录可以使用Flink流reader

| Option Name         | Required | Default | Remarks                                                      |
| ------------------- | -------- | ------- | ------------------------------------------------------------ |
| `changelog.enabled` | `false`  | `false` | It is turned off by default, to have the `upsert` semantics, only the merged messages are ensured to be kept, intermediate changes may be merged. Setting to true to support consumption of all changes |
