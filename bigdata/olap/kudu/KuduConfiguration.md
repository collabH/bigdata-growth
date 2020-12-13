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
* 修改kudu master/tsserver配置
```
hive_metastore_uris=hive metastore uri
```

* 在安全的集群环境,`--hive_metastore_sasl_enabled`被设置为`true`，`--hive_metastore_kerberos_principal`和`hive.metastore.kerberos.principal`一致
* 重启Kudu master服务器

# Kudu集成Impala

* Impala SQL语法与HQL相似，熟悉HQL即可。

## impala配置修改

```shell
vim /etc/default/impala
在IMPALA_SERVER_ARGS添加
-kudu_master_hosts=hadoop:7051
```

## DDL

### 创建内部表

```sql
create table  test(
id bigint,
name string,
primary key(id))
partition by hash partitions 16
stored as kudu
tblproperties(
'kudu.master_addresses'='hadoop:7051',
'kudu.table_name'='test');
```

### 创建外部表

```sql
create external table  test(
id bigint,
name string,
primary key(id))
partition by hash partitions 16
stored as kudu
tblproperties(
'kudu.master_addresses'='hadoop:7051',
'kudu.table_name'='test');
```

### 修改

```sql
-- 修改表名
ALTER TABLE test RENAME TO test1

-- 修改kudu表的tblProperties
alter table test set tblproperties('kudu.table'='test1')

-- 修改表类型
alter table test set tblproperties('external'='true')
```

## DML

### 插入数据

```sql
-- 插入单行数据
INSERT INTO test VALUES(1,'zhangsan')

-- 插入多条数据
INSERT INTO test VALUES(1,'zhangsan'),(2,'lisi')

-- 批量插入
INSERT INTBO test1 SELECT * FROM test
```

### 更新数据

```sql
UPDATE test SET name='li' where id =1
```

### 删除数据

```sql
DELETE from test where id = 2;
```









