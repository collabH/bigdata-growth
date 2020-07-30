# 架构和环境
## 概述

* Spark基于内存计算，整合了内存计算的单元，并且启用了分布式数据集，能够提供交互式查询和优化迭代工作负载。
* MR不擅长长迭代、交互式和流式的计算工作，主要因为它缺乏计算的各个阶段有效的资源共享，Spark引入RDD解决这个问题，基于内存计算，提高数据处理实时性，并且高容错和可伸缩性，可以部署在大量廉价硬件上，形成集群。

### Spark和MapReduce的对比

#### 中间结果

* 基于MR的计算引擎通常将中间结果输出到磁盘，以达到存储和容错的目的。因此涉及到中间结果的迭代处理就会导致多个MR任务串联执行，此时就会导致数据处理延迟缓慢等问题。
* Spark将执行操作抽象成DAG，将多个Stage任务串联或冰箱执行，无需将Stage中间结果存储到HDFS。

#### 执行策略

* MapReduce在数据Shuffle之间需要在Map阶段需要进行分区快排并且在merge阶段时也需要对map输出阶段的各个文件进行归并排序，在shuffle拷贝文件也需要通过归并排序进行合并，此时就导致Shuffle十分消耗性能。
* Spark提供Bypass机制和不同模式numMapsForShuffle机制，会根据stage属性和配置决定shuffle过程是否需要排序，并且中间结果可以直接缓存在内存中。

#### 任务调度开销

* MapReduce系统为了处理长达数小时的批量作业，在一些极端情况，提交任务延迟非常高。
* Spark基于Actor模式并且基于Netty的NIO来进行进程间的通信，并且使用多线程以及Actor模型将任务解耦。

#### 容错性

* Spark RDD提供血缘关系(lineage),一旦失败可以根据父RDD自动重建，保证容错性。

## Spark架构

* 当计算与存储能力无法满足大规模数据处理需求时，自身CPU与存储无法水平扩展会导致先天的限制。

### 分布式系统架构

* 每个计算单元时松耦合的，并且计算单元包含自己的CPU、内存、总线及硬盘等私有计算资源。分布架构的问题在于共享资源的问题，因此为了资源的共享又不会导致IO的瓶颈，`分布式计算的原则是数据本地化计算`。

### Spark架构

* `基于Master-Slave模型`，Master负责控制整个集群的运行，Worker节点负责计算，接受Master节点指令并返回计算进程到Master；Executor负责任务的执行；Client是用户提交应用的客户端；Driver负责协调提交后的分布式应用。

![Spark架构](./源码分析/img/Spark架构.jpg)

* worker负责管理计算节点并创建Executor来并行处理Task任务，Task执行过程所需文件和包由Driver序列化后传输给对应的Worker节点，Executor对相应分区的任务进行处理。

#### Spark基础组件

* Client:提交应用的客户端
* Driver:执行Application中的main函数并创建SparkContext
* ClusterManager:在Yarn中为RM，在Standalone模式为Master，控制整个集群。
* Worker:从节点，负责控制计算节点，启动Executor或Driver，在yarn模式中为NM
* Executor:在计算节点执行任务的组件。
* SparkContext:应用的上下文，控制应用的生命周期。
* RDD:弹性分布式数据集，Spark的基本计算单元，一组RDD可形成有向五环图。
* DAG Scheduler:根据应用构建基于Stage的DAG，并将Stage提交给Task Schduler
* Task Scheduler :将Task分发给Executor执行
* SparkEnv: 线程级别上下文，存储运行时重要组件
  * SparkConf:存储配置信息
  * BroadcastManager:负责广播变量的控制及元信息的存储。
  * BlockManager:负责Block的管理、创建和查找。
  * MetricsSystem:监控运行时的性能指标。
  * MapOutputTracker:负责shuffle元信息的存储。

#### Spark执行流程

* 用户在Client提交应用
* Master找到worker启动Driver
* Driver向RM或Master申请资源，并将应用转换为RDD Graph
* DAG Scheduler将RDD Graph转化为Stage的有向五环图提交给Task Scheduler
* Task Scheduler提交Task给Executor执行。

## Spark部署

### 环境准备

* JDK1.8和scala2.12
* 配置SSH免密码登陆

```shell
ssh-keygen -t rsa
scp ids_rsa.pub user@ip:~/.ssh/
mv id_rsa.pub authorized_keys
```

### Hadoop的安装配置

* 下载Hadoop压缩包
* 添加环境变量

```shell
export HADOOP_HOME=/usr/local/hadoop
export PATH=$HADOOP_HOME/bin:$PATH
export PATH=$HADOOP_HOME/sbin:$PATH
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
```

* 配置hadoop_env.sh

```shell
# The java implementation to use.
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_221.jdk/Contents/Home
```

* core-site.xml

```xml
<property>
        <name>fs.defaultFS</name>
        <value>hdfs://bigdatadev:8020</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/Users/xiamuguizhi/Documents/develop/learn/bigdata/hadoop-dir</value>
    </property>
    <!--修改缓冲区大小10MB，默认4KB-->
    <property>
        <name>io.file.buffer.size</name>
        <value>131072</value>
    </property>
    <!--开启代理用户权限相关-->
    <property>
        <name>hadoop.proxyuser.hduser.hosts</name>
        <value>*</value>
    </property>
    <property>
        <name>hadoop.proxyuser.hduser.groups</name>
        <value>*</value>
    </property>
```

* yarn-site.xml

```xml
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.auxservices.mapreduce.shuffle.class</name>
        <value>org.apache.hadoop.mapred.ShuffleHandler</value>
    </property>    
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>bigdatadev</value>
    </property>
    <property>
        <name>yarn.nodemanager.hostname</name>
        <value>bigdatadev</value>
    </property>
    <!--rm addrss配置-->
    <property>
        <name>yarn.resourcemanager.address</name>
        <value>bigdatadev:8032</value>
    </property>
    <!--rm调度器端口-->
    <property>
        <name>yarn.resourcemanager.scheduler.address</name>
        <value>bigdatadev:8030</value>
    </property>
    <!--resource-tracker端口-->
    <property>
        <name>yarn.resourcemanager.resource-tracker.address</name>
        <value>bigdatadev:8031</value>
    </property>
    <!--resource管理器端口-->
    <property>
        <name>yarn.resourcemanager.admin.address</name>
        <value>bigdatadev:8033</value>
    </property>    
    <!--webUI端口-->
    <property>
        <name>yarn.resourcemanager.webapp.address</name>
        <value>bigdatadev:8088</value>
    </property>   
```

* mapped-site.xml

```xml
<!--hadoop对map-reduce运行框架的三种实现，classic、yarn、local-->
   <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
   <!--mapreduce jobHistory server地址，通过mr-history-server.sh start history启动-->
    <property>
        <name>mapreduce.jobhistory.address</name>
        <value>bigdatadev:10020</value>
    </property>
   <!--mapreduce jobHistory webUI地址-->
    <property>
        <name>mapreduce.jobhistory.webapp.address</name>
        <value>bigdatadev:19888</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
```

* hdfs-site.xml

```xml
  <!--block副本数配置-->
  <property>
        <name>dfs.replication</name>
        <value>1</value>
  </property>
  <!--配置从节点名和端口号-->
  <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>bigdatadev:9001</value>
  </property>
  <!--配置namenode的存储目录-->
  <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:/Users/xiamuguizhi/Documents/develop/learn/bigdata/hadoop-dir/namenode</value>
  </property>
  <!--配置datanode的存储目录-->
  <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:/Users/xiamuguizhi/Documents/develop/learn/bigdata/hadoop-dir/datanode</value>
  </property>
  <!--开启webhdfs，否则不能使用webhdfs的liststatus、listfilestatus等命令来列出文件和状态等命令-->
  <property>
        <name>dfs.webhdfs.enabled</name>
        <value>true</value>
  </property>
```



* 创建目录

```shell
mkdir -p /Users/xiamuguizhi/Documents/develop/learn/bigdata/hadoop-dir/namenode
mkdir -p /Users/xiamuguizhi/Documents/develop/learn/bigdata/hadoop-dir/datanode
```

* 将所有从节点主机名加入slaves中

```
192.168.1.2 hadoop1
192.168.1.3 hadoop2
192.168.1.4 hadoop3
```

* 格式化namenode

### Spark安装部署

* 下载Spark安装包
* 配置Spark环境变量

```
export SPARK_HOME=/user/spark
PATH=$SPARK_HOME/bin
```

* 修改/etc/hosts加入集群中Master及各个Worker节点
* 配置spark-env.sh

```shell
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_221.jdk/Contents/Home
export SCALA_HOME=/Users/xiamuguizhi/Documents/develop/workspace/tools/scala-2.12.11
export SPARK_MASTER_IP=127.0.0.1
export SPARK_WORKER_MEMORY=1g
```

* slaves,将各个worker节点添加至slaves节点

```
worker1
worker2
worker3
```

### Hadoop与Spark的集群复制

* 使用pssh工具将JDK、Scala、Hadoop环境、Spark环境、系统配置(host、profile)分发到集群服务器中

# Spark编程模型

