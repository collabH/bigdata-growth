#   概述

## Flink的优势

* Apache Flink 是一个分布式大数据处理引擎，可对有限数据流和无限数据流进行有状态或无状态的计算，能够部署在各种集群环境，对各种规模大小的数据进行快速计算。
* 有状态的计算，状态容错性依赖于checkpoint机制做状态持久化存储。
* 多层API(Table/SQL API、DataStream/DataSet API、ProcessFunction API)
* 三种事件事件
* exactly-once语义，状态一致性保证
* 低延迟，每秒处理数百万个事件，毫秒级别延迟。

## 流处理演变

### lambda架构

* 俩套系统，同时保证低延迟和结果准确。

![lambda架构](./img/lambda架构.jpg)

* 开发维护、迭代比较麻烦，涉及到离线数仓和实时数仓的异构架构，难度偏大。

## Flink和SparkStreaming区别

* stream and micro-batching

![SparkStreamingVsFlink](./img/SparkStreamingVsFlink.jpg)

* 数据模型
  * spark采用RDD模型，spark Streaming的DStream相当于对RDD序列的操作，是一小批一小批的RDD集合。
  * flink基本数据模型是数据流，以及事件序列。
* 运行时架构
  * spark是批计算，将DAG划分为不同的stage，一个stage完成后才可以计算下一个。
  * flink是标准的流执行模式，一个事件在一个节点处理完后可以直接发往下一个节点进行处理。

# Flink安装

## Local部署模式

* 安装JDK
* 下载flink对应版本压缩包
* 进入flink/bin目录下，运行start-cluster.sh命令
* 访问localhost:8081启动集群

## Standalone模式

* 配置ssh免密登录

### flink-conf.yaml

```yaml
# 配置javahome
env.java.home: /Library/Java/JavaVirtualMachines/jdk1.8.0_221.jdk/Contents/Home
# 配置master节点
jobmanager.rpc.address: hadoop
# 配置每个节点运行申请的最大的jobmanager内存和taskmanager内存
jobmanager.memory.process.size: 8096mb
taskmanager.memory.process.size: 2048mb
```

### workes配置

```shell
# 将worker节点ip地址配置在此文件中
hadoop1
hadoop2
```

### 集群命令

#### 启动集群

* bin/start-cluster.sh和bin/stop-cluster.sh

#### 添加JobManager

* bin/jobmanager.sh ((start|start-foreground) [host] [webui-port])|stop|stop-all

#### 添加taskManager

* bin/taskmanager.sh start|start-foreground|stop|stop-all

## Yarn模式

### 前置条件

```shell
# 环境变量中配置HADOOP_CLASSPATH
export HADOOP_CLASSPATH=/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/etc/hadoop:/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/share/hadoop/common/lib/*:/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/share/hadoop/common/*:/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/share/hadoop/hdfs:/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/share/hadoop/hdfs/lib/*:/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/share/hadoop/hdfs/*:/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/share/hadoop/yarn/lib/*:/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/share/hadoop/yarn/*:/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/share/hadoop/mapreduce/lib/*:/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/share/hadoop/mapreduce/*:/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5/contrib/capacity-scheduler/*.jar:/Users/babywang/Documents/reserch/studySummary/module/hbase/hbase-1.6.0/lib
```

* 下载`flink-shaded-hadoop-2-uber-2.8.3-10.0.jar`放在lib下

### Session模式

* Session-Cluster模式需要先启动集群，然后再提交作业，接着会向yarn申请一块空间后，资源永远保持不变。如果资源满了，下个作业就无法提交类似于standalone模式。
* 所有作业共享Dispatcher和RM，共享资源，适合小规模执行时间短的作业。

```shell
yarn-session.sh
Usage:
   Optional
     -D <arg>                        Dynamic properties 动态参数
     -d,--detached                   Start detached # 后台进程
     -jm,--jobManagerMemory <arg>    Memory for JobManager Container with optional unit (default: MB) 
     -nm,--name                      Set a custom name for the application on YARN 自定义applicationName
     -at,--applicationType           Set a custom application type on YARN 自定义Yarn的应用类型
     -q,--query                      Display available YARN resources (memory, cores) 查看可用YARN的资源
     -qu,--queue <arg>               Specify YARN queue. 指定YARN队列
     -s,--slots <arg>                Number of slots per TaskManager 指定TaskManager可用的slot数
     -tm,--taskManagerMemory <arg>   Memory per TaskManager Container with optional unit (default: MB)
     -z,--zookeeperNamespace <arg>   Namespace to create the Zookeeper sub-paths for HA mode 高可用zookeeper的ZNODE名称
     
# 通过—D动态参数方式覆盖flink-conf.yaml中的默认值
yarn-session.sh -Dfs.overwrite-files=true -Dtaskmanager.memory.network.min=536346624.
```

* 提交任务

```shell
flin run 
	-c classname 启动的driver主类
	-C url 
	-d 指定运行job的模式为后台模式
	-n 不能重新执行savepoint的时候允许跳过
	-p 程序执行并行度
	-s 指定从某个savepoint路径恢复
	-t 执行模式， "collection", "remote", "local","kubernetes-session", "yarn-per-job", "yarn-session","yarn-application" and "kubernetes-application"
```

* yarn.per-job-cluster.include-user-jar 用户jar包

### Pre-Job-Cluster模式

* 耦合Job会对应一个集群，每提交一个作业会根据自身的情况，都会单独向yarn申请资源，直到作业执行完成，一个作业的失败与否不会影响下一个作业的正常提交和运行。
* 独享Dispatcher和RM，按需接受资源申请，适合规模大长时间运行的作业。

```shell
flink run -t yarn-per-job -c dev.learn.flink.base.StreamingJob -d -yat flink -yjm 1024m -ytm 2048m -ynm test -ys 10 -p 2 -n flink-learn-1.0-SNAPSHOT.jar 
```

### application模式

```shell
# 运行WordCount
flink run-application -t yarn-application -Djobmanager.memory.process.size=2048m -Dtaskmanager.memory.process.size=4096m  ./examples/batch/WordCount.jar
```

* `yarn.provided.lib.dirs`提前在应用运行前提交的jar包

```shell
flink run-application -t yarn-application \
-Dyarn.provided.lib.dirs="hdfs://myhdfs/my-remote-flink-dist-dir" \
hdfs://myhdfs/jars/my-application.jar
```

* `yarn.application.priority`:设置提交顺序

## HA配置

### Standalone Cluster模式

* masters配置

```
hadoop:8081
hadoop:8082
```

* flink-conf.yaml配置

```yaml
# 高可用配置，默认是随机选择的
high-availability.jobmanager.port: 50000-50025
# 高可用模式配置
high-availability: zookeeper
# zookeeper配置
high-availability.zookeeper.quorum: hadoop:2181
# 高可用flink jobmanager存储zk ZNODE配置
high-availability.zookeeper.path.root: /flink
# jobManager元数据将保留在文件系统storageDir中，并且只有指向此状态的指针存储在ZooKeeper中。
high-availability.storageDir: hdfs:///flink1.11.1/ha/
```

* start-cluster.sh启动集群

### Yarn Cluster高可用

* yarn-site.xml

```xml
# 配置am的最大重试时间
<property>
  <name>yarn.resourcemanager.am.max-attempts</name>
  <value>4</value>
  <description>
    The maximum number of application master execution attempts.
  </description>
</property>
```

* flink-conf.yaml

```yaml
# application最大重试时间
yarn.application-attempts: 10
```

* 启动yarn cluster

```shell
yarn-session.sh -tm 2048m -jm 1024m -s 4 -d -nm test
```

## 容错与状态

### Checkpoint

* checkpoint默认情况下`仅用于恢复失败的作业，并不保留，当程序取消时checkpoint就会被删除`。可以通过配置来保留checkpoint，保留的checkpoint在作业失败或取消时不会被清除。

```java
CheckpointConfig config = env.getCheckpointConfig();
config.enableExternalizedCheckpoints(ExternalizedCheckpointCleanup.RETAIN_ON_CANCELLATION);
```

* **`ExternalizedCheckpointCleanup.RETAIN_ON_CANCELLATION`**：当作业取消时，保留作业的 checkpoint。注意，这种情况下，需要手动清除该作业保留的 checkpoint。
* **`ExternalizedCheckpointCleanup.DELETE_ON_CANCELLATION`**：当作业取消时，删除作业的 checkpoint。仅当作业失败时，作业的 checkpoint 才会被保留。

#### checkpoint配置

* checkpoint由元数据文件、数据文件组成。通过`statecheckpoints.dir`配置元数据文件和数据文件存储路径，也可以在代码中设置。

```
/user-defined-checkpoint-dir
    /{job-id}
        |
        + --shared/
        + --taskowned/
        + --chk-1/
        + --chk-2/
        + --chk-3/
        ...
```

* 其中 **SHARED** 目录保存了可能被多个 checkpoint 引用的文件，**TASKOWNED** 保存了不会被 JobManager 删除的文件，**EXCLUSIVE** 则保存那些仅被单个 checkpoint 引用的文件。

* 从保留的checkpoint中恢复状态

```shell
$ bin/flink run -s :checkpointMetaDataPath [:runArgs]
```

* 容错配置

```yaml
state.backend: rocksdb
state.checkpoints.dir: hdfs://hadoop:8020/flink1.11.1/checkpoints
state.savepoints.dir: hdfs://hadoop:8020/flink1.11.1/savepoints
state.backend.incremental: true
# 故障转移策略，默认为region，按照区域恢复
jobmanager.execution.failover-strategy: region
```

### savepoint

* Savepoint 由两部分组成：稳定存储上包含二进制文件的目录（通常很大），和元数据文件（相对较小）。 稳定存储上的文件表示作业执行状态的数据镜像。 Savepoint 的`元数据文件以（绝对路径）的形式包含（主要）指向作为 Savepoint 一部分的稳定存储上的所有文件的指针`。

#### 与checkpoint的区别

* **checkpoint**类似于恢复日志的概念(redolog), Checkpoint 的主要目的是`为意外失败的作业提供恢复机制`。 Checkpoint 的生命周期由 Flink 管理，即 Flink 创建，管理和删除 Checkpoint - 无需用户交互。 作为一种恢复和定期触发的方法，Checkpoint 实现有两个设计目标：`i）轻量级创建和 ii）尽可能快地恢复`。
* Savepoint 由用户创建，拥有和删除。 他们的用例是计划的，手动备份和恢复,恢复成本相对于checkpoint会更高一些，相对checkpoint更重量一些。

#### 分配算子ID

* 通过`uid(String)`方法手动指定算子ID，算子ID用于恢复每个算子的状态。

```java
datasource.uid("network-source").map(new WordCountMapFunction())
                .uid("map-id")
                .keyBy((KeySelector<Tuple2<String, Integer>, Object>) stringIntegerTuple2 -> stringIntegerTuple2.f0)
                .timeWindow(Time.seconds(30))
                .reduce(new SumReduceFunction())
                .uid("reduce-id")
                .print().setParallelism(1);
```

#### savepoint操作

* 触发savepoint,`flink savepoint :jobId [:targetDirctory]`
* 使用YARN触发Savepoint,`flink savepoint :jobId [:targetDirctory] -yid :yarnAppId`
* 使用savepoint取消作业,`flink cancel -s [:targetDirectory] :jobId`
* 从savepoint恢复,`flink run -s :savepointPath [:runArgs]`
  * --allowNoRestoredState 跳过无法映射到新程序的状态
* 删除savepoint,`flink savepoint -d :savepointPath`

# 原理剖析

## 运行时架构

### 运行时组件

* JobManager,作业管理器
  * 控制应用程序的主进程，每个应用程序会被一个不同的JobManager所控制执行。
  * JobManger会先接收到执行的应用程序，这个应用程序包含：作业图(JobGrap)、逻辑数据流图(logic dataflow graph)和打包了所有的累、库和其他资源的jar包。
  * jobManager会把JobGraph转换成一个物理层面的数据流图，这个图被叫做“执行图”（ExecutionGraph），包含了所有可以并行执行的任务。
  * JobManager会向RM请求执行任务必要的资源，就是tm所需的slot。一旦获取足够的资源，就会将执行图分发到真正运行它们的tm上。运行过程中，Jm负责所需要中央协调的操作，比如checkpoint、savepoint的元数据存储等。
* TaskManager，任务管理器
  * 任务管理器中资源调度的最小单元是任务槽。任务管理器中的任务槽数表示并发处理任务的数量。
  * flink的工作进程，存在多个每个存在多个slot，slot的个数限制了tm执行任务的数量。
  * 启动后tm会想rm注册它的slot，收到rm的指令后，tm会将一个或多个slot提供给jm调用。dm可以向slot分配tasks来执行。
  * 执行的过程中，一个tm可以跟其他运行同一个应用程序的tm交换数据。
* ResourceManager，资源管理器
  * ResourceManager负责Flink集群中的资源取消/分配和供应-它管理任务插槽，这些任务插槽是Flink集群中资源调度的单位（请参阅TaskManagers）。 Flink为不同的环境和资源提供者（例如YARN，Mesos，Kubernetes和独立部署）实现了多个ResourceManager。 在独立设置中，ResourceManager只能分配可用TaskManager的插槽，而不能自行启动新的TaskManager。
* Dispatcher，分发器
  * 可以跨作业运行，它为应用提交提供了REST接口。
  * 当一个应用被提交执行时，分发器就会启动并将应用移交给一个JM。
  * Dispatcher会启动一个Web UI，用来方便的展示和监听作业执行的信息。

### 作业提交流程

* 任务调度

![The processes involved in executing a Flink dataflow](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/processes.svg)

* Yarn提交流程

![Yarn任务提交流程](./img/任务提交流程(yarn).jpg)

### 任务和算子调用链

* 对于分布式执行，Flink将操作符子任务连接到一起，形成多个任务。每个任务由一个线程执行。将操作符链接到任务中是一种有用的优化:它减少了线程到线程的切换和缓冲开销，提高了总体吞吐量，同时减少了延迟。
* 一个特定算子的子任务(subtask)的个数被称之为其并行度(parallelism)。一般情况下，一个stream的并行度，可以任务就是其所有算子中的最大并行度（`因为slot共享的原因`）。

![Operator chaining into Tasks](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/tasks_chains.svg)

### TaskManger和Slots

#### task和slot的关系

* Flink中每一个TaskManager都是一个JVM进程，它坑会在独立的线程上运行一个或多个subtask
* 为了控制一个taskmanager能接受多个task，TaskManager通过task slot来进行控制(一个TaskManager至少有一个slot)

![A TaskManager with Task Slots and Tasks](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/tasks_slots.svg)

#### slot共享

* 默认情况下，flink允许字任务共享slot，即使是不同任务的字任务，这样的结果是一个slot可以保存作业的整个管道。
* 如果是同一步操作的并行subtask需要放到不同的slot，如果是先后发生的不同的subtask可以放在同一个slot中，实现slot的共享。
* 自定义slot共享组

```java
# 该算子之后的操作都放到一个共享的slot组里
.slotSharingGroup("a")
```

![TaskManagers with shared Task Slots](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/slot_sharing.svg)

### 并行子任务的分配

![并行子任务的分配](./img/并行子任务的分配.jpg)

## Flink执行分析

### 数据流(DataFlow)

* 运行时Flink上运行的程序会被映射成"逻辑数据流"(dataflows)，它包含了三个部分，sources、sink以及transformations。

### 执行图(ExecutionGraph)

* Flink的执行度分为4层:StreamGraph->JobGraph->ExecutionGraph->物理执行图
* **StreamGraph**:是根据用户通过 Stream API 编写的代码生成的最初的图。用来表示程序的拓扑结构。
* **JobGraph**：StreamGraph经过优化后生成了 JobGraph，提交给 JobManager 的数据结构。主要的优化为，将多个符合条件的节点 **chain 在一起作为一个节点**，这样可以减少数据在节点之间流动所需要的序列化/反序列化/传输消耗。
* **ExecutionGraph**：JobManager 根据 JobGraph 生成ExecutionGraph。**ExecutionGraph是JobGraph的并行化版本**，是调度层最核心的数据结构。
* **物理执行图**：JobManager 根据 ExecutionGraph 对 Job 进行调度后，在各个TaskManager 上部署 Task 后形成的“图”，并不是一个具体的数据结构。

![执行图](./img/执行图.jpg)

### 数据传输形式

* 一个程序中，不同的算子可能具有不同的并行度。
* 算子之间传输数据的形式可以是`one-to-one(forwarding)的模式`也可以是`redistributing`的模式，具体是哪种形式取决于算子的种类。
  * one-to-one:stream维护着分区以及元素的顺序(比如source和map之间)。这意味着map算子的子任务看到的元素的个数以顺序跟source算子的subtask产生的元素的个数、顺序相同。map、filter、flatMap等算子都是one-to-one的对应关系，类似于Spark的map、flatmap、filter等同样类似于窄依赖。
  * redistributing:stream的分区会发生改变。每个算子的subtask根据所选择的trasnsformation发送数据到不同的目标任务。例如keyBy基于hashCode重分区、而broadcast和rebalance会随机重新分区，这些算子都会引起redistributing过程，而redistribute过程就类似于spark中的shuffle过程。

### 任务链(operator chains)

* Flink采用一种称为任务链的优化技术，可以在特定条件下减少本地通信的开销。为了满足任务链的要求，必须将两个或多个算子设为相同的并行度，并通过本地转发(local forward)的方式进行连接。
* `相同的并行度`的one-to-one操作，flink这样相连的算子链接在一起形成一个task，原来的算子成为里面的subtask。
* `并行度相同，并且是one-to-one`操作，可以将俩个task合并。

![执行图](./img/任务链.jpg)

* 禁止合并任务链优化

```java
# 全局任务链切段
env.disableOperatorChaining()
# 切断算子任务链
datasource.uid("network-source").map(new WordCountMapFunction())
                .uid("map-id")
                .keyBy((KeySelector<Tuple2<String, Integer>, Object>) stringIntegerTuple2 -> stringIntegerTuple2.f0)
                .timeWindow(Time.seconds(30))
                .reduce(new SumReduceFunction()).disableChaining()
```

