[TOC]

# 快速开始

## Jars

* Paimon当前支持Flink1.19~1.15，以下为jar包下载地址：

| Version      | Type        | Jar                                                          |
| ------------ | ----------- | ------------------------------------------------------------ |
| Flink 1.19   | Bundled Jar | [paimon-flink-1.19-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-flink-1.19/0.9-SNAPSHOT/) |
| Flink 1.18   | Bundled Jar | [paimon-flink-1.18-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-flink-1.18/0.9-SNAPSHOT/) |
| Flink 1.17   | Bundled Jar | [paimon-flink-1.17-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-flink-1.17/0.9-SNAPSHOT/) |
| Flink 1.16   | Bundled Jar | [paimon-flink-1.16-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-flink-1.16/0.9-SNAPSHOT/) |
| Flink 1.15   | Bundled Jar | [paimon-flink-1.15-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-flink-1.15/0.9-SNAPSHOT/) |
| Flink Action | Action Jar  | [paimon-flink-action-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-flink-action/0.9-SNAPSHOT/) |

## 开始

* 下载Flink环境

```bash
tar -xzf flink-*.tgz
```

* 找到对应Flink版本的paimon包放置Flink Home/lib下

```bash
cp paimon-flink-*.jar <FLINK_HOME>/lib/
```

* 将Hadoop Bundled Jar放置Flink Home/lib下

```bash
cp flink-shaded-hadoop-2-uber-*.jar <FLINK_HOME>/lib/
```

* 启动Flink集群，修改`<FLINK_HOME>/conf/config.yaml`配置

```yaml
# 修改tm slot个数
taskmanager:
  numberOfTaskSlots: 2
```

**启动Flink集群**

```shell
<FLINK_HOME>/bin/start-cluster.sh
```

**启动flink sql client**

```bash
<FLINK_HOME>/bin/sql-client.sh
```

* 创建Paimon Catalog和表

```sql
CREATE CATALOG paimon_catalog WITH (
    'type'='paimon',
    'warehouse'='file:/Users/huangshimin/Documents/study/flink/paimonData'
);
USE CATALOG paimon_catalog;

-- create a word count table
CREATE TABLE word_count (
    word STRING PRIMARY KEY NOT ENFORCED,
    cnt BIGINT
);
```

* 向Paimon表里写数据

```sql
-- create a word data generator table
CREATE TEMPORARY TABLE word_table (
    word STRING
) WITH (
    'connector' = 'datagen',
    'fields.word.length' = '1'
);

-- paimon requires checkpoint interval in streaming mode
SET 'execution.checkpointing.interval' = '10 s';

-- write streaming data to dynamic table
INSERT INTO word_count SELECT word, COUNT(*) FROM word_table GROUP BY word;
```

* OLAP方式查询数据

```sql
-- use tableau result mode
SET 'sql-client.execution.result-mode' = 'tableau';

-- switch to batch mode
RESET 'execution.checkpointing.interval';
SET 'execution.runtime-mode' = 'batch';

-- olap query the table
SELECT * FROM word_count;
```

* 流式读取

```sql
-- switch to streaming mode
SET 'execution.runtime-mode' = 'streaming';

-- track the changes of table and calculate the count interval statistics
SELECT `interval`, COUNT(*) AS interval_cnt FROM
    (SELECT cnt / 10000 AS `interval` FROM word_count) GROUP BY `interval`;
```

* 退出客户端&关闭集群

```sql
EXIT;

./bin/stop-cluster.sh
```

## 使用Flink Managed内存

* Paimon任务可以基于执行器内存创建内存池，这些内存将由Flink执行器管理，例如Flink任务管理器中的托管内存。它将通过executor管理多个任务的写入器缓冲区，从而提高执行器的稳定性和性能。

| Option                            | Default | Description                                                  |
| --------------------------------- | ------- | ------------------------------------------------------------ |
| sink.use-managed-memory-allocator | false   | 如果设置为true，Flink sink将为merge tree使用托管内存;否则，它将创建一个独立的内存分配器，这意味着每个任务分配和管理自己的内存池(堆内存)，如果一个Executor中有太多的任务，可能会导致性能问题甚至OOM。 |
| sink.managed.writer-buffer-memory | 256M    | managed内存中写入器缓冲区的权重，Flink会根据权重计算出写入器的内存大小，实际使用的内存取决于运行环境。现在，在这个属性中定义的内存大小等于在运行时分配给写缓冲区的确切内存。 |

```sql
INSERT INTO paimon_table /*+ OPTIONS('sink.use-managed-memory-allocator'='true', 'sink.managed.writer-buffer-memory'='256M') */
SELECT * FROM ....;
```

## 设置动态配置

* 与Paimon表进行交互时，可以调整表配置而不更改catalog中的配置。Paimon将提取job粒度的动态配置，并在当前会话中生效。动态配置的key的格式为`paimon.${catalogName}.${dbName}.${tableName}.${config_key}`。 `catalogName/dbName/tableName`可以为 *，这意味着匹配所有特定部分。

```sql
-- set scan.timestamp-millis=1697018249000 for the table mycatalog.default.T
SET 'paimon.mycatalog.default.T.scan.timestamp-millis' = '1697018249000';
SELECT * FROM T;

-- set scan.timestamp-millis=1697018249000 for the table default.T in any catalog
SET 'paimon.*.default.T.scan.timestamp-millis' = '1697018249000';
SELECT * FROM T;
```

# SQL DDL

## Create Catalog

* paimon catalog当前支持三种类型的metastore
  * `filesystem metastore`:默认metastore，它在文件系统中存储元数据和表文件。
  * `hive metastore`:它还将元数据存储在Hive metastore中。用户可以直接从Hive访问这些表。
  * `jdbc metastore`:它额外地将元数据存储在关系数据库中，如MySQL, Postgres等。

### Create Filesystem Catalog

```sql
CREATE CATALOG my_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 'hdfs:///path/to/warehouse'
);

USE CATALOG my_catalog;
```

### Creating Hive Catalog

* 通过使用Paimon Hive catalog，对catalog的更改将直接影响到相应的Hive metastore。在这样的catalog中创建的表也可以直接从Hive访问。要使用Hive catalog, Database name, Table name和Field name应该是小写的。
* Flink中的Paimon Hive catalog依赖于Flink Hive连接器bundled jar。需要将flink hive的jar包下载放置classpath下

| Metastore version | Bundle Name   | SQL Client JAR                                               |
| :---------------- | :------------ | :----------------------------------------------------------- |
| 2.3.0 - 3.1.3     | Flink Bundle  | [Download](https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/table/hive/overview/#using-bundled-hive-jar) |
| 1.2.0 - x.x.x     | Presto Bundle | [Download](https://repo.maven.apache.org/maven2/com/facebook/presto/hive/hive-apache/1.2.2-2/hive-apache-1.2.2-2.jar) |

```sql
CREATE CATALOG my_hive WITH (
    'type' = 'paimon',
    'metastore' = 'hive',
    -- 'uri' = 'thrift://<hive-metastore-host-name>:<port>', default use 'hive.metastore.uris' in HiveConf
    -- 'hive-conf-dir' = '...', this is recommended in the kerberos environment
    -- 'hadoop-conf-dir' = '...', this is recommended in the kerberos environment
    -- 'warehouse' = 'hdfs:///path/to/warehouse', default use 'hive.metastore.warehouse.dir' in HiveConf
);

USE CATALOG my_hive;
```

* 当使用Hive catalog通过Alter Table更改不兼容的列类型时，需要配置`hive.metastore.disallow.incompatible.col.type.changes=false`.

* 如果正在使用Hive3，请禁用Hive ACID

```shell
hive.strict.managed.tables=false
hive.create.as.insert.only=false
metastore.create.as.acid=false
```

#### 同步分区到Hive Metastore

* 默认情况下，Paimon不会将新创建的分区同步到Hive metastore。用户将在Hive中看到一个未分区的表。分区push-down将改为过滤器push-down。 
* 如果需要同步Paimon表的分区至Hive metastore中，设置表配置`metastore.partitioned-table`为true。

#### 添加Hive表参数

* 使用table配置可以方便地定义Hive表参数。参数前缀为`hive.`将在Hive表的`TBLPROPERTIES`中自动定义。例如，使用 `hive.table.owner=huangshimin` 将自动添加参数`table.owner=huangshimin`在创建过程中添加到表属性。

#### Setting Location in Properties

* 如果您使用的是对象存储，并且不希望Hive的文件系统访问Paimon表/数据库的位置，这可能会导致错误，例如"No FileSystem for scheme: s3a”。您可以通过构件的配置在表/数据库的 `location-in-properties`。

### Creating JDBC Catalog

* 通过使用Paimon JDBC Catalog，对Catalog的更改将直接存储在SQLITE、MySQL、Postgres等关系数据库中。
* 目前，Lock配置只支持MySQL和SQLite。如果您使用不同类型的数据库进行Catalog存储，请不要配置`lock.enabled`。
* Flink中的Paimon JDBC Catalog需要正确添加相应的jar包以连接到数据库。您应该首先下载JDBC连接器绑定的jar并将其添加到classpath中。例如MySQL, postgres

| database type | Bundle Name          | SQL Client JAR                                               |
| :------------ | :------------------- | :----------------------------------------------------------- |
| mysql         | mysql-connector-java | [Download](https://mvnrepository.com/artifact/mysql/mysql-connector-java) |
| postgres      | postgresql           | [Download](https://mvnrepository.com/artifact/org.postgresql/postgresql) |

```sql
CREATE CATALOG my_jdbc WITH (
    'type' = 'paimon',
    'metastore' = 'jdbc',
    'uri' = 'jdbc:mysql://<host>:<port>/<databaseName>',
    'jdbc.user' = '...', 
    'jdbc.password' = '...', 
    'catalog-key'='jdbc',
    'warehouse' = 'hdfs:///path/to/warehouse'
);

USE CATALOG my_jdbc;
```

## Create Table

* 创建主键表

```sql
-- 创建dt、hh、user_id为主键的表
CREATE TABLE my_table (
    user_id BIGINT,
    item_id BIGINT,
    behavior STRING,
    dt STRING,
    hh STRING,
    PRIMARY KEY (dt, hh, user_id) NOT ENFORCED
);
```

* 创建分区表

```sql
CREATE TABLE my_table (
    user_id BIGINT,
    item_id BIGINT,
    behavior STRING,
    dt STRING,
    hh STRING,
    PRIMARY KEY (dt, hh, user_id) NOT ENFORCED
) PARTITIONED BY (dt, hh);
```

### 指定统计模式

* Paimon将自动收集数据文件的统计信息，以加快查询过程。支持以下四种模式：
  * `full`: 采集全部指标: `null_count, min, max` .
  * `truncate(length)`: 长度可以是任何正数，默认模式为 `truncate(16)`,这意味着收集`null_count`，`min/max value`将会截断长度为16。这主要是为了避免太大的列，这些数据将会防止mainfest文件中
  * `counts`: 只采集`null_count`
  * `none`: 关闭元数据指标采集
* 统计收集器模式可以通过`'metadata.stats-mode'`配置，默认情况下为`'truncate(16)'`。可以通过`'fields.{field_name}.stats-mode'`来配置字段级别统计。

### 字段默认值

* Paimon表当前支持通过表属性 `'fields.item_id.default-value'`字段设置默认值，注意，分区字段和主键字段不能指定。

## Create Table As Select

```sql
/* For streaming mode, you need to enable the checkpoint. */

CREATE TABLE my_table (
    user_id BIGINT,
    item_id BIGINT
);
CREATE TABLE my_table_as AS SELECT * FROM my_table;

/* partitioned table */
CREATE TABLE my_table_partition (
     user_id BIGINT,
     item_id BIGINT,
     behavior STRING,
     dt STRING,
     hh STRING
) PARTITIONED BY (dt, hh);
CREATE TABLE my_table_partition_as WITH ('partition' = 'dt') AS SELECT * FROM my_table_partition;
    
/* change options */
CREATE TABLE my_table_options (
       user_id BIGINT,
       item_id BIGINT
) WITH ('file.format' = 'orc');
CREATE TABLE my_table_options_as WITH ('file.format' = 'parquet') AS SELECT * FROM my_table_options;

/* primary key */
CREATE TABLE my_table_pk (
      user_id BIGINT,
      item_id BIGINT,
      behavior STRING,
      dt STRING,
      hh STRING,
      PRIMARY KEY (dt, hh, user_id) NOT ENFORCED
);
CREATE TABLE my_table_pk_as WITH ('primary-key' = 'dt,hh') AS SELECT * FROM my_table_pk;


/* primary key + partition */
CREATE TABLE my_table_all (
      user_id BIGINT,
      item_id BIGINT,
      behavior STRING,
      dt STRING,
      hh STRING,
      PRIMARY KEY (dt, hh, user_id) NOT ENFORCED 
) PARTITIONED BY (dt, hh);
CREATE TABLE my_table_all_as WITH ('primary-key' = 'dt,hh', 'partition' = 'dt') AS SELECT * FROM my_table_all;
```

## Create Table Like

* 创建与另一个表具有相同模式、分区和表属性的表

```sql
CREATE TABLE my_table (
    user_id BIGINT,
    item_id BIGINT,
    behavior STRING,
    dt STRING,
    hh STRING,
    PRIMARY KEY (dt, hh, user_id) NOT ENFORCED
);

CREATE TABLE my_table_like LIKE my_table;

-- Create Paimon Table like other connector table
CREATE TABLE my_table_like WITH ('connector' = 'paimon') LIKE my_table;
```

## 使用Flink临时表

* 当前Flink SQL会话只记录临时表，而不管理临时表。如果临时表被删除，它的资源不会被删除。当Flink SQL会话关闭时，也会删除临时表。如果希望将Paimon Catalog与其他表一起使用，但又不希望将它们存储在其他catalog中，则可以创建一个临时表。

```sql
CREATE CATALOG my_catalog WITH (
    'type' = 'paimon',
    'warehouse' = 'hdfs:///path/to/warehouse'
);

USE CATALOG my_catalog;

-- Assume that there is already a table named my_table in my_catalog

CREATE TEMPORARY TABLE temp_table (
    k INT,
    v STRING
) WITH (
    'connector' = 'filesystem',
    'path' = 'hdfs:///path/to/temp_table.csv',
    'format' = 'csv'
);

SELECT my_table.k, my_table.v, temp_table.v FROM my_table JOIN temp_table ON my_table.k = temp_table.k;
```

# SQL Write

## 语法

```sql
INSERT { INTO | OVERWRITE } table_identifier [ part_spec ] [ column_list ] { value_expr | query };
```

## INSERT INTO

* 使用Insert Into可以将记录和更改写入到表里

```sql
INSERT INTO my_table SELECT ...
```

* INSERT INTO支持批处理和流模式。在Streaming模式下，默认情况下，它还将在Flink Sink中执行 compaction, snapshot expiration，甚至 partition expiration (如果配置了)。

### Clustering

* 在Paimon中，clustering是一个功能它允许您在写入过程中根据某些列的值对Append Table中的数据进行聚类。这种数据组织可以显著提高读取数据时下游任务的效率，因为它支持更快、更有针对性的数据检索。此特性仅支持Append Table和批处理执行模式。

```sql
-- 创建表时指定clustering字段
CREATE TABLE my_table (
    a STRING,
    b STRING,
    c STRING,
) WITH (
  'sink.clustering.by-columns' = 'a,b',
);
-- 插入数据时通过SQL Hints指定clustering字段
INSERT INTO my_table /*+ OPTIONS('sink.clustering.by-columns' = 'a,b') */
SELECT * FROM source;
```

* 使用自动选择的策略(例如ORDER、ZORDER或HILBERT)对数据进行聚类，可以通过设置`sink.clustering.strategy`手动指定聚类策略。聚类依赖于抽样和排序。如果聚类过程花费的时间太长，可以通过设置`sink.clustering.sample-factor`来减少总样本数。或通过设置`sink.clustering.sort-in-cluster`为`false`禁用排序步骤。

## INSERT OVERWRITE

* 对于未分区的表，Paimon支持覆盖整个表。(或对于分区表禁用`dynamic-partition-overwrite`)。

```sql
INSERT OVERWRITE my_table SELECT ...
```

### 覆盖写分区

* 静态覆盖写分区

```sql
INSERT OVERWRITE my_table PARTITION (key1 = value1, key2 = value2, ...) SELECT ...
```

### 动态覆盖写

* Flink的默认覆盖模式是动态分区覆盖(这意味着Paimon只删除被覆盖数据中出现的分区)。您可以配置`dynamic-partition-overwrite`，将其更改为静态覆盖。

```sql
-- MyTable is a Partitioned Table

-- Dynamic overwrite
INSERT OVERWRITE my_table SELECT ...

-- Static overwrite (Overwrite whole table)
INSERT OVERWRITE my_table /*+ OPTIONS('dynamic-partition-overwrite' = 'false') */ SELECT ...
```

## Truncate Table

```sql
-- 历史版本
INSERT OVERWRITE my_table /*+ OPTIONS('dynamic-partition-overwrite'='false') */ SELECT * FROM my_table WHERE false;
-- FLINL 1.18+
TRUNCATE TABLE my_table;
```

## 清理分区

* Paimon支持俩种方式清理分区
  * 与清除表一样，可以使用`INSERT OVERWRITE`通过向分区插入空值来清除分区的数据。
  * 方法#1不支持删除多个分区。如果需要删除多个分区，可以通过`flink run`提交删除分区作业。

```sql
-- Syntax
INSERT OVERWRITE my_table /*+ OPTIONS('dynamic-partition-overwrite'='false') */ 
PARTITION (key1 = value1, key2 = value2, ...) SELECT selectSpec FROM my_table WHERE false;

-- The following SQL is an example:
-- table definition
CREATE TABLE my_table (
    k0 INT,
    k1 INT,
    v STRING
) PARTITIONED BY (k0, k1);

-- you can use
INSERT OVERWRITE my_table /*+ OPTIONS('dynamic-partition-overwrite'='false') */ 
PARTITION (k0 = 0) SELECT k1, v FROM my_table WHERE false;

-- or
INSERT OVERWRITE my_table /*+ OPTIONS('dynamic-partition-overwrite'='false') */ 
PARTITION (k0 = 0, k1 = 0) SELECT v FROM my_table WHERE false;
```

## 更新数据

> 1. 只有主键表支持更新数据
> 2. 要支持此特性，需要MergeEngine是 [deduplicate](https://paimon.apache.org/docs/master/primary-key-table/merge-engine/#deduplicate) or [partial-update](https://paimon.apache.org/docs/master/primary-key-table/merge-engine/#partial-update) 
> 3. 不支持更新主键。

* 目前，Paimon支持在Flink 1.17及以后的版本中使用UPDATE更新记录。您可以在Flink的批处理模式下执行UPDATE。

```sql
-- Syntax
UPDATE table_identifier SET column1 = value1, column2 = value2, ... WHERE condition;

-- The following SQL is an example:
-- table definition
CREATE TABLE my_table (
	a STRING,
	b INT,
	c INT,
	PRIMARY KEY (a) NOT ENFORCED
) WITH ( 
	'merge-engine' = 'deduplicate' 
);

-- you can use
UPDATE my_table SET b = 1, c = 2 WHERE a = 'myTable';
```

## 删除数据

> 1. 只有主键表支持
> 2. 如果表有多个主键，MergeEngine需要为deduplicate
> 3. 不支持在流式模式删除数据

```sql
-- Syntax
DELETE FROM table_identifier WHERE conditions;

-- The following SQL is an example:
-- table definition
CREATE TABLE my_table (
    id BIGINT NOT NULL,
    currency STRING,
    rate BIGINT,
    dt String,
    PRIMARY KEY (id, dt) NOT ENFORCED
) PARTITIONED BY (dt) WITH ( 
    'merge-engine' = 'deduplicate' 
);

-- you can use
DELETE FROM my_table WHERE currency = 'UNKNOWN';
```

## Partition Make Done

* 对于分区表，可能需要调度每个分区以触发下游批处理计算。因此，有必要选择这个时间来表明它已准备好进行调度，并尽量减少调度期间的数据漂移量。我们称这个过程为:“Partition Mark Done”.

```sql
CREATE TABLE my_partitioned_table (
    f0 INT,
    f1 INT,
    f2 INT,
    ...
    dt STRING
) PARTITIONED BY (dt) WITH (
    'partition.timestamp-formatter'='yyyyMMdd',
    'partition.timestamp-pattern'='$dt',
    'partition.time-interval'='1 d',
    'partition.idle-time-to-done'='15 m'
);
```

* 首先，您需要定义分区的时间解析器和分区之间的时间间隔，以便确定何时可以正确地标记分区完成。
* 其次，您需要定义空闲时间，它决定分区没有新数据需要多长时间，然后将其标记为已完成。
* 第三，默认情况下，分区标记完成后会创建一个SUCCESS文件，SUCCESS文件的内容是一个json，包含creatationtime和modiationtime，它们可以帮助你了解是否有延迟的数据。您还可以配置其他操作。

# SQL Query

## Batch Query

* Paimon的批处理读取返回表快照中的所有数据。默认情况下，批处理读取返回最新的快照。

```sql
SET 'execution.runtime-mode' = 'batch';
```

### Batch Time Travel

* Paimon批处理读取随Time Travel可以**指定快照或标签**，并读取相应的数据。

```sql
-- read the snapshot with id 1L
SELECT * FROM test1 /*+ OPTIONS('scan.snapshot-id' = '1') */;

-- read the snapshot from specified timestamp in unix milliseconds
SELECT * FROM test1 /*+ OPTIONS('scan.timestamp-millis' = '1678883047356') */;

-- read the snapshot from specified timestamp string ,it will be automatically converted to timestamp in unix milliseconds
-- Supported formats include：yyyy-MM-dd, yyyy-MM-dd HH:mm:ss, yyyy-MM-dd HH:mm:ss.SSS, use default local time zone
SELECT * FROM test1 /*+ OPTIONS('scan.timestamp' = '2024-07-25 19:35:00') */;

-- read tag 'my-tag'
SELECT * FROM test1 /*+ OPTIONS('scan.tag-name' = 'my-tag') */;

-- read the snapshot from watermark, will match the first snapshot after the watermark
SELECT * FROM test1 /*+ OPTIONS('scan.watermark' = '1678883047356') */; 
```

### Batch Incremental

* 读取开始快照(不包含)和结束快照之间的增量变化。例如:5,10表示快照5和快照10之间的变化量。TAG1,TAG3表示TAG1和TAG3之间的变化。

```sql
-- incremental between snapshot ids
SELECT * FROM test1 /*+ OPTIONS('incremental-between' = '1,2') */;

-- incremental between snapshot time mills
SELECT * FROM test1 /*+ OPTIONS('incremental-between-timestamp' = '1692169000000,1692169900000') */;
```

* 默认情况下，将扫描changelog文件以查找生成changelog文件的表。否则，扫描新修改的文件。可以强制指定`incremental-between-scan-mode`。
* 在批处理SQL中，不允许返回DELETE记录，因此将删除`-D`的记录。如果希望看到DELETE记录，您可以使用审计日志表

```sql
SELECT * FROM test1$audit_log /*+ OPTIONS('incremental-between' = '1,2') */;
```

## Streaming Query

* 默认情况下，流式读取在第一次启动时生成表上的最新快照，并继续读取最新的更改。默认情况下，Paimon确保启动所包括所有数据都被正确处理，

```sql
-- 设置流式读取模式
SET 'execution.runtime-mode' = 'streaming';
-- 不读取快照，读取最新完整数据
SELECT * FROM test1 /*+ OPTIONS('scan.mode' = 'latest') */;
```

### Streaming Time Travel

* 如果您只想处理今天及以后的数据，那么可以使用分区过滤器

```sql
SELECT * FROM test1 WHERE dt > '2023-06-26';
```

* 如果它不是一个分区表，或者不能按分区进行过滤，则可以使用**Time travel**的流读取。

```sql
-- read changes from snapshot id 1L 
SELECT * FROM test1 /*+ OPTIONS('scan.snapshot-id' = '1') */;

-- read changes from snapshot specified timestamp
SELECT * FROM test1 /*+ OPTIONS('scan.timestamp-millis' = '1678883047356') */;

-- read snapshot id 1L upon first startup, and continue to read the changes
SELECT * FROM test1 /*+ OPTIONS('scan.mode'='from-snapshot-full','scan.snapshot-id' = '1') */;
```

* Time Travel的流式读数依赖于快照，但是默认情况下，快照仅保留1小时内数据，这可以防止读取较旧的增量数据。因此，Paimon还提供了一种用于流式读取的模式，即`scan.file-creation-time-millis`，该模式提供了一种粗糙的过滤，以保留Timemillis之后生成的文件。

```sql
SELECT * FROM test1 /*+ OPTIONS('scan.file-creation-time-millis' = '1678883047356') */;
```

### Consumer ID

* 您可以在流式读表时指定消费者id

```sql
SELECT * FROM test1 /*+ OPTIONS('consumer-id' = 'myid','consumer.expiration-time'='100') */;
```

* 当流读取Paimon表时，要记录到文件系统中的下一个快照id。这有几个优点：
  * 当上一个作业停止时，新启动的作业可以继续使用前一个消费进度，**而无需从状态恢复**。新的读取将从消费者文件中找到的下一个快照id开始读取。如果不想要这种行为，可以设置`consumer.ignore-progress`为`true`
  * 在确定快照是否过期时，Paimon查看文件系统中表的所有消费者，如果仍然有消费者依赖于该快照，则该快照将不会在到期时被删除。

> 注意:消费者将阻止快照过期。您可以指定消费者。过期时间，用于管理消费者的生命周期。

* 默认情况下，消费者使用 `exactly-once` 模式来记录消费进度，这严格确保在消费者中记录的是所有读取器精确消费的**快照id + 1**。可以设置`consumer.mode`设置为` `at-least-once` 允许读取器以不同的速率使用快照，并将所有读取器中最慢的快照id记录到消费者中。这种模式可以提供更多的功能，如水印对齐。

> 由于精确一次模式和至少一次模式的实现是完全不同的，所以切换模式时，flink的状态是不兼容的，不能从状态恢复。

* 可以使用给定的消费者ID和下一个快照ID重置消费者，并删除具有给定消费者ID的消费者。首先，需要使用此消费者ID停止流任务，然后执行重置消费者操作作业。

```bash
<FLINK_HOME>/bin/flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    reset-consumer \
    --warehouse <warehouse-path> \
    --database <database-name> \ 
    --table <table-name> \
    --consumer_id <consumer-id> \
    [--next_snapshot <next-snapshot-id>] \
    [--catalog_conf <paimon-catalog-conf> [--catalog_conf <paimon-catalog-conf> ...]]
```

### Read Overwrite

* 默认情况下，流读取将忽略INSERT OVERWRITE生成的提交。如果您想要读取OVERWRITE的提交，配置`streaming-read-overwrite`

## Read Parallelism

* 默认情况下，批处理读取的并行度与split的数量相同，而流式读取的并行度与bucket的数量相同，但不大于``scan.infer-parallelism.max``配置，关闭`scan.infer-parallelism`配置将会使用全局并行度读取

| Key                        | Default | Type    | Description                                                  |
| :------------------------- | :------ | :------ | :----------------------------------------------------------- |
| scan.infer-parallelism     | true    | Boolean | If it is false, parallelism of source are set by global parallelism. Otherwise, source parallelism is inferred from splits number (batch mode) or bucket number(streaming mode).如果为false，则source的并行度由全局并行度一致。否则，从splits个数(批处理模式)或bucket数(流模式)推断source并行性。 |
| scan.infer-parallelism.max | 1024    | Integer | 如果scan.infer-parallelism配置为true, 该配置限制最大读取并行度 |
| scan.parallelism           | (none)  | Integer | Define a custom parallelism for the scan source. By default, if this option is not defined, the planner will derive the parallelism for each statement individually by also considering the global configuration. If user enable the scan.infer-parallelism, the planner will derive the parallelism by inferred parallelism. |

## 查询优化

* 建议与查询一起指定**分区和主键**过滤，这将加快查询的Data Skipping，可以加速数据跳变的过滤函数如下：
  * `=`
  * `<`
  * `<=`
  * `>`
  * `>=`
  * `IN (...)`
  * `LIKE 'abc%'`
  * `IS NULL`
* Paimon将按主键对数据进行排序，这加快了**点查询和范围查询**的速度。**当使用复合主键时，查询过滤器最好在主键的最左边形成一个前缀，以获得良好的加速**，具体如下：

```sql
CREATE TABLE orders (
    catalog_id BIGINT,
    order_id BIGINT,
    .....,
    PRIMARY KEY (catalog_id, order_id) NOT ENFORCED -- composite primary key
);
-- 按照主键顺序构造查询条件
SELECT * FROM orders WHERE catalog_id=1025;

SELECT * FROM orders WHERE catalog_id=1025 AND order_id=29495;

SELECT * FROM orders
  WHERE catalog_id=1025
  AND order_id>2035 AND order_id<6000;
-- bad case，以下查询不能获得查询加速
SELECT * FROM orders WHERE order_id=29495;

SELECT * FROM orders WHERE catalog_id=1025 OR order_id=29495;
```

# SQL Lookup

## Normal Lookup

* 通过`FOR SYSTEM_TIME AS OF`实现lookup join，注意：流表需要指定时间属性字段

```sql
SELECT o.order_id, o.total, c.country, c.zip
FROM orders AS o
JOIN customers
FOR SYSTEM_TIME AS OF o.proc_time AS c
ON o.customer_id = c.id;
```

## Retry Lookup

* 如果lookup join不上的情况可以使用retry lookup来进行重试，防止join不上导致数据丢失，flink 1.16以上版本支持

```sql
-- 指定被join的表，重试条件和策略
SELECT /*+ LOOKUP('table'='c', 'retry-predicate'='lookup_miss', 'retry-strategy'='fixed_delay', 'fixed-delay'='1s', 'max-attempts'='600') */
o.order_id, o.total, c.country, c.zip
FROM orders AS o
JOIN customers
FOR SYSTEM_TIME AS OF o.proc_time AS c
ON o.customer_id = c.id;
```

## Async Retry Lookup

* Retry Lookup是同步的，它的问题是，一条记录将阻塞后续记录，从而导致整个作业被阻塞。可以考虑使用**async + allow_unordered** 来避免阻塞，连接丢失的记录将不再阻塞其他记录。

```sql
SELECT /*+ LOOKUP('table'='c', 'retry-predicate'='lookup_miss', 'output-mode'='allow_unordered', 'retry-strategy'='fixed_delay', 'fixed-delay'='1s', 'max-attempts'='600') */
o.order_id, o.total, c.country, c.zip
FROM orders AS o
JOIN customers /*+ OPTIONS('lookup.async'='true', 'lookup.async-thread-number'='16') */
FOR SYSTEM_TIME AS OF o.proc_time AS c
ON o.customer_id = c.id;
```

* 如果主表是CDC流，`allow_unordered`将会在Flink SQL忽略(只支持append流)，您可以尝试使用Paimon的`audit_log`系统表特性来(将CDC流转换为追加流)。

## Dynamic Partition

* 在传统的数据仓库中，每个分区经常维护最新的完整数据，因此这个分区表只需要join最新的分区。Paimon专门为这个场景支持了`max_pt`特性。

```sql
-- 定义分区表
CREATE TABLE customers (
  id INT,
  name STRING,
  country STRING,
  zip STRING,
  dt STRING,
  PRIMARY KEY (id, dt) NOT ENFORCED
) PARTITIONED BY (dt);
-- Lookup Join
SELECT o.order_id, o.total, c.country, c.zip
FROM orders AS o
JOIN customers /*+ OPTIONS('lookup.dynamic-partition'='max_pt()', 'lookup.dynamic-partition.refresh-interval'='1 h') */
FOR SYSTEM_TIME AS OF o.proc_time AS c
ON o.customer_id = c.id;
```

* Lookup节点会自动刷新最新分区，并查询最新分区的数据。

## Query Service

* 可以运行Flink Streaming Job来启动该表的查询服务。当QueryService存在时，Flink Lookup Join会优先从QueryService获取数据，这将有效提高查询性能。

```sql
-- flink sql
CALL sys.query_service('database_name.table_name', parallelism);

-- paimon action job
<FLINK_HOME>/bin/flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    query_service \
    --warehouse <warehouse-path> \
    --database <database-name> \
    --table <table-name> \
    [--parallelism <parallelism>] \
    [--catalog_conf <paimon-catalog-conf> [--catalog_conf <paimon-catalog-conf> ...]]
```

# SQL Alter

```sql
-- 修改/添加表属性
ALTER TABLE my_table SET (
    'write-buffer-size' = '256 MB'
);
-- 删除表属性
ALTER TABLE my_table RESET ('write-buffer-size');
-- 修改/添加表描述
ALTER TABLE my_table SET (
    'comment' = 'table comment'
    );
-- 删除表描述
ALTER TABLE my_table RESET ('comment');
-- 修改表名，如果使用对象存储，如S3或OSS，请谨慎使用此语法，因为对象存储的重命名不是原子性的，在失败的情况下可能只会移动部分文件。
ALTER TABLE my_table RENAME TO my_table_new;
-- 添加新列
ALTER TABLE my_table ADD (c1 INT, c2 STRING);
-- 修改列名
ALTER TABLE my_table RENAME c0 TO c1;
-- 删除列，在hive metastore中需要配置hive.metastore.disallow.incompatible.col.type.changes
ALTER TABLE my_table DROP (c1, c2);
-- 删除分区
ALTER TABLE my_table DROP PARTITION (`id` = 1);
ALTER TABLE my_table DROP PARTITION (`id` = 1, `name` = 'paimon');
ALTER TABLE my_table DROP PARTITION (`id` = 1), PARTITION (`id` = 2);
-- 修改列为空
ALTER TABLE my_table MODIFY coupon_info FLOAT;
-- 修改列不为空，如果NULL值已经存在则删除，当前仅支持Flink
SET 'table.exec.sink.not-null-enforcer' = 'DROP';
ALTER TABLE my_table MODIFY coupon_info FLOAT NOT NULL;
-- 修改列描述
ALTER TABLE my_table MODIFY buy_count BIGINT COMMENT 'buy count';
-- 指定列前后添加新列
ALTER TABLE my_table ADD c INT FIRST;
ALTER TABLE my_table ADD c INT AFTER b;
-- 修改列的位置
ALTER TABLE my_table MODIFY col_a DOUBLE FIRST;
ALTER TABLE my_table MODIFY col_a DOUBLE AFTER col_b;
-- 修改列类型
ALTER TABLE my_table MODIFY col_a DOUBLE;
-- 添加Watermark
ALTER TABLE my_table ADD (
    ts AS TO_TIMESTAMP(log_ts) AFTER log_ts,
    WATERMARK FOR ts AS ts - INTERVAL '1' HOUR
);
-- 删除Watermark
ALTER TABLE my_table DROP WATERMARK;
-- 修改Watermark
ALTER TABLE my_table MODIFY WATERMARK FOR ts AS ts - INTERVAL '2' HOUR
```

# Expire Partition

* 当创建分区表的时候可以设置`partition.expiration-time`。Paimon流式sink会定期检查分区的状态，并根据时间删除过期的分区。如何判断一个分区已经过期，当创建分区表的时候可以设置`partition.expiration-strategy`，该策略决定如何提取分区时间，并将其与当前时间进行比较，以查看分区的生存时间是否超过了`partition.expiration-time`。过期策略支持以下2种：
  * `values-time` :该策略将从分区值中提取的时间与当前时间进行比较，此策略为默认策略。
  * `update-time` : 该策略将分区的最后更新时间与当前时间进行比较。这一策略适用以下场景：
    * 分区值不是日期格式
    * 只想保留在过去的N天/几个月/几年中已更新的数据。
    * 数据初始化会导入大量的历史数据。

> **注意：**分区过期后，该分区在逻辑上被删除，最新的快照无法查询到该分区的数据。但是文件系统中的文件不会立即被物理删除，这取决于相应的快照何时到期。

* `values-time` 策略：

```sql
CREATE TABLE t (...) PARTITIONED BY (dt) WITH (
    'partition.expiration-time' = '7 d',
    'partition.expiration-check-interval' = '1 d',
    'partition.timestamp-formatter' = 'yyyyMMdd'   -- this is required in `values-time` strategy.
);
-- Let's say now the date is 2024-07-09，so before the date of 2024-07-02 will expire.
insert into t values('pk', '2024-07-01');

-- An example for multiple partition fields
CREATE TABLE t (...) PARTITIONED BY (other_key, dt) WITH (
    'partition.expiration-time' = '7 d',
    'partition.expiration-check-interval' = '1 d',
    'partition.timestamp-formatter' = 'yyyyMMdd',
    'partition.timestamp-pattern' = '$dt'
);
```

* `update-time` 策略

```sql
CREATE TABLE t (...) PARTITIONED BY (dt) WITH (
    'partition.expiration-time' = '7 d',
    'partition.expiration-check-interval' = '1 d',
    'partition.expiration-strategy' = 'update-time'
);

-- The last update time of the partition is now, so it will not expire.
insert into t values('pk', '2024-01-01');
-- Support non-date formatted partition.
insert into t values('pk', 'par-1'); 
```

## 参数配置

| Option                              | Default     | Type     | Description                                                  |
| :---------------------------------- | :---------- | :------- | :----------------------------------------------------------- |
| partition.expiration-strategy       | values-time | String   | 指定分区过期策略，`vlaues-time`策略，从分区值中提取，默认策略。`update-time`策略，比较分区的最新更新时间与当天时间 |
| partition.expiration-check-interval | 1 h         | Duration | 分区过期的校验间隔                                           |
| partition.expiration-time           | (none)      | Duration | 分区的过期时间间隔。如果分区的生存期超过此值，则分区将过期。分区时间从分区值中提取。 |
| partition.timestamp-formatter       | (none)      | String   | 从`'partition.timestamp-pattern`配置的字段提取的值进行格式化，默认为 'yyyy-MM-dd HH:mm:ss' 和 'yyyy-MM-dd'。支持多个分区字段，如`$year-$month-$day $hour:00:00`。与Java的DateTimeFormatter兼容 |
| partition.timestamp-pattern         | (none)      | String   | 指定一个模式来从分区获取时间戳，默认情况下，从第一个字段读取。如果分区中的时间戳是一个名为“dt”的字段，则可以使用“$dt”。如果年、月、日和小时分布在多个字段中，则可以使用'$year-$month-$day $hour:00:00'。如果时间戳在dt和hour字段中，则可以使用'$dt $hour:00:00'。 |

# Procedures

* Flink1.18或最新版本支持`CALL`语法，这使得通过编写SQL而不是提交Flink作业来操纵Paimon表的数据和元数据变得更加容易。在1.18版本，procedure仅支持按位置传递参数，你必须按顺序传递所有参数，如果你不想传递一些参数，必须使用`''`跳过，如果你想compaction表`default.t`指定并行度4，但是不指定分区和排序策略，可以执行以下语法：

```sql
CALL sys.compact('default.t', '', '', '', 'sink.parallelism=4')
```

* 在更高版本，procedure支撑通过配置名传递参数，您可以以任何顺序传递参数，并且可以省略任何可选参数。如下：

```sql
CALL sys.compact(`table` => 'default.t', options => 'sink.parallelism=4')
```

* 指定分区，使用字符指定分区过滤器，`","`的意思表示`AND`,";"表示`OR`。例如指定分区过滤条件为`date=01 or date=02`你需要配置`date=01;date=02`;

## Paimon支持的Procedures

### compact

* 指定特定表进行`compaction`

```sql
-- table(必选):指定需要compact的表，
-- partitions(可选):指定需要compact的分区
-- order_strategy(可选):排序策略，'order' or 'zorder' or 'hilbert' or 'none'.
-- order_by(可选):排序字段
-- options(可选):动态添加的表配置
-- where(可选): 分区过滤器(不能和partitions一起使用).使用需要`where`
-- use partition filter
CALL sys.compact(`table` => 'default.T', partitions => 'p=0', order_strategy => 'zorder', order_by => 'a,b', options => 'sink.parallelism=4')
-- use partition predicate
CALL sys.compact(`table` => 'default.T', `where` => 'dt>10 and h<20', order_strategy => 'zorder', order_by => 'a,b', options => 'sink.parallelism=4')
```

### compact_database

```sql
-- includingDatabases: 指定需要compaction的库，支持正则表达式
-- mode: compact的模式. "divided": 为每个表启动一个sink，检测新表需要重新启动作业。 "combined" (default): 为所有表启动单个合并sink，将自动检测新表。
-- includingTables:指定需要compaction的表集合，支持正则表达式
-- excludingTables: 指定不需要compaction的表集合，支持正则表达式
-- tableOptions: 动态添加的表配置
-- 使用方式
CALL [catalog.]sys.compact_database()
CALL [catalog.]sys.compact_database('includingDatabases')
CALL [catalog.]sys.compact_database('includingDatabases', 'mode')
CALL [catalog.]sys.compact_database('includingDatabases', 'mode', 'includingTables')
CALL [catalog.]sys.compact_database('includingDatabases', 'mode', 'includingTables', 'excludingTables')
CALL [catalog.]sys.compact_database('includingDatabases', 'mode', 'includingTables', 'excludingTables', 'tableOptions')
```

### create_tag

* 为表的快照创建tag，支持指定快照

```sql
-- identifier: 表描述，不能为空
-- tagName: tag名称
-- snapshotId (Long): 指定快照id，基于此快照创建tag
-- time_retained: 创建的tag最大保留时间
-- 基于指定快照
CALL [catalog.]sys.create_tag('identifier', 'tagName', snapshotId)
-- 基于最新快照
CALL [catalog.]sys.create_tag('identifier', 'tagName')
-- 使用方式
CALL sys.create_tag('default.T', 'my_tag', 10, '1 d')
```

### delete_tag

```sql
-- identifier: 表描述，不能为空
-- tagName: tag名称
-- 使用方式
CALL [catalog.]sys.delete_tag('identifier', 'tagName')	
```

### merge_into

* merge into过程，类似于iceberg支持的merge into语法，支撑对一条记录的不同情况进行对应操作

```sql
-- 参数参考：https://paimon.apache.org/how-to/writing-tables#merging-into-table
-- 当匹配上执行upsert
CALL [catalog.]sys.merge_into('identifier','targetAlias',
'sourceSqls','sourceTable','mergeCondition',
'matchedUpsertCondition','matchedUpsertSetting')
-- 当匹配上执行upsert，当匹配不上执行insert
CALL [catalog.]sys.merge_into('identifier','targetAlias',
'sourceSqls','sourceTable','mergeCondition',
'matchedUpsertCondition','matchedUpsertSetting',
'notMatchedInsertCondition','notMatchedInsertValues')
-- 当匹配上执行delete
CALL [catalog].sys.merge_into('identifier','targetAlias',
'sourceSqls','sourceTable','mergeCondition',
'matchedDeleteCondition')
-- 当匹配上 upsert + delete;
-- 当匹配不上执行insert
CALL [catalog].sys.merge_into('identifier','targetAlias',
'sourceSqls','sourceTable','mergeCondition',
'matchedUpsertCondition','matchedUpsertSetting',
'notMatchedInsertCondition','notMatchedInsertValues',
'matchedDeleteCondition')

-- 案例
call sys.merge_into('default.test1','t1','create TEMPORARY view s1 as select 1 as id,cast(1 as string) as name','s1','t1.id=s1.id','','name=s1.name','','*');
```

### remove_orphan_files

* 删除孤立文件过程

```sql
-- identifier: 指定表，不能为空，可以使用database_name.*清理整个db
-- olderThan: 为了避免删除新写入的文件，此过程默认只删除超过1天的孤立文件。此参数可以修改间隔，例如'2023-10-31 12:00:00'，删除该时间之前的文件
-- dryRun: 当为true时，只查看孤立文件，不要实际删除文件。默认为false。
-- 使用方法
CALL [catalog.]sys.remove_orphan_files('identifier')
CALL [catalog.]sys.remove_orphan_files('identifier', 'olderThan')
CALL [catalog.]sys.remove_orphan_files('identifier', 'olderThan', 'dryRun')
```

### reset_consumer

* 重置consumer

```sql
-- identifier:指定表，不能为空
-- consumerId: 重置或删除消费者
-- nextSnapshotId (Long): 消费的新的下一个快照id。
-- 重置特定消费者消费点为下一个快照
CALL [catalog.]sys.reset_consumer('identifier', 'consumerId', nextSnapshotId)
-- 删除消费者
CALL [catalog.]sys.reset_consumer('identifier', 'consumerId')
```

### rollback_to

* 回滚表到指定版本

```sql
-- identifier: 指定表，不能为空
-- snapshotId (Long): 快照id
-- tagName: tag名
-- 回滚到指定快照
CALL sys.rollback_to('identifier', snapshotId)
-- 回滚到指定tag
CALL sys.rollback_to('identifier', 'tagName')
```

### expire_snapshots

* 过期指定快照

```sql
-- table: 指定表，不能为空
-- retain_max: 已完成快照最大保留个数
-- retain_min: 已完成快照最小保留个数
-- order_than: 快照被删除的时间戳
-- max_deletes: 一次可以删除的最大快照数量。
-- for Flink 1.18
CALL sys.expire_snapshots(table, retain_max)
CALL sys.expire_snapshots('default.T', 2)
-- for Flink 1.19 and later
CALL sys.expire_snapshots(table, retain_max, retain_min, older_than, max_deletes)
CALL sys.expire_snapshots(`table` => 'default.T', retain_max => 2)
CALL sys.expire_snapshots(`table` => 'default.T', older_than => '2024-01-01 12:00:00')
CALL sys.expire_snapshots(`table` => 'default.T', older_than => '2024-01-01 12:00:00', retain_min => 10)
CALL sys.expire_snapshots(`table` => 'default.T', older_than => '2024-01-01 12:00:00', max_deletes => 10)
```

### expire_partitions

* 过期分区

```sql
-- table: 指定表，不能为空
-- expiration_time: 分区的过期时间间隔。如果分区的生存期超过此值，则分区将过期。分区时间从分区值中提取。
-- timestamp_formatter: 从字符串格式化时间戳的格式化格式
-- expire_strategy: 指定的分区过期策略，具体参考#Expire Partition章节
CALL sys.expire_partitions(table, expiration_time, timestamp_formatter, expire_strategy)
-- for Flink 1.18
CALL sys.expire_partitions('default.T', '1 d', 'yyyy-MM-dd', 'values-time')
-- for Flink 1.19 and later
CALL sys.expire_partitions(`table` => 'default.T', expiration_time => '1 d', timestamp_formatter => 'yyyy-MM-dd', expire_strategy => 'values-time')

```

### repair

* 将文件系统信息同步到Metastore，类似与hive中的msck repair table，数据直接写到文件系统时，修复该文件的元数据

```sql
-- empty: 为空时，表示这个catalog下的全部db和表
-- databaseName : 指定的db
-- tableName: 指定的表
-- repair这个catalog下的全部db和表
CALL sys.repair()
-- repair这个表的全部表
CALL sys.repair('databaseName')
-- repair table
CALL sys.repair('databaseName.tableName')
-- 修复多个db或表，通过,分割
CALL sys.repair('databaseName01,database02.tableName01,database03')

CALL sys.repair('test_db.T')
```

### rewrite_file_index

* 重写表的文件索引

```sql
-- identifier: <databaseName>.<tableName>.
-- partitions : 指定分区，可选
CALL sys.rewrite_file_index(<identifier> [, <partitions>])
-- 重写整个表的文件索引
CALL sys.rewrite_file_index('test_db.T')
-- 重写指定分区的文件索引
CALL sys.rewrite_file_index('test_db.T', 'pt=a')
```

### create_branch

* 根据给定的快照/tag创建branch，或者只创建空branch

```sql
-- identifier: <databaseName>.<tableName>.不能为空
-- branchName: 新branch名称
-- snapshotId (Long): 基于这个快照创建branch
-- tagName: 基于这个tag创建branch
-- 基于指定的快照
CALL [catalog.]sys.create_branch('identifier', 'branchName', snapshotId)
CALL sys.create_branch('default.T', 'branch1', 10)
-- 基于指定的tag
CALL [catalog.]sys.create_branch('identifier', 'branchName', 'tagName')
CALL sys.create_branch('default.T', 'branch1', 'tag1')
-- create empty branch
CALL [catalog.]sys.create_branch('identifier', 'branchName')
CALL sys.create_branch('default.T', 'branch1')
```

### delete_branch

* 删除branch

```sql
-- identifier:<databaseName>.<tableName>.不能为空
-- branchName: branch名称，如果删除多个通过","分割
CALL [catalog.]sys.delete_branch('identifier', 'branchName')	
```

### fast_forward

* 将一个分支合并到主分支

```sql
-- identifier: <databaseName>.<tableName>.不能为空
-- branchName: 要合并的分支名称。
CALL [catalog.]sys.fast_forward('identifier', 'branchName')	
CALL sys.fast_forward('default.T', 'branch1')
```

# Action Jars

## 启动语法

```shell
# action： 执行任务类型
# args：配置参数
<FLINK_HOME>/bin/flink run \
 /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
 <action>
 <args>
# 启动一个compact任务
<FLINK_HOME>/bin/flink run \
 /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
 compact \
 --path <TABLE_PATH>
```

## Merge Into Table

* Paimon支持MERGE INTO，通过flink run`提交`merge_into`作业。

> * 只有主键表支持merge into
> * 该操作不会产生`UPDATE_BEFORE`，因此不建议设置`changelog-producer = input`

*  `merge_into`操作使用 `UPSERT`语义而不是 `UPDATE`，这意味着如果存在该行，则进行更新，否则会插入。例如，对于非主键表，您可以更新每一列，但是对于主键表，如果要更新主键，则必须插入一个新的行，该行与表中的行具有不同的主键。在这种情况下，`UPSERT`很有用。

```shell
<FLINK_HOME>/bin/flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    merge_into \
    --warehouse <warehouse-path> \
    --database <database-name> \
    --table <target-table> \
    [--target_as <target-table-alias>] \
    --source_table <source_table-name> \
    [--source_sql <sql> ...]\
    --on <merge-condition> \
    --merge_actions <matched-upsert,matched-delete,not-matched-insert,not-matched-by-source-upsert,not-matched-by-source-delete> \
    --matched_upsert_condition <matched-condition> \
    --matched_upsert_set <upsert-changes> \
    --matched_delete_condition <matched-condition> \
    --not_matched_insert_condition <not-matched-condition> \
    --not_matched_insert_values <insert-values> \
    --not_matched_by_source_upsert_condition <not-matched-by-source-condition> \
    --not_matched_by_source_upsert_set <not-matched-upsert-changes> \
    --not_matched_by_source_delete_condition <not-matched-by-source-condition> \
    [--catalog_conf <paimon-catalog-conf> [--catalog_conf <paimon-catalog-conf> ...]]

## 案例
## 找到订单id相同的数据，如果T表的price大于100的数据进行upsert，小于10的删除
./flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    merge_into \
    --warehouse <warehouse-path> \
    --database <database-name> \
    --table T \
    --source_table S \
    --on "T.id = S.order_id" \
    --merge_actions \
    matched-upsert,matched-delete \
    --matched_upsert_condition "T.price > 100" \
    --matched_upsert_set "mark = 'important'" \
    --matched_delete_condition "T.price < 10" 
    
## 找到订单id相同的表，对price+20
./flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    merge_into \
    --warehouse <warehouse-path> \
    --database <database-name> \
    --table T \
    --source_table S \
    --on "T.id = S.order_id" \
    --merge_actions \
    matched-upsert,not-matched-insert \
    --matched_upsert_set "price = T.price + 20" \
    --not_matched_insert_values * 

-- For not matched by source order rows (which are in the target table and does not match any row in the
-- source table based on the merge-condition), decrease the price or if the mark is 'trivial', delete them:
# 找到订单id的数据，当匹配不上时，T表的mark不等于trivial执行upsert，T表的price-20，当T表的mark为trivial删除数据
./flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    merge_into \
    --warehouse <warehouse-path> \
    --database <database-name> \
    --table T \
    --source_table S \
    --on "T.id = S.order_id" \
    --merge_actions \
    not-matched-by-source-upsert,not-matched-by-source-delete \
    --not_matched_by_source_upsert_condition "T.mark <> 'trivial'" \
    --not_matched_by_source_upsert_set "price = T.price - 20" \
    --not_matched_by_source_delete_condition "T.mark = 'trivial'"
    
-- 在新的catalog里创建视图作为source表
./flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    merge_into \
    --warehouse <warehouse-path> \
    --database <database-name> \
    --table T \
    --source_sql "CREATE CATALOG test_cat WITH (...)" \
    --source_sql "CREATE TEMPORARY VIEW test_cat.`default`.S AS SELECT order_id, price, 'important' FROM important_order" \
    --source_table test_cat.default.S \
    --on "T.id = S.order_id" \
    --merge_actions not-matched-insert\
    --not_matched_insert_values *
```

* `matched`语法解释：
  * matched: 修改的行来自target表和每个基于merge-condition和可选的matched-condition能够匹配的source表的行 (source ∩ target).
  * not matched: 修改的行来自source表和target表基于merge-condition和可选地not_matched_condition所有行不能匹配的数据 (source - target).
  * not matched by source: 修改的行来自target表和source表基于merge-condition和可选地not-matched-by-source-condition 所有行不能匹配的数据(target - source)

### 参数格式

* matched_upsert_changes: col = <source_table>.col | expression [, …] (Means setting <target_table>.col with given value. Do not add ‘<target_table>.’ before ‘col’.)
  Especially, you can use ‘*’ to set columns with all source columns (require target table’s schema is equal to source’s).*
* *not_matched_upsert_changes is similar to matched_upsert_changes, but you cannot reference source table’s column or use ‘*’.

* insert_values:
  col1, col2, …, col_end
  Must specify values of all columns. For each column, you can reference <source_table>.col or use an expression.
  Especially, you can use ‘*’ to insert with all source columns (require target table’s schema is equal to source’s).

* not_matched_condition cannot use target table’s columns to construct condition expression.

* not_matched_by_source_condition cannot use source table’s columns to construct condition expression.

```bash
# 具体查看如下：
<FLINK_HOME>/bin/flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    merge_into --help
```

## Deleting from table

* 在Flink 1.16和以前的版本中，Paimon只支持通过`flink run`提交删除作业来删除记录。

```bash
<FLINK_HOME>/bin/flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    delete \
    --warehouse <warehouse-path> \
    --database <database-name> \
    --table <table-name> \
    --where <filter_spec> \
    [--catalog_conf <paimon-catalog-conf> [--catalog_conf <paimon-catalog-conf> ...]]
    
# filter_spec等同于SQL中的'WHERE'语句 .例如
    age >= 18 AND age <= 60
    animal <> 'cat'
    id > (SELECT count(*) FROM employee)
    
# 查看更多参数
<FLINK_HOME>/bin/flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    delete --help
```

## Drop Partition

```bash
<FLINK_HOME>/bin/flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    drop_partition \
    --warehouse <warehouse-path> \
    --database <database-name> \
    --table <table-name> \
    [--partition <partition_spec> [--partition <partition_spec> ...]] \
    [--catalog_conf <paimon-catalog-conf> [--catalog_conf <paimon-catalog-conf> ...]]

partition_spec:
key1=value1,key2=value2...

# 查看更多参数
<FLINK_HOME>/bin/flink run \
    /path/to/paimon-flink-action-0.9-SNAPSHOT.jar \
    drop_partition --help
```

# Savepoint

* Paimon有自己的快照管理，这可能会与Flink的checkpoint管理发生冲突，导致从Savepoint恢复时出现异常(不会影响底层数据存储)。
* 可以通过以下方式执行savepoint：
  * 使用`bin/flink stop --type [native/canonical] --savepointPath [:targetDirectory] :jobId`来触发savepoint
  * 使用带有Flink savepoint的Paimon tag，并在从savepoint恢复之前滚回tag。

## Stop with savepoint

* Flink的这个特性确保最后一个checkpoint被完全处理，这意味着不会再留下未提交的元数据。

```shell
bin/flink stop --type [native/canonical] --savepointPath [:targetDirectory] :jobId
```

## Tag with Savepoint

* 在Flink中，我们可以从kafka中消费，然后写到paimon。由于flink的checkpoint只保留有限的数量，因此我们将在特定时间(如代码升级、数据更新等)触发savepoint，以确保状态可以保留更长的时间，从而可以增量地恢复作业。
* Paimon的快照类似于flink的checkpoint，两者都将自动过期，但Paimon的标记特性允许快照保留很长时间。因此，我们可以结合paimon的tag和flink的savepoint，实现作业从指定savepoint的增量恢复。

### 启用方式

* 步骤1：为savepoint启用自动创建tag
  * 设置`sink.savepoint.auto-tag`为`true`
* 步骤2：触发savepoint
  * `bin/flink savepoint :jobId [:targetDirectory]`
* 步骤3：选择与savepoint相对应的tag
  * 与savepoint相对应的tag将以`savepoint-${savepointID}`的形式命名，可以通过`select * from test$tags`查询tag
* 步骤4： 回滚paimon表
  * 回滚paimon表到指定tag
* 步骤5：从savepoint重新启动
  * `bin/flink run -s :savepointPath [:runArgs]`

# Flink API

## 依赖管理

```xml
 <dependency>
            <groupId>org.apache.paimon</groupId>
            <artifactId>paimon-flink-1.20</artifactId>
            <version>0.9-SNAPSHOT</version>
        </dependency>

        <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-table-api-java-bridge</artifactId>
            <version>1.20.0</version>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-table-api-java</artifactId>
            <version>1.20.0</version>
        </dependency>
        <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-table-runtime</artifactId>
            <version>1.20.0</version>
        </dependency>
 				 <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-connector-files</artifactId>
            <version>1.20.0</version>
        </dependency>
        <dependency>
            <groupId>org.apache.hadoop</groupId>
            <artifactId>hadoop-common</artifactId>
            <version>3.3.4</version>
        </dependency>
```

## Write to Table

```java
package org.myorg.quickstart;

import org.apache.flink.api.common.typeinfo.Types;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.DataTypes;
import org.apache.flink.table.types.DataType;
import org.apache.flink.types.Row;
import org.apache.flink.types.RowKind;
import org.apache.paimon.catalog.Catalog;
import org.apache.paimon.catalog.FileSystemCatalog;
import org.apache.paimon.catalog.Identifier;
import org.apache.paimon.flink.sink.FlinkSinkBuilder;
import org.apache.paimon.fs.Path;
import org.apache.paimon.fs.local.LocalFileIO;
import org.apache.paimon.options.Options;
import org.apache.paimon.table.Table;

public class PaimonFlinkWriteAPI {
    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // create a changelog DataStream
        DataStream<Row> input =
                env.fromElements(
                                Row.ofKind(RowKind.INSERT, 1, 12),
                                Row.ofKind(RowKind.INSERT, 2, 5),
                                Row.ofKind(RowKind.UPDATE_BEFORE, 1, 12),
                                Row.ofKind(RowKind.UPDATE_AFTER, 1, 100))
                        .returns(
                                Types.ROW_NAMED(
                                        new String[]{"id", "age"}, Types.INT, Types.INT));

        // get table from catalog
        Options catalogOptions = new Options();
        catalogOptions.set("user", "root");
        catalogOptions.set("password", "root");

        Catalog catalog = new FileSystemCatalog(new LocalFileIO(),
                new Path("/Users/huangshimin/Documents/study/flink/paimonData"),
                catalogOptions);
        Table table = catalog.getTable(Identifier.create("default", "test_batch_tag_table"));

        DataType inputType =
                DataTypes.ROW(
                        DataTypes.FIELD("id", DataTypes.INT()),
                        DataTypes.FIELD("age", DataTypes.INT()));
        FlinkSinkBuilder builder = new FlinkSinkBuilder(table)
                .forRow(input, inputType)
                .overwrite()
                .parallelism(1);


        builder.build();
        env.execute();
    }
}
```

## Read from Table

```java
package org.myorg.quickstart;

import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.paimon.catalog.Catalog;
import org.apache.paimon.catalog.FileSystemCatalog;
import org.apache.paimon.catalog.Identifier;
import org.apache.paimon.flink.source.FlinkSourceBuilder;
import org.apache.paimon.fs.Path;
import org.apache.paimon.fs.local.LocalFileIO;
import org.apache.paimon.options.Options;
import org.apache.paimon.table.Table;

public class PaimonFlinkReadAPI {
    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();


        // get table from catalog
        Options catalogOptions = new Options();
        catalogOptions.set("user", "root");
        catalogOptions.set("password", "root");

        Catalog catalog = new FileSystemCatalog(new LocalFileIO(),
                new Path("/Users/huangshimin/Documents/study/flink/paimonData"),
                catalogOptions);
        Table table = catalog.getTable(Identifier.create("default", "test_batch_tag_table"));

        FlinkSourceBuilder builder = new FlinkSourceBuilder(table)
                .env(env);


        builder.build().print();
        env.execute();
    }
}
```

## Cdc ingestion Table

```java
package org.myorg.quickstart;

import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.paimon.catalog.Catalog;
import org.apache.paimon.catalog.FileSystemCatalog;
import org.apache.paimon.catalog.Identifier;
import org.apache.paimon.flink.sink.cdc.RichCdcRecord;
import org.apache.paimon.flink.sink.cdc.RichCdcSinkBuilder;
import org.apache.paimon.fs.Path;
import org.apache.paimon.fs.local.LocalFileIO;
import org.apache.paimon.options.Options;
import org.apache.paimon.table.Table;
import org.apache.paimon.types.DataTypes;

import static org.apache.paimon.types.RowKind.INSERT;
import static org.apache.paimon.types.RowKind.UPDATE_AFTER;
import static org.apache.paimon.types.RowKind.UPDATE_BEFORE;

public class PaimonFlinkCDCWriteAPI {
    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // create a cdc DataStream
        DataStream<RichCdcRecord> dataStream =
                env.fromElements(
                        RichCdcRecord.builder(INSERT)
                                .field("order_id", DataTypes.BIGINT(), "123")
                                .field("price", DataTypes.DOUBLE(), "62.2")
                                .build(),
                        // dt field will be added with schema evolution
                        RichCdcRecord.builder(INSERT)
                                .field("order_id", DataTypes.BIGINT(), "245")
                                .field("price", DataTypes.DOUBLE(), "82.1")
                                .field("dt", DataTypes.TIMESTAMP(), "2023-06-12 20:21:12")
                                .build(),
                        RichCdcRecord.builder(UPDATE_BEFORE)
                                .field("order_id", DataTypes.BIGINT(), "123")
                                .field("price", DataTypes.DOUBLE(), "62.2")
                                .build(),
                        RichCdcRecord.builder(UPDATE_AFTER)
                                .field("order_id", DataTypes.BIGINT(), "123")
                                .field("price", DataTypes.DOUBLE(), "90.1")
                                .field("dt", DataTypes.TIMESTAMP(), "2024-06-12 20:21:12")
                                .build(),
                        RichCdcRecord.builder(INSERT)
                                .field("order_id", DataTypes.BIGINT(), "124")
                                .field("price", DataTypes.DOUBLE(), "62.1")
                                .field("dt", DataTypes.TIMESTAMP(), "2024-07-12 20:21:12")
                                .build()
                        );

        Identifier identifier = Identifier.create("default", "cdc_table");
        Options catalogOptions = new Options();
        catalogOptions.set("user", "root");
        catalogOptions.set("password", "root");
        Catalog.Loader catalogLoader =
                () -> new FileSystemCatalog(new LocalFileIO(),
                        new Path("/Users/huangshimin/Documents/study/flink/paimonData"),
                        catalogOptions);
        Table table = catalogLoader.load().getTable(identifier);

        new RichCdcSinkBuilder(table)
                .forRichCdcRecord(dataStream)
                .identifier(identifier)
                .catalogLoader(catalogLoader)
                .build();

        env.execute();
    }
}
```