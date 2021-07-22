# 概述

* Apache Iceberg是用于大型分析数据集的开放表格式。 Iceberg在Trino和Spark中添加了使用高性能格式的表，该格式的工作方式类似于SQL表。

## 用户特性

* schem演进支持添加、删除、更新或重命名，并且没有副作用
* 隐藏分区可以防止导致错误提示或错误查询的用户错误
* 分区布局演变可以随着数据量或查询模式的变化而更新表的布局
* 时间旅行可实现使用完全相同的表快照的可重复查询，或者使用户轻松检查更改
* 版本回滚使用户可以通过将表重置为良好状态来快速纠正问题

## 可靠性和性能

* 对于生产环境来说iceberg单表可以支撑数10PB级别的数据，这些数据甚至可以在没有分布式SQL引擎的情况下读取。
  * scan计划快速-分布式SQL引擎不需要读取表或查找文件
  * 优秀的过滤-使用表元数据，使用分区和列级统计来修剪数据文件
* Iceberg是为了解决最终一致的云对象存储中的正确性问题而设计的
  * 使用任何云存储，通过避免列表和重命名，在HDFS中减少NN拥塞
  * 序列化隔离性：表更改是原子的，读取器永远不会看到部分或未提交的更改
  * 多个并发写入器使用乐观并发，并将重试以确保兼容更新成功，即使在写入冲突时也是如此

# Tables相关

## 配置

### Table参数配置

#### Read参数属性

* read.split.target-size:默认 134217728 (128 MB),合并数据输入分片时的目标大小
* read.split.metadata-target-size:33554432 (32 MB)，合并元数据输入分片时的目标大小
* read.split.planning-lookback:默认10，合并输入分片时要考虑的箱数
* read.split.open-file-cost:4194304(4MB),打开文件的估计费用，用作合并分片时的最小权重。

#### Write参数属性

* write.format.default:默认parquet，写入数据格式，支持orc、parquet、orc
* write.parquet.row-group-size-默认134217728 (128 MB)，Parquet row group size
* write.parquet.page-size-bytes:默认1048576 (1 MB),Parquet page size
* write.parquet.dict-size-bytes:默认2097152 (2 MB)，Parquet dictionary page size
* write.parquet.compression-codec:默认gzip
* write.parquet.compression-level:默认为null
* write.avro.compression-codec:默认gzip
* write.location-provider.impl:默认null，LocationProvider的可选自定义实现
* write.metadata.compression-codec:默认none，可以选择gzip
* write.metadata.metrics.default:默认truncate(16)，表中所有列的默认指标模式； 无，计数，截断（长度）或完整
* write.metadata.metrics.column.col1
* write.target-file-size-bytes:默认为最大值，控制生成到目标的文件的大小
* write.distribution-mode:默认none，定义写数据的分布：none：不对行进行随机排序； hash：按分区键散列； range：如果表具有SortOrder，则按分区键或排序键分配范围
* write.wap.enabled:默认false
* write.summary.partition-limit:默认为0，如果更改的分区计数小于此限制，则在快照汇总中包含分区级汇总统计
* write.metadata.delete-after-commit.enabled:默认为false，控制提交后是否删除最旧版本的元数据文件
* write.metadata.previous-versions-max:默认为100，在提交后删除前保留的前版本元数据文件的最大数量
* write.spark.fanout.enabled:默认为false

#### 表行为配置

* commit.retry.num-retries:默认为4，失败前重试提交的次数
* commit.retry.min-wait-ms:默认为100，在重新尝试提交之前等待的最小时间(以毫秒为单位)
* commit.retry.max-wait-ms:默认60000 (1 min)
* commit.retry.total-timeout-ms:1800000 (30 min)，重试提交之前等待的最大时间(以毫秒为单位)
* commit.manifest.target-size-bytes:8388608 (8 MB)，合并清单文件时的目标大小
* commit.manifest.min-count-to-merge:默认100，合并之前要累积的最小清单数量
* commit.manifest-merge.enabled:默认true，控制是否在写入时自动合并清单
* history.expire.max-snapshot-age-ms：默认为432000000 (5 days)，快照到期时要保留的默认最大快照寿命
* history.expire.min-snapshots-to-keep:默认为1，快照到期时要保留的默认最小快照数

#### 兼容性标识

* compatibility.snapshot-id-inheritance.enabled:默认为false，允许提交快照而不显示快照id

### Catalog参数配置

* catalog-impl:默认为null，引擎使用的自定义catalog实现
* io-impl:默认为null，引擎使用的自定义文件Io实现
* warehouse:数据仓库的根路径
* uri:a URI string, such as Hive metastore URI
* clients:客户端pool的数量

#### Lock catalog参数

* lock-impl：锁管理器的自定义实现，实际接口取决于所使用的catalog
* lock.table：用于锁定的辅助表，例如在AWS DynamoDB锁定管理器中
* lock.acquire-interval-ms：默认5 seconds，每次尝试获取锁之间等待的时间间隔
* lock.acquire-timeout-ms：默认3minutes，尝试获取锁的最长时间
* lock.heartbeat-interval-ms：3 seconds，获取锁后每个心跳之间等待的间隔
* lock.heartbeat-timeout-ms：15 seconds，没有心跳的最长时间考虑锁定已过期

### Hadoop配置

* iceberg.hive.client-pool-size: hive客户端连接池数量，默认5
* iceberg.hive.lock-timeout-ms：默认18000，获取锁定的最长时间（以毫秒为单位）
* iceberg.hive.lock-check-min-wait-ms:50,最小时间（以毫秒为单位），以检查锁获取状态
* iceberg.hive.lock-check-max-wait-ms:5000,最长时间（以毫秒为单位），以检查锁获取状态

## 支持的Schemas

| Type               | Description                                                  | Notes                                  |
| :----------------- | :----------------------------------------------------------- | :------------------------------------- |
| **`boolean`**      | True or false                                                |                                        |
| **`int`**          | 32-bit signed integers                                       | 可以存long                             |
| **`long`**         | 64-bit signed integers                                       |                                        |
| **`float`**        | [32-bit IEEE 754](https://en.wikipedia.org/wiki/IEEE_754) floating point | 可以存double                           |
| **`double`**       | [64-bit IEEE 754](https://en.wikipedia.org/wiki/IEEE_754) floating point |                                        |
| **`decimal(P,S)`** | Fixed-point decimal; precision P, scale S                    | precision必须小于等于38，scale是固定的 |
| **`date`**         | Calendar date without timezone or time                       |                                        |
| **`time`**         | Time of day without date, timezone                           | 存储微秒                               |
| **`timestamp`**    | Timestamp without timezone                                   | 存储微秒                               |
| **`timestamptz`**  | Timestamp with timezone                                      | 存储微秒                               |
| **`string`**       | Arbitrary-length character sequences                         | Encoded with UTF-8                     |
| **`fixed(L)`**     | Fixed-length byte array of length L                          |                                        |
| **`binary`**       | Arbitrary-length byte array                                  |                                        |
| **`struct<...>`**  | A record with named fields of any data type                  |                                        |
| **`list<E>`**      | A list with elements of any data type                        |                                        |
| **`map<K, V>`**    | A map with keys and values of any data type                  |                                        |

## Partition

### Iceberg分区的区别

* 其他表格式像hive支持的分区，但是iceberg支持隐藏分区
  * iceberg处理在表中为行产生分区值的繁琐且易于出错的任务
  * Iceberg避免自动读取不必要的分区。消费者不需要知道表是如何分区的，也不需要在查询中添加额外的过滤器
  * iceberg分区布局可以根据需要演变。

#### 在Hive中的分区

* 在Hive中，分区是显式的，并以列的形式出现，因此日志表将有一个名为事件日期的列。在写入时，插入需要为事件日期列提供数据

```sql
INSERT INTO logs PARTITION (event_date)
  SELECT level, message, event_time, format_time(event_time, 'YYYY-MM-dd')
  FROM unstructured_log_source
```

* 相似的，查询的时候如果需要分区过滤也必须带上分区

```sql
SELECT level, count(1) as count FROM logs
WHERE event_time BETWEEN '2018-12-01 10:00:00' AND '2018-12-01 12:00:00'
  AND event_date = '2018-12-01'
```

#### Hive分区存在的问题

* hive必须给定分区值，这存在如下问题
  * hive不能校验分区值，这取决于写入器产生的正确的值
    * 使用错误的格式，2018-12-01而不是20181201，生成默默地不正确的结果，而不是查询故障
    * 使用错误的源列，如processing_time或时区也会导致结果不正确，而不是故障
  * 用户可以正确地编写查询
    * 使用错误的格式也会导致默默错误的结果
    * 不理解表物理布局的用户得到不必要的缓慢查询Hive不能自动翻译过滤器
  * 工作查询与表的分区方案相关联，因此在不破坏查询的情况下无法更改分区配置

#### iceberg的隐藏分区

* iceberg通过采用列值和可选地转换它来产生分区值。 iceberg负责将Event_time转换为Event_date，并跟踪关系。
* 表分区被配置使用这些关系，如logs表讲按照date(event_time)和level来分区
* 因为Iceberg不需要用户维护的分区列，所以它可以隐藏分区。分区值每次都正确生成，并且在可能的情况下总是用于加快查询速度。生产者和消费者甚至看不到event_date。
* 最重要的是，查询不再依赖于表的物理布局。通过物理和逻辑的分离，Iceberg表可以随着数据量的变化而演变分区方案。不需要进行昂贵的迁移就可以修复配置错误的表。

## Table后期演变

* Iceberg支持就地表演化。您可以像SQL一样演变表模式——甚至是嵌套结构——或者在数据量变化时更改分区布局。Iceberg不需要代价高昂的干扰，比如重写表数据或迁移到一个新表。
* 例如，Hive表分区不能更改，所以从每日分区布局移动到每小时分区布局需要一个新的表。因为查询依赖于分区，所以必须为新表重写查询。在某些情况下，即使是像重命名列这样简单的更改也不受支持，或者会导致数据正确性问题。

### Schema的演变

* iceberg支持一下schema的变化
  * ADD：添加一个新列到表里或者一个嵌套结构
  * Drop：从表或嵌套结构中删除一个存在的列
  * Rename：修改一个存在的列或嵌套结构的属性名
  * Update：扩大列的类型，struct字段，地图键，映射值或列表元素
  * reorder：更改嵌套结构中列或字段的顺序
* iceberg架构更新是元数据更改，因此不需要重写数据文件以执行更新。请注意，map键不支持添加或删除会改变平等的结构字段。

### 分区的演变

* iceberg表分区可以在现有表中更新，因为查询不直接引用分区值。
* 当您发展分区规范时，用早期规范写入的旧数据保持不变。 使用新布局使用新规格编写新数据。 每个分区版本的元数据单独保留。 因此，当您开始编写查询时，您会得到分割计划。 这是每个分区布局使用它所派生的筛选器分别计划文件的位置，其中它导出了该特定分区布局。 这是一个创新示例的视觉表示：

![Partition evolution diagram](https://iceberg.apache.org/img/partition-spec-evolution.png)

### Sort Order演变

* 类似于分区规范，iceberg排序顺序也可以在现有表中更新。 当您发展排序顺序时，用早期订单写入的旧数据保持不变。 引擎总是可以选择以最新的排序顺序写入数据或在排序时不排序时未进行昂贵。

```java
Table sampleTable = ...;
sampleTable.replaceSortOrder()
   .asc("id", NullOrder.NULLS_LAST)
   .dec("category", NullOrder.NULL_FIRST)
   .commit();
```

## 表的维护

### 推荐的维护方式

#### 过期快照

* 每个写入iceBerg表创建表的新快照或版本。 快照可以用于时间旅行查询，或者可以将表卷回任何有效快照。
* 快照累积直到它们以expiresNapshots操作到期。 建议定期到期的快照删除不再需要的数据文件，并保持表元数据的大小。
* 如下过期1天前的快照：

```java
Table table = ...
long tsToExpire = System.currentTimeMillis() - (1000 * 60 * 60 * 24); // 1 day
table.expireSnapshots()
     .expireOlderThan(tsToExpire)
     .commit();
```

#### 移除老的元数据文件

* Iceberg使用JSON文件跟踪表元数据。对表的每个更改都会生成一个新的元数据文件，以提供原子性
* 默认情况下，旧的元数据文件作为历史记录保存。频繁提交的表，比如那些由流作业编写的表，可能需要定期清理元数据文件。
* 要自动清除元数据文件，请在表属性中设置`write.metadata.delete-after-commit.enabled = true`。 这将保留一些元数据文件（最多为`write.metadata.previous-versions-max`），并且在创建每个新建之后将删除最旧的元数据文件。

#### 移除Remove文件

* 在Spark等分布式处理引擎中，任务或作业失败可能会留下表元数据没有引用的文件，在某些情况下，正常的快照过期可能无法确定某个文件不再需要并删除它。
* 如下方式清理没有引用的元数据文件:

```java
Table table = ...
Actions.forTable(table)
    .removeOrphanFiles()
    .execute();
```

* 删除孤立文件的保留间隔小于完成任何写入的预期时间是危险的，因为如果将正在处理的文件视为孤立文件并删除，可能会破坏表。默认为3天。

### 可选的维护方式

#### 合并数据文件

* Iceberg跟踪表中的每个数据文件。更多的数据文件会导致更多的元数据存储在清单文件中，而较小的数据文件会导致不必要的元数据数量和文件打开成本的低效率查询。
* iceberg能够使用spark并行的合并数据文件通过`rewriteDataFiles`action，这将把小文件合并成更大的文件，以减少元数据开销和运行时文件打开成本。

```java
Table table = ...
  // 合并8月18号的数据为500MB大小的文件
Actions.forTable(table).rewriteDataFiles()
    .filter(Expressions.equal("date", "2020-08-18"))
    .targetSizeInBytes(500 * 1024 * 1024) // 500 MB
    .execute();
```

#### 重写manifests

* Iceberg在其清单列表和清单文件中使用元数据，加快了查询规划，并删除了不必要的数据文件。元数据树的作用是作为表数据的索引。
* 元数据树中的清单按照添加的顺序自动压缩，这使得当写模式与读过滤器对齐时查询速度更快。例如，写入每小时分区的数据时，会与时间范围查询过滤器对齐。
* 当表的写模式与查询模式不一致时，使用rewriteManifests或rewriteManifests动作(用于使用Spark的并行重写)重写元数据并将其重新分组为清单。

```java
Table table = ...
table.rewriteManifests()
    .rewriteIf(file -> file.length() < 10 * 1024 * 1024) // 10 MB
    .clusterBy(file -> file.partition().get(0, Integer.class))
    .commit();
```

## 性能

### 扫描计划

* 扫描规划是在查询所需的表中查找文件的过程。
* 在Iceberg表中进行规划适合于单个节点，因为Iceberg的元数据可以用于修剪不需要的元数据文件，此外还可以过滤不包含匹配数据的数据文件。
* 从单个节点的快速扫描计划启用：
  * 通过消除分布式扫描来规划分布式扫描，降低了SQL查询的延迟
  * 任何客户机独立进程的访问都可以直接从Iceberg表读取数据

#### 元数据过滤

* Iceberg使用两个级别的元数据来跟踪快照中的文件。
  * **Manifest files**存储数据文件的列表，沿每个数据文件的分区数据和列级统计
  *  **manifest list**存储快照清单列表，以及每个分区字段的值范围
* 为了进行快速扫描规划，Iceberg首先使用 **manifest list**中的分区值范围筛选manifest。然后，它读取每个manifest以获得数据文件。在这个方案中，**manifest list**充当**Manifest files**的索引，这样就可以在不读取所有清单的情况下进行计划。
* 除了分区值范围外，清单列表还存储清单中添加或删除的文件数量，以加速快照过期等操作。

#### 数据过滤

* Manifest files包括每个数据文件的分区数据和列级统计的元组。
* 在规划期间，查询谓词自动转换为分区数据上的谓词，并首先应用于筛选数据文件。接下来，列级值计数、空计数、下界和上界用于消除不能匹配查询谓词的文件。
* 通过在规划时使用上界和下界来过滤数据文件，Iceberg使用聚集数据来消除分割，而无需运行任务。在某些情况下，性能提高了10倍。

## 可靠性

* Hive表同时使用分区的中央元存储和单个文件的文件系统来跟踪数据文件。这使得不可能对表的内容进行原子性更改，最终像S3这样的一致存储可能会由于使用清单文件来重构表的状态而返回不正确的结果。它还需要作业计划进行许多缓慢的列表调用:O(n)与分区的数量。
* Iceberg使用持久树结构跟踪每个快照中的数据文件的完整列表。每次写或删除都会生成一个新的快照，该快照尽可能多地重用前一个快照的元数据树，以避免高写量。
* Iceberg表中的有效快照存储在表元数据文件中，以及对当前快照的引用。提交使用原子操作替换当前表元数据文件的路径。这确保了对表数据和元数据的所有更新都是原子的，并且是可序列化隔离的基础。
* 以下提高了可靠性保证:
  * **Serializable isolation**：所有表更改都发生在原子表更新的线性历史中
  * **Reliable reads**：读取器总是使用一致的表快照而不持有锁
  * **Version history and rollback**:表快照作为历史记录保存，如果作业产生错误数据，表可以回滚
  * **Safe file-level operations**：通过支持原子变化，Iceberg支持新的用例，比如安全地压缩小文件和安全地将后期数据附加到表中
* 这些设计有助于性能：
  * **O(1)RPCs to plan**:读取快照需要O(1)个RPC调用，而不是在表中列出O(n)个目录来计划作业
  * **Distributed planning**:文件剪枝和谓词下推被分发到作业中，从而消除了元存储作为瓶颈的问题
  * **Finer granularity partitioning**:分布式规划和O(1) RPC调用消除了当前对细粒度分区的障碍

### 并发写操作

* Iceberg使用乐观并发支持多个并发写。
* 每个写入器都假设没有其他写入器在操作，并为某个操作写入新的表元数据。然后，编写器尝试通过自动地将新表元数据文件交换为现有元数据文件来提交。
* 如果原子交换因为另一个写入器提交而失败，则失败的写入器会根据新的当前表状态写入新的元数据树来重试。

#### 重试的花费

* 编写器通过结构化更改以使工作可以在重试中重用，从而避免昂贵的重试操作。
* 例如，appends通常为附加的数据文件创建一个新的清单文件，可以将其添加到表中，而无需每次尝试都重写清单。

#### 重试的校验

* 提交被构造为假设和操作。在冲突之后，写入器检查当前表状态是否满足这些假设。如果满足了这些假设，那么就可以安全地重新应用操作并提交。
* 例如，压缩可能会将a.a avro文件和b.a avro文件重写为merged.parquet。这是安全的提交，只要表仍然包含文件a.avro和文件b.avro。如果任何一个文件被冲突的提交删除，则操作必须失败。否则，删除源文件并添加合并文件是安全的。
