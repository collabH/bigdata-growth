# Flume概述

## 定义

* Flume是向Hadoop批量导入基于事件的海量数据，例如利用Flume从一组Web服务器中搜集日志文件，然后把这些文件转移到一个新的HDFS汇总文件中以做进一步处理，其终点(或者sink)通常为HDFS。
* Flume也支持导入其他系统比如HBase或Solr。
* 基于流式架构，灵活简单。

## Flume适合场景

![Flume场景](../zookeeper/img/Flume场景.jpg)

## 运行流程

​        ![img](https://uploader.shimo.im/f/Fd3AS12j9EIw9fEl.png!thumbnail)      

* 使用Flume需要`运行Flume代理`，Flume代理是由`持续运行的source`、`sink`以及`channel`(用于连接source和sink)构成的Java进程
* Flume的`source产生事件`，并将其`传输给channel`，`channel存储这些事件直至转发给sink`。
* 可以把source-channel-sink的组合视为基本的Flume构件。

## 基础架构

### Agent

* `JVM进程`，以事件的形式将数据从source sink到目的地。
* 包含Souce、Channel、Sink是哪个部分

### Souce

* `Souce`复制接收数据到FLume Agent的组件。SOuce组件支持处理多种类型多种格式的日志数据，包括`avro`、thrift、`exec`、`jms`、spooling directory、`netcat`、sequence generator、syslog、http、legacy。

### Sink

* Sink不断地轮询Channel中的事件且批量地移除它们，并将这些事件批量写入到存储或索引系统、或者被发送到另一个Flume Agent.
* Sink组件目的地包括`hdfs`、`logger`、`avro`、thrift、ipc、`file`、`HBase`、solr、自定义。

### Channel

* Channel是位于`Source和Sink`之间的缓冲区。因此，Channel允许`Source和Sink运作在不同的速率`。Channel是`线程安全的`，可以同时处理`几个Source的写入操作和几个Sink的读取操作`。
* 自带Channel:`Memory`和`File`以及`KafkaChannel`。
* Memory Channel是内存中的队列。File Channel是将所有事件写到磁盘。

### Event

* 传输单元,Flume数据传输的基本单元，以Event的形式将数据从源头送至目的地。Event由`Header`和`Body`两部分组成，`Header`用来存放该event的一些属性，为K-V结构，Body用来`存放该条数据， 形式为字节数组`。

# Flume安装

## 安装配置

```properties
http://www.apache.org/dyn/closer.lua/flume/1.9.0/apache-flume-1.9.0-bin.tar.gz

# 解压
tar -zxvf apache-flume-1.9.0-bin.tar.gz
# 配置环境变量
#Flume环境
export FLUME_HOME=/Users/babywang/Documents/reserch/studySummary/bigdata/flume/apache-flume-1.9.0
export PATH=$PATH:$FLUME_HOME/bin

# 配置JAVA HOME
# export JAVA_HOME=/usr/lib/jvm/java-8-oracle
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_221.jdk/Contents/Home
```

* Flume-ng启动代理查看是否安装成功

## 入门案例

### 官方文档Netcat

#### 创建配置

```properties
# example.conf: A single-node Flume configuration

# Name the components on this agent
# a1为agent的名称
a1.sources = r1
a1.sinks = k1
a1.channels = c1

# Describe/configure the source
# 配置agent a1的source配置
a1.sources.r1.type = netcat
a1.sources.r1.bind = localhost
a1.sources.r1.port = 9999

# Describe the sink
# 配置agent a1的sink配置
a1.sinks.k1.type = logger

# Use a channel which buffers events in memory
# 配置agent a1的channel配置
a1.channels.c1.type = memory
a1.channels.c1.capacity = 1000
a1.channels.c1.transactionCapacity = 100

# Bind the source and sink to the channel
# 绑定source和channel，sink和channel，channel和sink为1对n，source和channel为1对多
a1.sources.r1.channels = c1
a1.sinks.k1.channel = c1
```

#### 启动Flume-ng

```shell
flume-ng agent -n a1 -c $FLUME_HOME/conf -f netcat-flume-logger.conf -Dflume.root.logger=INFO,console
```

* -n: 指定运行的agent名称
* -c:指定flume配置文件目录
* -f:运行的Job

#### 启动netcat客户端

```shell
nc localhost 9999
```

### 实时监控单个文件

* 实时监控Zookeeper日志，并上传到HDFS中

#### 配置文件到日志

```properties
a1.sources = r1
a1.sinks = k1
a1.channels = c1


# 配置source -F失败后会重试 -f直接读取后面的数据
a1.sources.r1.type = exec
a1.sources.r1.command = tail -f /Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/logs/hadoop-babywang-namenode-research.log

# 配置sink
a1.sinks.k1.type = logger

# 配置agent a1的channel配置
a1.channels.c1.type = memory
a1.channels.c1.capacity = 1000
a1.channels.c1.transactionCapacity = 100

# source绑定channel
a1.sources.r1.channels = c1
a1.sinks.k1.channel=c1
```

* 启动flume-ng

```shell
flume-ng agent -n a1 -c $FLUME_HOME/conf -f file-flume-logger.conf -Dflume.root.logger=INFO,console
```

#### 日志到HDFS

* 将Hadoop相关jar拷贝至Flume lib目录下

```java
#从hadoop/shared目录下拷贝
hadoop-auth-2.8.5.jar
hadoop-common-2.8.5.jar
hadoop-hdfs-2.8.5.jar
commons-io-2.4.jar
commons-configuration-1.6.jar
htrace-core4-4.0.1-incubating.jar
```

* 配置

```properties
a1.sources = r1
a1.sinks = k1
a1.channels = c1


# 配置source -F失败后会重试 -f直接读取后面的数据
a1.sources.r1.type = exec
a1.sources.r1.command = tail -f /Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/logs/hadoop-babywang-namenode-research.log

# 配置sink
a1.sinks.k1.type = hdfs
a1.sinks.k1.hdfs.path = hdfs://hadoop:8020/hadoop/logs/%y-%m-%d/%H%M/%S
# 上传文件前缀
a1.sinks.k1.hdfs.filePrefix = namenode-
# 上传文件后缀
a1.sinks.k1.hdfs.fileSuffix = log
# 是否按照实际滚动文件夹
a1.sinks.k1.hdfs.round = true
# 多少时间单位创建一个新的文件夹
a1.sinks.k1.hdfs.roundValue = 1
a1.sinks.k1.hdfs.roundUnit = hour
# 是否使用本地时间戳
a1.sinks.k1.hdfs.useLocalTimeStamp = true
# 积攒多少个Event才flush到HDFS一次
a1.sinks.k1.hdfs.batchSize = 1000
# 设置文件类型，可支持压缩
a1.sinks.k1.hdfs.fileType = DataStream
# 多久生成一个文件
a1.sinks.k1.hdfs.rollInterval = 60
# 设置每个文件的滚动大小 
a1.sinks.k1.hdfs.rollSize = 134217700
# 文件的滚动与Event数量无关
a1.sinks.k1.hdfs.rollCount = 0

# 配置agent a1的channel配置
a1.channels.c1.type = memory
a1.channels.c1.capacity = 3000
a1.channels.c1.transactionCapacity = 2000

# source绑定channel
a1.sources.r1.channels = c1
a1.sinks.k1.channel=c1
```

* 启动脚本

```shell
flume-ng agent -n a1 -c $FLUME_HOME/conf -f file-flume-hdfs.conf
```

### 实时监控目录下多个新文件

* 使用Spooling Directory Source



