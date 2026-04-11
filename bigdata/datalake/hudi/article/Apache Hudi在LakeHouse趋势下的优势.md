```plain
导读：伴随着lakehouse(datahouse+datalake)概念的兴起，数据湖框架近些年一直备受关注，Hudi作为少有的几个开源数据湖框架之一，不管是在社区还是业界也是备受追捧，特别的近期Hudi 0.11.0版本横空出世，基于Hudi的湖仓一体方案也在慢慢变得成熟而稳定，本文将会Hudi的特性以及个性化配置原理深入讲解其在LakeHouse趋势下有的优势。
```

# 什么是LakeHouse

## LakeHouse由来

![img](./img/大数据发展.png)

- 数据仓库：主要存储的是以**关系型数据库**组织起来的**结构化数据**。数据通过转换、整合以及清理，并导入到目标表中。在数仓中，数据存储的结构与其定义的schema是强匹配的。
- 数据湖：存储任何类型的数据，包括像图片、文档这样的非结构化数据。数据湖通常更大，其存储成本也更为廉价。存储其中的数据不需要满足特定的schema，数据湖也不会尝试去将特定的schema施行其上。相反的是，数据的拥有者通常会在读取数据的时候解析schema（schema-on-read），当处理相应的数据时，将转换施加其上。
- LakeHouse(湖仓一体)：LakeHouse是从数据仓库阶段->数据湖阶段逐渐演进而来的，是一种结合了**数据湖和数据仓库(DataHouse+DataLake)优势的新架构。由上图可知，LakeHouse主要解决数据可靠性、数据更新成本、时效性、BI、数据分析**等痛点。

## LakeHouse特性

LakeHouse的特性和解决的问题[详见](https://blog.csdn.net/u011487470/article/details/120955058)

- **事务支持：**支持ACID事务，保证了多方可使用SQL并发读写数据。
- **模式演进和治理：**LakeHouse具有随着数据元数据的变化Schema可以动态演进变化，并且对于数据也可以支持多版本的支持。
- **存储与计算分离：**这意味着存储和计算使用单独的集群，因此这些系统能够支持更多用户并发和更大数据量。一些现代数据仓库也具有此属性。
- **BI支持：**LakeHouse可以直接在源数据上使用BI工具。这样可以提高数据新鲜度，减少等待时间，降低必须同时在数据湖和数据仓库中操作两个数据副本的成本。
- **开放性：**使用的存储格式（如Parquet）是开放式和标准化的，并提供API以便各类工具和引擎（包括机器学习和Python / R库）可以直接有效地访问数据。
- **支持从非结构化数据到结构化数据的多种数据类型：**LakeHouse可用于存储、优化、分析和访问许多数据应用所需的包括图像、视频、音频、半结构化数据和文本等数据类型。
- **支持各种工作负载：**包括数据科学、机器学习以及SQL和分析。可能需要多种工具来支持这些工作负载，但它们底层都依赖同一数据存储库。
- **端到端流**：实时报表是许多企业中的标准应用。对流的支持消除了需要构建单独系统来专门用于服务实时数据应用的需求。

## 解决的问题

- **数据重复性：**如果一个组织同时维护了一个数据湖和多个数仓，这无疑会带来数据冗余。在最好的情况下，这仅仅只会带来数据处理的不高效，但是在最差的情况下，它会导致数据不一致的情况出现。Data Lakehouse统一了一切，它去除了数据的重复性，真正做到了**Single Version of Truth(唯一版本)**。
- **高存储成本：**数仓和数据湖都是为了降低数据存储的成本。数仓往往是通过降低冗余，以及整合异构的数据源来做到降低成本。而数据湖则往往使用大数据文件系统（譬如HDFS）和Spark在廉价的硬件上存储计算数据。而最为廉价的方式是结合这些技术来降低成本，这就是现在Lakehouse架构的目标。
- **报表和分析应用之间的差异：**数据分析师们通常倾向于使用整合后的数据，比如数仓或是数据集市。而数据科学家则更倾向于同数据湖打交道，使用各种分析技术来处理未经加工的数据。在一个组织内，往往这两个团队之间没有太多的交集，但实际上他们之间的工作又有一定的重复和矛盾。而当使用Data Lakehouse后，两个团队可以在同一数据架构上进行工作，避免不必要的重复。
- **数据停滞：**在数据湖中，数据停滞是一个最为严重的问题，如果数据一直无人治理，那将很快变为数据沼泽。我们往往轻易的将数据丢入湖中，但缺乏有效的治理，长此以往，数据的时效性变得越来越难追溯。Lakehouse的引入，对于海量数据进行catalog，能够更有效地帮助提升分析数据的时效性。
- **潜在不兼容性带来的风险：**数据分析仍是一门兴起的技术，新的工具和技术每年仍在不停地出现中。一些技术可能只和数据湖兼容，而另一些则又可能只和数仓兼容。Lakehouse灵活的架构意味着公司可以为未来做两方面的准备。

# 为什么选择Hudi

## Hudi概述

Hudi(Hadoop Updates and Incrementals)通过hadoop提供流式处理能力，它支持ACID和`Snapshot`数据隔离，保证数据读取完整性，实现读写并发能力。对用commit的数据能够实现数据秒级入湖，支持可插拔的索引机制能够实现upsert能力。支持Schema Evolution满足**模式演进和治理**。支持**Merge On Read和Copy On Write**俩种类型表，对于不同的实时性需求可以选择不同类型的表。并且Hudi底层可以基于多种存储之上比如HDFS、Baidu Cloud、AWS S3等云存储之上，并且支持多种Hadoop生态的OLAP引擎其中包括**Presto、Hive、Impala、Spark SQL**等一系列OLAP引擎。Hudi这一系列的基础能力基本上能够满足业界对于LakeHouse架构所需的全部能力，这也是Hudi能够在三大开源数据湖框架被大部分大厂应用的原因。

**Hudi底层存储格式**

![img](./img/hudi底层存储.png)

Hudi的存储格式总体划分为File Group、File Slice、Timeline三个大块组件

- **File Group:**包含1~n个File Slice
- **Timeline:**是用于维护不同时刻对表执行的所有操作的时间轴，有助于提供标的瞬时视图和支持按到达顺序检索数据，包含**COMMIT、CLEANS、DELTA_COMMIT、COMPACTION、ROLLBAK、SAVEPOINT**等操作。
- **FIle Slice:**包含base data file和delta data log file，是否包含log file取决于表的类型，Copy On Write只包含base data，Merge On Read包含base data和log file。

## Hudi的优势

- Hudi提供俩种表类型分别为**Merge On Read**和**Copy On Write**表类型，分别用来支持近实时场景和传统数据仓库场景。
- Hudi自身支持多种Service如**Boostrapping、Compaction、Clustering、Metadata Indexing、Cleaning**等能力，这也为加速数据查询和实时数据入湖提供一些技术基础。
- Hudi提供多种数据入湖的工具，如**Spark Datasource Writer、Flink SQL Writer、DeltaStreamer、Kafka Connect Sink、Debezium On Hudi**等插件，其中覆盖多个source。

### Hudi Table Type

- Merge On Read:读取时进行base file和delta file的合并，适用于数据实时入湖场景，配合合理的compact配置可以达到秒级(写入+读取)能力
- Copy On Write:写入时进行合并更新，会根据上一个base file和当前写入数据进行merge，最终的数据格式就等同于`parquet`文件格式的性能，用于替代传统数据湖分析场景的表类型。

#### **两种表类型对比**

| Trade-off         | CopyOnWrite                        | MergeOnRead                              |
| ----------------- | ---------------------------------- | ---------------------------------------- |
| 数据延迟          | Higher                             | Lower                                    |
| 查询延迟          | Lower                              | Higher                                   |
| Update cost (I/O) | Higher (每次都是覆盖写)            | Lower (增量方式写入delta log)            |
| Parquet File Size | Smaller (high update(I/0) cost)    | Larger (low update cost)                 |
| 写放大            | Higher（可以设置文件版本数来控制） | Lower (depending on compaction strategy) |

#### **Copy On Write工作流程**

![img](./img/cow写入流程.png)

当数据写入的时候，对现有**File Group**的更新将为该文件组生成一个带有`提交即时时间戳`的新片，插入时，分配一个新的**File Group**，并为该**File Group**写入第一个**File Slice**。这些**File Slice**和它们的提交时间在上面用颜色编码。针对这样一个表运行的SQL查询(例如:select count(*)计算该分区中的总记录)，首先检查最近提交的时间轴，然后过滤每个文件组中除最近的**File Slice**以外的所有**File Slice**。旧查询没有看到当前用粉红色编码的inflight提交文件，但在提交后开始的新查询将获得新数据。因此，查询不受任何写失败/部分写的影响，只在已提交的数据上运行。

#### **Merge On Read工作流程**

![img](./img/mor写入流程.png)

MOR表大约每1分钟提交一次，这在其他表类型中是做不到的。在每个文件id组中，现在有一个增量日志文件，它保存对base data文件中的记录的传入更新。在这个示例中，增量日志文件保存了从10:05到10:10的所有数据。与之前一样，base data文件仍然使用提交进行版本控制。因此，如果只看base文件，那么表布局看起来就像copy on write表。查询相同的底层表有两种方法: **Read Optimized query** 和 **Snapshot query**,这取决于我们选择的是查询性能还是数据的新鲜度。当我们触发compact时，决定compact的是什么，这是解决这些难题的关键。通过实现压缩策略，将最**新的分区与旧的分区进行比较**，我们可以确保Read Optimized query以一致的方式查看X分钟内发布的数据。

#### Hudi Query Type

- `Snapshot Queries`：查询查看给定提交或压缩操作时表的最新快照。对于**MergeOnRead**，它通过动态合并最新文件片的base文件和delte文件来公开接近实时的数据(几分钟)。对于**CopyOnWrite**，它提供了现有parquet表的临时替代品，同时提供了插入/删除和其他写功能。
- `Incremental Queries`:由于给定的commit/compaction，查询只能看到写入表的新数据。这有效地提供了更改流来支持增量数据管道。
- `Read Optimized Queries`:查询查看给定commit/compaction操作时的表的最新快照。仅公开最新文件片中的base/columnar文件，并保证与非hudi columnar表相比具有相同的columnar查询性能，只读取最近compaction的base file。

### Clustering架构

Hudi为了平衡文件大小和摄取速度的平衡提供了**hoodie.parquet.small.file.limit**参数来设置最小文件大小，如果该参数设置为0可以强制新数据写入新的File Group中，否则会优先确保新数据被写入到现有小的File Group中，直到达到参数限制大小为止，这样会增加摄取延迟因为存在查找最优写入File Group的操作。这时候对于Hudi底层的文件布局要求就相对严格，Hudi因此提供一种**Clustering架构**通过异步或者同步方式运行，通过一种新的**REPLACE**操作将Hudi元数据**Timeline**中标记**Clustering操作，Clustering**分为调度和执行俩种类型。参考[Hudi Clustering架构](https://mp.weixin.qq.com/s/5JdOrI8HpJJS-xkVG296iw)

#### 调度Clustering

识别符合Clustering条件的文件：根据所选的Clustering策略，调度逻辑将识别符合Clustering条件的文件。

根据特定条件对符合Clustering条件的文件进行分组。每个组的数据大小应为`targetFileSize`的倍数。分组是计划中定义的"策略"的一部分。此外还有一个选项可以限制组大小，以改善并行性并避免混排大量数据。

最后将Clustering计划以avro元数据格式保存到时间线。

#### 运行Clustering

读取Clustering计划，并获得`clusteringGroups`，其标记了需要进行Clustering的文件组。

对于每个组使用strategyParams实例化适当的策略类（例如：sortColumns），然后应用该策略重写数据。

创建一个`REPLACE`提交，并更新HoodieReplaceCommitMetadata中的元数据。

Clustering服务基于Hudi的MVCC设计，允许继续插入新数据，而Clustering操作在后台运行以重新格式化数据布局，从而确保并发读写者之间的快照隔离。

注意：现在对表进行Clustering时还不支持更新，将来会支持并发更新。

![img](./img/Clustering机制.png)

### Compaction

Compaction操作是LSM-Tree的一个操作，Hudi底层存储类似于LSM-Tree数据文件支持多个Version的概念，通过Rewrite或者Merge的方式来进行数据处理，因此如果Hudi MOR表底层File Slice的log file过多会导致严重的读放大问题，因为需要在读取的时候进行merge操作。Compaction操作是将多个版本数据进行合并压缩的操作，合适的compaction策略可以使得MOR表达到类比雨COW表的性能。Hudi提供3种Compaction策略分别为**异步Compaction、同步Compaction和离线Compaction。**

#### 异步Compaction

- **Compaction调度:** 通过摄取数据任务来完成，Hudi会扫描这些分区和选择一些file slices来进行copmact。并且copmaction操作最终会写入Hudi的**Timeline。**
- **Compaction执行:**读取copmaction计划和file slices去进行compaction操作。

##### Flink中的应用

```scala
    val compactionHudiOptions =
     // 是否开启streaming job内的异步compaction
      s"""  '${FlinkOptions.COMPACTION_ASYNC_ENABLED.key}'='true',
      // 最大多少个delta_commit操作出发一次compaction操作
         |  '${FlinkOptions.COMPACTION_DELTA_COMMITS.key}'='5',
         // 是否开启调度compaction
         |  '${FlinkOptions.COMPACTION_SCHEDULE_ENABLED.key}'='true',
        // compaction任务并行度
         |  '${FlinkOptions.COMPACTION_TASKS.key}'='20',
         // compaction最大的内存，超过会溢写磁盘
         |  '${FlinkOptions.COMPACTION_MAX_MEMORY.key}'='200',
         // compaction触发策略，支持commit数量、compaction的时间间隔、数量和固定间隔、数量或者时间间隔四种触发策略
         |  '${FlinkOptions.COMPACTION_TRIGGER_STRATEGY.key}'='${FlinkOptions.NUM_COMMITS}'"""
```

#### 同步Compaction

- 同步Compaction可以使得刚摄入的数据就能够比较高效的进行查询，但是摄取延迟会相对大。

#### 离线Compaction

- 通过Hudi提供的Compaction工具对特定MOR表进行Compaction，其中支持Spark、Hudi Cli、Flink三种方式，分别以Spark、Flink任务运行对应的Compaction任务进行Compaction操作。

### Other

- **数据ETL工具:**Hudi还有提供了很多能力如实时入湖插件**DeltaStreamer、Flink CDC Connector、Debezium On Hudi、Kafka Connect Sink等**，同时也提供了批量入湖工具如**Bulk Insert、Spark Datasource Writer、Flink SQL Writer等。**
- **Schema Evolution:**schema演化能力，不停机方式兼容元数据的变化。
- **Data Skiping:**
  - 支持多种可插拔Index能力，从而使得hudi拥有高效的upsert能力，index默认也支持如**Simple Index、Bloom Filter、Global Bloom Filter、Hbase Index等**多种类型的索引。
  - Column Stat Index，通过将Parquet Footer存储到的metadata table并且创建对应的columnIndex来记录Column的statistics(max/min value、Null Count、total number等)信息，来达到pruning效果，这里大家可以思考下为什么不直接读取Parquet的footer数据，具体可以参考下[Hudi RFC-27](https://github.com/apache/hudi/blob/master/rfc/rfc-27/rfc-27.md)，这个RFC详细说明了Column Stat Index的设计细节。
- 还有很多其他能力大家也可以通过官方文档来进行了解。

## LakeHouse三剑客对比

业界数据湖有三种比较流行的开源框架分别是Hudi、Iceberg、Delta，三种数据湖框架在对应的能力上也呈现的差异化比较大。

| ·                           | Delta                                              | Hudi                                                         | Iceberg                      |
| --------------------------- | -------------------------------------------------- | ------------------------------------------------------------ | ---------------------------- |
| 增加写入                    | Spark                                              | Spark/Flink                                                  | Spark/Flink                  |
| ACID 修改                   | HDFS, S3 (Databricks), OSS                         | HDFS,S3,BOS,OSS等                                            | HDFS, S3                     |
| Upserts/Delete/Merge/Update | Delete/Merge/Update                                | Upserts/Delete/Merge                                         | No                           |
| Streaming sink              | Yes                                                | Yes                                                          | Yes(not ready?)              |
| Streaming source            | Yes                                                | Yes                                                          | No                           |
| 文件格式                    | Parquet                                            | Avro(meta data),Parquet(base file)                           | Parquet, ORC                 |
| Data Skipping               | File-Level Max-Min stats + Z-Ordering (Databricks) | File-Level Max-Min stats + Index(Bloom Filter、HBase Index等) | File-Level Max-Min Filtering |
| Concurrency control         | Optimistic                                         | Optimistic                                                   | Optimistic                   |
| Data Validation             | Yes (Databricks)                                   | No                                                           | Yes                          |
| Merge on read               | No                                                 | Yes                                                          | No                           |
| Copy on write               | No                                                 | Yes                                                          | No                           |
| Schema Evolution            | Yes                                                | Yes                                                          | Yes                          |
| File I/O Cache              | Yes (Databricks)                                   | No                                                           | No                           |
| Cleanup                     | Manual                                             | Automatic                                                    | No                           |
| Compaction                  | Manual                                             | Automatic                                                    | No                           |

可以看出Hudi相对于其他俩种数据湖框架有很多比较重要的能力，比如自动Compaction和自动Cleanup能力，这样不会担心因为数据文件多个版本导致数据存在**读放大**问题，提供的Copy On Write表类型也帮助一些原本基于HDFS建设的传统数仓能够将任务便捷的迁移至Hudi平台。并且底层支持多种可插拔可扩展的索引机制，在面对不同业务场景可以支持多种灵活的变化来解决业务痛点。

## 谁在使用Hudi

![img](./img/whoUse.png)

可以看出来Hudi目前已经被国内外大厂所使用，并且在本人公司内部目前也在使用Hudi这也是选择Hudi的一大因素。

# Hudi在公司内的应用场景

## 实时数据平台存储场景

### 背景和痛点

从公司内部底层核心数据处理平台CDP的数据存储技术选型出发考虑，CDP底层数据存储选择了Kudu+Doris的组合，核心的用户行为、画像、标签等业务数据存储在Kudu中，然后通过规划好的消息格式将数据通过Kafka传输至Doris中，这其实存在很大的问题首先是数据链路过长，需要保证Kudu和Doris双写问题，在实际使用场景中因为私域页面使用的指标底层数据源存在Kudu和Doris的场景从而导致数据不一致问题，并且也会存在消息队列的不稳定导致的数据丢失和无序从而导致下游Doris基于Replace All方式插入数据时存在数据丢失问题。在数据即系查询方面因为Kudu的特殊性其仅支持Presto和Impala俩种OLAP引擎。

并且因为Kudu需要直接提供数据服务给页面，其的查询能力随着并发能力上升会导致查询耗时逐渐增大，因此需要对Kudu中的日志递增大表进行冷热数据处理，这也引入了一个数据冷备任务和数据冷备存储的新问题，从而导致整体CDP的数据治理是相对复杂而不可控的。

### Hudi解决的问题

在旧的数据平台存储架构里Kudu往往作为一个业务库来使用，并且因为其并不支持跨Tablet的事务从而导致在业务逻辑上需要一些同步处理(这也是平台数据处理吞吐量的局限所在)，Doris作为一个分析引擎当时因为Kudu并没有类似于MySQL的binlog机制从而导致数据入Doris数据仓库存在不稳定性等问题。数据平台需要比较实时的数据一般是用户的画像数据，配合Hudi这些画像数据可以通过MySQL来进行存储，配合Hudi On Flink提供的CDC能力可以将MySQL的业务数据近实时入Hudi的ODS层，其他实时任务可以基于Hudi提供的Streaming Source能力配合Kafka的消息进行实时数据指标计算能力并将最终的结果在重新入Hudi的DM层，再配合Hudi支持的多种OLAP引擎进行数据服务提供，数据分析和数据产品同学也可以通过Hive等平台进行即系查询。Hudi也替代了Doris可以直接提供数据分析能力，从而避免了Kudu至Doris之间的数据同步问题。

## 整体数据仓库

### 背景和痛点

因为公司是敏捷开发模式会存在多个敏捷团队和多个业务域对于不同的业务场景数据的格式和时效性要求也是不一样的，目前部门内的数据仓库使用的工具也分为很多如公司内的数据开发套件等平台等，这也导致各个敏捷团队需要各自处理需要的数据需求，对于这些厂内的平台需要很多前置要求，往往对于一个团队很小的取数需求来说，一系列的前置操作往往导致需要很大的成本。并且如果凤阁平台因为其封装的Spark SQL或者其他计算引擎失败后对应团队的RD同学也需要知道相关的技术框架知识才能更好的定位和解决问题。

### Hudi解决的问题

基于Hudi提供的能力可以在部门内部建设一个不限制业务场景、业务域和业务格式的LakeHouse平台，Hudi本身也支持数据的多版本、实时写入、读取能力，并且可以交由专门的团队来维护一套统一的数据口径，各个敏捷团队如果需要使用数据可以通过消息管道、Spark SQL批量等等各个方式进行数据拉取，从而统一存储和计算的口径。

# Flink On Hudi源码分析

- 根据上述案例的Flink On Hudi实践，这一个part会基于Hudi On Flink 0.9.x版本对其核心的流式写入函数进行源码走读，核心包含如何分bucket、如何flush bucket、内部flink state的维护等源码分析，主要是帮助大家如何去阅读Hudi源码建立一个方法论。

## StreamWriteFunction

- 用于将数据写入外部系统，这个函数首先会buffer一批HoodieRecord数据，当一批buffer数据上超过` FlinkOptions#WRITE_BATCH_SIZE`大小或者全部的buffer数据超过`FlinkOptions#WRITE_TASK_MAX_SIZE`，或者是Flink开始做ck，则flush。如果一批数据写入成功，则StreamWriteOperatorCoordinator会标识写入成功。
- 这个operator coordinator会校验和提交最后一个instant，当最后一个instant提交成功时会启动一个新的instant。它会开启一个新的instant之前回滚全部inflight instant，hoodie的instant只会在一个ck中。写函数在它ck超时抛出异常时刷新数据buffer，任何检查点失败最终都会触发作业失败。

### 核心属性

```java
/**
   * Write buffer as buckets for a checkpoint. The key is bucket ID.
   */
  private transient Map<String, DataBucket> buckets;

  /**
   * Config options.
   */
  private final Configuration config;

  /**
   * Id of current subtask.
   */
  private int taskID;

  /**
   * Write Client.
   */
  private transient HoodieFlinkWriteClient writeClient;

/**
* 写入函数
*/
  private transient BiFunction<List<HoodieRecord>, String, List<WriteStatus>> writeFunction;

  /**
   * The REQUESTED instant we write the data.
   */
  private volatile String currentInstant;

  /**
   * Gateway to send operator events to the operator coordinator.
   */
  private transient OperatorEventGateway eventGateway;

  /**
   * Commit action type.
   */
  private transient String actionType;

  /**
   * Total size tracer. 记录大小的tracer
   */
  private transient TotalSizeTracer tracer;

  /**
   * Flag saying whether the write task is waiting for the checkpoint success notification
   * after it finished a checkpoint.
   *
   * <p>The flag is needed because the write task does not block during the waiting time interval,
   * some data buckets still flush out with old instant time. There are two cases that the flush may produce
   * corrupted files if the old instant is committed successfully:
   * 1) the write handle was writing data but interrupted, left a corrupted parquet file;
   * 2) the write handle finished the write but was not closed, left an empty parquet file.
   *
   * <p>To solve, when this flag was set to true, we block the data flushing thus the #processElement method,
   * the flag was reset to false if the task receives the checkpoint success event or the latest inflight instant
   * time changed(the last instant committed successfully).
   */
  private volatile boolean confirming = false;

  /**
   * List state of the write metadata events.
   */
  private transient ListState<WriteMetadataEvent> writeMetadataState;

  /**
   * Write status list for the current checkpoint.
   */
  private List<WriteStatus> writeStatuses;
```

### open方法

- Flink提供的open方法，每个subtask启动的时候会首先运行open方法执行相关逻辑

```java
public void open(Configuration parameters) throws IOException {
this.tracer = new TotalSizeTracer(this.config);
initBuffer();
initWriteFunction();
}
private static class TotalSizeTracer {
private long bufferSize = 0L;
private final double maxBufferSize;
TotalSizeTracer(Configuration conf) {
  long mergeReaderMem = 100; // constant 100MB
  long mergeMapMaxMem = conf.getInteger(FlinkOptions.WRITE_MERGE_MAX_MEMORY);
  // 最大的buffer大小
  this.maxBufferSize = (conf.getDouble(FlinkOptions.WRITE_TASK_MAX_SIZE) - mergeReaderMem - mergeMapMaxMem) * 1024 * 1024;
  final String errMsg = String.format("'%s' should be at least greater than '%s' plus merge reader memory(constant 100MB now)",
      FlinkOptions.WRITE_TASK_MAX_SIZE.key(), FlinkOptions.WRITE_MERGE_MAX_MEMORY.key());
  ValidationUtils.checkState(this.maxBufferSize > 0, errMsg);
}

/**
 * Trace the given record size {@code recordSize}.
 *
 * @param recordSize The record size
 * @return true if the buffer size exceeds the maximum buffer size
 */
boolean trace(long recordSize) {
  // 判断是否大于maxBufferSize
  this.bufferSize += recordSize;
  return this.bufferSize > this.maxBufferSize;
}

void countDown(long size) {
  this.bufferSize -= size;
}

public void reset() {
  this.bufferSize = 0;
}
}
// 初始化bucket
private void initBuffer() {
this.buckets = new LinkedHashMap<>();
}
// 初始writeFunction
private void initWriteFunction() {
final String writeOperation = this.config.get(FlinkOptions.OPERATION);
switch (WriteOperationType.fromValue(writeOperation)) {
case INSERT:
this.writeFunction = (records, instantTime) -> this.writeClient.insert(records, instantTime);
break;
case UPSERT:
this.writeFunction = (records, instantTime) -> this.writeClient.upsert(records, instantTime);
break;
case INSERT_OVERWRITE:
this.writeFunction = (records, instantTime) -> this.writeClient.insertOverwrite(records, instantTime);
break;
case INSERT_OVERWRITE_TABLE:
this.writeFunction = (records, instantTime) -> this.writeClient.insertOverwriteTable(records, instantTime);
break;
default:
throw new RuntimeException("Unsupported write operation : " + writeOperation);
}
}
```

### initializeState

- Flink的initializeState方法，初始化Flink State，创建hudi写入客户端，获取actionType，然后根据是否savepoint确定是否重新提交inflight阶段的instant

```java
public void initializeState(FunctionInitializationContext context) throws Exception {
    this.taskID = getRuntimeContext().getIndexOfThisSubtask();
    // 创建hudi写入客户端
    this.writeClient = StreamerUtil.createWriteClient(this.config, getRuntimeContext());
    // 读取with配置
    this.actionType = CommitUtils.getCommitActionType(
        WriteOperationType.fromValue(config.getString(FlinkOptions.OPERATION)),
        HoodieTableType.valueOf(config.getString(FlinkOptions.TABLE_TYPE)));

    this.writeStatuses = new ArrayList<>();
    // 写入元数据状态
    this.writeMetadataState = context.getOperatorStateStore().getListState(
        new ListStateDescriptor<>(
            "write-metadata-state",
            TypeInformation.of(WriteMetadataEvent.class)
        ));

    this.currentInstant = this.writeClient.getLastPendingInstant(this.actionType);
    if (context.isRestored()) {
      restoreWriteMetadata();
    } else {
      sendBootstrapEvent();
    }
    // blocks flushing until the coordinator starts a new instant
    this.confirming = true;
  }


//WriteMetadataEvent
public class WriteMetadataEvent implements OperatorEvent {
  private static final long serialVersionUID = 1L;

  public static final String BOOTSTRAP_INSTANT = "";

  private List<WriteStatus> writeStatuses;
  private int taskID;
  // instant时间
  private String instantTime;
  // 是否最后一个批次
  private boolean lastBatch;

  /**
   * Flag saying whether the event comes from the end of input, e.g. the source
   * is bounded, there are two cases in which this flag should be set to true:
   * 1. batch execution mode
   * 2. bounded stream source such as VALUES
   */
  private boolean endInput;

  /**
   * Flag saying whether the event comes from bootstrap of a write function.
   */
  private boolean bootstrap;
}

// 恢复写入元数据
private void restoreWriteMetadata() throws Exception {
    String lastInflight = this.writeClient.getLastPendingInstant(this.actionType);
    boolean eventSent = false;
    for (WriteMetadataEvent event : this.writeMetadataState.get()) {
      if (Objects.equals(lastInflight, event.getInstantTime())) {
        // The checkpoint succeed but the meta does not commit,
        // re-commit the inflight instant
        // 重新提交inflight的instant
        this.eventGateway.sendEventToCoordinator(event);
        LOG.info("Send uncommitted write metadata event to coordinator, task[{}].", taskID);
        eventSent = true;
      }
    }
    if (!eventSent) {
      sendBootstrapEvent();
    }
  }

  private void sendBootstrapEvent() {
    // 发送空的event
    this.eventGateway.sendEventToCoordinator(WriteMetadataEvent.emptyBootstrap(taskID));
    LOG.info("Send bootstrap write metadata event to coordinator, task[{}].", taskID);
  }
```

### snapshotState

- Flink的snapshotState方法每次checkpoint操作会调用这个方法进行快照操作。

```java
public void snapshotState(FunctionSnapshotContext functionSnapshotContext) throws Exception {
  //基于协调器首先启动检查点的事实，
  //它将检查有效性。
  //等待缓冲区数据刷新，并请求一个新的即时
    flushRemaining(false);
    // 重新加载writeMeta状态
    reloadWriteMetaState();
  }
// endInput标识是否无界流
private void flushRemaining(boolean endInput) {
      // hasData==(this.buckets.size() > 0 && this.buckets.values().stream().anyMatch(bucket -> bucket.records.size() > 0);)
  // 获取当前instant
    this.currentInstant = instantToWrite(hasData());
    if (this.currentInstant == null) {
      // in case there are empty checkpoints that has no input data
      throw new HoodieException("No inflight instant when flushing data!");
    }
    final List<WriteStatus> writeStatus;
    if (buckets.size() > 0) {
      writeStatus = new ArrayList<>();
      this.buckets.values()
          // The records are partitioned by the bucket ID and each batch sent to
          // the writer belongs to one bucket.
          .forEach(bucket -> {
            List<HoodieRecord> records = bucket.writeBuffer();
            if (records.size() > 0) {
              if (config.getBoolean(FlinkOptions.INSERT_DROP_DUPS)) {
                // 去重
                records = FlinkWriteHelper.newInstance().deduplicateRecords(records, (HoodieIndex) null, -1);
              }
              // 预写 在刷新之前设置:用正确的分区路径和fileID修补第一个记录。
              bucket.preWrite(records);
              // 写入数据
              writeStatus.addAll(writeFunction.apply(records, currentInstant));
              records.clear();
              bucket.reset();
            }
          });
    } else {
      LOG.info("No data to write in subtask [{}] for instant [{}]", taskID, currentInstant);
      writeStatus = Collections.emptyList();
    }
  // 构造WriteMetadataEvent
    final WriteMetadataEvent event = WriteMetadataEvent.builder()
        .taskID(taskID)
        .instantTime(currentInstant)
        .writeStatus(writeStatus)
        .lastBatch(true)
        .endInput(endInput)
        .build();
    // 发送event
    this.eventGateway.sendEventToCoordinator(event);
    this.buckets.clear();
    this.tracer.reset();
    this.writeClient.cleanHandles();
  // 写入状态放入状态
    this.writeStatuses.addAll(writeStatus);
    // blocks flushing until the coordinator starts a new instant
    this.confirming = true;
  }

 /**
   * Reload the write metadata state as the current checkpoint.
   */
  private void reloadWriteMetaState() throws Exception {
    // 清理writeMetadataState
    this.writeMetadataState.clear();
    WriteMetadataEvent event = WriteMetadataEvent.builder()
        .taskID(taskID)
        .instantTime(currentInstant)
        .writeStatus(new ArrayList<>(writeStatuses))
        .bootstrap(true)
        .build();
    this.writeMetadataState.add(event);
    writeStatuses.clear();
  }
```

### bufferRecord

- Hudi底层核心数据写入方法，根据writer batch size和全部buffer大小来确定是否需要刷新bucket，其中包含对bucket数据是否去重、预写（找到对应的file id）等操作

```java
private void bufferRecord(HoodieRecord<?> value) {
  // 根据record获取bucketId {partition path}_{fileID}.
    final String bucketID = getBucketID(value);
        // 获取对应bucket
    DataBucket bucket = this.buckets.computeIfAbsent(bucketID,
        k -> new DataBucket(this.config.getDouble(FlinkOptions.WRITE_BATCH_SIZE), value));
  // 包装hoodie记录
    final DataItem item = DataItem.fromHoodieRecord(value);
        // 判断是否需要刷新bucket，是否超过WRITE_BATCH_SIZE大小
    boolean flushBucket = bucket.detector.detect(item);
   // 判断是否需要刷新buffer，是否超过maxBufferSize，总buffer大小
    boolean flushBuffer = this.tracer.trace(bucket.detector.lastRecordSize);
    if (flushBucket) {
      if (flushBucket(bucket)) {
        // 清理总buffer大小
        this.tracer.countDown(bucket.detector.totalSize);
        // 重置bucket大小
        bucket.reset();
      }
    } else if (flushBuffer) {
      // find the max size bucket and flush it out，找到最大的bucket然后flush
      List<DataBucket> sortedBuckets = this.buckets.values().stream()
          .sorted((b1, b2) -> Long.compare(b2.detector.totalSize, b1.detector.totalSize))
          .collect(Collectors.toList());
      final DataBucket bucketToFlush = sortedBuckets.get(0);
      if (flushBucket(bucketToFlush)) {
        this.tracer.countDown(bucketToFlush.detector.totalSize);
        bucketToFlush.reset();
      } else {
        LOG.warn("The buffer size hits the threshold {}, but still flush the max size data bucket failed!", this.tracer.maxBufferSize);
      }
    }
  // 一批buffer数据上不超过` FlinkOptions#WRITE_BATCH_SIZE`大小或者全部的buffer数据超过`FlinkOptions#WRITE_TASK_MAX_SIZE`
    bucket.records.add(item);
  }

// 刷新bucket
private boolean flushBucket(DataBucket bucket) {
    String instant = instantToWrite(true);

    if (instant == null) {
      // in case there are empty checkpoints that has no input data
      LOG.info("No inflight instant when flushing data, skip.");
      return false;
    }

    List<HoodieRecord> records = bucket.writeBuffer();
    ValidationUtils.checkState(records.size() > 0, "Data bucket to flush has no buffering records");
    if (config.getBoolean(FlinkOptions.INSERT_DROP_DUPS)) {
      // 去重hoodieRecord
      records = FlinkWriteHelper.newInstance().deduplicateRecords(records, (HoodieIndex) null, -1);
    }
      // 预写 在刷新之前设置:用正确的分区路径和fileID修补第一个记录。
    bucket.preWrite(records);
    // 写入记录
    final List<WriteStatus> writeStatus = new ArrayList<>(writeFunction.apply(records, instant));
    records.clear();
   // 发送数据
    final WriteMetadataEvent event = WriteMetadataEvent.builder()
        .taskID(taskID)
        .instantTime(instant) // the write instant may shift but the event still use the currentInstant.
        .writeStatus(writeStatus)
        .lastBatch(false)
        .endInput(false)
        .build();

    this.eventGateway.sendEventToCoordinator(event);
    writeStatuses.addAll(writeStatus);
    return true;
  }
```

# 总结&QA

LakeHouse作为大数据领域目前炙手可热的一项新兴的架构理论，也需要一个合适的技术框架来支持其理论，Hudi作为三大开源数据湖框架之一，其完美支撑了LakeHouse几大核心特性。并且目前Hudi社区的活跃度也是三大开源框架中最活跃的，Flink和Spark在Hudi中的能力建设也近贴其大版本方向，随着Hudi 0.11.x版本的发布，Hudi已经可以支持1.14.x版本的Flink与3.x版本的Spark版本，Hudi也因此在LakeHouse领域变得越来越重要。

![img](../../../img/公众号.png)

**感谢关注**

# 附录

## 资料参考

- [个人Hudi学习知识仓库](https://shimin-huang.gitbook.io/doc/bigdata/datalake/hudi)
- [最佳实践 | 通过Apache Hudi和Alluxio建设高性能数据湖](https://mp.weixin.qq.com/s?__biz=MzIyMzQ0NjA0MQ==&mid=2247485340&idx=1&sn=009db01fb1bd77813eea14db94477d66&scene=21#wechat_redirect)
- [基于Apache Hudi + Flink的亿级数据入湖实践](https://mp.weixin.qq.com/s?__biz=MzIyMzQ0NjA0MQ==&mid=2247487958&idx=1&sn=95241088552e4f244775ff9212f28c12&chksm=e81f44a0df68cdb67604caceb344582ce9b79be8aeaab5c386b0f6a35dd8163c0975b43b0b43&scene=178&cur_album_id=1608246271566282759#rd)
- [Data Lakehouse: Building the Next Generation of Data Lakes using Apache Hudi](https://medium.com/slalom-build/data-lakehouse-building-the-next-generation-of-data-lakes-using-apache-hudi-41550f62f5f)
- [The Art of Building Open Data Lakes with Apache Hudi, Kafka, Hive, and Debezium](https://garystafford.medium.com/the-art-of-building-open-data-lakes-with-apache-hudi-kafka-hive-and-debezium-3d2f71c5981f)
- https://hudi.apache.org/
- [Hudi实践整合](https://github.com/leesf/hudi-resources)



## 代码仓库

[FlinkWithHudi Alluxio](https://github.com/collabH/flink-learn/tree/master/flink-hudi/src/main/java/dev/flink/hudi)