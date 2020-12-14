# 概述

* 可以使用impala查询存储在Kudu上的表，该功能允许方便地访问存储系统，该存储系统针对不同类型的工作负载进行了调优，而不是使用impala默认设置
* Impala整合kudu可以使用DELETE、UPDATE、UPSERT和PRIMARY KEY，但是不支持LOAD DATA，TRUNCATE TABLE和INSERT OVERWRITE。

# 配置Impala整合Kudu

* impalad启动时使用`-kudu_master_hosts`配置属性(可以不配置)
* 创建表通过CREATE TABLE ... STORED AS KUDU语句，并且在tlbproperties设置`kudu.table_name`和`kudu.master_addresses`
* Kudu副本因子，默认使用impala创建kudu表使用的tablet的副本因子为3个可以在tblproperties中配置`kudu.num_table_replicas`属性
* DDL通过PRIMARY KEY(id)指定主键，通过NOT NULL指定列不为空

## 创表语法

```sql
CREATE TABLE table_name(
id bigint  PRIMARY KEY
          | [NOT] NULL
          | ENCODING codec
          |  COMPRESSION algorithm
          |  DEFAULT constant_expression
          |  BLOCK_SIZE number  
)PARTITION BY HASH(id) PARTITIONS 2 STORED AS KUDU;
```

### ENCODING属性

* AUTO_ENCODING:根据列的类型使用默认的编码格式，bitshuffle对于数值类型的列和dictionary对于string类型的列
* PLAN_ENCODING:将该值保留在其原始二进制文件中
* RLE:compress repeated values(when sorted in primary key order )by including a count
* DICT_ENCODING:当不同字符串值的数量较低时，用数字ID替换原始字符串
* BIT_SHUFFLE:重新排列值的位，以有效地压缩相同或仅根据主键顺序略有变化的值序列。生成的编码数据也用LZ4进行压缩。
* PREFIX_ENCODING:压缩string相同前缀的值，主要用于kudu内部

### COMPRESSION属性

* LZ4，SNAPPY和ZLIB

### BLOCAK_SIZE属性

* 尽管kudu不使用HDFS内部文件，不受到hdfs块大小的影响，它确实有一个基本的I/O单元，称为block size。

## Impala DML操作Kudu

* 使用`UPDATE`和`DELETE`语句能修改数据并且重写到kudu表，`UPSERT`语句作用于存在主键使用`UPDATE`不存在主键使用`INSERT`
* KUDU和Impala不支持事务，任何插入、更新或删除语句的效果都是立即可见的,不能执行一系列UPDATE语句，并且只能使更改立即可见
* impala2.10使用/*+NOCLUSTED*/和/*+NOSHUFFLE*/能够在命中操作是关闭分区和排序之后在发送数据到KUDU，排序也可能消耗巨大的内存，可以设置`MEM_LIMIT`查询参数对于这些查询。

## Kudu表的一致性

* kudu表具有一致性特征，如由主键列控制的唯一性和不可空的列。一致性的重点在于防止重复或不完整的数据存储在表中

## Impala查询Kudu性能

* 对于涉及到kudu表的查询，impala可以委托将结果集匹配到kudu的工作，避免了对包含HDFS数据文件的表进行全表扫描时所涉及的一些I/O.对于分区表这个优化的类型是特别高效的，当impala查询使用`WHERE`语句指定一个或多个主键列时并且他们是分区键。
* Impala2.11x之后，能够下推额外的信息去优化涉及join查询的kudu表。

# kudu表的分区

* kudu表使用特殊的机制在底层的tablet server之间分发数据.尽管我们指定我们将这样的表称为分区表，通过在create table语句中使用不同的子句，它们区别于传统的impala分区表。
* kudu在ddl中通过partition by HASH,RANGE指定相关的分区

## Hash分区

* 新插入的数据根据指定的hash键将数据并行的分发到多个tablet severs的tablest上，分割散列值会给查询带来额外的开销，其中使用基于范围谓词的查询可能必须读取tablet server以检索所有相关值。

```sql
crate table table_name(id bigint primary key)partition by hash(id) partitions 50 stored as kudu
```

* 对于大型表，分区个数最好是tablet server的10倍。

## Range分区

* range分区必须在数据在这张表之前创建.

```sql
# hash配合range使用
create table table_name(id bigint primary key)partition by hash(id)partitions 50,
range(partition 1 <= values<20,partition 20<=values<30,partition value=50)stored as kudu
  
# 非连续的range分区
  partition by range(year) (partiiton 2006<=values<= 2019,partition 2024<=values<=2050)
  
# 修改分区
alter table test add partition 30<values< 50;
alter table test drop partition 1<=values<5;
```

# 日期类型

* Impala2.9x之后可以在kudu表中使用`TIMESTAMP`去替代`date`和`BIGINT`
* 使用`unix_timestamp(now())`获取时间戳

# Impala处理Kudu metadata

* 默认情况下，kudu表的大部分元数据由底层存储层处理。kudu表对metastore数据库的依赖更少，并且对impala端的元数据缓存要求更少。
* impala可以添加或者删除kudu表的列

# 加载数据到Kudu表

* Kudu表不支持`Load Data`操作，能够做到`INSERT`,`UPDATE`和`UPSERT`操作是幂等，能够执行多次提供相同的值
* 不能够使用事务语义在多个表操作，因为不能够强制保证Impala和Kudu表一致

