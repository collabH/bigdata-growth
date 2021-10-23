## Hudu概览

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