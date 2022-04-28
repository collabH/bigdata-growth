---
description: 知识库概览
---

# 概览

![img.png](img/logo.png)

## repository

[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT/)

[![Stargazers over time](https://starchart.cc/collabH/repository.svg)](./)

### 概述

* 个人学习知识库涉及到数据仓库建模、实时计算、大数据、Java、算法等。
* [在线文档](https://repository-1.gitbook.io/bigdata-growth/)

### RoadMap

![roadMap](roadmap/roadmap.jpg)

### 基础能力

#### 数据结构

#### 分布式理论

* [分布式架构](base/fen-bu-shi-li-lun/fen-bu-shi-jia-gou.md)

#### 计算机理论

* [LSM存储模型](base/计算机理论/LSM存储模型.md)

#### Scala

* [ScalaOverView](base/scala/ScalaOverView.md)

#### JVM

#### Java

**并发编程**

* [认识并发编程](base/java/bing-fa-bian-cheng/ren-shi-bing-fa-bian-cheng.md)
* [并发工具包](base/java/并发编程/并发工具类concurrent.md)

**JDK源码**

**todo**

### 算法

* [算法题解](base/algorithm/算法题解.md)

### BigData

#### cache

**数据编排技术**

**alluxio**

* [Alluxio概览](bigdata/cache/alluxio/AlluxioOverView.md)
* [Alluxio部署](bigdata/cache/alluxio/AlluxioDeployment.md)
* [Alluxio整合计算引擎](bigdata/cache/alluxio/AlluxioWithEngine.md)

#### datalake

**hudi**

* [Hudi概览](bigdata/datalake/hudi/hudiOverview.md)
* [Hudi整合Spark](bigdata/datalake/hudi/hudiWithSpark.md)
* [Hudi整合Flink](bigdata/datalake/hudi/hudiWithFlink.md)
* [Hudi调优实践](bigdata/datalake/hudi/hudi调优实践.md)
* [Hudi原理分析](bigdata/datalake/hudi/hudi原理分析.md)
* [hudi数据湖实践](bigdata/datalake/hudi/hudi数据湖实践.md)

**iceberg**

* [IceBerg概览](bigdata/datalake/iceberg/icebergOverview.md)
* [IceBerg整合Flink](bigdata/datalake/iceberg/icebergWithFlink.md)
* [IceBerg整合Hive](bigdata/datalake/iceberg/icebergWithHive.md)
* [IceBerg整合Spark](bigdata/datalake/iceberg/IcebergWithSpark.md)

#### kvstore

**K-V结构存储,如Hbase、RocksDb(内嵌KV存储)等**

**rocksDB**

* [rocksDB概述](bigdata/kvstore/rocksdb/RocksdbOverview.md)
* [rocksDB配置](bigdata/kvstore/rocksdb/Rocksdb配置.md)
* [rocksDB组件描述](bigdata/kvstore/rocksdb/Rocksdb组件描述.md)
* [rocksdb on flink](<bigdata/kvstore/rocksdb/RocksDB On Flink.md>)
* [rocksdb API](https://github.com/collabH/repository/blob/master/bigdata/kvstore/rocksdb/RocksDB%20API.xmind)

#### HBase

* [HBase概览](bigdata/kvstore/hbase/HBaseOverview.md)
* [HBaseShell](https://github.com/collabH/repository/blob/master/bigdata/kvstore/hbase/HBase%20Shell.xmind)
* [HBaseJavaAPI](https://github.com/collabH/repository/blob/master/bigdata/kvstore/hbase/HBase%20Java%20API.xmind)
* [HBase整合MapReduce](bigdata/kvstore/hbase/HBase整合第三方组件.md)
* [HBase过滤器](bigdata/kvstore/hbase/Hbase过滤器.md)

#### Hadoop

**广义上的Hadoop生态圈的学习笔记，主要记录HDFS、MapReduce、Yarn相关读书笔记及源码分析等。**

**HDFS**

* [Hadoop快速入门](https://github.com/collabH/repository/blob/master/bigdata/hadoop/Hadoop%E5%BF%AB%E9%80%9F%E5%BC%80%E5%A7%8B.xmind)
* [HDFSOverView](https://github.com/collabH/repository/blob/master/bigdata/hadoop/HDFS/HDFSOverView.xmind)
* [Hadoop广义生态系统](https://github.com/collabH/repository/blob/master/bigdata/hadoop/Hadoop%E5%B9%BF%E4%B9%89%E7%94%9F%E6%80%81%E7%B3%BB%E7%BB%9F.xmind)
* [Hadoop高可用配置](bigdata/hadoop/Hadoop高可用配置.md)
* [HadoopCommon分析](https://github.com/collabH/repository/blob/master/bigdata/hadoop/HDFS/HadoopCommon%E5%8C%85%E5%88%86%E6%9E%90.pdf)
* [HDFS集群相关管理](bigdata/hadoop/HDFS/HDFS集群管理.md)
* [HDFS Shell](<bigdata/hadoop/HDFS/HDFS Shell命令.md>)

**MapReduce**

* [分布式处理框架MapReduce](bigdata/hadoop/MapReduce/分布式处理框架MapReduce.md)
* [MapReduce概览](https://github.com/collabH/repository/blob/master/bigdata/hadoop/MapReduce/MapReduceOverView.xmind)
* [MapReduce调优](https://github.com/collabH/repository/blob/master/bigdata/hadoop/MapReduce/MapReduce%E8%B0%83%E4%BC%98.xmind)
* [MapReduce数据相关操作](bigdata/hadoop/MapReduce/MapReduce数据操作.md)
* [MapReduce输入输出剖析](bigdata/hadoop/MapReduce/MapReduce输入输出剖析.md)
* [MapReduce的工作机制](bigdata/hadoop/MapReduce/MapReduce的工作原理剖析.md)

**Yarn**

* [Yarn快速入门](bigdata/hadoop/Yarn/YARN快速入门.md)

**生产配置**

* [Hadoop高可用配置](bigdata/hadoop/Hadoop高可用配置.md)
* [Hadoop生产相关配置](bigdata/hadoop/Hadoop相关组件生产级别配置.md)

#### Engine

**计算引擎相关，主要包含Flink、Spark等**

**Flink**

* 主要包含对Flink文档阅读的总结和相关Flink源码的阅读，以及Flink新特性记录等等

**Core**

* [FlinkOverView](bigdata/engine/flink/core/FlinkOverview.md)
* [CheckPoint机制](bigdata/engine/flink/core/Checkpoint机制.md)
* [TableSQLOverview](bigdata/engine/flink/core/TableSQLOverview.md)
* [DataStream API](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/core/FlinkDataStream%20API.xmind)
* [ProcessFunction API](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/core/ProcessFunction%20API.xmind)
* [Data Source](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/core/Data%20Source.xmind)
* [Table API](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/core/TABLE%20API.xmind)
* [Flink SQL](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/core/FlinkSQL.xmind)
* [Flink Hive](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/core/Flink%20Hive.xmind)
* [Flink CEP](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/core/Flink%20Cep.xmind)
* [Flink Function](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/core/Flink%20Function.xmind)
* [DataSource API](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/core/Data%20Source.xmind)

**SourceCode**

* [FlinkCheckpoint源码分析](bigdata/engine/flink/sourcecode/FlinkCheckpoint源码分析.md)
* [FlinkSQL源码解析](bigdata/engine/flink/sourcecode/FlinkSQL源码解析.md)
* [Flink内核源码分析](bigdata/engine/flink/sourcecode/Flink内核源码分析.md)
* [Flink网络流控及反压](bigdata/engine/flink/sourcecode/Flink网络流控及反压.md)
* [TaskExecutor内存模型原理深入](bigdata/engine/flink/sourcecode/TaskExecutor内存模型原理深入.md)
* [Flink窗口实现应用](bigdata/engine/flink/sourcecode/Flink窗口实现应用原理.md)
* [Flink运行环境源码解析](bigdata/engine/flink/sourcecode/Flink运行环境源码解析.md)
* [FlinkTimerService机制分析](bigdata/engine/flink/sourcecode/FlinkTimerService机制分析.md)
* [StreamSource源解析](bigdata/engine/flink/sourcecode/StreamSource源解析.md)
* [Flink状态管理与检查点机制](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/sourcecode/Flink%E7%8A%B6%E6%80%81%E7%AE%A1%E7%90%86%E4%B8%8E%E6%A3%80%E6%9F%A5%E7%82%B9%E6%9C%BA%E5%88%B6.xmind)

**Book**

**Flink内核原理与实现**

* [1-3章读书笔记](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/books/Flink%E5%86%85%E6%A0%B8%E5%8E%9F%E7%90%86%E4%B8%8E%E5%AE%9E%E7%8E%B0/1-3%E7%AB%A0%E8%AF%BB%E4%B9%A6%E7%AC%94%E8%AE%B0.xmind)
* [第4章时间与窗口](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/books/Flink%E5%86%85%E6%A0%B8%E5%8E%9F%E7%90%86%E4%B8%8E%E5%AE%9E%E7%8E%B0/%E7%AC%AC4%E7%AB%A0%E6%97%B6%E9%97%B4%E4%B8%8E%E7%AA%97%E5%8F%A3.xmind)
* [5-6章读书笔记](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/books/Flink%E5%86%85%E6%A0%B8%E5%8E%9F%E7%90%86%E4%B8%8E%E5%AE%9E%E7%8E%B0/5-6%E7%AB%A0%E7%B1%BB%E5%9E%8B%E5%BA%8F%E5%88%97%E5%8C%96%E5%92%8C%E5%86%85%E5%AD%98%E7%AE%A1%E7%90%86%E8%AF%BB%E4%B9%A6%E7%AC%94%E8%AE%B0.xmind)
* [第7章状态原理](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/books/Flink%E5%86%85%E6%A0%B8%E5%8E%9F%E7%90%86%E4%B8%8E%E5%AE%9E%E7%8E%B0/%E7%AC%AC7%E7%AB%A0%E7%8A%B6%E6%80%81%E5%8E%9F%E7%90%86.xmind)
* [第8章作业提交](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/books/Flink%E5%86%85%E6%A0%B8%E5%8E%9F%E7%90%86%E4%B8%8E%E5%AE%9E%E7%8E%B0/%E7%AC%AC8%E7%AB%A0%E4%BD%9C%E4%B8%9A%E6%8F%90%E4%BA%A4.xmind)
* [第9章资源管理](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/books/Flink%E5%86%85%E6%A0%B8%E5%8E%9F%E7%90%86%E4%B8%8E%E5%AE%9E%E7%8E%B0/%E7%AC%AC9%E7%AB%A0%E8%B5%84%E6%BA%90%E7%AE%A1%E7%90%86.xmind)
* [第10章作业调度](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/books/Flink%E5%86%85%E6%A0%B8%E5%8E%9F%E7%90%86%E4%B8%8E%E5%AE%9E%E7%8E%B0/%E7%AC%AC10%E7%AB%A0%E4%BD%9C%E4%B8%9A%E8%B0%83%E5%BA%A6.xmind)
* [第11-13章Task执行数据交换等](bigdata/engine/flink/books/Flink内核原理与实现/第11-13章Task执行数据交换等.md)

**Feature**

* [Flink1.12新特性](bigdata/engine/flink/feature/Flink1.12新特性.md)
* [Flink1.13新特性](bigdata/engine/flink/feature/Flink1.13新特性.md)
* [Flink1.14新特性](bigdata/engine/flink/feature/Flink1.14新特性.md)

**Practice**

* [Flink踩坑指南](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/practice/Flink%E8%B8%A9%E5%9D%91.xmind)
* [记录一次Flink反压问题](bigdata/engine/flink/practice/记录一次Flink反压问题.md)
* [Flink SQL实践调优](https://github.com/collabH/repository/blob/master/bigdata/engine/flink/practice/Flink%20SQL%E8%B0%83%E4%BC%98.xmind)
* [Flink On K8s实践](<bigdata/engine/flink/practice/Flink On K8s.md>)

**Connector**

* [自定义Table Connector](bigdata/engine/flink/connector/自定义TableConnector.md)

**monitor**

* [搭建Flink任务指标监控系统](bigdata/engine/flink/monitor/搭建Flink任务指标监控系统.md)

**Spark**

**主要包含Spark相关书籍读书笔记、Spark核心组件分析、Spark相关API实践以及Spark生产踩坑等。**

* [Spark基础入门](https://github.com/collabH/repository/blob/master/bigdata/engine/spark/Spark%E5%9F%BA%E7%A1%80%E5%85%A5%E9%97%A8.xmind)
* [SparkOnDeploy](bigdata/engine/spark/SparkOnDeploy.md)
* [Spark调度系统](bigdata/engine/spark/Spark调度系统.md)
* [Spark计算引擎和Shuffle](bigdata/engine/spark/Spark计算引擎和Shuffle.md)
* [Spark存储体系](bigdata/engine/spark/Spark存储体系.md)
* [Spark大数据处理读书笔记](https://github.com/collabH/repository/blob/master/bigdata/engine/spark/Spark%E5%A4%A7%E6%95%B0%E6%8D%AE%E5%A4%84%E7%90%86%E8%AF%BB%E4%B9%A6%E7%AC%94%E8%AE%B0.xmind)

**Spark Core**

* [SparkCore](https://github.com/collabH/repository/blob/master/bigdata/engine/spark/spark%20core/Spark%20Core.xmind)
* [SparkOperator](https://github.com/collabH/repository/blob/master/bigdata/engine/spark/spark%20core/Spark%20Operator.xmind)
* [SparkConnector](https://github.com/collabH/repository/blob/master/bigdata/engine/spark/spark%20core/Spark%20Connector.xmind)

**Spark SQL**

* [SparkSQLAPI](https://github.com/collabH/repository/blob/master/bigdata/engine/spark/spark%20sql/Spark%20SQL%20API.xmind)
* [SparkSQL](https://github.com/collabH/repository/blob/master/bigdata/engine/spark/spark%20sql/Spark%20SQL.xmind)
* [SparkSQL API](<bigdata/engine/spark/spark sql/SparkSQL API.md>)
* [SparkSQL优化分析](<bigdata/engine/spark/spark sql/SparkSQL优化分析.md>)

**Spark Practice**

* [Spark生产实践](bigdata/engine/spark/practice/Spark生产实践.md)

**Spark Streaming**

* [SparkStreaming](https://github.com/collabH/repository/blob/master/bigdata/engine/spark/spark%20streaming/Spark%20Steaming.xmind)
* [SparkStreaming整合Flume](<bigdata/engine/spark/spark streaming/SparkStreaming整合Flume.md>)

**源码解析**

* [从浅到深剖析Spark源码](bigdata/engine/spark/从浅到深剖析Spark源码.md)
* [源码分析系列](https://github.com/collabH/repository/blob/master/bigdata/engine/spark/%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/README.md)

#### Collect

**数据采集框架，主要包含Binlog增量与SQL快照方式框架**

#### Canal

* [CanalOverView](bigdata/collect/canal/CanalOverView.md)

#### Debezium

* [DebeziumOverView](bigdata/collect/debezium/DebeziumOverView.md)
* [Debezium踩坑](https://github.com/collabH/repository/blob/master/bigdata/collect/debezium/Debezium%E8%B8%A9%E5%9D%91.xmind)
* [Debezium监控系统搭建](bigdata/collect/debezium/Debezium监控系统搭建.md)
* [Debezium使用改造](bigdata/collect/debezium/Debezium使用改造.md)

**Flume**

* [Flume快速入门](bigdata/collect/flume/FlumeOverwrite.md)
* [Flume对接Kafka](bigdata/collect/flume/Flume对接Kafka.md)

**Sqoop**

* [SqoopOverview](bigdata/collect/sqoop/SqoopOverview.md)
* [Sqoop实战操作](bigdata/collect/sqoop/Sqoop实战操作.md)

#### MQ

**消息中间件相关，主要包含大数据中使用比较多的Kafka和Pulsar**

**Kafka**

* [kafka概览](https://github.com/collabH/repository/blob/master/bigdata/mq/kafka/KafkaOverView.xmind)
* [基本概念](bigdata/mq/kafka/基本概念.md)
* [kafka监控](bigdata/mq/kafka/Kafka监控.md)
* [生产者源码剖析](bigdata/mq/kafka/生产者源码剖析.md)
* [消费者源码剖析](bigdata/mq/kafka/消费者源码剖析.md)
* [kafkaShell](https://github.com/collabH/repository/blob/master/bigdata/mq/kafka/KafkaShell.xmind)
* [kafka权威指南读书笔记](https://github.com/collabH/repository/blob/master/bigdata/mq/kafka/kafka%E6%9D%83%E5%A8%81%E6%8C%87%E5%8D%97/README.md)
* [深入理解Kafka读书笔记](https://github.com/collabH/repository/blob/master/bigdata/mq/kafka/%E6%B7%B1%E5%85%A5%E7%90%86%E8%A7%A3Kafka/README.md)

**Pulsar**

* [快速入门](bigdata/mq/pulsar/1.快速入门.md)
* [原理与实践](bigdata/mq/pulsar/2.原理与实践.md)

#### Zookeeper

* [Zookeeper原理和参数配置](bigdata/zookeeper/ZookeeperOverView.md)
* [Zookeeper操作与部署](bigdata/zookeeper/Zookeeper操作与部署.md)

#### schedule

**Azkaban**

* [Azkaban生产实践](bigdata/scheduler/Azkaban生产实践.md)

**DolphinScheduler**

* [DolphinScheduler快速开始](bigdata/scheduler/DolphinScheduler快速开始.md)

#### olap

**主要核心包含Kudu、Impala相关Olap引擎，生产实践及论文记录等。**

**Hive**

* [HiveOverwrite](bigdata/olap/hive/HiveOverwrite.md)
* [Hive SQL](https://github.com/collabH/repository/blob/master/bigdata/olap/hive/Hive%20SQL.xmind)
* [Hive调优指南](https://github.com/collabH/repository/blob/master/bigdata/olap/hive/Hive%E8%B0%83%E4%BC%98%E6%8C%87%E5%8D%97.xmind)
* [Hive踩坑解决方案](https://github.com/collabH/repository/blob/master/bigdata/olap/hive/Hive%E8%B8%A9%E5%9D%91%E8%A7%A3%E5%86%B3%E6%96%B9%E6%A1%88.xmind)
* [Hive编程指南读书笔记](https://github.com/collabH/repository/blob/master/bigdata/olap/hive/hive%E7%BC%96%E7%A8%8B%E6%8C%87%E5%8D%97/README.md)
* [Hive Shell Beeline](<bigdata/olap/hive/Hive Shell和Beeline命令.md>)
* [Hive分区表和分桶表](bigdata/olap/hive/Hive分区表和分桶表.md)

**Presto**

* [presto概述](bigdata/olap/presto/PrestoOverview.md)

**clickhouse**

* [ClickHouse快速入门](bigdata/olap/clickhouse/ClickHouseOverView.md)
* [ClickHouse表引擎](https://github.com/collabH/repository/blob/master/bigdata/olap/clickhouse/ClickHouse%E8%A1%A8%E5%BC%95%E6%93%8E.xmind)

**Druid**

* [Druid概述](bigdata/olap/druid/DruidOverView.md)

**Kylin**

* [Kylin概述](bigdata/olap/kylin/KylinOverWrite.md)

**Kudu**

* [KuduOverView](bigdata/olap/kudu/KuduOverView.md)
* [Kudu表和Schema设计](bigdata/olap/kudu/KuduSchemaDesgin.md)
* [KuduConfiguration](bigdata/olap/kudu/KuduConfiguration.md)
* [Kudu原理分析](bigdata/olap/kudu/Kudu原理分析.md)
* [Kudu踩坑](https://github.com/collabH/repository/blob/master/bigdata/olap/kudu/Kudu%E8%B8%A9%E5%9D%91.xmind)
* [Kudu存储结构架构图](https://github.com/collabH/repository/blob/master/bigdata/olap/kudu/Kudu%E5%AD%98%E5%82%A8%E7%BB%93%E6%9E%84/README.md)
* [Kudu生产实践](bigdata/olap/kudu/Kudu生产实践.md)

**paper**

* [Kudu论文阅读](bigdata/olap/kudu/paper/KuduPaper阅读.md)

**Impala**

* [ImpalaOverView](bigdata/olap/impala/ImpalaOverView.md)
* [ImpalaSQL](https://github.com/collabH/repository/blob/master/bigdata/olap/impala/Impala%20SQL.xmind)
* [Impala操作KUDU](bigdata/olap/impala/使用Impala查询Kudu表.md)
* [Impala生产实践](bigdata/olap/impala/Impala生产实践.md)

#### graph

**图库相关**

**nebula graph**

* [1.简介](<bigdata/graph/nebula graph/1.简介.md>)
* [2.快速入门](<bigdata/graph/nebula graph/2.快速入门.md>)

#### tools

**工具集相关，包含计算平台、sql语法Tree等**

**zeppelin**

* [zeppelin](https://github.com/collabH/repository/blob/master/bigdata/tools/zeppelin/Zeppelin.xmind)

**SQL语法树**

**calcite**

* [ApacheCalciteOverView](bigdata/tools/sqltree/calcite/CalciteOverView.md)

### 数据仓库建设

#### 理论

* [数据建模](datawarehouse/理论/DataModeler.md)
* [数据仓库建模](https://github.com/collabH/repository/blob/master/datawarehouse/%E7%90%86%E8%AE%BA/%E6%95%B0%E6%8D%AE%E4%BB%93%E5%BA%93%E5%BB%BA%E6%A8%A1.xmind)
* [数据仓库](datawarehouse/li-lun/shu-ju-cang-ku-shi-zhan.md)

#### 数据中台设计

* [数据中台设计](datawarehouse/shu-ju-zhong-tai-mo-kuai-she-ji/shu-ju-zhong-tai-she-ji.md)
* [thoth自研元数据平台设计](datawarehouse/数据中台模块设计/thoth自研元数据平台设计.md)

#### 方案实践

* [Kudu数据冷备](datawarehouse/方案实践/Kudu数据冷备方案.md)
* [基于Flink的实时数仓建设](datawarehouse/fang-an-shi-jian/ji-yu-flink-de-shi-shi-shu-cang-jian-she.md)

#### 读书笔记

* [数据中台读书笔记](datawarehouse/li-lun/shu-ju-zhong-tai-du-shu-bi-ji.md)

### devops

* [shell命令](https://github.com/collabH/repository/blob/master/devops/Shell%E5%AD%A6%E4%B9%A0.xmind)
* [Linux命令](https://github.com/collabH/repository/blob/master/devops/Linux%E5%AD%A6%E4%B9%A0.xmind)
* [openshift基础命令](datawarehouse/li-lun/devops/k8sopenshift-ke-hu-duan-ming-ling-shi-yong.md)

### maven

* [maven骨架制作](datawarehouse/li-lun/devops/maven/zhi-zuo-maven-gu-jia.md)
* [maven命令](datawarehouse/li-lun/devops/maven/maven-ming-ling.md)

### 服务监控

* [Prometheus](servicemonitor/Prometheus/Prometheus实战.md)

### mac

* [iterm2](mac/iterm2/)

## 贡献方式

* 欢迎通过[Gitter](https://gitter.im/collabH-repository/community)参与贡献
* [贡献者指南](CONTRIBUTING.md)

## 技术分享

![](img/公众号.jpeg)
