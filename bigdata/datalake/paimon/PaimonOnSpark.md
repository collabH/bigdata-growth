# 快速开始

## 前置准备

* Paimon支持Spark 3.5, 3.4, 3.3, 3.2 和 3.1版本

| Version   | Jar                                                          |
| --------- | ------------------------------------------------------------ |
| Spark 3.5 | [paimon-spark-3.5-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-spark-3.5/0.9-SNAPSHOT/) |
| Spark 3.4 | [paimon-spark-3.4-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-spark-3.4/0.9-SNAPSHOT/) |
| Spark 3.3 | [paimon-spark-3.3-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-spark-3.3/0.9-SNAPSHOT/) |
| Spark 3.2 | [paimon-spark-3.2-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-spark-3.2/0.9-SNAPSHOT/) |
| Spark 3.1 | [paimon-spark-3.1-0.9-SNAPSHOT.jar](https://repository.apache.org/snapshots/org/apache/paimon/paimon-spark-3.1/0.9-SNAPSHOT/) |

* 也可以从源码手动构建paimon spark jar，从[clone the git repository

```bash
mvn clean install -DskipTests
```

## 配置

* 步骤1：指定paimon jar

```bash
# 通过jars参数或者packages参数指定paimon jar,使用packages需要将jar包防止spark/jars下
spark-sql ... --jars /path/to/paimon-spark-3.3-0.9-SNAPSHOT.jar
spark-sql ... --packages org.apache.paimon:paimon-spark-3.3:0.9-SNAPSHOT
```

* 步骤2：指定paimon catalog

```bash
# 启动Spark-SQL时，使用以下命令将Paimon的Spark Catalog注册为Paimon。仓库的表文件存储在/tmp/paimon下。
spark-sql ... \
    --conf spark.sql.catalog.paimon=org.apache.paimon.spark.SparkCatalog \
    --conf spark.sql.catalog.paimon.warehouse=file:/tmp/paimon \
    --conf spark.sql.extensions=org.apache.paimon.spark.extensions.PaimonSparkSessionExtensions
# spark.sql.catalog.(catalog_name)，如上配置catalog名称在catalog.之后
```

* 步骤3：完成的启动命令

```bash
spark-sql   --conf spark.sql.catalog.paimon=org.apache.paimon.spark.SparkCatalog \
    --conf spark.sql.catalog.paimon.warehouse=file:/Users/huangshimin/Documents/study/flink/paimonData \
    --conf spark.sql.extensions=org.apache.paimon.spark.extensions.PaimonSparkSessionExtensions \
	  --jars /Users/huangshimin/Documents/study/spark/paimon-spark-3.4-0.9-20240801.002500-46.jar
```

* 步骤4：切换catalog、database，执行创建、插入、查询操作

```sql
use paimon;
use default;
create table my_table (
    k int,
    v string
) tblproperties (
    'primary-key' = 'k'
);
INSERT INTO my_table VALUES (1, 'Hi'), (2, 'Hello');
select * from my_table;
```

# SQL DDL

## Create Catalog

* paimon catalog当前支持三种类型的metastore
  * `filesystem metastore`:默认metastore，它在文件系统中存储元数据和表文件。
  * `hive metastore`:它还将元数据存储在Hive metastore中。用户可以直接从Hive访问这些表。
  * `jdbc metastore`:它额外地将元数据存储在关系数据库中，如MySQL, Postgres等。

### Create Filesystem Catalog

* 创建一个catalog名为`paimon`，数据存储在`hdfs:///path/to/warehouse`的catalog

```bash
spark-sql ... \
    --conf spark.sql.catalog.paimon=org.apache.paimon.spark.SparkCatalog \
    --conf spark.sql.catalog.paimon.warehouse=hdfs:///path/to/warehouse
```

* 切换catalog

```sql
USE paimon.default;
```

### Creating Hive Catalog

* 通过使用Paimon Hive catalog，对catalog的更改将直接影响到相应的Hive metastore。在这样的catalog中创建的表也可以直接从Hive访问。要使用Hive catalog, Database name, Table name和Field name应该是小写的。

```bash
spark-sql ... \
    --conf spark.sql.catalog.paimon=org.apache.paimon.spark.SparkCatalog \
    --conf spark.sql.catalog.paimon.warehouse=hdfs:///path/to/warehouse \
    --conf spark.sql.catalog.paimon.metastore=hive \
    --conf spark.sql.catalog.paimon.uri=thrift://<hive-metastore-host-name>:<port>
```

### Creating JDBC Catalog

* 通过使用Paimon JDBC Catalog，对Catalog的更改将直接存储在SQLITE、MySQL、Postgres等关系数据库中。
* 目前，Lock配置只支持MySQL和SQLite。如果您使用不同类型的数据库进行Catalog存储，请不要配置`lock.enabled`。
* Spark中的Paimon JDBC Catalog需要正确添加相应的连接数据库的jar包。应该首先下载JDBC连接器的jar并将其添加到classpath中。例如MySQL, postgres

| database type | Bundle Name          | SQL Client JAR                                               |
| :------------ | :------------------- | :----------------------------------------------------------- |
| mysql         | mysql-connector-java | [Download](https://mvnrepository.com/artifact/mysql/mysql-connector-java) |
| postgres      | postgresql           | [Download](https://mvnrepository.com/artifact/org.postgresql/postgresql) |

```bash
spark-sql ... \
    --conf spark.sql.catalog.paimon=org.apache.paimon.spark.SparkCatalog \
    --conf spark.sql.catalog.paimon.warehouse=hdfs:///path/to/warehouse \
    --conf spark.sql.catalog.paimon.metastore=jdbc \
    --conf spark.sql.catalog.paimon.uri=jdbc:mysql://<host>:<port>/<databaseName> \
    --conf spark.sql.catalog.paimon.jdbc.user=... \
    --conf spark.sql.catalog.paimon.jdbc.password=...
```

## Create Table

* 在使用Paimon catalog之后，可以创建和删除表。在Paimon Catalogs中创建的表由Catalog管理。当表从Catalog中删除时，它的表文件也将被删除。

```sql
-- 在paimon catalog下创建一个表my_table，其主键为dt、hh、user_id
CREATE TABLE my_table (
    user_id BIGINT,
    item_id BIGINT,
    behavior STRING,
    dt STRING,
    hh STRING
) TBLPROPERTIES (
    'primary-key' = 'dt,hh,user_id'
);
-- 创建一个分区表
CREATE TABLE my_table (
    user_id BIGINT,
    item_id BIGINT,
    behavior STRING,
    dt STRING,
    hh STRING
) PARTITIONED BY (dt, hh) TBLPROPERTIES (
    'primary-key' = 'dt,hh,user_id'
);
```

## Create Table As Select

```sql
CREATE TABLE my_table (
     user_id BIGINT,
     item_id BIGINT
);
-- 使用my_table的查询结果来创建一个my_table_as
CREATE TABLE my_table_as AS SELECT * FROM my_table;

-- 分区表
CREATE TABLE my_table_partition (
      user_id BIGINT,
      item_id BIGINT,
      behavior STRING,
      dt STRING,
      hh STRING
) PARTITIONED BY (dt, hh);
-- 使用my_table_partition的结果来创建一个以dt分区的分区表my_table_partition_as
CREATE TABLE my_table_partition_as PARTITIONED BY (dt) AS SELECT * FROM my_table_partition;

-- 修改表属性
CREATE TABLE my_table_options (
       user_id BIGINT,
       item_id BIGINT
) TBLPROPERTIES ('file.format' = 'orc');
-- 修改表文件格式orc为parquet
CREATE TABLE my_table_options_as TBLPROPERTIES ('file.format' = 'parquet') AS SELECT * FROM my_table_options;


-- 主键表
CREATE TABLE my_table_pk (
     user_id BIGINT,
     item_id BIGINT,
     behavior STRING,
     dt STRING,
     hh STRING
) TBLPROPERTIES (
    'primary-key' = 'dt,hh,user_id'
);
-- 基于老表创建一个新的主键表
CREATE TABLE my_table_pk_as TBLPROPERTIES ('primary-key' = 'dt') AS SELECT * FROM my_table_pk;

-- 主键+分区
CREATE TABLE my_table_all (
    user_id BIGINT,
    item_id BIGINT,
    behavior STRING,
    dt STRING,
    hh STRING
) PARTITIONED BY (dt, hh) TBLPROPERTIES (
    'primary-key' = 'dt,hh,user_id'
);
CREATE TABLE my_table_all_as PARTITIONED BY (dt) TBLPROPERTIES ('primary-key' = 'dt,hh') AS SELECT * FROM my_table_all;
```

# SQL Write

## 语法

```sql
INSERT { INTO | OVERWRITE } table_identifier [ part_spec ] [ column_list ] { value_expr | query };
```

## INSERT INTO

* 使用INSERT INTO将记录和更改写入到表中。

```sql
INSERT INTO my_table SELECT ...
```

## Overwriting the Whole Table

* 使用' INSERT OVERWRITE '来覆盖整个未分区表。

```sql
INSERT OVERWRITE my_table SELECT ...
```

### Overwriting a Partition

* 使用 `INSERT OVERWRITE` 覆盖整个分区

```sql
INSERT OVERWRITE my_table PARTITION (key1 = value1, key2 = value2, ...) SELECT ...
```

### Dynamic Overwrite

* spark默认overwrite模式为`static`分区覆盖，开启动态分区覆盖需要设置`spark.sql.sources.partitionOverwriteMode`为`dynamic`

```sql
CREATE TABLE my_table (id INT, pt STRING) PARTITIONED BY (pt);
INSERT INTO my_table VALUES (1, 'p1'), (2, 'p2');

-- static overwrite，会覆盖全部分区
INSERT OVERWRITE my_table VALUES (3, 'p1');

SELECT * FROM my_table;
/*
+---+---+
| id| pt|
+---+---+
|  3| p1|
+---+---+
*/

-- Dynamic overwrite (只覆盖 pt='p1')
SET spark.sql.sources.partitionOverwriteMode=dynamic;
INSERT OVERWRITE my_table VALUES (3, 'p1');

SELECT * FROM my_table;
/*
+---+---+
| id| pt|
+---+---+
|  2| p2|
|  3| p1|
+---+---+
*/
```

## Truncate tables

```sql
TRUNCATE TABLE my_table;
```

## Updating tables

* spark 支持修改基本类型和结构类型

```sql
-- Syntax
UPDATE table_identifier SET column1 = value1, column2 = value2, ... WHERE condition;

CREATE TABLE t (
  id INT, 
  s STRUCT<c1: INT, c2: STRING>, 
  name STRING)
TBLPROPERTIES (
  'primary-key' = 'id', 
  'merge-engine' = 'deduplicate'
);

-- you can use
UPDATE t SET name = 'a_new' WHERE id = 1;
UPDATE t SET s.c2 = 'a_new' WHERE s.c1 = 1;
```

## Deleting from table

```sql
DELETE FROM my_table WHERE currency = 'UNKNOWN';
```

## Merging into table

* Paimon当前支持`Merge into`语法在Spark 3+，它允许在一次提交中基于source表进行一系列更新、插入和删除操作

> 1. 只支持主键表
> 2. 不支持更新主键
> 3. `WHEN NOT MATCHED BY SOURCE` 语法不支持

**案例1：**

```sql
-- 如果target和source中a字段相同的行存在，则全部修改，否则插入

MERGE INTO target
USING source
ON target.a = source.a
WHEN MATCHED THEN
UPDATE SET *
WHEN NOT MATCHED
THEN INSERT *
```

**案例2：**

```sql
MERGE INTO target
USING source
ON target.a = source.a
-- 当目标表a为5是，则更新b为source.b + target.b
WHEN MATCHED AND target.a = 5 THEN
   UPDATE SET b = source.b + target.b    
WHEN MATCHED AND source.c > 'c2' THEN
   UPDATE SET *    
WHEN MATCHED THEN
   DELETE      
WHEN NOT MATCHED AND c > 'c9' THEN
   INSERT (a, b, c) VALUES (a, b * 1.1, c)    
WHEN NOT MATCHED THEN
INSERT *     
```

## Streaming Write

> Paimon 当前支持Spark 3+对于流式写入
>
> Paimon Structured Streaming only supports the two `append` and `complete` modes.

```scala
// Create a paimon table if not exists.
spark.sql(s"""
           |CREATE TABLE T (k INT, v STRING)
           |TBLPROPERTIES ('primary-key'='a', 'bucket'='3')
           |""".stripMargin)

// Here we use MemoryStream to fake a streaming source.
val inputData = MemoryStream[(Int, String)]
val df = inputData.toDS().toDF("k", "v")

// Streaming Write to paimon table.
val stream = df
  .writeStream
  .outputMode("append")
  .option("checkpointLocation", "/path/to/checkpoint")
  .format("paimon")
  .start("/path/to/paimon/sink/table")
```

## Schema Evolution

* Schema evolution是一种允许用户轻松修改表的当前schema以适应现有数据或随时间变化的新数据的特性，同时保持数据的完整性和一致性。
* Paimon支持在写入数据时自动合并source数据和当前表数据的schema，并将合并后的schema用作表的最新schema，只需要配置`write.merge-schema`为`true`即可。

```scala
data.write
  .format("paimon")
  .mode("append")
  .option("write.merge-schema", "true")
  .save(location)
```

*  当开启`write.merge-schema`时，默认情况下，Paimon允许用户对表schema执行以下操作：
  * 添加新列
  * 修改列类型(e.g. Int -> Long)
* Paimon还支持特定类型之间的显式类型转换(e.g. String -> Date, Long -> Int),它需要显式配置`write.merge-schema.explicit-cast`为`true`
* Schema evolution可以同时用于流模式。

```scala
val inputData = MemoryStream[(Int, String)]
inputData
  .toDS()
  .toDF("col1", "col2")
  .writeStream
  .format("paimon")
  .option("checkpointLocation", "/path/to/checkpoint")
  .option("write.merge-schema", "true")
  .option("write.merge-schema.explicit-cast", "true")
  .start(location)
```

| Scan Mode                        | Description                                                  |
| :------------------------------- | :----------------------------------------------------------- |
| write.merge-schema               | If true, merge the data schema and the table schema automatically before write data. |
| write.merge-schema.explicit-cast | If true, allow to merge data types if the two types meet the rules for explicit casting. |

# SQL Query

## Batch Query

* Paimon的批量读取返回表快照中的所有数据。默认情况下，批量读取返回最新的快照。

### Batch Time Travel

* time travel的Paimon批量读可以指定一个snapshot-id或一个tag，并读取相应的数据，需要Spark3.3+版本

```sql
-- 根据快照id读取数据
SELECT * FROM t VERSION AS OF 1;

-- 根据写入时间读取最近快照
SELECT * FROM t TIMESTAMP AS OF '2023-06-01 00:00:00.123';

-- 根据时间戳读取最近快照
SELECT * FROM t TIMESTAMP AS OF 1678883047;

-- read tag 'my-tag'
SELECT * FROM t VERSION AS OF 'my-tag';

-- read the snapshot from specified watermark. will match the first snapshot after the watermark
SELECT * FROM t VERSION AS OF 'watermark-1678883047356';
```

## Batch Incremental

* 读取开始快照(不包含)和结束快照之间的增量变化，例如：
  * ‘5,10’ 读取快照5和快照10的最新的数据
  * ‘TAG1,TAG3’ 读取`TAG1`和`TAG3`的最新的数据
* 默认情况下，将扫描changelog文件以查找生成changelog文件的表。否则，扫描新修改的文件。指定`ncremental-between-scan-mode`指定模式。要求Spark3.2+版本；
* Paimon支持使用Spark SQL进行增量查询，而增量查询是由Spark表值函数实现的。

```sql
SELECT * FROM paimon_incremental_query('test1', 1, 5);
-- 增量查询不支持查询DELETE数据，如果想要查询DELETE数据，可以查询系统表audit_log
SELECT * FROM `test1$audit_log`;
```

## Streaming Query

> Paimon currently supports Spark 3.3+ for streaming read.

* Paimon支持的流式多去模式

| Scan Mode          | Description                                                  |
| :----------------- | :----------------------------------------------------------- |
| latest             | 对于流式数据源，连续地读取最新的更改，而不是在开始时生成快照。 |
| latest-full        | 对于流式数据源， 在第一次启动时在表上生成最新的快照，并继续读取最新的更改。 |
| from-timestamp     | 对于流式数据源，从“scan.timestamp-millis”指定的时间戳开始连续读取更改。不会在开始时生成快照。 |
| from-snapshot      | 对于流式数据源，从“scan.snapshot-id”指定的快照开始连续读取更改，开始时不生成快照。 |
| from-snapshot-full | 对于流式数据源，生成由“scan.snapshot-id”指定的快照。在第一次启动时在表上读取，并持续读取更改。 |
| default            | It is equivalent to from-snapshot if "scan.snapshot-id" is specified. It is equivalent to from-timestamp if "timestamp-millis" is specified. Or, It is equivalent to latest-full. |

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
-- 创建复合主键表
CREATE TABLE orders (
    catalog_id BIGINT,
    order_id BIGINT,
    .....,
) TBLPROPERTIES (
    'primary-key' = 'catalog_id,order_id'
);
-- 走复合主键查询优化
SELECT * FROM orders WHERE catalog_id=1025;

SELECT * FROM orders WHERE catalog_id=1025 AND order_id=29495;

SELECT * FROM orders
  WHERE catalog_id=1025
  AND order_id>2035 AND order_id<6000;
  
-- 不触发复合主键查询优化
SELECT * FROM orders WHERE order_id=29495;

SELECT * FROM orders WHERE catalog_id=1025 OR order_id=29495;
```

# SQL Alter

## Changing/Adding Table Properties

* 修改表`my_table`的 `write-buffer-size` 为`256MB`

```sql
ALTER TABLE my_table SET TBLPROPERTIES (
    'write-buffer-size' = '256 MB'
);
```

## Removing Table Properties

```sql
ALTER TABLE my_table UNSET TBLPROPERTIES ('write-buffer-size');
```

## Changing/Adding Table Comment

```sql
ALTER TABLE my_table SET TBLPROPERTIES (
    'comment' = 'table comment'
    );
```

## Removing Table Comment

```sql
ALTER TABLE my_table UNSET TBLPROPERTIES ('comment');
```

## Rename Table Name

```sql
ALTER TABLE my_table RENAME TO my_table_new;
ALTER TABLE [catalog.[database.]]test1 RENAME to [database.]test2;
ALTER TABLE catalog.database.test1 RENAME to catalog.database.test2;
```

> 如果使用对象存储，如S3或OSS，请谨慎使用此语法，因为对象存储的重命名不是原子性的，在失败的情况下可能只会移动部分文件。

## Adding New Columns

```sql
ALTER TABLE my_table ADD COLUMNS (
    c1 INT,
    c2 STRING
);
```

## Renaming Column Name

```sql
ALTER TABLE my_table RENAME COLUMN c0 TO c1;
```

## Dropping Columns 

```sql
ALTER TABLE my_table DROP COLUMNS (c1, c2);
```

## Dropping Partitions

```sql
ALTER TABLE my_table DROP PARTITION (`id` = 1, `name` = 'paimon');
```

## Changing Column Comment

```sql
ALTER TABLE my_table ALTER COLUMN buy_count COMMENT 'buy count';
```

## Adding Column Position 

```sql
ALTER TABLE my_table ADD COLUMN c INT FIRST;
ALTER TABLE my_table ADD COLUMN c INT AFTER b;
```

## Changing Column Position

```sql
ALTER TABLE my_table ALTER COLUMN col_a FIRST;

ALTER TABLE my_table ALTER COLUMN col_a AFTER col_b;
```

## Changing Column Type

```sql
ALTER TABLE my_table ALTER COLUMN col_a TYPE DOUBLE;
```

# Procedures

[Spark Paimon Procedures列表](https://paimon.apache.org/docs/master/spark/procedures/#procedures)