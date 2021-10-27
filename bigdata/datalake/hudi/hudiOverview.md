# Hudu概览

* Hudi通过hadoop提供流式处理能力
  * Update/Delete操作记录
  * change流能力

## Timeline

* 在其核心，Hudi维护了在不同时刻对表执行的所有操作的时间轴，这有助于提供表的瞬时视图，同时也有效地支持按到达顺序检索数据。一个Hudi instant由以下组件组成
  * `Instant action` : 表中执行的动作类型
  * `Instant time` :瞬时时间通常是一个时间戳(例如:20190117010349)，它按动作开始时间的顺序单调增加。
  * `state` :瞬时的当前状态
* 主要操作包括一下：
  * `COMMIT`:将一批记录原子方式写入库
  * `CLEANS`:删除表中不再需要的旧版本文件的后台活动。
  * `DELTA_COMMIT`:增量提交指的是将一批记录原子写入MergeOnRead类型的表中，其中一些/所有的数据可以只写入增量日志。
  * `COMPACTION`:后台进行COMPACTION操作合并数据，例如基于log文件移动修改的行列格式等
  * `ROLLBACK`:表示提交/增量提交不成功并回滚，删除在此期间在此期间产生的任何部分文件
  * `SAVEPOINT`:将某些文件组标记为“已保存”，以便清洁器不会删除它们。在灾难/数据恢复方案的情况下，它有助于将表恢复到时间轴上的点。
* 任何给定的瞬间都可能处于以下状态之一:
  * `REQUESTED`:表示已安排的操作，但尚未启动
  * `INFLIGHT`:表示当前正在执行操作
  * `COMPLETED`:表示执行完成的操作

![](./img/hudi_timeline.png)

* 上面的例子显示了在10:00到10:20之间在Hudi表上发生的upserts，大约每5分钟，在Hudi时间轴上留下提交元数据，以及其他后台清理/压缩。需要做的一个关键观察是，提交时间指示数据的到达时间(10:20AM)，而实际数据组织反映实际时间或事件时间，数据的目的是(从07:00开始的每小时桶)。在权衡延迟和数据完整性时，这是两个关键概念。
* 当有延迟到达的数据(原定为9:00到达>的数据在10:20晚了1小时)时，我们可以看到upsert将新数据生成到更旧的时间桶/文件夹中。在时间轴的帮助下，尝试获取从10:00小时以来成功提交的所有新数据的增量查询，能够非常有效地只使用更改的文件，而不必扫描所有时间桶> 07:00。

## 文件布局

* Hudi将表组织到DFS的`basepath`的目录结构中。表被分成多个分区，分区是包含该分区数据文件的文件夹，非常类似于Hive表。每个分区由它的`partitionpath`惟一标识，`partitionpath`相对于基本路径。
* 在每个分区中，文件被组织成`file group`，由`file id`唯一标识。每个文件组包含一系列`file slices`,其中，每个`slice`包含在某个提交/压缩瞬间生成的基本文件(`*.parquet`)，以及一组日志文件(`*.log.*`)，这些日志文件包含自基本文件生成以来对基本文件的插入/更新。

### index

* hudi提供高性能的upsert能力，通过索引机制将给定的hoodie键(记录键+分区路径)一致地映射到一个文件id。记录键和文件组/文件id之间的映射，在记录的第一个版本被写入文件后不会改变。简言之，映射文件组包含一组记录的所有版本。

## Table Types&Queries

* hudi表列席定义数据如何被索引和布局在DFS上并且如何在这样的组织之上实现上面的原语和时间轴活动（数据如何被写入），反过来，查询类型定义底层数据是如何暴露于查询的（即如何读取数据）。

| Table Type    | Supported Query types                  |
| ------------- | -------------------------------------- |
| Copy On Write | 快照读+增量读                          |
| Merge On Read | 快照读+增量读 + Read Optimized Queries |

### Table Type

* Copy On Write:使用专用的columnar文件格式存在数据(例如parquet)，通过在写入期间执行同步合并，简单地更新版本和重写文件。
* Merge On Read:使用混合的columnar(例如parquet)+row based(例如avro)文件格式来存储数据。更新被记录到增量文件中，然后被压缩以同步或异步地生成新版本的columnar文件。

#### 俩种表类型的对比

| Trade-off           | CopyOnWrite                     | MergeOnRead                              |
| ------------------- | ------------------------------- | ---------------------------------------- |
| Data Latency        | Higher                          | Lower                                    |
| Query Latency       | Lower                           | Higher                                   |
| Update cost (I/O)   | Higher (rewrite entire parquet) | Lower (append to delta log)              |
| Parquet File Size   | Smaller (high update(I/0) cost) | Larger (low update cost)                 |
| Write Amplification | Higher                          | Lower (depending on compaction strategy) |

### Query types

* hudi支持以下查询类型：
  * `Snapshot Queries`：查询查看给定提交或压缩操作时表的最新快照。对于**MergeOnRead**，它通过动态合并最新文件片的base文件和delte文件来公开接近实时的数据(几分钟)。对于**CopyOnWrite**，它提供了现有parquet表的临时替代品，同时提供了插入/删除和其他写侧功能。
  * `Incremental Queries`:由于给定的commit/compaction，查询只能看到写入表的新数据。这有效地提供了更改流来支持增量数据管道。
  * `Read Optimized Queries`:查询查看给定commit/compaction操作时的表的最新快照。仅公开最新文件片中的base/columnar文件，并保证与非hudi columnar表相比具有相同的columnar查询性能。

#### 快照读和Read Optimized的对比

| Trade-off     | Snapshot                                                     | Read Optimized                               |
| ------------- | ------------------------------------------------------------ | -------------------------------------------- |
| Data Latency  | Lower                                                        | Higher                                       |
| Query Latency | Higher (merge base / columnar file + row based delta / log files) | Lower (raw base / columnar file performance) |

## Copy On Write Table

* Copy-On-Write的File Slices只包含base/columnar文件并且每次提交都提供一个新版本的base文件。换句话说，我们隐式地压缩了每个提交，这样只存在columnar数据。因此，写放大(输入数据的1个字节所写的字节数)要高得多，而读放大为零。这是分析负载所需要的属性，因为分析场景的压力在于读场景。
* 下面演示了从概念上讲，当数据写入copy-on-write表并在其上运行两个查询时，这是如何工作的。

![](./img/copy_on_write.png)

* 当数据写入的时候，对现有文件组的更新将为该文件组生成一个带有提交即时时间戳的新片，插入时，分配一个新的文件组，并为该文件组写入第一个片。这些文件片和它们的提交时间在上面用颜色编码。针对这样一个表运行的SQL查询(例如:select count(*)计算该分区中的总记录)，首先检查最近提交的时间轴，然后过滤每个文件组中除最近的文件片以外的所有文件片。如您所见，旧查询没有看到当前用粉红色编码的inflight提交文件，但在提交后开始的新查询将获得新数据。因此，查询不受任何写失败/部分写的影响，只在已提交的数据上运行。
* Copy On Write Table的目的，是从根本上改进目前表的管理方式
  * 第一类支持在文件级原子更新数据，而不是重写整个表/分区
  * 能够增量地消费更改，而不是浪费的扫描或摸索启发式
  * 严格控制文件大小以保持优异的查询性能(小文件会极大地影响查询性能)。

## Merge On Read Table

* Merge on Read Table是copy on write的一个超集，从某种意义上说，它仍然支持对表的读优化查询，方法是只公开最新文件片中的base/columnar文件。另外，它将每个文件组传入的upserts存储到基于行的增量日志中，以便在查询期间动态地将增量日志应用到每个文件id的最新版本中，从而支持快照查询。因此，这种表类型试图智能地平衡读和写放大，以提供接近实时的数据。这里最重要的变化是压缩器，它现在仔细选择需要将哪些增量日志文件压缩到它们的columnar base文件中，以保持查询性能(较大的增量日志文件在查询端合并数据时会导致更长的合并时间)

![](./img/merge_on_read.png)

* 我们现在大约每1分钟提交一次，这在其他表类型中是做不到的。
* 在每个文件id组中，现在有一个增量日志文件，它保存对base columnar文件中的记录的传入更新。在这个示例中，增量日志文件保存了从10:05到10:10的所有数据。与之前一样，base columnar文件仍然使用提交进行版本控制。因此，如果只看base文件，那么表布局看起来就像写表的副本。
* 查询相同的底层表有两种方法: Read Optimized query 和 Snapshot query,这取决于我们选择的是查询性能还是数据的新鲜度。
* 对于Read Optimized query，何时提交的数据可用的语义会以一种微妙的方式改变。注意，这种在10:10运行的查询不会看到上面10:05之后的数据，而Snapshot query总是看到最新的数据。
* 当我们触发压缩时，决定压缩的是什么，这是解决这些难题的关键。通过实现压缩策略，将最新的分区与旧的分区进行比较，我们可以确保Read Optimized query以一致的方式查看X分钟内发布的数据。

> Merge on read的目的是直接在DFS上进行接近实时的处理，而不是将数据复制到可能无法处理数据量的专门系统。这个表还有一些次要的好处，比如通过避免数据的同步合并减少了写的放大，也就是说，在批处理中每1字节的数据写入的数据量

# Use Case

## 近实时数据采集

* Hudi对各类数据的采集都有很大好处，Hudi强制指定一个最小文件大小在DFS上。这个有助于解决HDFS和云存储存在的小文件问题，显著提高查询性能。Hudi增加了非常需要的原子提交新数据的能力，使查询永远看不到部分写入，并帮助采集从失败中优雅地恢复。
* 对于RDBMS的采集，Hudi通过Upserts提供更快的加载，而不是昂贵和低效的批量加载。使用类似Debezium或Kafka Connect或Sqoop增量导入的变更捕获解决方案并将它们应用到DFS上的等价Hudi表是非常常见的。对于像Cassandra / Voldemort / HBase这样的NoSQL数据存储，即使是中等规模的安装也会存储数十亿行的数据。毫无疑问，完全批量加载是不可行的，如果摄入要跟上通常的高更新量，就需要更有效的方法。

## 数据删除

* Hudi提供了删除存储在数据湖数据的能力，更重要的是，它提供了处理大量写放大的有效方法，基于用户id(或任何辅助键)的随机删除，通过`Merge on Read`表类型产生。Hudi优雅的基于日志的并发控制，确保了摄取/写入可以持续触发，因为后台压缩作业分摊了重写数据/强制删除的成本。
* Hudi还解锁了数据集群等特殊功能，允许用户优化删除数据布局。具体来说，用户可以基于user_id聚类旧的事件日志数据，这样，评估数据删除候选的查询就可以这样做，而最近的分区则针对查询性能进行优化，并根据时间戳进行聚类。

## 统一分析存储

* 统一了离线/实时数据分析，无需在采用不同的OLAP组件。
* Hudi支持分钟级别数据采集，这样保证了近实时数仓能力基础。

## 增量处理管道

* 以记录粒度(而不是文件夹/分区)从上游Hudi表HU消费新数据(包括后期数据)，应用处理逻辑，并有效地更新/协调下游Hudi表HD的后期数据。在这里，HU和HD可以以更频繁的时间表(比如15分钟)连续调度，并在HD上提供30分钟的端-端延迟。

# Writing Data

* Hudi表使用`DeltaStreamer`工具采集新的变化数据通过外部数据源，以及通过使用Hudi数据源的`upserts`加速大型Spark作业。然后可以使用各种查询引擎查询这些表。

## Write Operations

* `UPSERT`:这是默认操作，通过查找索引，输入记录首先被标记为插入或更新。这些记录最终在运行启发式算法后写入，以确定如何最好地将它们打包到存储上，以优化文件大小等事项。这个操作推荐用于`数据库更改捕获`这样的用例，因为输入几乎肯定包含更新。目标表永远不会显示重复项。
* `INSERT`:这个操作在启发式/文件大小方面与upsert非常相似，`但完全跳过了索引查找步骤`。因此，对于日志重复删除之类的用例，它可能比upserts快得多(结合下面提到的过滤重复项的选项)。这也适用于表可以`容忍重复`，但只需要Hudi的事务性写/增量拉取/存储管理功能的用例。
* `BULK_INSERT`:upsert和insert操作都将输入记录保存在内存中，以加快存储启发式计算的速度(以及其他操作)，因此，在初始加载/引导Hudi表时可能会很麻烦。大容量插入提供了与插入相同的语义，同时实现了基于排序的数据写入算法，该算法可以很好地扩展到几百tb的初始负载。然而，与像insert /upserts那样保证文件大小相比，这只是在调整文件大小方面做了最大的努力。

## DeltaStreamer

* `HoodieDeltaStreamer`实用程序(hudi-utilities-bundle的一部分)提供了从不同来源(如DFS或Kafka)获取信息的方法，具有以下功能。
  * 从kafka exactly once方式采集新事件，sqoop增量导入或`HiveIncrementalPuller`的输出或者一个DFS的目录下的文件
  * 支持接收`json、avro或者一个自定义的数据类型`的数据
  * 管理checkpoints，robback&recovery
  * 利用DFS或Confluentschema registry来管理Avro的schema
  * 支持transformations插件

```shell
[hoodie]$ spark-submit --class org.apache.hudi.utilities.deltastreamer.HoodieDeltaStreamer `ls packaging/hudi-utilities-bundle/target/hudi-utilities-bundle-*.jar` --help
Usage: <main class> [options]
Options:
    --checkpoint
      Resume Delta Streamer from this checkpoint.
    --commit-on-errors
      Commit even when some records failed to be written
      Default: false
    --compact-scheduling-minshare
      Minshare for compaction as defined in
      https://spark.apache.org/docs/latest/job-scheduling
      Default: 0
    --compact-scheduling-weight
      Scheduling weight for compaction as defined in
      https://spark.apache.org/docs/latest/job-scheduling
      Default: 1
    --continuous
      Delta Streamer runs in continuous mode running source-fetch -> Transform
      -> Hudi Write in loop
      Default: false
    --delta-sync-scheduling-minshare
      Minshare for delta sync as defined in
      https://spark.apache.org/docs/latest/job-scheduling
      Default: 0
    --delta-sync-scheduling-weight
      Scheduling weight for delta sync as defined in
      https://spark.apache.org/docs/latest/job-scheduling
      Default: 1
    --disable-compaction
      Compaction is enabled for MoR table by default. This flag disables it
      Default: false
    --enable-hive-sync
      Enable syncing to hive
      Default: false
    --filter-dupes
      Should duplicate records from source be dropped/filtered out before
      insert/bulk-insert
      Default: false
    --help, -h

    --hoodie-conf
      Any configuration that can be set in the properties file (using the CLI
      parameter "--propsFilePath") can also be passed command line using this
      parameter
      Default: []
    --max-pending-compactions
      Maximum number of outstanding inflight/requested compactions. Delta Sync
      will not happen unlessoutstanding compactions is less than this number
      Default: 5
    --min-sync-interval-seconds
      the min sync interval of each sync in continuous mode
      Default: 0
    --op
      Takes one of these values : UPSERT (default), INSERT (use when input is
      purely new data/inserts to gain speed)
      Default: UPSERT
      Possible Values: [UPSERT, INSERT, BULK_INSERT]
    --payload-class
      subclass of HoodieRecordPayload, that works off a GenericRecord.
      Implement your own, if you want to do something other than overwriting
      existing value
      Default: org.apache.hudi.common.model.OverwriteWithLatestAvroPayload
    --props
      path to properties file on localfs or dfs, with configurations for
      hoodie client, schema provider, key generator and data source. For
      hoodie client props, sane defaults are used, but recommend use to
      provide basic things like metrics endpoints, hive configs etc. For
      sources, referto individual classes, for supported properties.
      Default: file:///Users/vinoth/bin/hoodie/src/test/resources/delta-streamer-config/dfs-source.properties
    --schemaprovider-class
      subclass of org.apache.hudi.utilities.schema.SchemaProvider to attach
      schemas to input & target table data, built in options:
      org.apache.hudi.utilities.schema.FilebasedSchemaProvider.Source (See
      org.apache.hudi.utilities.sources.Source) implementation can implement
      their own SchemaProvider. For Sources that return Dataset<Row>, the
      schema is obtained implicitly. However, this CLI option allows
      overriding the schemaprovider returned by Source.
    --source-class
      Subclass of org.apache.hudi.utilities.sources to read data. Built-in
      options: org.apache.hudi.utilities.sources.{JsonDFSSource (default),
      AvroDFSSource, JsonKafkaSource, AvroKafkaSource, HiveIncrPullSource}
      Default: org.apache.hudi.utilities.sources.JsonDFSSource
    --source-limit
      Maximum amount of data to read from source. Default: No limit For e.g:
      DFS-Source => max bytes to read, Kafka-Source => max events to read
      Default: 9223372036854775807
    --source-ordering-field
      Field within source record to decide how to break ties between records
      with same key in input data. Default: 'ts' holding unix timestamp of
      record
      Default: ts
    --spark-master
      spark master to use.
      Default: local[2]
  * --table-type
      Type of table. COPY_ON_WRITE (or) MERGE_ON_READ
  * --target-base-path
      base path for the target hoodie table. (Will be created if did not exist
      first time around. If exists, expected to be a hoodie table)
  * --target-table
      name of the target table in Hive
    --transformer-class
      subclass of org.apache.hudi.utilities.transform.Transformer. Allows
      transforming raw source Dataset to a target Dataset (conforming to
      target schema) before writing. Default : Not set. E:g -
      org.apache.hudi.utilities.transform.SqlQueryBasedTransformer (which
      allows a SQL query templated to be passed as a transformation function)
```

* example

```shell
[hoodie]$ spark-submit --class org.apache.hudi.utilities.deltastreamer.HoodieDeltaStreamer `ls packaging/hudi-utilities-bundle/target/hudi-utilities-bundle-*.jar` \
  --props file://${PWD}/hudi-utilities/src/test/resources/delta-streamer-config/kafka-source.properties \
  --schemaprovider-class org.apache.hudi.utilities.schema.SchemaRegistryProvider \
  --source-class org.apache.hudi.utilities.sources.AvroKafkaSource \
  --source-ordering-field impresssiontime \
  --target-base-path file:\/\/\/tmp/hudi-deltastreamer-op \ 
  --target-table uber.impressions \
  --op BULK_INSERT
```

# Schema Evolution

* Hudi支持常见的模式演化场景，比如添加一个可空的字段或提升字段的数据类型，开箱即用。此外，该模式可以跨引擎查询，如Presto、Hive和Spark SQL。下表总结了与不同Hudi表类型兼容的模式更改类型。

| Schema Change                                                | COW  | MOR  | Remarks                                                      |
| ------------------------------------------------------------ | ---- | ---- | ------------------------------------------------------------ |
| Add a new nullable column at root level at the end           | Yes  | Yes  | `Yes` means that a write with evolved schema succeeds and a read following the write succeeds to read entire dataset. |
| Add a new nullable column to inner struct (at the end)       | Yes  | Yes  |                                                              |
| Add a new complex type field with default (map and array)    | Yes  | Yes  |                                                              |
| Add a new nullable column and change the ordering of fields  | No   | No   | Write succeeds but read fails if the write with evolved schema updated only some of the base files but not all. Currently, Hudi does not maintain a schema registry with history of changes across base files. Nevertheless, if the upsert touched all base files then the read will succeed. |
| Add a custom nullable Hudi meta column, e.g. `_hoodie_meta_col` | Yes  | Yes  |                                                              |
| Promote datatype from `int` to `long` for a field at root level | Yes  | Yes  | For other types, Hudi supports promotion as specified in [Avro schema resolution](http://avro.apache.org/docs/current/spec#Schema+Resolution). |
| Promote datatype from `int` to `long` for a nested field     | Yes  | Yes  |                                                              |
| Promote datatype from `int` to `long` for a complex type (value of map or array) | Yes  | Yes  |                                                              |
| Add a new non-nullable column at root level at the end       | No   | No   | In case of MOR table with Spark data source, write succeeds but read fails. As a **workaround**, you can make the field nullable. |
| Add a new non-nullable column to inner struct (at the end)   | No   | No   |                                                              |
| Change datatype from `long` to `int` for a nested field      | No   | No   |                                                              |
| Change datatype from `long` to `int` for a complex type (value of map or array) | No   | No   |                                                              |
|                                                              |      |      |                                                              |

# 并发控制

## 支持的并发控制

* **MVCC**:压缩、清理、集群等Hudi表服务利用Multi Version Concurrency Control在多个表服务写入器和读取器之间提供快照隔离。此外，通过使用MVCC, Hudi提供了`单个摄取写入器和多个并发读取器`之间的快照隔离。通过这个模型，Hudi支持并发运行任意数量的表服务作业，而不存在任何并发冲突。这是通过确保此类表服务的调度计划总是在单个写入模式下发生，以确保没有冲突并避免竞争条件而实现的
*  **OPTIMISTIC CONCURRENCY**:上面描述的写操作(如UPSERT、INSERT)等，利用乐观并发控制来支持对同一个Hudi表的多个写入操作。Hudi支持`file level OCC`，也就是说，`对于发生在同一个表上的任何2次提交(或写入)`，如果它们没有对被更改的`重叠文件`进行写操作，则允许两个写入操作成功。这个功能目前还处于实验阶段，需要Zookeeper或hivemetstore来获取锁。

## Single Writer Guarantee

* `UPSERT Guarantee`:
* *INSERT Guarantee*:
