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