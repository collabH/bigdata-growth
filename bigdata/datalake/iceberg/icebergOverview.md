# 概述

* Apache Iceberg是用于大型分析数据集的开放表格式。 Iceberg在Trino和Spark中添加了使用高性能格式的表，该格式的工作方式类似于SQL表。

## 特性

* schem演进支持添加、删除、更新或重命名，并且没有副作用
* 隐藏分区可以防止导致错误提示或错误查询的用户错误
* 分区布局演变可以随着数据量或查询模式的变化而更新表的布局
* 时间旅行可实现使用完全相同的表快照的可重复查询，或者使用户轻松检查更改
* 版本回滚使用户可以通过将表重置为良好状态来快速纠正问题

## 

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