# 概览

* Celeborn是一种Remote Shuffle Service解决方案，支持混合、独立、存算分离方式部署，来提供更加稳定、快速、弹性的Shuffle服务。
* Apache Celeborn 具有两个维度：
  - 第一，引擎无关。官方已经实现了 Spark 和 Flink。后续会进行MR和Tez的集成。
  - 第二，中间数据。这里是指包括 **Shuffle 和 Spill Data**。当我们把中间数据全部托管，它的计算节点就不需要这么大的本地盘了，也就意味着计算节点可以做到真正的无状态，这就可以实现在作业运行的过程中做到更好的伸缩，从而获得更好的弹性和资源使用率。**存算分离**

## 架构

* 在分布式计算引擎中，计算节点之间的数据交换很常见但是开销很大。这个开销来自于传统shuffle框架中的磁盘和网络效率问题（Mapper和Reducer之间的M*N）：

![](./img/shuffle架构.jpg)

* 除了效率低下外，传统的shuffle框架还需要计算节点中的大量本地存储来存储shuffle数据，从而阻止了存算分离架构的可能。
* celeborn通过以更有效的方式重新组织shuffle数据并把数据存储在单独的服务中来解决上述问题。Celeborn的架构如下：

![](./img/celeborn架构.jpg)

### 组件

* celeborn有三个主要组件为：Master、Worker、Client
  * Master管理Celeborn集群，基于Raft协议实现高可用(HA)。
  * Worker处理读写请求
  * Client向Celeborn集群写入/读取数据，并管理应用程序的Shuffle元数据。
* 在大多数分布式计算引擎中，通常有两种角色：一种是用于应用程序生命周期管理和任务协调，例如Spark中的`Driver`和Flink中的`JobMaster`；另一种是用于执行任务，例如Spark中的`Executor`和Flink中的`TaskManager`。
* 同样，Celeborn客户端也分为两种角色：LifecycleManager控制页面，负责管理应用程序的所有shuffle元数据；ShuffleClient，数据管理页面，负责从Workers读写数据。LifecycleManager类似于`Driver`或

## 安装

* 下载Celeborn:https://celeborn.apache.org/download/

## 配置

### 配置环境变量

```shell
mkdir cebeborn-0.3.0
tar -C cebeborn-0.3.0 -zxvf apache-celeborn-0.3.0-incubating-bin.tgz
export $CELEBORN_HOME=/Users/huangshimin/Documents/study/celeborn/cebeborn-0.3.0/apache-celeborn-0.3.0-incubating-bin
```

### 配置日志和存储

* 配置日志

```shell
cd $CELEBORN_HOME/conf
cp log4j2.xml.template log4j2.xml
```

* 配置存储

```shell
cd $CELEBORN_HOME/conf
echo "celeborn.worker.storage.dirs=/Users/huangshimin/Documents/study/celeborn/shuffle" > celeborn-defaults.conf
```

## 启动服务

### 启动Master

```shell
cd $CELEBORN_HOME
./sbin/start-master.sh

# 查看日志找到master节点host:ip
starting org.apache.celeborn.service.deploy.master.Master, logging to /Users/huangshimin/Documents/study/celeborn/cebeborn-0.3.0/apache-celeborn-0.3.0-incubating-bin/logs/celeborn-huangshimin-org.apache.celeborn.service.deploy.master.Master-1-B000000419982B.out
```

### 启动Worker

```shell
cd $CELEBORN_HOME
./sbin/start-worker.sh celeborn://172.21.195.62:9097

# 以下日志表示启动成功
23/08/25 14:42:24,112 INFO [main] MasterClient: connect to master 172.21.195.62:9097.
23/08/25 14:42:24,325 INFO [main] Worker: Register worker successfully.

```

## Spark On Celeborn

### spark-celeborn环境准备

```shell
cp $CELEBORN_HOME/spark/celeborn-client-spark-3-shaded_2.12-0.3.0-incubating.jar $SPARK_HOME/jars
```

### 启动spark shell

* 指定remote shuffle serivce配置

```shell
spark-shell \
--conf spark.shuffle.manager=org.apache.spark.shuffle.celeborn.SparkShuffleManager \
--conf spark.shuffle.service.enabled=false
```

* 模拟Shuffle

```scala
spark.sparkContext
  .parallelize(1 to 10, 10)
  .flatMap(_ => (1 to 100).iterator.map(num => num))
  .repartition(10)
  .count
```

* 观察celeborn master和worker日志

```
# master
23/08/25 15:14:03,735 INFO [dispatcher-event-loop-28] Master: Offer slots successfully for 10 reducers of local-1692947511566-0 on 1 workers.

# worker
23/08/25 15:15:54,378 INFO [worker-forward-message-scheduler] StorageManager: Updated diskInfos:
DiskInfo(maxSlots: 0, committed shuffles 1 shuffleAllocations: Map(), mountPoint: /, usableSpace: 10.6 GiB, avgFlushTime: 0 ns, avgFetchTime: 0 ns, activeSlots: 0) status: HEALTHY dirs /Users/huangshimin/Documents/study/celeborn/shuffle/celeborn-worker/shuffle_data
23/08/25 15:15:55,851 INFO [memory-manager-reporter] MemoryManager: Direct memory usage: 24.0 MiB/1024.0 MiB, disk buffer size: 0.0 B, sort memory size: 0.0 B, read buffer size: 0.0 B
23/08/25 15:16:05,856 INFO [memory-manager-reporter] MemoryManager: Direct memory usage: 24.0 MiB/1024.0 MiB, disk buffer size: 0.0 B, sort memory size: 0.0 B, read buffer size: 0.0 B
```

# 部署

## 服务器部署

### 部署celeborn

* 前置环境与概览/安装模块类似

### 修改Master、Worker内存

```shell
vim $CELEBORN_HOME/conf/
cp celeborn-env.sh.template celeborn-env.sh
vim celeborn-env.sh

#!/usr/bin/env bash
CELEBORN_MASTER_MEMORY=4g
CELEBORN_WORKER_MEMORY=2g
CELEBORN_WORKER_OFFHEAP_MEMORY=4g
```

### 修改配置

* 单master集群

```properties
vim celeborn-defaults.conf

# 配置信息
# used by client and worker to connect to master
celeborn.master.endpoints celeborn:9097

# used by master to bootstrap
celeborn.master.host celeborn
celeborn.master.port 9097

celeborn.metrics.enabled true
celeborn.worker.flusher.buffer.size 256k

# If Celeborn workers have local disks and HDFS. Following configs should be added.
# If Celeborn workers have local disks, use following config.
# Disk type is HDD by defaut. 
# celeborn.worker.storage.dirs /mnt/disk1:disktype=SSD,/mnt/disk2:disktype=SSD
celeborn.worker.storage.dirs=/Users/huangshimin/Documents/study/celeborn/shuffle

# 数据存储HDFS
# If Celeborn workers don't have local disks. You can use HDFS.
# Do not set `celeborn.worker.storage.dirs` and use following configs.
celeborn.storage.activeTypes HDFS
celeborn.worker.sortPartition.threads 64
celeborn.worker.commitFiles.timeout 240s
celeborn.worker.commitFiles.threads 128
celeborn.master.slot.assign.policy roundrobin
celeborn.rpc.askTimeout 240s
celeborn.worker.flusher.hdfs.buffer.size 4m
celeborn.worker.storage.hdfs.dir hdfs://<namenode>/celeborn
celeborn.worker.replicate.fastFail.duration 240s

# If your hosts have disk raid or use lvm, set celeborn.worker.monitor.disk.enabled to false
celeborn.worker.monitor.disk.enabled false

```

* ha集群

```properties
# used by client and worker to connect to master
celeborn.master.endpoints clb-1:9097,clb-2:9097,clb-3:9097

# used by master nodes to bootstrap, every node should know the topology of whole cluster, for each node,
# `celeborn.master.ha.node.id` should be unique, and `celeborn.master.ha.node.<id>.host` is required.
celeborn.master.ha.enabled true
celeborn.master.ha.node.id 1
celeborn.master.ha.node.1.host clb-1
celeborn.master.ha.node.1.port 9097
celeborn.master.ha.node.1.ratis.port 9872
celeborn.master.ha.node.2.host clb-2
celeborn.master.ha.node.2.port 9097
celeborn.master.ha.node.2.ratis.port 9872
celeborn.master.ha.node.3.host clb-3
celeborn.master.ha.node.3.port 9097
celeborn.master.ha.node.3.ratis.port 9872
celeborn.master.ha.ratis.raft.server.storage.dir /mnt/disk1/celeborn_ratis/

celeborn.metrics.enabled true
# If you want to use HDFS as shuffle storage, make sure that flush buffer size is at least 4MB or larger.
celeborn.worker.flusher.buffer.size 256k

# If Celeborn workers have local disks and HDFS. Following configs should be added.
# If Celeborn workers have local disks, use following config.
# Disk type is HDD by default.
celeborn.worker.storage.dirs /mnt/disk1:disktype=SSD,/mnt/disk2:disktype=SSD

# If Celeborn workers don't have local disks. You can use HDFS.
# Do not set `celeborn.worker.storage.dirs` and use following configs.
celeborn.storage.activeTypes HDFS
celeborn.worker.sortPartition.threads 64
celeborn.worker.commitFiles.timeout 240s
celeborn.worker.commitFiles.threads 128
celeborn.master.slot.assign.policy roundrobin
celeborn.rpc.askTimeout 240s
celeborn.worker.flusher.hdfs.buffer.size 4m
celeborn.worker.storage.hdfs.dir hdfs://<namenode>/celeborn
celeborn.worker.replicate.fastFail.duration 240s

# If your hosts have disk raid or use lvm, set celeborn.worker.monitor.disk.enabled to false
celeborn.worker.monitor.disk.enabled false

```

* Flink引擎额外配置

```properties
# if you are using Celeborn for flink, these settings will be needed
celeborn.worker.directMemoryRatioForReadBuffer 0.4
celeborn.worker.directMemoryRatioToResume 0.5
# these setting will affect performance. 
# If there is enough off-heap memory you can try to increase read buffers.
# Read buffer max memory usage for a data partition is `taskmanager.memory.segment-size * readBuffersMax`
celeborn.worker.partition.initial.readBuffersMin 512
celeborn.worker.partition.initial.readBuffersMax 1024
celeborn.worker.readBuffer.allocationWait 10ms
```

* 复制配置到celeborn全部节点
* 启动全部服务，如果安装的celeborn分布在所有节点的相同路径并且可以所有节点可以通过ssh连接，可以使用`$CELEBORN_HOME/sbin/start-all.sh`启动全部服务
* 启动成功会在Master日志下打印如下：

```
22/10/08 19:29:11,805 INFO [main] Dispatcher: Dispatcher numThreads: 64
22/10/08 19:29:11,875 INFO [main] TransportClientFactory: mode NIO threads 64
22/10/08 19:29:12,057 INFO [main] Utils: Successfully started service 'MasterSys' on port 9097.
22/10/08 19:29:12,113 INFO [main] Master: Metrics system enabled.
22/10/08 19:29:12,125 INFO [main] HttpServer: master: HttpServer started on port 9098.
22/10/08 19:29:12,126 INFO [main] Master: Master started.
22/10/08 19:29:57,842 INFO [dispatcher-event-loop-19] Master: Registered worker
Host: 192.168.15.140
RpcPort: 37359
PushPort: 38303
FetchPort: 37569
ReplicatePort: 37093
SlotsUsed: 0()
LastHeartbeat: 0
Disks: {/mnt/disk1=DiskInfo(maxSlots: 6679, committed shuffles 0 shuffleAllocations: Map(), mountPoint: /mnt/disk1, usableSpace: 448284381184, avgFlushTime: 0, activeSlots: 0) status: HEALTHY dirs , /mnt/disk3=DiskInfo(maxSlots: 6716, committed shuffles 0 shuffleAllocations: Map(), mountPoint: /mnt/disk3, usableSpace: 450755608576, avgFlushTime: 0, activeSlots: 0) status: HEALTHY dirs , /mnt/disk2=DiskInfo(maxSlots: 6713, committed shuffles 0 shuffleAllocations: Map(), mountPoint: /mnt/disk2, usableSpace: 450532900864, avgFlushTime: 0, activeSlots: 0) status: HEALTHY dirs , /mnt/disk4=DiskInfo(maxSlots: 6712, committed shuffles 0 shuffleAllocations: Map(), mountPoint: /mnt/disk4, usableSpace: 450456805376, avgFlushTime: 0, activeSlots: 0) status: HEALTHY dirs }
WorkerRef: null
```

### 部署Spark客户端

* 复制`$CEBEBORN_HOME/spark/*.jar`相关版本的jar包至`$SPARK_HOME/jars`
* 修改`spark-defaults.conf`配置

```shell
spark.shuffle.manager org.apache.spark.shuffle.celeborn.SparkShuffleManager
# must use kryo serializer because java serializer do not support relocation
spark.serializer org.apache.spark.serializer.KryoSerializer

# celeborn master
spark.celeborn.master.endpoints clb-1:9097,clb-2:9097,clb-3:9097
spark.shuffle.service.enabled false

# options: hash, sort
# Hash shuffle writer use (partition count) * (celeborn.client.push.buffer.max.size) * (spark.executor.cores) memory.
# Sort shuffle writer use less memory than hash shuffle writer, if your shuffle partition count is large, try to use sort hash writer.  
spark.celeborn.client.spark.shuffle.writer hash

# we recommend set spark.celeborn.client.push.replicate.enabled to true to enable server-side data replication
# If you have only one worker, this setting must be false 
# If your Celeborn is using HDFS, it's recommended to set this setting to false
spark.celeborn.client.push.replicate.enabled true

# Support for Spark AQE only tested under Spark 3
# we recommend set localShuffleReader to false to get better performance of Celeborn
spark.sql.adaptive.localShuffleReader.enabled false

# If Celeborn is using HDFS
spark.celeborn.worker.storage.hdfs.dir hdfs://<namenode>/celeborn

# we recommend enabling aqe support to gain better performance
spark.sql.adaptive.enabled true
spark.sql.adaptive.skewJoin.enabled true
```

### 部署Flink客户端

* 复制`$CEBEBORN_HOME/flink/*.jar`相关版本的jar包至`$FLINK_HOME/lib`
* 修改`flink-conf.yaml`配置

```yaml
shuffle-service-factory.class: org.apache.celeborn.plugin.flink.RemoteShuffleServiceFactory
celeborn.master.endpoints: clb-1:9097,clb-2:9097,clb-3:9097

celeborn.client.shuffle.batchHandleReleasePartition.enabled: true
celeborn.client.push.maxReqsInFlight: 128

# network connections between peers
celeborn.data.io.numConnectionsPerPeer: 16
# threads number may vary according to your cluster but do not set to 1
celeborn.data.io.threads: 32
celeborn.client.shuffle.batchHandleCommitPartition.threads: 32
celeborn.rpc.dispatcher.numThreads: 32

# floating buffers may need to change `taskmanager.network.memory.fraction` and `taskmanager.network.memory.max`
taskmanager.network.memory.floating-buffers-per-gate: 4096
taskmanager.network.memory.buffers-per-channel: 0
taskmanager.memory.task.off-heap.size: 512m
```

## Kubernetes部署

* 具体Kubernetes部署查看官方文档：https://celeborn.apache.org/docs/latest/deploy_on_k8s/#5-access-celeborn-service