# 快速开始
## Spark3使用Iceberg
[spark-iceberg](https://iceberg.apache.org/releases/)
```shell
spark-shell --packages org.apache.iceberg:iceberg-spark3-runtime:0.11.1
```
### 添加catalogs
* iceberg附带了catalog，使SQL命令能够管理表并按名称加载表。使用spark.sql.catalog下的属性配置catalog。

```shell
spark-sql --packages org.apache.iceberg:iceberg-spark3-runtime:0.11.1\
    --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
    --conf spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog \
    --conf spark.sql.catalog.spark_catalog.type=hive \
    --conf spark.sql.catalog.local=org.apache.iceberg.spark.SparkCatalog \
    --conf spark.sql.catalog.local.type=hadoop \
    --conf spark.sql.catalog.local.warehouse=/user/hive/warehouse
```

### 创建表

```sql
create table test(id bigint,name string) using iceberg
```

### 写数据

#### INSERT
```sql
INSERT INTO test values(1,'hsm');
INSERT INTO test select id ,name from test1 where id=1;
```

* spark iceberg支持行级别的更新通过MERGE INTO和DELETE FROM

```sql
-- 如果匹配上了则相加，匹配不上则插入
MERGE INTO test t USING(select * from updates) u ON t.id=u.id
WHEN MATCHED THEN UPDATE SET t.count=t.count+u.count
WHEN NOT MATCHED THEN INSERT *
```

* iceberg支持通过df写入iceberg

```scala
spark.table("source").select("id", "data")
     .writeTo("local.db.table").append()
```

### 读取数据

```sql
select count(id) as count ,name from test 
group by name;
```

* 读取表快照

```sql
SELECT * FROM test.snapshots
```

# Spark配置
## Catalogs

*  创建catalog通过`spark.sql.catalog.(catalog-name)`来设置
* iceberg支持俩种实现
  * `org.apache.iceberg.spark.SparkCatalog`支持Hive Metastore或hadoop warehouse作为catalog
  * `org.apache.iceberg.spark.SparkSessionCatalog`支持spark构造的catalog

| Property                                           | Values                        | Description                                                  |
| :------------------------------------------------- | :---------------------------- | :----------------------------------------------------------- |
| spark.sql.catalog.*catalog-name*.type              | `hive` or `hadoop`            | The underlying Iceberg catalog implementation, `HiveCatalog` or `HadoopCatalog` |
| spark.sql.catalog.*catalog-name*.catalog-impl      |                               | The underlying Iceberg catalog implementation. When set, the value of `type` property is ignored |
| spark.sql.catalog.*catalog-name*.default-namespace | default                       | The default current namespace for the catalog                |
| spark.sql.catalog.*catalog-name*.uri               | thrift://host:port            | Metastore connect URI; default from `hive-site.xml`          |
| spark.sql.catalog.*catalog-name*.warehouse         | hdfs://nn:8020/warehouse/path | Base path for the warehouse directory                        |
| spark.sql.catalog.*catalog-name*.cache-enabled     | `true` or `false`             | Whether to enable catalog cache, default value is `true`     |

* 使用hive catalog
```shell
spark-sql --packages org.apache.iceberg:iceberg-spark3-runtime:0.11.1\
    --conf spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkCatalog \
    --conf spark.sql.catalog.spark_catalog.type=hive \
    --conf spark.sql.catalog.spark_catalog.uri=thrift://hadoop:9083 \
    --conf spark.sql.catalog.spark_catalog.cache-enabled=true
```

### 使用catalog
```sql
USE hive_prod.db;
select * from table;
```

## SQL扩展

* iceberg0.11.0或者更新的版本添加一个spark扩展模块可以添加新的sql命令，比如调用存储过程或ALTER TABLE ... WRITE ORDERED BY.

| Spark extensions property | Iceberg extensions implementation                            |
| :------------------------ | :----------------------------------------------------------- |
| `spark.sql.extensions`    | `org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions` |

## 运行配置
### 读参数
* spark通过配置DataFrameReader读取iceberg
```scala
// time travel
spark.read
    .option("snapshot-id", 10963874102873L)
    .table("catalog.db.table")
```

| Spark option          | Default               | Description                                                  |
| :-------------------- | :-------------------- | :----------------------------------------------------------- |
| snapshot-id           | (latest)              | 读取特定的snapshot-id                                        |
| as-of-timestamp       | (latest)              | 以毫秒为单位的时间戳;所使用的快照将是当前的快照。            |
| split-size            | As per table property | Overrides this table’s read.split.target-size and read.split.metadata-target-size |
| lookback              | As per table property | Overrides this table’s read.split.planning-lookback          |
| file-open-cost        | As per table property | Overrides this table’s read.split.open-file-cost             |
| vectorization-enabled | As per table property | Overrides this table’s read.parquet.vectorization.enabled    |
| batch-size            | As per table property | Overrides this table’s read.parquet.vectorization.batch-size |

### 写参数

```scala
// write with Avro instead of Parquet
df.write
    .option("write-format", "avro")
    .option("snapshot-property.key", "value")
    .insertInto("catalog.db.table")
```

| Spark option                   | Default                    | Description                                                  |
| :----------------------------- | :------------------------- | :----------------------------------------------------------- |
| write-format                   | Table write.format.default | File format to use for this write operation; parquet, avro, or orc |
| target-file-size-bytes         | As per table property      | Overrides this table’s write.target-file-size-bytes          |
| check-nullability              | true                       | Sets the nullable check on fields                            |
| snapshot-property.*custom-key* | null                       | Adds an entry with custom-key and corresponding value in the snapshot summary |
| fanout-enabled                 | false                      | Overrides this table’s write.spark.fanout.enabled            |
| check-ordering                 | true                       | Checks if input schema and table schema are same             |

# Spark DDL

* Iceberg使用Apache Spark的DataSourceV2 API来实现数据源和catalog。Spark DSv2是一个不断发展的API，在Spark版本中有不同级别的支持。Spark 2.4不支持SQL DDL。

## 创建表
```sql
CREATE TABLE prod.db.sample (
    id bigint COMMENT 'unique id',
    data string)
USING iceberg
```
* PARTITION BY(partition-expressions):配置分区
* LOCATION '(全路径存储地址)':配置表存储路径
* COMMENT '表描述'
* TBLPROPERTIES ('key'='value', ...):表配置[表配置](https://iceberg.apache.org/configuration/)

### PARTITIONED BY
* 使用category分区
```sql
CREATE TABLE prod.db.sample (
    id bigint,
    data string,
    category string)
USING iceberg
PARTITIONED BY (category)
```

* 使用隐藏分区
```sql
CREATE TABLE prod.db.sample (
    id bigint,
    data string,
    category string,
    ts timestamp)
USING iceberg
PARTITIONED BY (bucket(16, id), days(ts), category)
```
* 支持的转换函数有:
  * years(ts)
  * months(ts)
  * days(ts)/date(ts): 相当于yyyyMMdd
  * hours(ts)/date_hour(ts):相当于yyyyMMdd HH分区
  * bucket(N,col):根据col的hash值分成n个bucket
  * truncate(L,col): 用L截断的值划分
    * String会按照给定长度截断
    * int和long类型类似与truncate(10,i)会分为0，10，20，30，...分区
## CREATE TABLE ... AS SELECT

* iceberg支持CTAS，SparkCatalog支持，SparkSessionCatalog不支持
```sql
CREATE TABLE prod.db.sample
USING iceberg
AS SELECT ...
```

## REPLACE TABLE ... AS SELECT
* iceberg支持RTAS，SparkCatalog支持，SparkSessionCatalog不支持
```sql
REPLACE TABLE prod.db.sample
USING iceberg
AS SELECT ...
```
```sql
CREATE OR REPLACE TABLE prod.db.sample
USING iceberg
AS SELECT ...
```

## ALTER TABLE
* ALTER TABLE支持在spark 3，包含
  * 重命名表
  * 设置或移除表属性
  * 添加、删除和改名列
  * 添加删除和改名嵌套字段
  * 重新排序顶级列和嵌套的结构字段
  * 扩大int、float和decimal字段的类型
  * 标记必须列为非必须
### ALTER TABLE ... RENAME TO
```sql
ALTER TABLE prod.db.sample RENAME TO prod.db.new_name
```

### ALTER TABLE ... SET TBLPROPERTIES
* 添加配置
```sql
ALTER TABLE prod.db.sample SET TBLPROPERTIES (
    'read.split.target-size'='268435456'
)
```
* 移除配置
```sql
ALTER TABLE prod.db.sample UNSET TBLPROPERTIES ('read.split.target-size')
```

### ALTER TABLE ... ADD COLUMN
* 添加列
```sql
ALTER TABLE prod.db.sample
ADD COLUMNS (
    new_column string comment 'new_column docs'
  )
```

* 添加嵌套结构
```sql
-- create a struct column
ALTER TABLE prod.db.sample
ADD COLUMN point struct<x: double, y: double>;

-- add a field to the struct
ALTER TABLE prod.db.sample
ADD COLUMN point.z double
```

* Spark2.4之后可以使用FIRST和AFTER
```sql
ALTER TABLE prod.db.sample
ADD COLUMN new_column bigint AFTER other_column

ALTER TABLE prod.db.sample
  ADD COLUMN nested.new_column bigint FIRST
```

### ALTER TABLE ... RENAME COLUMN
```sql
ALTER TABLE prod.db.sample RENAME COLUMN data TO payload
ALTER TABLE prod.db.sample RENAME COLUMN location.lat TO latitude
```

### ALTER TABLE ... ALTER COLUMN
* 修改列的类型
```sql
ALTER TABLE prod.db.sample ALTER COLUMN measurement TYPE double
```
* 修改列的类型和描述
```sql
ALTER TABLE prod.db.sample ALTER COLUMN measurement TYPE double COMMENT 'unit is bytes per second'
ALTER TABLE prod.db.sample ALTER COLUMN measurement COMMENT 'unit is kilobytes per second'
```

* 使用First和After
```sql
ALTER TABLE prod.db.sample ALTER COLUMN col FIRST
ALTER TABLE prod.db.sample ALTER COLUMN nested.col AFTER other_col
```

* 设置Not NULL和删除NOT Null
```sql
ALTER TABLE prod.db.sample ALTER COLUMN id DROP NOT NULL
```

### ALTER TABLE ... DROP COLUMN
```sql
ALTER TABLE prod.db.sample DROP COLUMN id
ALTER TABLE prod.db.sample DROP COLUMN point.z
```

## ALTER TABLE SQL extensions
* spark 3.x使用[sql-extensions](https://iceberg.apache.org/spark-configuration/#sql-extensions)

### ALTER TABLE ... ADD PARTITION FIELD¶
* 添加新的分区字段
```sql
ALTER TABLE prod.db.sample ADD PARTITION FIELD catalog -- identity transform
```
* 分区转换也支持
```sql
ALTER TABLE prod.db.sample ADD PARTITION FIELD bucket(16, id)
ALTER TABLE prod.db.sample ADD PARTITION FIELD truncate(data, 4)
ALTER TABLE prod.db.sample ADD PARTITION FIELD years(ts)
-- use optional AS keyword to specify a custom name for the partition field 
ALTER TABLE prod.db.sample ADD PARTITION FIELD bucket(16, id) AS shard
```
* 添加分区字段是一个元数据操作不能改变已经存在的表数据，新的数据将会被写入到新的分区但是存在的数据将会被保留在老的分区里。
* 当标的分区发生变化时动态分区覆盖行为将会改变，因为动态分区覆盖替换了分区。

### ALTER TABLE ... DROP PARTITION FIELD
* 删除存在的分区字段
```sql
ALTER TABLE prod.db.sample DROP PARTITION FIELD catalog
ALTER TABLE prod.db.sample DROP PARTITION FIELD bucket(16, id)
ALTER TABLE prod.db.sample DROP PARTITION FIELD truncate(data, 4)
ALTER TABLE prod.db.sample DROP PARTITION FIELD years(ts)
ALTER TABLE prod.db.sample DROP PARTITION FIELD shard
```
* 删除分区是个元数据操作不会改变已经存在的数据，新插入的数据将会写入新分区，但是存在的数据将会保留在老的分区布局里。

### ALTER TABLE ... WRITE ORDERED BY
* iceberg表能够配置排序的方式使用动态的排序数据写入到表里在一些引擎里，例如MERGE INTO在Spark里将会使用表排序

```sql
ALTER TABLE prod.db.sample WRITE ORDERED BY category, id
-- use optional ASC/DEC keyword to specify sort order of each field (default ASC)
ALTER TABLE prod.db.sample WRITE ORDERED BY category ASC, id DESC
-- use optional NULLS FIRST/NULLS LAST keyword to specify null order of each field (default FIRST)
ALTER TABLE prod.db.sample WRITE ORDERED BY category ASC NULLS LAST, id DESC NULLS FIRST
```

# Spark Queries

* Iceberg使用Spark DataSourceV2 API去操作数据

| Feature support                                              | Spark 3.0 | Spark 2.4 | Notes |
| :----------------------------------------------------------- | :-------- | :-------- | :---- |
| [`SELECT`](https://iceberg.apache.org/spark-queries/#querying-with-sql) | ✔️         |           |       |
| [DataFrame reads](https://iceberg.apache.org/spark-queries/#querying-with-dataframes) | ✔️         | ✔️         |       |
| [Metadata table `SELECT`](https://iceberg.apache.org/spark-queries/#inspecting-tables) | ✔️         |           |       |
| [History metadata table](https://iceberg.apache.org/spark-queries/#history) | ✔️         | ✔️         |       |
| [Snapshots metadata table](https://iceberg.apache.org/spark-queries/#snapshots) | ✔️         | ✔️         |       |
| [Files metadata table](https://iceberg.apache.org/spark-queries/#files) | ✔️         | ✔️         |       |
| [Manifests metadata table](https://iceberg.apache.org/spark-queries/#manifests) | ✔️         | ✔️         |       |

## 通过SQL查询

```sql
SELECT * FROM prod.db.table -- catalog: prod, namespace: db, table: table
```
* 源数据表类似于`history`和`snapshots`，可以使用iceberg表作为一个namespace
```sql
SELECT * FROM prod.db.table.files
```
## Querying with DataFrames

```scala
  val frame: DataFrame = spark.table("spark_catalog.iceberg_db.test")
    frame.show()
```

### Read Metadata Table
```sql
    spark.read.format("iceberg")
      .load("iceberg_db.test.files")
      // 不截断字符串
      .show(truncate = false)

    spark.read.format("iceberg")
      .load("iceberg_db.test.history")
      // 不截断字符串
      .show(truncate = false)
    spark.read.format("iceberg")
      .load("iceberg_db.test.snapshots")
      // 不截断字符串
      .show(truncate = false)
```

### Time travel

* `snapshot-id`选择指定表的快照
* `as-of-timestamp` 选择当前快照为一个时间戳，单位毫秒

```scala
// time travel to October 26, 1986 at 01:21:00
spark.read
    .option("as-of-timestamp", "499162860000")
    .format("iceberg")
    .load("path/to/table")

// time travel to snapshot with ID 10963874102873L
spark.read
        .option("snapshot-id",8745438249199332230L)
        .format("iceberg")
        .load("iceberg_db.test")
        .show(20)
```

# Spark写Iceberg

* spark使用iceberg配置spark catalogs

| Feature support                                              | Spark 3.0 | Spark 2.4 | Notes                                        |
| :----------------------------------------------------------- | :-------- | :-------- | :------------------------------------------- |
| [SQL insert into](https://iceberg.apache.org/spark-writes/#insert-into) | ✔️         |           |                                              |
| [SQL merge into](https://iceberg.apache.org/spark-writes/#merge-into) | ✔️         |           | ⚠ Requires Iceberg Spark extensions          |
| [SQL insert overwrite](https://iceberg.apache.org/spark-writes/#insert-overwrite) | ✔️         |           |                                              |
| [SQL delete from](https://iceberg.apache.org/spark-writes/#delete-from) | ✔️         |           | ⚠ Row-level delete requires Spark extensions |
| [DataFrame append](https://iceberg.apache.org/spark-writes/#appending-data) | ✔️         | ✔️         |                                              |
| [DataFrame overwrite](https://iceberg.apache.org/spark-writes/#overwriting-data) | ✔️         | ✔️         | ⚠ Behavior changed in Spark 3.0              |
| [DataFrame CTAS and RTAS](https://iceberg.apache.org/spark-writes/#creating-tables) | ✔️         |           |                                              |

## 通过SQL

* Spark 3支持SQL INSERT INTO，MERGE INTO和INSERT OVERWRITE

### `INSERT INTO`

```sql
INSERT INTO prod.db.table VALUES (1, 'a'), (2, 'b')
INSERT INTO prod.db.table SELECT ...
```

### `MERGE INTO`

* Spark 3添加支持MERGE INTO能够支持行级别修改

```sql
MERGE INTO prod.db.target t   -- a target table
USING (SELECT ...) s          -- the source updates
ON t.id = s.id                -- condition to find updates for target rows
WHEN ...                      -- updates



WHEN MATCHED AND s.op = 'delete' THEN DELETE
WHEN MATCHED AND t.count IS NULL AND s.op = 'increment' THEN UPDATE SET t.count = 0
WHEN MATCHED AND s.op = 'increment' THEN UPDATE SET t.count = t.count + 1
```

### `INSERT OVERWRITE`

* 动态分区方式overwrite

```sql
INSERT OVERWRITE prod.my_app.logs
SELECT uuid, first(level), first(ts), first(message)
FROM prod.my_app.logs
WHERE cast(ts as date) = '2020-07-01'
GROUP BY uuid
```

* 静态分区写入

```sql
INSERT OVERWRITE prod.my_app.logs
PARTITION (level = 'INFO')
SELECT uuid, first(level), first(ts), first(message)
FROM prod.my_app.logs
WHERE level = 'INFO'
GROUP BY uuid
```

### `DELETE FROM`

```sql
DELETE FROM prod.db.table
WHERE ts >= '2020-05-01 00:00:00' and ts < '2020-06-01 00:00:00'
```

## DataFrame

### Appending data

* spark 3.x

```scala
val data: DataFrame = ...
data.writeTo("prod.db.table").append()
```

* spark 2.4

```scala
data.write
    .format("iceberg")
    .mode("append")
    .save("db.table")
```

### Overwriting data

* spark 3.x

```scala
val data: DataFrame = ...
data.writeTo("prod.db.table").overwritePartitions()

data.writeTo("prod.db.table").overwrite($"level" === "INFO")
```

* spark 2.4

```scala
data.write
    .format("iceberg")
    .mode("overwrite")
    .save("db.table")
```

### Creating tables

```scala
val data: DataFrame = ...
data.writeTo("prod.db.table").create()

# 制定表参数
data.writeTo("prod.db.table")
    .tableProperty("write.format.default", "orc")
    .partitionBy($"level", days($"ts"))
    .createOrReplace()
```

