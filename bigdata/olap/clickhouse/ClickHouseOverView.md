 # 概述

* ClickHouse是俄罗斯的Yandex于2016年开源的列式存储数据库(DBMS),主要用于在线分析处理查询(OLAP),能够使用sQL查询实时生成分析数据报告。

## 特点

* 真正的列式数据库管理系统，除了数据本身外不应该有其他额外的数据，这意味着为了避免在值旁边存储它们的长度«number»，你必须支持固定长度数值类型。ClickHouse不单单是一个数据库， 它是一个数据库管理系统。因为它允许在运行时创建表和数据库、加载数据和运行查询，而无需重新配置或重启服务。

### 数据压缩

* 在一些列式数据库管理系统中并没有使用数据压缩。但是, 若想达到比较优异的性能，数据压缩确实起到了至关重要的作用。

### 数据的磁盘存储

* 许多的列式数据库只能在内存中工作，这种方式会造成比实际更多的设备预算。ClickHouse被设计用于工作在传统磁盘上的系统，它提供每GB更低的存储成本，但如果有可以使用SSD和内存，它也会合理的利用这些资源。

### 多核心并行处理

* ClickHouse会使用服务器上一切可用的资源，从而以最自然的方式并行处理大型查询。

### 多服务器分布式处理

* 在ClickHouse中，数据可以保存在不同的shard上，每一个shard都由一组用于容错的replica组成，查询可以并行地在所有shard上进行处理。这些对用户来说是透明的。

### 支持SQL

* ClickHouse支持基于SQL的声明式查询语言，该语言大部分情况下是与SQL标准兼容的。支持的查询包括 GROUP BY，ORDER BY，IN，JOIN以及非相关子查询。不支持窗口函数和相关子查询。

### 向量引擎

* 为了高效的使用CPU，数据不仅仅按列存储，同时还按向量(列的一部分)进行处理，这样可以更加高效地使用CPU。

### 实时的数据更新

* ClickHouse支持在表中定义主键。为了使查询能够快速在主键中进行范围查找，数据总是以增量的方式有序的存储在MergeTree中。因此，数据可以持续不断地高效的写入到表中，并且写入的过程中不会存在任何加锁的行为。

### 索引

* 按照主键对数据进行排序，这将帮助ClickHouse在几十毫秒以内完成对数据特定值或范围的查找。

### 适合在线查询

### 支持近似计算

ClickHouse提供各种各样在允许牺牲数据精度的情况下对查询进行加速的方法：

1. 用于近似计算的各类聚合函数，如：distinct values, medians, quantiles
2. 基于数据的部分样本进行近似查询。这时，仅会从磁盘检索少部分比例的数据。
3. 不使用全部的聚合条件，通过随机选择有限个数据聚合条件进行聚合。这在数据聚合条件满足某些分布条件下，在提供相当准确的聚合结果的同时降低了计算资源的使用。

### 支持数据复制和数据完整性

* ClickHouse使用异步的多主复制技术。当数据被写入任何一个可用副本后，系统会在后台将数据分发给其他副本，以保证系统在不同副本上保持相同的数据。在大多数情况下ClickHouse能在故障后自动恢复，在一些少数的复杂情况下需要手动恢复。

### 限制

* 没有完整的事务支持
* 缺少高频率，低延迟的修改或删除已存在数据的能力。仅能用于批量删除或修改数据。
* 稀疏索引使得ClickHouse不适合通过其键检索单行的点查询。

## 安装

### 修改CentOS打开文件数限制

```shell
vim /etc/security/limits.conf
对应框架/
* soft nofile 65536
* hard nofile 65536
* soft nproc 131072
* hard nproc 131072

vim security/limits.d/90-nproc.conf
* soft nofile 65536
* hard nofile 65536
* soft nproc 131072
* hard nproc 131072
```

### 取消CentOsSELINUX

```shell
vim /etc/selinux/config
SELINUX=disabled
```

### 安装clickhouse-client

```shell
sudo yum install yum-utils
sudo rpm --import https://repo.clickhouse.tech/CLICKHOUSE-KEY.GPG
sudo yum-config-manager --add-repo https://repo.clickhouse.tech/rpm/clickhouse.repo
sudo yum install clickhouse-server clickhouse-client

sudo /etc/init.d/clickhouse-server start
clickhouse-client
```

### docker安装

#### 单机版

* 编写docker-compose.yaml文件

```yaml
version: "3"
services:
    server:
     image: yandex/clickhouse-server
     ports:
     - "8123:8123"
     - "9000:9000"
     - "9009:9009"
     
     ulimits:
      nproc: 65535
      nofile:
       soft: 262144
       hard: 262144
    client:
      image: yandex/clickhouse-client
      command: ['--host', 'server']
```

* docker-compose up -d启动
* 访问地址

```shell
http interface http://hostip:8123,默认客户端9000，docker-compose中制定8123
```

* docker连接clickhouse-client

```shell
docker run -it --rm --link clickhouse:clickhouse-server yandex/clickhouse-client --host clickhouse-server
```

#### 安装GUI-tabix

```shell
docker run -d -p 8080:80 spoonest/clickhouse-tabix-web-client
```

* 修改/etc/click-server/config.xml

```xml
# 修改配置
<listen_host>::</listen_host>
```

### 客户端参数

| --host,-h      | 服务端的host名称，默认是'localtion'  |
| -------------- | ------------------------------------ |
| --port         | 连接的短裤，默认值:9000              |
| --user,-u      | 用户名。默认值：default              |
| --password     | 密码，默认值:空字符串                |
| --query,-q     | 非交互模式下的查询语句               |
| --database,-d  | 默认当前操作的数据库，默认值:default |
| --multiline,-m | 允许多行语句查询                     |
| --format,-f    | 使用指定的默认格式输出结果           |
| --time,-t      | 非交互模式下打印查询执行的时间到窗口 |
| --stacktrace   | 如果出现异常，打印堆栈异常           |
| --config-file   | 配置文件的名称           |

# 数据类型

## 与其他数据库区别

| Mysql     | Hive      | ClickHouse(区分大小写) |
| --------- | --------- | ---------------------- |
| byte      | TINYINT   | Int8                   |
| short     | SMALLINT  | Int16                  |
| int       | INT       | Int32                  |
| long      | BIGINT    | Int64                  |
| varchar   | STRING    | String/FixedString(n)  |
| timestamp | TIMESTAMP | DateTime               |
| float     | FLOAT     | Float32                |
| double    | DOUBLE    | Float64                |
| boolean   | BOOLEAN   | 无                     |

## 整型

* 固定长度的整形，包括有符号整形或无符号整形。
* 整型范围(-2^n-1~2^n-1 -1)
  * Int8 [-2&7:2^7-1]
  * Int16 [-2^15:2^15-1]
  * Int32 [-2^31 -1:2^31 -1]
  * Int64 [-2^63:-2^63-1]
* 无符号整型范围(0~2^n -1)
  * UInt8 [0,2^8-1]
  * UInt16 [0,2^16-1]
  * UInt32 [0,2^32-1]
  * UInt64 [0,2^64-1]

## 浮点型

* Float32 - float
* Float63 - double

```
我们建议您尽可能以整数形式存储数据。例如，将固定精度的数字转换为整数值，例如货币数量或页面加载时间用毫秒为单位表示
```

### NaN和Inf

* Inf-无穷大

```sql
SELECT 0.5 / 0
# 返回inf
```

* -Inf -负无穷

```sql
SELECT -0.5 / 0
# 返回-Inf
```

* Nan-不是一个数字

```sql
select 0/0
# 返回nan
```

## 字符串

### String

* 字符串可以任意长度的，它包含任意的字节集，包含空字节。
* 可以替代VARCHAR，BLOB，CLOB和其他来自DBMS的类型

### FixedString(N)

* 固定长度N的字符串，N必须是严格的正自然数。当服务端读取长度小于N的字符串时，通过在字符串末尾添加空字节来达到N字节长度。当服务端读取长度大于N的字符串时，返回错误信息。

## 枚举类型

* 包剧哦Enum8和Enum16类型。Enum保存'string'=interge的对应关系。
* Enum8用'String'=Int8对描述
* Enum16用'String'=Int16来描述

### 使用例子

* 创建一个表带有`Enum8('hello'=1,'world'=2)的列类型

```sql
CREATE TABLE t_enum
(
    x Enum('hello' = 1, 'world' = 2)
)
ENGINE = TinyLog
```

* 插入数据

```sql
# 插入定义的枚举
INSERT INTO t_enum VALUES ('hello'), ('world'), ('hello')
# 插入为定义的枚举，会报错
INSERT INTO t_enum values('a')
```

* 查询数据

```sql
# 查询插入的数据
select * from t_enum;

# 查询对应的int8类型
SELECT CAST(x, 'Int8') FROM t_enum
# 返回Enum8的类型格式
SELECT toTypeName(CAST('a', 'Enum(\'a\' = 1, \'b\' = 2)'))
```

### 规则及用法

* `Enum8`类型的每个值的范围是`-128~127`,`Enum16` 类型的每个值范围是 `-32768 ... 32767`。
* `Enum` 中的字符串和数值都不能是 [NULL](https://clickhouse.tech/docs/zh/sql-reference/data-types/enum/)
* Enum包含在`可为空`类型中，可以存储Null

```sql
CREATE TABLE t_enum_nullable
(
    x Nullable( Enum8('hello' = 1, 'world' = 2) )
)
ENGINE = TinyLog

# 插入NULL
INSERT INTO t_enum_nullable Values('hello'),('world'),(NULL)
```

* 在内存中，`Enum` 列的存储方式与相应数值的 `Int8` 或 `Int16` 相同。当以文本方式读取的时候，ClickHouse 将值解析成字符串然后去枚举值的集合中搜索对应字符串。如果没有找到，会抛出异常。当读取文本格式的时候，会根据读取到的字符串去找对应的数值。如果没有找到，会抛出异常。
* 当以文本形式写入时，ClickHouse 将值解析成字符串写入。如果列数据包含垃圾数据（不是来自有效集合的数字），则抛出异常。Enum 类型以二进制读取和写入的方式与 `Int8` 和 `Int16` 类型一样的。
* Enum 值使用 `toT` 函数可以转换成数值类型，其中 T 是一个数值类型。若 `T` 恰好对应 Enum 的底层数值类型，这个转换是零消耗的。
* Enum 类型可以被 `ALTER` 无成本地修改对应集合的值。可以通过 `ALTER` 操作来增加或删除 Enum 的成员（只要表没有用到该值，删除都是安全的）。作为安全保障，改变之前使用过的 Enum 成员将抛出异常。通过 `ALTER` 操作，可以将 `Enum8` 转成 `Enum16`，反之亦然，就像 `Int8` 转 `Int16`一样。

## 数组

`array(T)`:T代表任意类型的元素

* 一个数组类型能够支持任何类型的泛型类型

### 查询array

```sql
select array(1,2) as x,toTypeName(x)
SELECT [1, 2] AS x, toTypeName(x)
```

## 元组类型

* Tuple(t1,T2...)，元组可以包含多个元素，每个元素有自己单独的类型。
* 在动态创建元组时，ClickHouse会自动检测每个参数的类型，作为可以存储参数值的最小类型。`如果参数为NULL，则元组元素的类型可为空`。

### 创建元组

```sql
select tuple(1,'a') as x ,toTypeName( x)
```

## Decimal类型

* Decimal(P,S),Decimal32(S),Decimal64(S),Decimal128(S)

### 参数

* P -精度。有效范围:[1:38]。确定数字可以有多少位小数(包括分数)。
* S -规模。有效范围:[0:P]。确定小数部分可以有多少位小数。

### Decimal值范围

```
P from [ 1 : 9 ] - for Decimal32(S)
P from [ 10 : 18 ] - for Decimal64(S)
P from [ 19 : 38 ] - for Decimal128(S)
```

- Decimal32(S) - ( -1 * 10^(9 - S), 1 * 10^(9 - S) )
- Decimal64(S) - ( -1 * 10^(18 - S), 1 * 10^(18 - S) )
- Decimal128(S) - ( -1 * 10^(38 - S), 1 * 10^(38 - S) )

```sql
select toDecimal32(1,4) as x,x/3
```

## Datetime

语法：`DateTime([timezone])`

* 允许在时间中存储一个瞬间，可以表示为日历日期和一天的时间。

### 例子

```sql
CREATE TABLE dt
(
    `timestamp` DateTime('Europe/Moscow'),
    `event_id` UInt8
)
ENGINE = TinyLog;

INSERT INTO dt Values (1546300800, 1), ('2019-01-01 00:00:00', 2);

SELECT * FROM dt;
```

* 筛选DateTime值

```sql
SELECT * FROM dt WHERE timestamp = toDateTime('2019-01-01 00:00:00', 'Europe/Moscow')
```

* 得到dateTime列的时区

```sql
SELECT toDateTime(now(), 'Europe/Moscow') AS column, toTypeName(column) AS x
```

* 时区转换

```sql
SELECT
toDateTime(timestamp, 'Europe/London') as lon_time,
toDateTime(timestamp, 'Europe/Moscow') as mos_time
FROM dt
```

### Datetime64

语法:`DateTime64(precision, [timezone])`

* precision为精度，代表Datetime存储的秒以后的位数

```sql
CREATE TABLE dt
(
    `timestamp` DateTime64(3, 'Europe/Moscow'),
    `event_id` UInt8
)
ENGINE = TinyLog
INSERT INTO dt Values (1546300800000, 1), ('2019-01-01 00:00:00', 2)

SELECT * FROM dt

-- where
SELECT * FROM dt WHERE timestamp = toDateTime64('2019-01-01 00:00:00', 3, 'Europe/Moscow')

-- get timezone
SELECT toDateTime64(now(), 3, 'Europe/Moscow') AS column, toTypeName(column) AS x
-- timezone conversion
SELECT
toDateTime64(timestamp, 3, 'Europe/London') as lon_time,
toDateTime64(timestamp, 3, 'Europe/Moscow') as mos_time
FROM dt
```

## LowCardinality

语法:`LowCardinality(data_type`

### 描述

* 将其他数据类型的内部表示更改为字典编码的，Lowcardinality是一种上层结构，它改变了数据存储方法和数据处理规则。ClickHouse将字典编码应用于低基数列。对于许多应用程序来说，使用字典编码的数据进行操作可以显著提高SELECT查询的性能。
* LowCarditality数据类型的使用效率取决于数据多样性。如果一个字典包含的不同值少于10,000个，那么ClickHouse主要显示了更高的数据读取和存储效率。如果字典包含超过100,000个不同值，那么ClickHouse的性能可能比使用普通数据类型差。

### 参数

* data_type-String,FixedString,Date,DateTime，Decimal，可以将其转换为字典编码。

```sql
CREATE TABLE lc_t
(
    `id` UInt16,
    `strings` LowCardinality(String)
)
ENGINE = MergeTree()
ORDER BY id
```

## 嵌套数据结构

* 嵌套的数据结构就像单元格中的表格。嵌套数据结构的参数、列名和类型的指定方法与在CREATE TABLE查询中相同。每个表行可以对应于嵌套数据结构中的任意数量的行。

```sql
-- create
CREATE TABLE test.visits
(
    CounterID UInt32,
    StartDate Date,
    Sign Int8,
    IsNew UInt8,
    VisitID UInt64,
    UserID UInt64,
    Goals Nested
    (
        ID UInt32,
        Serial UInt32,
        EventTime DateTime,
        Price Int64,
        OrderID String,
        CurrencyID UInt32
    )
) ENGINE = CollapsingMergeTree(StartDate, intHash32(UserID), (CounterID, StartDate, intHash32(UserID), VisitID), 8192, Sign)

--select
SELECT
    Goals.ID,
    Goals.EventTime
FROM test.visits
WHERE CounterID = 101500 AND length(Goals.ID) < 5
LIMIT 10

```

## Nullable(tyoename)

* 允许存储特殊的标记(NULL)，它表示缺失的值与TypeName允许的正常值一起。例如，可空(Int8)类型的列可以存储Int8类型的值，而没有值的行将存储NULL。

```sql
CREATE TABLE t_null(x Int8, y Nullable(Int8)) ENGINE TinyLog
```

# 表引擎

## 特点

* 数据的存储方式和位置，写到哪里以及从哪里读取数据
* 支持那些查询以及如何支持
* 并发啊数据访问
* 索引的使用
* 是否可以支持多线程请求
* 数据复制参数

## 引擎类型

### MergeTree

* 适用于高负载任务的最通用和功能最强大的表引擎，这些引擎的共同特点是可以快速插入数据并进行后续的后台数据处理。
* MergeTree系列引擎支持数据复制（使用[Replicated*](https://clickhouse.tech/docs/zh/engines/table-engines/mergetree-family/replication/#table_engines-replication) 的引擎版本），分区和一些其他引擎不支持的其他功能。

#### 该类型的引擎

* MergeTree
* ReplacingMergeTree
* SummingMergeTree
* AggregatingMergeTree
* CollapsingMergeTree
* VersionedCollapsingMergeTree
* GraphiteMergeTree

### 日志

* 具有最小功能的轻量级引擎，当需要快速写入许多小表(最多约100万行)并在以后整体读取它们时，该类型的引擎是最有效的。

#### 该类型的引擎

* TinyLog
* StripeLog
* Log

### 集成引擎

* 用于与其他的数据存储与处理系统集成的引擎。

#### 该类型的引擎

* Kafka
* MySQL
* ODBC
* JDBC
* HDFS

### 用于其他特定功能的引擎

* Distributed
* MaterializedView
* Dictionary
* Merge
* File
* Null
* Set
* Join
* URL
* View
* Memory
* Buffer

## 虚拟列

```
虚拟列是表引擎组成的一部分，它在对应的表引擎的源代码中定义。

您不能在 CREATE TABLE 中指定虚拟列，并且虚拟列不会包含在 SHOW CREATE TABLE 和 DESCRIBE TABLE 的查询结果中。虚拟列是只读的，所以您不能向虚拟列中写入数据。

如果想要查询虚拟列中的数据，您必须在SELECT查询中包含虚拟列的名字。SELECT * 不会返回虚拟列的内容。

若您创建的表中有一列与虚拟列的名字相同，那么虚拟列将不能再被访问。我们不建议您这样做。为了避免这种列名的冲突，虚拟列的名字一般都以下划线开头。
```

# HDFS

## ClickHouse加载hdfs csv文件

```sql
-- 从HDFS加载数据
CREATE TABLE hdfs_data(
    id Int32,
    name String
)ENGINE=HDFS('hdfs://hadoop:8020/clickhouse/test.csv','CSV');

drop table hdfs_data;

--  测试读取
SELECT * FROM hdfs_data
```

# 优化

## max_table_size_to_drop

* 此参数在/etc/clickhouse-server/config.xml中，本参数应用于需求删除表或分区的情况，默认50GB，意思是如果要删除的分区或者表，数据量达到了参数值大小，会删除失败。建议改成0，0代表无论数据多大，都可以删除。

## max_memory_usage

* user.xml中配置，标示单纯Query占用内存最大值，超过本值Query失败，建议在资源足够的情况下调大。

## 删除多个节点的表

```sql
drop table t on cluster clusterName
```

