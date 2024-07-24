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