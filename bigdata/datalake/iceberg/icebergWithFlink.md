# 概述

* Iceberg 的官方定义是一种表格式，可以简单理解为是基于计算层（Flink , Spark）和存储层（ORC，Parqurt，Avro）的一个中间层，用 Flink 或者 Spark 将数据写入 Iceberg，然后再通过其他方式来读取这个表，比如 Spark，Flink，Presto 等。


# 集成Flink

## 创建Iceberg hive catalog
```sql
    CREATE CATALOG hive_catalog WITH (
      'type'='iceberg',
      'catalog-type'='hive',
      'uri'='thrift://localhost:9083',
      'clients'='5',
      'property-version'='1',
      'warehouse'='hdfs://nn:8020/warehouse/path'
    );
```
* type: `iceberg`(必填项)
* catalog-type: 当前支持`hive`和`hadoop`(必填项)
* uri: The Hive metastore’s thrift URI.(必填项) 
* clients: Hive metastore客户端池大小，默认值为2。(可选)
* property-version：描述属性版本的版本号。 如果属性格式发生更改，此属性可用于向后兼容。 当前属性版本为1。（可选）
* warehouse：Hive仓库的位置，如果既未设置`hive-conf-dir`来指定包含`hive-site.xml`配置文件的位置，又未向`类路径`添加正确的`hive-site.xml`，则用户应指定此路径。
* hive-conf-dir：包含`hive-site.xml`配置文件的目录的路径，该文件将用于提供自定义Hive配置值。 如果同时设置`hive-conf-dir`和`warehouse`，则`<hive-conf-dir> /hive-site.xml`中的`hive.metastore.warehouse.dir`的值（或来自classpath的hive配置文件）将被`warehouse`值覆盖。

## 创建Iceberg hadoop catalog
```sql
CREATE CATALOG hadoop_catalog WITH (
  'type'='iceberg',
  'catalog-type'='hadoop',
  'warehouse'='hdfs://nn:8020/warehouse/path',
  'property-version'='1'
);
```
* warehouse:用于存放元数据文件和数据文件的HDFS目录。(必需)

## 创建Database
```sql
CREATE DATABASE iceberg_db;
USE iceberg_db;
```

## 创建Table

```sql
CREATE TABLE hive_catalog.default.sample (
    id BIGINT COMMENT 'unique id',
    data STRING
);
```

* PARTITION BY (column1, column2, ...):创建分区表
* COMMENT 'table comment':表含义备注
* WITH('key'='value',...)设置表配置，[table configuration](https://iceberg.apache.org/configuration/)

## 基于已存在的表复制表结构

```sql
CREATE TABLE hive_catalog.default.sample (
    id BIGINT COMMENT 'unique id',
    data STRING
);

CREATE TABLE  hive_catalog.default.sample_like LIKE hive_catalog.default.sample;
```

## ALTER

### 修改表参数配置

```sql
ALTER TABLE hive_catalog.default.sample SET ('write.format.default'='avro')
```

### 重命名

```sql
ALTER TABLE hive_catalog.default.sample RENAME TO hive_catalog.default.new_sample;
```

### 删除表

```sql
DROP TABLE hive_catalog.default.sample;
```

