# 概述

## 特点

* 提供对HDFS、HBase、Kudu数据的高性能、低延迟的交互式SQL查询性能。

* 基于Hive，使用内存计算，兼顾数据仓库、基有实时、批处理、多并发的有点，是PB级大数据实时查询分析引擎。

## 优缺点

### 优点

* 基于内存运行，不需要把中间结果写入磁盘，省掉了大量的I/O开销。
* 无需转换为MR，直接访问存储在HDFS、HBASE和Kudu中的数据进行作业，速度快。
* 使用了支持Data Locality的I/O调度机制，尽可能将数据和计算分配到同一台机器上进行，减少了网络开销。
* 支持各种文件格式，如TEXTFILE、SEQUENCEFILE、RCFile、Parquet。
* 可以访问hive的metastore，对hive数据支持做数据分析。

### 缺点

* 对内存依赖大，且完全依赖于Hive。
* 分区超过1万，性能严重下降。
* 只能读取文本文件，不能直接读取自定义二进制文件。
* 每当新的记录/文件被添加到HDFS中的数据目录中，该表需要被刷新。

## Impala的架构

![img](http://impala.apache.org/img/impala.png)

![impala架构](../kudu/img/impala架构图.jpg)

* Impalad
  * 接收client的请求、Query执行并返回给中心协调及诶单；
  * 子节点上的守护进程，负责向statestore保持通信，汇报工作。
* Catalog
  * 分发表的元数据信息到各个impalad中；
  * 接收来自statestore的所有请求。
* Statestore
  * 负责收集分布在集群中各个impalad进程的资源信息、各节点健康状态，同步节点信息。
  * 负责query的协调调度。

# Impala操作

## Impala外部Shell

```shell
[root@cm-master shell]#  impala-shell -h
Options:
  -h, --help            show this help message and exit
  -i IMPALAD, --impalad=IMPALAD
                        <host:port> of impalad to connect to
                        [default: cm-master:21000]
  -q QUERY, --query=QUERY
                        Execute a query without the shell [default: none]
  -f QUERY_FILE, --query_file=QUERY_FILE
                        Execute the queries in the query file, delimited by ;
                        [default: none]
  -o OUTPUT_FILE, --output_file=OUTPUT_FILE
                        If set, query results are written to the given file.
                        Results from multiple semicolon-terminated queries
                        will be appended to the same file [default: none]
  -B, --delimited       Output rows in delimited mode [default: False]
  --print_header        Print column names in delimited mode when pretty-
                        printed. [default: False]
  --output_delimiter=OUTPUT_DELIMITER
                        Field delimiter to use for output in delimited mode
                        [default: \t]
  -p, --show_profiles   Always display query profiles after execution
                        [default: False]
  --quiet               Disable verbose output [default: False]
  -v, --version         Print version information [default: False]
  -c, --ignore_query_failure
                        Continue on query failure [default: False]
  -r, --refresh_after_connect
                        Refresh Impala catalog after connecting
                        [default: False]
  -d DEFAULT_DB, --database=DEFAULT_DB
                        Issues a use database command on startup
                        [default: none]
  -u USER, --user=USER  User to authenticate with. [default: root]
  --ssl                 Connect to Impala via SSL-secured connection
                        [default: False]
  --var=KEYVAL          Define variable(s) to be used within the Impala
                        session. [default: none]
```

## Impala内部Shell

| 选项                      | 描述                                                         |
| :------------------------ | :----------------------------------------------------------- |
| help                      | 显示帮助信息                                                 |
| explain <sql>             | 显示执行计划                                                 |
| profile (查询完成后执行） | 查询最近一次查询的底层信息                                   |
| shell <shell>             | 不退出impala-shell执行shell命令                              |
| version                   | 显示impala-shell和impala的版本信息                           |
| connect                   | 连接impalad主机，默认端口21000（同于impala-shell -i），如 connect hadoop103; |
| refresh <tablename>       | 增量刷新元数据库                                             |
| invalidate metadata       | 全量刷新元数据库（慎用）（同于 impala-shell -r）             |
| history                   | 历史命令                                                     |

### 进入内部shell

```shell
# 进入外部shell
impala-shell

# 进入内部shell
help方式查看
```

# Impala的数据类型

| Hive数据类型 | Impala数据类型 | 长度                                                 |
| ------------ | -------------- | ---------------------------------------------------- |
| TINYINT      | TINYINT        | 1byte有符号整数                                      |
| SMALINT      | SMALINT        | 2byte有符号整数                                      |
| INT          | INT            | 4byte有符号整数                                      |
| BIGINT       | BIGINT         | 8byte有符号整数                                      |
| BOOLEAN      | BOOLEAN        | 布尔类型，true或者false                              |
| FLOAT        | FLOAT          | 单精度浮点数                                         |
| DOUBLE       | DOUBLE         | 双精度浮点数                                         |
| STRING       | STRING         | 字符系列。可以指定字符集。可以使用单引号或者双引号。 |
| TIMESTAMP    | TIMESTAMP      | 时间类型                                             |
| BINARY       | 不支持         | 字节数组                                             |

* Impala虽然支持`array`、`map`、`struct`复杂数据类型，但是并不完全支持，一般处理方法，将复杂类型转化为基本类型，从hive中创表。