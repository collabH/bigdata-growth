# 概述
* iceberg支持通过读取和写iceberg使用StorageHandler

| CREATE EXTERNAL TABLE | ✔️                     | ✔️                     |
| --------------------- | --------------------- | --------------------- |
| CREATE TABLE          | ✔️                     | ✔️                     |
| DROP TABLE            | ✔️                     | ✔️                     |
| SELECT                | ✔️ (MapReduce and Tez) | ✔️ (MapReduce and Tez) |
| INSERT INTO           | ✔️ (MapReduce only)️    | ✔️ (MapReduce only)    |

# icberg整合hive

## 加载runtime jar

* 在hive开启支持iceberg，需要`HiveIcebergStorageHandler`和支持类需要在Hive的类路径上可用。将`iceberg-hive-runtime`文件放到hive的classpath下`

```shell
# 一次性
add jar /path/to/iceberg-hive-runtime.jar;
# 直接放入hive home/lib下
```

## Hadoop配置

* 为应用全局启用Hive支持，hive-site.xml配置` iceberg.engine.hive.enabled=true`
* 如果在0.11.x版本开启Tez需要设置`hive.vectorized.execution.enabled=false`

# Catalog管理

## 全局hive catalog

* 从Hive引擎的角度来看，在运行时环境下的Hadoop配置中只有一个全局数据目录。相反，Iceberg支持多种不同的数据目录类型，如Hive、Hadoop、AWS Glue或自定义目录实现。iceberg还允许根据表在文件系统中的路径直接加载表。那些表不属于任何目录。用户可能希望通过Hive引擎读取这些跨目录和基于路径的表，以用于像join这样的用例。
* hive元数据可以用不同方式加载iceberg表
  * 如果没有`iceberg.catalog`配置表将会通过HiveCatalog加载
  * 如果`iceberg.catalog`设置了catalog名称，这个表将会被自定义catalog加载
  * 如果`iceberg.catalog`被设置为location_based_table，表将会直接使用表根路径加载。

## 自定义Icberg catalogs

| Config Key                                  | Description                                              |
| :------------------------------------------ | :------------------------------------------------------- |
| iceberg.catalog.<catalog_name>.type         | type of catalog: `hive` or `hadoop`                      |
| iceberg.catalog.<catalog_name>.catalog-impl | catalog implementation, must not be null if type is null |
| iceberg.catalog.<catalog_name>.<key>        | any config key and value pairs for the catalog           |

* 注册HiveCatalog

```properties
SET iceberg.catalog.another_hive.type=hive;
SET iceberg.catalog.another_hive.uri=thrift://hadoop:9083;
SET iceberg.catalog.another_hive.clients=10;
SET iceberg.catalog.another_hive.warehouse=hdfs://hadoop:8020/user/hive/warehous;
```

* 注册HadoopCatalog

```properties
SET iceberg.catalog.hadoop.type=hadoop;
iceberg.catalog.another_hive.warehouse=hdfs://hadoop:8020/user/hive/warehous;
```

* 注册AWS GlueCatalog

```properties
SET iceberg.catalog.glue.catalog-impl=org.apache.iceberg.aws.GlueCatalog;
SET iceberg.catalog.glue.warehouse=s3://my-bucket/my/key/prefix;
SET iceberg.catalog.glue.lock-impl=org.apache.iceberg.aws.glue.DynamoLockManager;
SET iceberg.catalog.glue.lock.table=myGlueLockTable;
```

# DDL命令

## CREATE EXTERNAL TABLE

* 在hive上创建iceberg外部表

### hive catalog表

* 如前所述，通过启用Hive引擎特性的HiveCatalog创建的表可以直接被Hive引擎看到，所以不需要创建覆盖。

### 自定义catalog表

```sql
-- 配置catalog
SET iceberg.catalog.hadoop_cat.type=hadoop;
SET iceberg.catalog.hadoop_cat.warehouse=hdfs://example.com:8020/hadoop_cat;

-- 指定表catalog
CREATE EXTERNAL TABLE database_a.table_a
STORED BY 'org.apache.iceberg.mr.hive.HiveIcebergStorageHandler'
TBLPROPERTIES ('iceberg.catalog'='hadoop_cat');
```

### 加载HDFS上的表

```sql
CREATE EXTERNAL TABLE table_a 
STORED BY 'org.apache.iceberg.mr.hive.HiveIcebergStorageHandler' 
LOCATION 'hdfs://some_bucket/some_path/table_a'
TBLPROPERTIES ('iceberg.catalog'='location_based_table');
```

## CREATE TABLE

* hive支持直接创建一个新的iceberg表通过create table

```sql
CREATE TABLE iceberg_db.table_a (
  id bigint, name string
) PARTITIONED BY (
  dept string
) STORED BY 'org.apache.iceberg.mr.hive.HiveIcebergStorageHandler'
location 'hdfs://hadoop:8020/user/hive/warehous/iceberg_db.db/table_a'
```

### Custom catalog table

* 如果表已经存在在自定义的catalog中将会覆盖掉。

```sql
SET iceberg.catalog.hadoop_cat.type=hadoop;
SET iceberg.catalog.hadoop_cat.warehouse=hdfs://example.com:8020/hadoop_cat;

CREATE TABLE database_a.table_a (
  id bigint, name string
) PARTITIONED BY (
  dept string
) STORED BY 'org.apache.iceberg.mr.hive.HiveIcebergStorageHandler'
TBLPROPERTIES ('iceberg.catalog'='hadoop_cat');
```

## DROP TABLE

```sql
DROP TABLE [IF EXISTS] table_name [PURGE];
```

| Config key           | Default | Description                                  |
| :------------------- | :------ | :------------------------------------------- |
| external.table.purge | true    | 如果默认情况下应该清除表中的所有数据和元数据 |
| gc.enabled           | true    | 如果默认情况下应该清除表中的所有数据和元数据 |

# 查询SQL

* Predicate pushdown：下推hive sql的where子句，在iceberg tableScan被实现。
* Column projection:Hive SQL SELECT子句中的列被投影到Iceberg读取器中，以减少读取的列数。
* Hive query engines:同时支持MapReduce和Tez查询执行引擎。

## 配置

| Config key                  | Default | Description                 |
| :-------------------------- | :------ | :-------------------------- |
| iceberg.mr.reuse.containers | false   | Avro reader是否应该重用容器 |
| iceberg.mr.case.sensitive   | true    | 如果查询区分大小写          |

# SQL写

## 配置

| Config key                               | Default | Description                                              |
| :--------------------------------------- | :------ | :------------------------------------------------------- |
| iceberg.mr.commit.table.thread.pool.size | 10      | 共享线程池中用于对输出表执行并行提交的线程数             |
| iceberg.mr.commit.file.thread.pool.size  | 10      | 共享线程池中用于对每个输出表中的文件执行并行提交的线程数 |

## INSERT INTO

```sql
INSERT INTO table_a VALUES ('a', 1);
INSERT INTO table_a SELECT ...;
-- 多条insert
FROM customers
    INSERT INTO target1 SELECT customer_id, first_name
    INSERT INTO target2 SELECT last_name, customer_id;
```

# 类型兼容性

* Hive和Iceberg支持不同类型的集合。iceberg可以自动执行类型转换，但不是针对所有组合，因此在设计表中的列类型之前，您可能希望了解iceberg中的类型转换。您可以通过Hadoop配置启用自动转换(默认不启用)

| Config key                        | Default | Description                  |
| :-------------------------------- | :------ | :--------------------------- |
| iceberg.mr.schema.auto.conversion | false   | 如果Hive应该执行类型自动转换 |

## Hive对应iceberg类型

| Hive                | Iceberg                    | Notes           |
| :------------------ | :------------------------- | :-------------- |
| boolean             | boolean                    |                 |
| short               | integer                    | auto-conversion |
| byte                | integer                    | auto-conversion |
| integer             | integer                    |                 |
| long                | long                       |                 |
| float               | float                      |                 |
| double              | double                     |                 |
| date                | date                       |                 |
| timestamp           | timestamp without timezone |                 |
| timestamplocaltz    | timestamp with timezone    | Hive 3 only     |
| interval_year_month |                            | not supported   |
| interval_day_time   |                            | not supported   |
| char                | string                     | auto-conversion |
| varchar             | string                     | auto-conversion |
| string              | string                     |                 |
| binary              | binary                     |                 |
| decimal             | decimal                    |                 |
| struct              | struct                     |                 |
| list                | list                       |                 |
| map                 | map                        |                 |
| union               |                            | not supported   |
