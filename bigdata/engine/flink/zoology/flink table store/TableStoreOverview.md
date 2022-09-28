# Quick Start

* Flink1.14之后才支持Table Stroe，下载对应版本的Flink。

## 前置环境

### 下载Flink Table Store所需依赖

* 下载[flink1.15]([**https://dlcdn.apache.org/flink/flink-1.15.2/flink-1.15.2-bin-scala_2.12.tgz**](https://dlcdn.apache.org/flink/flink-1.15.2/flink-1.15.2-bin-scala_2.12.tgz))
* 编译[Flink Table Store](https://nightlies.apache.org/flink/flink-table-store-docs-master/docs/engines/build/)

```shell
cp flink-table-store-dist-*.jar FLINK_HOME/lib/
```

* 下载[flink hadoop](https://repo.maven.apache.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/2.8.3-10.0/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar)

```shell
cp flink-shaded-hadoop-2-uber-*.jar FLINK_HOME/lib/
```

### 启动flink本地集群

* 修改配置

```shell
vim ./conf/flink-conf.yaml

taskmanager.numberOfTaskSlots: 2
```

* 启动local cluster

```shell
./bin/start-cluster.sh
```

* 启动SQL Client

```shell
./bin/sql-client.sh embedded
```

## 通过Table Store读写数据

### 创建table store表

```sql
CREATE CATALOG my_catalog WITH (
  'type'='table-store',
  'warehouse'='file:/Users/huangshimin/Documents/study/flink/tableStoreData'
);

USE CATALOG my_catalog;

-- create a word count table
CREATE TABLE word_count (
    word STRING PRIMARY KEY NOT ENFORCED,
    cnt BIGINT
);
```

### 写入数据

```sql
-- create a word data generator table
CREATE TEMPORARY TABLE word_table (
    word STRING
) WITH (
    'connector' = 'datagen',
    'fields.word.length' = '1'
);

-- table store requires checkpoint interval in streaming mode
SET 'execution.checkpointing.interval' = '10 s';

-- write streaming data to dynamic table
INSERT INTO word_count SELECT word, COUNT(*) FROM word_table GROUP BY word;
```

### 读取数据

```shell
-- use tableau result mode
SET 'sql-client.execution.result-mode' = 'tableau';

-- switch to batch mode，批量读取
RESET 'execution.checkpointing.interval';
SET 'execution.runtime-mode' = 'batch';

-- olap query the table
SELECT * FROM word_count;

-- 流式读取
SET 'execution.runtime-mode' = 'streaming';
SELECT `interval`, COUNT(*) AS interval_cnt FROM
  (SELECT cnt / 10000 AS `interval` FROM word_count) GROUP BY `interval`;
```

# Table Store概述

* Flink Table Store是在Flink中构建动态表进行流处理和批处理的统一存储，支持高速数据摄取和及时数据查询。Table Store提供以下核心功能:
  * 支持大规模数据集的存储，允许批处理和流模式下的读写。
  * 支持延迟最小至毫秒的流查询。
  * 支持最小延迟至第二级的批次/OLAP查询。
  * 默认支持增量快照流消费。因此用户不需要自己组合不同的数据管道。

## 架构

![](../../img/tablestore架构.jpg)

* **读/写：**Table Store支持读写数据和执行OLAP查询的通用方法。
  * 对于读，它支持读取数据来自1.历史快照(batch mode) 2.来自最新的offset(streaming mode) 3.混合方式读取增量快照数据
  * 对于写，支持从数据库的变更日志(CDC)的流同步或从离线数据的批量插入/覆盖。
* **外部生态系统:**除了支持Flink以外，Table Store还支持通过其他计算引擎来读取例如Hive/Spark/Trino。
* **内部原理:**Table Store使用混合存储体系结构，使用湖格式存储历史数据，使用消息队列系统存储增量数据。前者将列存文件存储在文件系统/对象存储中，并使用LSM树结构支持大量数据更新和高性能查询。后者使用Apache Kafka实时捕获数据。

## 统一的存储

* Flink SQL支持三种类型的连接器
  * **消息队列**，例如kafka，在这个管道的source阶段和中间处理阶段都使用它，以确保延迟保持在几秒内。
  * **OLAP系统**，例如clickhouse，它以流的方式接收处理过的数据，并为用户的特别查询服务。
  * **批次存储**，例如HIve，它支持传统批处理的各种操作，包括INSERT OVERWRITE。
* Flink Table Store提供表抽象。它的使用方式与传统数据库没有区别:
  * 在flink的`batch`执行模式，它就像一个Hive表，支持Batch SQL的各种操作。查询它可以查看最新的快照。
  * 在flink的`streaming`执行模式，他类似消息队列，查询它就像从一个消息队列中查询历史数据永不过期的流更改日志。

# Create Table

## Catalog

* Table Store使用独立的catalog来管理全部的database和table，需要指定`table-store`的类型和对应的`warehouse`路径

```sql
CREATE CATALOG my_catalog WITH (
  'type'='table-store',
  'warehouse'='hdfs://nn:8020/warehouse/path' -- or 'file://tmp/foo/bar'
);
USE CATALOG my_catalog;
```

* Table Store catalog支持以下SQL
  * `CREATE TABLE ... PARTITIONED BY`
  * `DROP TABLE ...`
  * `ALTER TABLE ...`
  * `SHOW DATABASES`
  * `SHOW TABLES`

```sql
CREATE TABLE [IF NOT EXISTS] [catalog_name.][db_name.]table_name
  (
    { <physical_column_definition> | <computed_column_definition> }[ , ...n]
    [ <watermark_definition> ]
    [ <table_constraint> ][ , ...n]
  )
  [PARTITIONED BY (partition_column_name1, partition_column_name2, ...)]
  WITH (key1=val1, key2=val2, ...)
   
<physical_column_definition>:
  column_name column_type [ <column_constraint> ] [COMMENT column_comment]
  
<column_constraint>:
  [CONSTRAINT constraint_name] PRIMARY KEY NOT ENFORCED

<table_constraint>:
  [CONSTRAINT constraint_name] PRIMARY KEY (column_name, ...) NOT ENFORCED

<computed_column_definition>:
  column_name AS computed_column_expression [COMMENT column_comment]

<watermark_definition>:
  WATERMARK FOR rowtime_column_name AS watermark_strategy_expression
```

* 数据会存储在`${warehouse}/${database_name}.db/${table_name}`下

## Table Options

| Option                  | Required | Default | Type    | Description                                                  |
| :---------------------- | :------- | :------ | :------ | :----------------------------------------------------------- |
| bucket                  | Yes      | 1       | Integer | table store的bucket数量，存储数据的地方                      |
| log.system              | No       | (none)  | String  | The log system used to keep changes of the table, supports 'kafka'. |
| kafka.bootstrap.servers | No       | (none)  | String  | Required Kafka server connection string for log store.       |
| kafka.topic             | No       | (none)  | String  | Topic of this kafka table.                                   |

## Distribution

* table store的数据分布由三个概念组成:Partition, Bucket, and Primary Key

```sql
CREATE TABLE MyTable (
  user_id BIGINT,
  item_id BIGINT,
  behavior STRING,
  dt STRING,
  PRIMARY KEY (dt, user_id) NOT ENFORCED
) PARTITIONED BY (dt) WITH (
  'bucket' = '4'
);
```

* partition:根据分区字段隔离不同的数据
* bucket:在单个分区内，根据主键的hash值分布到4个不同的bucket
* primary key:在当个bucket内，按照主键排序，构建LSM结构。

## Partition

* Table Store采用类似于hive的分区去分离数据，因此，各种操作可以通过分区作为一个管理单元进行管理。
* 分区过滤可以用最高效的方式来提升性能，查询语句应该尽可能的包含分区过滤条件

## Bucket

* Bucket的概念是将数据划分为更易于管理的部分，以实现更高效的查询。
* 用N作为bucket number，记录落入(0,1，…n - 1)bucket。对于每条记录，它属于哪个bucket是通过一个或多个列(表示为bucket键)的哈希值计算的，并根据bucket number进行mod。

```shell
bucket_id=hash_func(bucket_key)%num_of_buckets
```

* 使用方式如下,通过`bucket-key`显式指定bucket key。如果没有特殊指定会使用primary key或者整行记录作为bucket key。

```sql
CREATE TABLE MyTable (
  catalog_id BIGINT,
  user_id BIGINT,
  item_id BIGINT,
  behavior STRING,
  dt STRING
) WITH (
    'bucket-key' = 'catalog_id'
);
```

* Bucket key不能在表创建后更改。ALTER TABLE SET ('bucket-key' =…)或ALTER TABLE RESET ('bucket-key')将抛出异常。
* Bucket的数量非常重要，因为它决定了最坏情况下的最大处理并行度。但不能太大，否则，系统会创建很多小文件。一般情况下，要求的文件大小为**128mb**，建议每个子桶保存在磁盘上的**数据大小为1gb左右**。