* 使用Spark数据源，我们将遍历允许您插入和更新默认表类型(Copy on Write)的Hudi表的代码片段。在每次写操作之后，我们还将展示如何以快照方式和增量方式读取数据。

# 快速开始

## Spark Shell

```shell
# Spark 3.3
spark-shell \
  --packages org.apache.hudi:hudi-spark3.3-bundle_2.12:0.12.1 \
  --conf 'spark.serializer=org.apache.spark.serializer.KryoSerializer' \
  --conf 'spark.sql.catalog.spark_catalog=org.apache.spark.sql.hudi.catalog.HoodieCatalog' \
  --conf 'spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension'
# Spark 3.2
spark-shell \
  --packages org.apache.hudi:hudi-spark3.2-bundle_2.12:0.12.1 \
  --conf 'spark.serializer=org.apache.spark.serializer.KryoSerializer' \
  --conf 'spark.sql.catalog.spark_catalog=org.apache.spark.sql.hudi.catalog.HoodieCatalog' \
  --conf 'spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension'
# Spark 3.1
spark-shell \
  --packages org.apache.hudi:hudi-spark3.1-bundle_2.12:0.12.1 \
  --conf 'spark.serializer=org.apache.spark.serializer.KryoSerializer' \
  --conf 'spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension'
# Spark 2.4
spark-shell \
  --packages org.apache.hudi:hudi-spark2.4-bundle_2.11:0.12.1 \
  --conf 'spark.serializer=org.apache.spark.serializer.KryoSerializer' \
  --conf 'spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension'
  
// spark-shell
import org.apache.hudi.QuickstartUtils._
import scala.collection.JavaConversions._
import org.apache.spark.sql.SaveMode._
import org.apache.hudi.DataSourceReadOptions._
import org.apache.hudi.DataSourceWriteOptions._
import org.apache.hudi.config.HoodieWriteConfig._
import org.apache.hudi.common.model.HoodieRecord

val tableName = "hudi_trips_cow"
val basePath = "file:///tmp/hudi_trips_cow"
val dataGen = new DataGenerator
val snapshotQuery = "SELECT begin_lat, begin_lon, driver, end_lat, end_lon, fare, partitionpath, rider, ts, uuid FROM hudi_ro_table"
```

## Spark Sql

```shell
# Spark 3.3
spark-sql --packages org.apache.hudi:hudi-spark3.3-bundle_2.12:0.12.1 \
--conf 'spark.serializer=org.apache.spark.serializer.KryoSerializer' \
--conf 'spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension' \
--conf 'spark.sql.catalog.spark_catalog=org.apache.spark.sql.hudi.catalog.HoodieCatalog'

# Spark 3.2
spark-sql --packages org.apache.hudi:hudi-spark3.2-bundle_2.12:0.12.1 \
--conf 'spark.serializer=org.apache.spark.serializer.KryoSerializer' \
--conf 'spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension' \
--conf 'spark.sql.catalog.spark_catalog=org.apache.spark.sql.hudi.catalog.HoodieCatalog'

# Spark 3.1
spark-sql --packages org.apache.hudi:hudi-spark3.1-bundle_2.12:0.12.1 \
--conf 'spark.serializer=org.apache.spark.serializer.KryoSerializer' \
--conf 'spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension'

# Spark 2.4
spark-sql --packages org.apache.hudi:hudi-spark2.4-bundle_2.11:0.12.1 \
--conf 'spark.serializer=org.apache.spark.serializer.KryoSerializer' \
--conf 'spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension'
```

# Create Table

* Spark-sql使用显式的创建表命令：
  * Table types：两种类型的hudi表(CopyOnWrite (COW)和MergeOnRead (MOR))都可以使用spark-sql创建。`type=cow`或`type=mor`
  * 分区表和非分区表:可以创建一个分区表或非分区表通过spark sql，创建分区表需要通过`partitioned by`语句指定分区键。
  * `Managed&External Table`：spark-sql支持2种类型的表，叫做管理表和外部表。如果指定`location`语句则是外部表，否则是管理表。
  * 主键：用户可以根据需要选择创建带有主键的表。通过`primaryKey`来指定表的主键。

## 创建非分区表

```sql
-- create a managed cow table
create table if not exists hudi_table0 (
  id int, 
  name string, 
  price double
) using hudi
options (
  type = 'cow',
  primaryKey = 'id'
);

-- create an external mor table 外部表
create table if not exists hudi_table1 (
  id int, 
  name string, 
  price double,
  ts bigint
) using hudi
location '/tmp/hudi/hudi_table1'  
options (
  type = 'mor',
  primaryKey = 'id,name',
  preCombineField = 'ts' 
);


-- create a non-primary key table
create table if not exists hudi_table2(
  id int, 
  name string, 
  price double
) using hudi
options (
  type = 'cow'
);
```

## 创建分区表

```sql
create table if not exists hudi_table_p0 (
id bigint,
name string,
dt string，
hh string  
) using hudi
location '/tmp/hudi/hudi_table_p0'
options (
  type = 'cow',
  primaryKey = 'id',
  preCombineField = 'ts'
 ) 
partitioned by (dt, hh);
```

## 创建已经存在的Hudi表

```sql
create table hudi_existing_tbl using hudi
location '/tmp/hudi/hudi_existing_table';
```

## CTAS

* 为了更高性能的加载数据到hudi表，CTAS使用的是`bulk insert`作为写操作

```sql
-- cow表，默认也为cow表
create table h2 using hudi
options (type = 'cow', primaryKey = 'id')
partitioned by (dt)
as
select 1 as id, 'a1' as name, 10 as price, 1000 as dt;

-- 加载其他表数据到hudi
# create managed parquet table 
create table parquet_mngd using parquet location 'file:///tmp/parquet_dataset/*.parquet';
# CTAS by loading data into hudi table
create table hudi_tbl using hudi location 'file:/tmp/hudi/hudi_tbl/' options ( 
  type = 'cow', 
  primaryKey = 'id', 
  preCombineField = 'ts' 
 ) 
partitioned by (datestr) as select * from parquet_mngd;
```

## 创建表参数

| Parameter Name  | Introduction             |
| --------------- | ------------------------ |
| primaryKey      | recordKey                |
| type            | 表类型，支持`cow`和`mor` |
| preCombineField | preCombine字段           |

# Insert data

## SQL

```sql
insert into h0 select 1, 'a1', 20;

-- insert static partition
insert into h_p0 partition(dt = '2021-01-02') select 1, 'a1';

-- insert dynamic partition
insert into h_p0 select 1, 'a1', dt;

-- insert dynamic partition
insert into h_p1 select 1 as id, 'a1', '2021-01-03' as dt, '19' as hh;

-- insert overwrite table
insert overwrite table h0 select 1, 'a1', 20;

-- insert overwrite table with static partition
insert overwrite h_p0 partition(dt = '2021-01-02') select 1, 'a1';

-- insert overwrite table with dynamic partition
  insert overwrite table h_p1 select 2 as id, 'a2', '2021-01-03' as dt, '19' as hh;
```

* `insert mode`:当使用主键将数据插入到表中时，Hudi支持两种插入模式(下面我们称之为pk-table):
  * 使用`strict`模式，insert语句对不允许重复记录的COW表保持主键唯一性约束。如果在insert过程中已经存在一个记录，则对COW表抛出HoodieDuplicateKeyException。对于MOR表，允许对现有记录进行更新。
  * 使用`non-strict`模式，Hudi使用与spark数据源中pk表的插入操作相同的代码路径。可以使用`config: hoodie.sql.insert.mode`设置插入模式
* `Bulk Insert`:默认情况下，hudi对插入语句使用普通的插入操作。用户可以将`hoodie.sql.bulk.insert.enable`设置为true，以启用insert语句的批量插入。同时`hoodie.sql.insert.mode`设置为`non-strict`

## Scala

```scala
// spark-shell
val inserts = convertToStringList(dataGen.generateInserts(10))
val df = spark.read.json(spark.sparkContext.parallelize(inserts, 2))
df.write.format("hudi").
  options(getQuickstartWriteConfigs).
  option(PRECOMBINE_FIELD_OPT_KEY, "ts").
  option(RECORDKEY_FIELD_OPT_KEY, "uuid").
  option(PARTITIONPATH_FIELD_OPT_KEY, "partitionpath").
  option(TABLE_NAME, tableName).
  mode(Overwrite).
  save(basePath)
  
// validations
assert(df.except(spark.sql(snapshotQuery)).count() == 0)
```

# Query Data

## Scala

```scala
    spark.read.format("hudi")
      // 指定对应快照数据
      .option("as.of.instant", "20210728141108")
      .load("file:///Users/xiamuguizhi/spark-warehouse/hudi_db.db/hudi_table0/80865189-e8a1-4eb6-be58-27f50aa15a8f-0_0-21-1605_20211024133529.parquet")
      .createOrReplaceTempView("hudi_test_table")
    spark.sql("select * from hudi_test_table").show()
```

## SQL

```sql
 select fare, begin_lon, begin_lat, ts from  hudi_trips_snapshot where fare > 20.0
```

# Time Travel Query

* 0.9.0版本之后支持该功能

## Scala

```scala
spark.read.
  format("hudi").
  option("as.of.instant", "20210728141108100").
  load(basePath)

spark.read.
  format("hudi").
  option("as.of.instant", "2021-07-28 14:11:08.200").
  load(basePath)

// It is equal to "as.of.instant = 2021-07-28 00:00:00"
spark.read.
  format("hudi").
  option("as.of.instant", "2021-07-28").
  load(basePath)
```

## SQL

* Spark需要3.2+版本

```sql
create table hudi_cow_pt_tbl (
  id bigint,
  name string,
  ts bigint,
  dt string,
  hh string
) using hudi
tblproperties (
  type = 'cow',
  primaryKey = 'id',
  preCombineField = 'ts'
 )
partitioned by (dt, hh)
location '/tmp/hudi/hudi_cow_pt_tbl';

insert into hudi_cow_pt_tbl select 1, 'a0', 1000, '2021-12-09', '10';
select * from hudi_cow_pt_tbl;

-- record id=1 changes `name`
insert into hudi_cow_pt_tbl select 1, 'a1', 1001, '2021-12-09', '10';
select * from hudi_cow_pt_tbl;

-- time travel based on first commit time, assume `20220307091628793`
select * from hudi_cow_pt_tbl timestamp as of '20220307091628793' where id = 1;
-- time travel based on different timestamp formats
select * from hudi_cow_pt_tbl timestamp as of '2022-03-07 09:16:28.100' where id = 1;
select * from hudi_cow_pt_tbl timestamp as of '2022-03-08' where id = 1;
```



# Update data

## MergeInto

```sql
MERGE INTO tableIdentifier AS target_alias
USING (sub_query | tableIdentifier) AS source_alias
ON <merge_condition>
[ WHEN MATCHED [ AND <condition> ] THEN <matched_action> ]
[ WHEN MATCHED [ AND <condition> ] THEN <matched_action> ]
[ WHEN NOT MATCHED [ AND <condition> ]  THEN <not_matched_action> ]

-- 核心语法
<merge_condition> =A equal bool condition 
<matched_action>  =
  DELETE  |
  UPDATE SET *  |
  UPDATE SET column1 = expression1 [, column2 = expression2 ...]
<not_matched_action>  =
  INSERT *  |
  INSERT (column1 [, column2 ...]) VALUES (value1 [, value2 ...])
```

* 案例

```sql
-- source table using hudi for testing merging into non-partitioned table
create table merge_source (id int, name string, price double, ts bigint) using hudi
tblproperties (primaryKey = 'id', preCombineField = 'ts');
insert into merge_source values (1, "old_a1", 22.22, 900), (2, "new_a2", 33.33, 2000), (3, "new_a3", 44.44, 2000);

merge into hudi_mor_tbl as target
using merge_source as source
on target.id = source.id
when matched then update set *
when not matched then insert *
;

-- source table using parquet for testing merging into partitioned table
create table merge_source2 (id int, name string, flag string, dt string, hh string) using parquet;
insert into merge_source2 values (1, "new_a1", 'update', '2021-12-09', '10'), (2, "new_a2", 'delete', '2021-12-09', '11'), (3, "new_a3", 'insert', '2021-12-09', '12');

merge into hudi_cow_pt_tbl as target
using (
  select id, name, '1000' as ts, flag, dt, hh from merge_source2
) source
on target.id = source.id
when matched and flag != 'delete' then
 update set id = source.id, name = source.name, ts = source.ts, dt = source.dt, hh = source.hh
when matched and flag = 'delete' then delete
when not matched then
 insert (id, name, ts, dt, hh) values(source.id, source.name, source.ts, source.dt, source.hh)
;

```

## Update

### Scala

```scala
// spark-shell
val snapBeforeUpdate = spark.sql(snapshotQuery)
val updates = convertToStringList(dataGen.generateUpdates(10))
val df = spark.read.json(spark.sparkContext.parallelize(updates, 2))
df.write.format("hudi").
  options(getQuickstartWriteConfigs).
  option(PRECOMBINE_FIELD_OPT_KEY, "ts").
  option(RECORDKEY_FIELD_OPT_KEY, "uuid").
  option(PARTITIONPATH_FIELD_OPT_KEY, "partitionpath").
  option(TABLE_NAME, tableName).
  mode(Append).
  save(basePath)
  
// validations
assert(spark.sql(snapshotQuery).intersect(df).count() == df.count())
assert(spark.sql(snapshotQuery).except(df).except(snapBeforeUpdate).count() == 0)
```

### SQL

* Syntax

```sql
 UPDATE tableIdentifier SET column = EXPRESSION(,column = EXPRESSION) [ WHERE boolExpression]
```

* 案例

```sql
update hudi_table0 set price=2*price where id=1;
```

**必须需要指定preCombineField**

# Incremental query

```scala
// spark-shell
// reload data
spark.
  read.
  format("hudi").
  load(basePath).
  createOrReplaceTempView("hudi_trips_snapshot")

val commits = spark.sql("select distinct(_hoodie_commit_time) as commitTime from  hudi_trips_snapshot order by commitTime").map(k => k.getString(0)).take(50)
val beginTime = commits(commits.length - 2) // commit time we are interested in

// incrementally query data
val tripsIncrementalDF = spark.read.format("hudi").
  option(QUERY_TYPE_OPT_KEY, QUERY_TYPE_INCREMENTAL_OPT_VAL).
  option(BEGIN_INSTANTTIME_OPT_KEY, beginTime).
  load(basePath)
tripsIncrementalDF.createOrReplaceTempView("hudi_trips_incremental")

spark.sql("select `_hoodie_commit_time`, fare, begin_lon, begin_lat, ts from  hudi_trips_incremental where fare > 20.0").show()
```

# 指定时间查询

* 具体的时间可以通过将endTime指向特定的提交时间，将beginTime指向“000”(表示可能最早的提交时间)来表示。

```scala
// spark-shell
val beginTime = "000" // Represents all commits > this time.
val endTime = commits(commits.length - 2) // commit time we are interested in

//incrementally query data
val tripsPointInTimeDF = spark.read.format("hudi").
  option(QUERY_TYPE.key(), QUERY_TYPE_INCREMENTAL_OPT_VAL).
  option(BEGIN_INSTANTTIME.key(), beginTime).
  option(END_INSTANTTIME.key(), endTime).
  load(basePath)
tripsPointInTimeDF.createOrReplaceTempView("hudi_trips_point_in_time")
spark.sql("select `_hoodie_commit_time`, fare, begin_lon, begin_lat, ts from hudi_trips_point_in_time where fare > 20.0").show()
```

# Delete Data

Apache Hudi支持两种类型的删除:

(1)**Soft Deletes**:保留记录键，只清除所有其他字段的值(软删除中为空的记录始终保存在存储中，而不会删除);

(2)**Hard Deletes**:从表中物理删除记录的任何痕迹。详细信息请参见写入数据页面的删除部分。

## Soft Deletes

```sql
// spark-shell
spark.
  read.
  format("hudi").
  load(basePath).
  createOrReplaceTempView("hudi_trips_snapshot")
// fetch total records count
spark.sql("select uuid, partitionpath from hudi_trips_snapshot").count()
spark.sql("select uuid, partitionpath from hudi_trips_snapshot where rider is not null").count()
// fetch two records for soft deletes
val softDeleteDs = spark.sql("select * from hudi_trips_snapshot").limit(2)

// prepare the soft deletes by ensuring the appropriate fields are nullified
val nullifyColumns = softDeleteDs.schema.fields.
  map(field => (field.name, field.dataType.typeName)).
  filter(pair => (!HoodieRecord.HOODIE_META_COLUMNS.contains(pair._1)
    && !Array("ts", "uuid", "partitionpath").contains(pair._1)))

val softDeleteDf = nullifyColumns.
  foldLeft(softDeleteDs.drop(HoodieRecord.HOODIE_META_COLUMNS: _*))(
    (ds, col) => ds.withColumn(col._1, lit(null).cast(col._2)))

// simply upsert the table after setting these fields to null
softDeleteDf.write.format("hudi").
  options(getQuickstartWriteConfigs).
  option(OPERATION_OPT_KEY, "upsert").
  option(PRECOMBINE_FIELD_OPT_KEY, "ts").
  option(RECORDKEY_FIELD_OPT_KEY, "uuid").
  option(PARTITIONPATH_FIELD_OPT_KEY, "partitionpath").
  option(TABLE_NAME, tableName).
  mode(Append).
  save(basePath)

// reload data
spark.
  read.
  format("hudi").
  load(basePath).
  createOrReplaceTempView("hudi_trips_snapshot")

// This should return the same total count as before
spark.sql("select uuid, partitionpath from hudi_trips_snapshot").count()
// This should return (total - 2) count as two records are updated with nulls
spark.sql("select uuid, partitionpath from hudi_trips_snapshot where rider is not null").count()
```

## **Hard Deletes**

### Scala

```scala
// spark-shell
val snapshotBeforeDelete = spark.sql(snapshotQuery)
// fetch total records count
spark.sql("select uuid, partitionpath from hudi_trips_snapshot").count()
// fetch two records to be deleted
val ds = spark.sql("select uuid, partitionpath from hudi_trips_snapshot").limit(2)

// issue deletes
val deletes = dataGen.generateDeletes(ds.collectAsList())
val hardDeleteDf = spark.read.json(spark.sparkContext.parallelize(deletes, 2))

hardDeleteDf.write.format("hudi").
  options(getQuickstartWriteConfigs).
  option(OPERATION_OPT_KEY, "delete").
  option(PRECOMBINE_FIELD_OPT_KEY, "ts").
  option(RECORDKEY_FIELD_OPT_KEY, "uuid").
  option(PARTITIONPATH_FIELD_OPT_KEY, "partitionpath").
  option(TABLE_NAME, tableName).
  mode(Append).
  save(basePath)

// run the same read query as above.
val roAfterDeleteViewDF = spark.
  read.
  format("hudi").
  load(basePath)

roAfterDeleteViewDF.registerTempTable("hudi_trips_snapshot")
// fetch should return (total - 2) records
spark.sql("select uuid, partitionpath from hudi_trips_snapshot").count()

// validations
assert(spark.sql("select uuid, partitionpath, ts from hudi_trips_snapshot").intersect(hardDeleteDf).count() == 0)
assert(snapshotBeforeDelete.except(spark.sql("select uuid, partitionpath, ts from hudi_trips_snapshot")).except(snapshotBeforeDelete).count() == 0)
```

### SQL

```sql
DELETE FROM tableIdentifier [ WHERE BOOL_EXPRESSION]
```

# AlterTable

```sql
-- Alter table name
ALTER TABLE oldTableName RENAME TO newTableName

-- Alter table add columns
ALTER TABLE tableIdentifier ADD COLUMNS(colAndType (,colAndType)*)

-- Alter table column type
ALTER TABLE tableIdentifier CHANGE COLUMN colName colName colType
-- alter table properties
alter table h3 set serdeproperties (hoodie.keep.max.commits = '10') 
```

# Partition SQL Command

```sql
-- Drop Partition
ALTER TABLE tableIdentifier DROP PARTITION ( partition_col_name = partition_col_val [ , ... ] )

-- Show Partitions
SHOW PARTITIONS tableIdentifier
```

# Procedures

```sql
--Call procedure by positional arguments
CALL system.procedure_name(arg_1, arg_2, ... arg_n)

--Call procedure by named arguments
CALL system.procedure_name(arg_name_2 => arg_2, arg_name_1 => arg_1, ... arg_name_n => arg_n)
```

# set命令

```sql
set hoodie.insert.shuffle.parallelism = 100;
set hoodie.upsert.shuffle.parallelism = 100;
set hoodie.delete.shuffle.parallelism = 100;
```

# table options

```sql
create table if not exists h3(
  id bigint, 
  name string, 
  price double
) using hudi
options (
  primaryKey = 'id',
  type = 'mor',
  ${hoodie.config.key1} = '${hoodie.config.value2}',
  ${hoodie.config.key2} = '${hoodie.config.value2}',
  ....
);

e.g.
create table if not exists h3(
  id bigint, 
  name string, 
  price double
) using hudi
options (
  primaryKey = 'id',
  type = 'mor',
  hoodie.cleaner.fileversions.retained = '20',
  hoodie.keep.max.commits = '20'
);
```
