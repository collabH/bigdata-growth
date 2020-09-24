# Kudu配置

## 配置基础

* 要配置每个Kudu进程的行为，可以在启动它时`传递命令行标志`，或者通过使用一个或多个`--flagfile=<file>`选项从配置文件中读取这些选项，也可以通过`--flagfile`选项在你的配置文件中包含其他配置文件。

[配置文档](https://kudu.apache.org/docs/configuration_reference.html)

## 目录配置

* 每个Kudu节点都需要指定目录标志。通过`--fs_wal_dir`配置指定`write-ahead log`存储的位置
* 通过`--fs_metadata_dir`配置每个tablet存储元数据的位置，建议将这些目录放在高性能高带宽和低延迟的驱动器上，例如SSD。如果`--fs_metadata_dir`没有被指定，元数据将会被`--fs_wal_dir`目录下。为了防止因为WAL或元数据的丢失导致Kudu节点无法使用，可以配置相关的镜像，但是镜像会增加Kudu的写入的延迟。
* 通过`--fs_data_dirs`配置写入数据块的位置.这是一个以逗号分隔的目录列表。如果指定多个值，数据将跨目录显示。 如果没有设定将会存储在`--fs_wal_dir`目录下
* `--fs_data_dirs`一点设置需要通过工具来修改它
* `--fs_metadata_dir`和`--fs_wal_dir`可以修改，但是需要将原本的目录迁移。

## 配置Kudu Master

[kudu master configuration](https://kudu.apache.org/docs/configuration_reference.html#kudu-master_supported)

### 查看帮助

```shell
kudu-master --help
```

### kudu master支持的配置

| Flag                 | Valid Options | Default     | Description                                                  |
| :------------------- | :------------ | :---------- | :----------------------------------------------------------- |
| `--master_addresses` | string        | `localhost` | Comma-separated list of all the RPC addresses for Master consensus-configuration. If not specified, assumes a standalone Master. |
| `--fs_data_dirs`     | string        |             | List of directories where the Master will place its data blocks. |
| `--fs_metadata_dir`  | string        |             | The directory where the Master will place its tablet metadata. |
| `--fs_wal_dir`       | string        |             | The directory where the Master will place its write-ahead logs. |
| `--log_dir`          | string        | `/tmp`      | The directory to store Master log files.                     |

## 配置tablet server

[tablet server configuration](https://kudu.apache.org/docs/configuration_reference.html#kudu-tserver_supported)

### 查看帮助

```shell
kudu-tserver --help
```

### tablet server支持的配置

| Flag                      | Valid Options | Default          | Description                                                  |
| :------------------------ | :------------ | :--------------- | :----------------------------------------------------------- |
| --fs_data_dirs            | string        |                  | List of directories where the Tablet Server will place its data blocks. |
| --fs_metadata_dir         | string        |                  | The directory where the Tablet Server will place its tablet metadata. |
| --fs_wal_dir              | string        |                  | The directory where the Tablet Server will place its write-ahead logs. |
| --log_dir                 | string        | /tmp             | The directory to store Tablet Server log files               |
| --tserver_master_addrs    | string        | `127.0.0.1:7051` | Comma separated addresses of the masters which the tablet server should connect to. The masters do not read this flag. |
| --block_cache_capacity_mb | integer       | 512              | 分配给Kudu Tablet服务器块缓存的最大内存量。                  |
| --memory_limit_hard_bytes | integer       | 4294967296       | 在开始拒绝所有传入写操作之前，Tablet服务器可以消耗的最大内存量。 |

## 配置Kudu tables

* Kudu允许为每个表设置某些配置。要配置Kudu表的行为，可以在创建表时设置这些配置，或者通过Kudu API或Kudu命令行工具修改它们。

| Configuration                   | Valid Options | Default | Description                                                  |
| :------------------------------ | :------------ | :------ | :----------------------------------------------------------- |
| kudu.table.history_max_age_sec  | integer       |         | Number of seconds to retain history for tablets in this table. |
| kudu.table.maintenance_priority | integer       | 0       | Priority level of a table for maintenance.                   |

# 配置Hive Metastore

* Kudu允许和Hive Metastore集成，HMS是Hadoop生态系统中事实上的标准catalog和元数据提供者。当HMS集成开启，外部的HMS-aware工具能够感知Kudu表。

## database和表名

* 不开启Hive Metastore集成，kudu将表表示为单个平面名称空间，没有数据库的层次结构或概念。另外对表名的唯一限制是它们是一个有效的UTF-8编码的字符串。
* 开启Hive metastore集成，表明必须指定Hive数据库的表成员关系，表名标识符(即表名和数据库名)受Hive表名标识符约束。

### databases

* Hive具有数据库的概念，它是单个表的集合。每个数据库都形成自己的表名称的独立名称空间，当Hive Metastore集成开启kudu表必须要指定一个database。
* kudu表名必须采用`<hive-database-name>.<hive-table-name>`的格式，数据库是kudu表名的隐式部分，这样操作开启HMS和未开启HMS的kudu表没有区别。

### 命名约束

* 开启HMS后kudu表名需要遵从Hive表的规范，当`hive.supprot.special.characters.tablename`配置为`true`时,还支持表名称标识符（即表名称和数据库名称）中的正斜杠（/）字符。
* Hive Metastore并不强制表名标识符区分大小写。因此，当启用时，如果已经存在表，并且表名标识符仅因大小写不同而不同，Kudu将会效仿Hive并禁止创建表。对于表名标识符，打开、修改或删除表的操作也不区分大小写。

### 元数据同步

* 当开启Hive元数据集成，kudu将会动态的同步元数据在改变kudu表的时候，如果kudu和HMS的元数据不一致会导致外部工具无法使用这个kudu table。

## 开启Hive Metastore集成

* 在一个已经存在的集群开启Hive Metastore集成之前，确保升级的任何表都可以存在在kudu或者Hms的catalog里。[升级表](https://kudu.apache.org/docs/hive_metastore.html#upgrading-tables)
* 当Hive Metastore配置了细粒度的授权，Kudu管理员需要能够访问和修改由HMS为Kudu创建的目录。这可以通过将Kudu管理用户添加到Hive服务用户组来实现。例如通过允许`usermod -aG hive kudu`在HMS的节点上。
* 配置Hive Metastore包括通知时间监听器和Kudu HMS插件，允许更改和删除列，并在通知中添加完全节省对象，配置在hive-site.xml中

```xml
<property>
  <name>hive.metastore.transactional.event.listeners</name>
  <value>
    org.apache.hive.hcatalog.listener.DbNotificationListener,
    org.apache.kudu.hive.metastore.KuduMetastorePlugin
  </value>
</property>

<property>
  <name>hive.metastore.disallow.incompatible.col.type.changes</name>
  <value>false</value>
</property>

<property>
  <name>hive.metastore.notifications.add.thrift.objects</name>
  <value>true</value>
</property>
```

* 从源代码构建Kudu后，将在构建目录（例如build / release / bin）下找到的hms-plugin.jar添加到Hive的lib类路径。
* 重启Hive，并且在kudu开启Hive Metastore集成

```shell
--hive_metastore_uris=<HMS Thrift URI(s)>
--hive_metastore_sasl_enabled=<value of the Hive Metastore's hive.metastore.sasl.enabled configuration>
```

* 在安全的集群环境,`--hive_metastore_sasl_enabled`被设置为`true`，`--hive_metastore_kerberos_principal`和`hive.metastore.kerberos.principal`一致
* 重启Kudu master服务器

# Kudu的动态伸缩指南

## 概念

* 热副本：连续接收写操作的tablet副本。例如，在时间序列用例中，时间列上最近范围分区的平板副本将持续接收最新数据，并且将是热副本。
* 冷副本:冷副本即不经常接收写操作的副本，例如，每隔几分钟一次。可以读取一个冷副本。例如，在时间序列用例中，一个时间列上以前的范围分区的tablet副本根本不会接收写操作，或者只是偶尔接收到最新的更新或添加操作，但可能会不断读取。
* 磁盘上的数据:跨所有磁盘、复制后、压缩后和编码后存储在tablet server上的数据总量。

## 内存

* 通过`--memory_limit_hard_bytes`配置kudu tablet server可以使用的最大内存。tablet服务器使用的内存量随数据大小、写工作负载和读并发性而变化。

**下表提供了可以用于粗略估计内存使用情况的数字**

| Type                                        | Multiplier                                           | Description                                                  |
| :------------------------------------------ | :--------------------------------------------------- | :----------------------------------------------------------- |
| Memory required per TB of data on disk      | 1.5GB per 1TB data on disk                           | Amount of memory per unit of data on disk required for basic operation of the tablet server. |
| Hot Replicas' MemRowSets and DeltaMemStores | minimum 128MB per hot replica                        | Minimum amount of data to flush per MemRowSet flush. For most use cases, updates should be rare compared to inserts, so the DeltaMemStores should be very small. |
| Scans                                       | 256KB per column per core for read-heavy tables      | Amount of memory used by scanners, and which will be constantly needed for tables which are constantly read. |
| Block Cache                                 | Fixed by `--block_cache_capacity_mb` (default 512MB) | Amount of memory reserved for use by the block cache.        |

**使用示例负载的此信息可以得到以下内存使用情况的分解**

| Type                                  | Amount                                  |
| :------------------------------------ | :-------------------------------------- |
| 8TB data on disk                      | 8TB * 1.5GB / 1TB = 12GB                |
| 200 hot replicas                      | 200 * 128MB = 25.6GB                    |
| 1 40-column, frequently-scanned table | 40 * 40 * 256KB = 409.6MB               |
| Block Cache                           | `--block_cache_capacity_mb=512` = 512MB |
| Expected memory usage                 | 38.5GB                                  |
| Recommended hard limit                | 52GB                                    |

### 验证内存限制是否足够

* 设置完`--memory_limit_hard_bytes`后，内存使用应该保持在硬限制的50-75%左右，偶尔会出现高于75%但低于100%的峰值。如果tablet服务器始终运行在75%以上，则应该增加内存限制。
* 另外，监视内存拒绝的日志也很有用，它类似于:

```
Service unavailable: Soft memory limit exceeded (at 96.35% of capacity)
```

* 查看内存拒绝指标
  * `leader_memory_pressure_rejections`
  * `follower_memory_pressure_rejections`
  * `transaction_memory_pressure_rejections`
* 偶尔由于内存压力而被拒绝是正常的，并作为对客户机的背压。客户端将透明地重试操作。但是，任何操作都不应该超时。

## 文件描述符

* 进程被分配了最大数量的打开的文件描述符(也称为fds)。如果一个tablet server试图打开太多的fds，它通常会崩溃，并显示类似“打开的文件太多”之类的信息。

**下表总结了Kudu tablet服务器进程中文件描述符使用的来源**

| Type          | Multiplier                                                   | Description                                                  |
| :------------ | :----------------------------------------------------------- | :----------------------------------------------------------- |
| File cache    | Fixed by `--block_manager_max_open_files` (default 40% of process maximum) | Maximum allowed open fds reserved for use by the file cache. |
| Hot replicas  | 2 per WAL segment, 1 per WAL index                           | Number of fds used by hot replicas. See below for more explanation. |
| Cold replicas | 3 per cold replica                                           | Number of fds used per cold replica: 2 for the single WAL segment and 1 for the single WAL index. |

* 每个副本至少一个WAL segment和一个WAL index，并且应该有相同数量的段和索引。但是，如果一个副本的一个对等副本落后，那么它的段和索引的数量可能会更多。在对WALs进行垃圾收集时，关闭WAL段和索引fds。

| Type               | Amount                                                       |
| :----------------- | :----------------------------------------------------------- |
| file cache         | 40% * 32000 fds = 12800 fds                                  |
| 1600 cold replicas | 1600 cold replicas * 3 fds / cold replica = 4800 fds         |
| 200 hot replicas   | (2 / segment * 10 segments/hot replica * 200 hot replicas) + (1 / index * 10 indices / hot replica * 200 hot replicas) = 6000 fds |
| Total              | 23600 fds                                                    |

* 因此，对于本例，tablet服务器进程有大约32000 - 23600 = 8400个fds

## Threads

* 如果Kudu tablet server的线程数超过操作系统限制，则它将崩溃，通常在日志中显示一条消息，例如“ pthread_create失败：资源暂时不可用”。 如果超出系统线程数限制，则同一节点上的其他进程也可能崩溃。
* 整个Kudu都将线程和线程池用于各种目的，但几乎所有线程和线程池都不会随负载或数据/tablet大小而扩展； 而是，线程数可以是硬编码常量，由配置参数定义的常量，也可以是基于静态维度（例如CPU内核数）的常量。
* 唯一的例外是WAL append线程，它存在于每个“热”副本中。注意，所有的副本在启动时都被认为是热的，因此tablet服务器的线程使用通常会在启动时达到峰值，然后稳定下来。