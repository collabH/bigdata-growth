# 概述

* Kudu是Apache hadoop平台的列式存储管理引擎。Kudu拥有Hadoop生态系统应用程序的共同技术属性:它运行在商用硬件上，具有水平伸缩能力，支持高可用性操作。

## 特点

* 快速处理OLAP负载。
* 与MapReduce，Spark和其他Hadoop生态系统组件集成。
* 与Apache Impala的紧密集成，使其成为使用HDFS与Apache Parquet的一个好的、可变的替代方案。
* 强大但灵活的一致性模型，允许你根据每个请求选择一致性需求，包括严格可序列化一致性选项。
* 强大的性能，可以同时运行顺序和随机的工作负载。
* 易于维护和管理。
* 高可用，tablet servers和Master使用Raft Consensus算法，该算法确保只要有超过半数的副本可用，tablet就可以读写。例如，如果3个副本中的2个或5个副本中的3个可用，那么tablet就是可用的。
* 结构化数据模型。

### 和HDFS、HBASE的区别

![](./img/kudu和其他存储引擎的区别.jpg)

* HDFS是一个仅支持追加写的文件系统，对于需要顺序扫描大规模数据的存储引擎而言，它是表现最好的。
* Hbase支持实时随机读/写，以及OLTP应用需要的其他特性，HBase适合那种在线、实时、高并发，其中大多数操作都是随机读/写或短扫描的环境。

![](./img/几个存储引擎的对比.jpg)

### Kudu的高层设计

* 运行用户尽可能快的扫描数据，达到在HDFS中扫描原始文件速度的两倍。
* 运行用户已经可能快地执行随机读/写，响应大约为1ms
* 以高可用、容错、持久的方式实现以上这些目标。

## Kudu-Impala集成功能

* CREATE/ALTER/DROP TABLE
  * impala支持使用Kudu作为持久层创建、修改和删除表。
* INSERT
  * 数据可以使用与其他Impala表相同的语法插入到Impala中的Kudu表中，就像那些使用HDFS或HBase持久化的表一样。
* UPDATE/DELETE
  * Impala支持Upadte和DELETE SQL命令修改已经存在的数据在Kudu表中一行一行或一批一批。
* Flexible Partitioning(灵活分区)
  * 与Hive中的表分区类似，Kudu允许您通过hash或范围动态地将表预分割为预定义数量的tablet，以便在集群中均匀地分发写操作和查询。可以按任意数量的主键列、任意数量的散列和可选的分隔行列表进行分区。
* 并行扫描
  * 为了在现代硬件上实现可能的最高性能，Impala使用的Kudu客户端在多个tablet上并行扫描。
* 高性能查询
* 需要开启Hive的metastore服务。

## 架构图

![Kudu Architecture](https://kudu.apache.org/docs/images/kudu-architecture-2.png)

* 与HDFS和Hbase相似，Kudu使用单个的Master节点，用来管理集群的元数据，并且使用任意数量的Tablet Server(类似于Hbase的RegionServer角色)节点来存储实际数据。可以部署HA Master来提高容错能力。

## 概念和术语

### Columnar Data Store

* Kudu是一个列式存储引擎，一个列式数据存储引擎将数据存储在强类型的列。

### Read Efficiency

* 为了分析查询，你可以读取单独的列，或一部分列，当忽略其他列时，这意味着您可以在读取磁盘上最小数量的块的同时完成查询。作为行式存储，如果你只需要返回一部分的列的数据的话，你需要读取一整行的数据。

### Data Compression

* 因为给定的列只包含一种数据类型，所以基于模式的压缩比在基于行的解决方案中使用的混合数据类型的压缩效率高几个数量级。结合从列读取数据的效率，压缩允许您在完成查询的同时从磁盘读取更少的块。

### Table

* Table是存储数据的Kudu格式。一个Table有一个schema和一个完全有序的主键。一个表被分割成称为tablet的段。

### Tablet

* 是kudu表的`数据水平分区`，一个表可以划分成为多个tablet（类似hbase region）
* 每个tablet存储着一定连续range的数据(key)，且tablet两两之间的range不会重叠。
* 一个tablet是一个表的连续端，类似于其他存储引擎的一个分区。给定的tablet可以在多个tablet servers上存在副本，在任意给定的时间点其中一个副本被认为是Leader Tablet。任何副本都可以进行读和写操作，这需要服务于tablet的一组tablet服务器达成一致。

### Tablet Server从角色

* 相当于HDFS的DataNode和Hbase的RegionServer的混合体，tablet server的作用是执行所有与数据相关的操作：存储、访问、编码、压缩、compaction和复制。
* tablet server存储向kudu client提供tablet服务。对于给定的tablet，一个tablet server充当其leader，其他副本作为这个tablet的follower。只有leader能够提供写请求，leader和follower可以提供读服务。一个tablet server可以服务多个tablet，一个tablet可以由多个tablet server提供服务。
* Kudu最多支持300个tablet server，但是为了最高的稳定性，比建议tablet server超过100个
* 建议每个tablet server最多包含2000个tablet（包含副本）
* 建议每个table在每个tablet server上最多包含60个tablet（包含副本）
* 建议每个tablet server最多在磁盘上存储8 TB的数据。服务器上所有磁盘的容量之和可以超过8 TB，并且可以和HDFS共享。但是，我们建议Kudu的数据不要超过8TB。
* 为了获得对大事实表的最优扫描性能，建议保持一个tablet对应一个CPU核的比例。不要将被复制的表计算在内，应该只考虑Leader tablet的数量。对于小维度的表，可以只分配几个tablet。

### Master

* 存储表名、列名、列类型和数据位置之类的元数据，以及状态之类的信息，比如正在被创建、运行等。
* master持有全部的tablet，tablet server和catalog table和其他元数据在这个集群中。在任意时间只能存在一个master.如果当前leader断开链接，会有新的master通过raft算法选举产生。
* master还可以协调客户端的元数据操作，例如当创建一张新表时，客户端内部发送这个请求到master，master会将新表的元数据写入到catalog table中，并且协调在tablet servers创建tablets的过程。
* 全部的master的数据都存储在`一个tablet`中，可以将数据复制到全部的slave master中。
* tablet server的心跳通过固定间隔发送到master(默认是1秒一次)

### **Raft Consensus Algorithm**

* kudu使用[Raft consensus algorithm](https://raft.github.io/)作为状态容错和一致性，对常规的tablets和master data都是适用。通过Raft，一个tablet的多个副本选出一个leader，负责接受并复制写入到follower副本的操作。一旦在大多数副本中都保留了写操作，便会向客户端确认。 给定的一组N个副本（通常3个或5个）能够接受最多（N-1）/ 2个错误副本的写入。

### catalog table

* 一个catalog table是kudu的核心位置，它存储的信息关于table和tablets。这个catalog table可能不能被直接读取或者写入。相反，只能通过在客户机API中公开的元数据操作来访问它。
* 一个catalog table存储元数据的俩个分类
  * tables
    * table schema，locations，states
  * tablets
    * 当tablet server的每个tablet都有副本时，存储的事一组已经存在的tablets的state，开始和结束的key。

### logical replication

* Kudu复制操作，不是磁盘上的数据。这被称为逻辑复制，而不是物理复制。
* 这有几个优点：
  * 虽然插入和更新确实通过网络传输数据，但删除不需要移动任何数据。删除操作被发送到每个tablet服务器，服务器在本地执行删除操作。
  * 物理操作，例如压缩，不需要在网络上传输Kudu中的数据。这与使用HDFS的存储系统不同，在HDFS中，块需要通过网络传输，以实现所需的副本数量。
  * Tablet不需要在同一时间或同一时间表上执行压缩，或者在物理存储层上保持同步。这减少了所有tablet server同时经历高延迟的机会，因为紧凑或沉重的写负载。

## 写入与更新

### 写入操作步骤

1. 写操作被提交到一个tablet的Write Ahead Log（WAL）
2. 把插入操作添加到MemRowSet中。
3. 当MemRowSet满了之后，就被刷新(flushed)到磁盘，成为DIskRowSet

#### MemRowSet

* 每次Kudu收到新数据时，这份数据存储的地方成为MemRowSet，类似于一个临时的写缓冲区，当MemRowSet满时，就被刷新到磁盘。

#### 对表的首次插入

![](./img/表的首次插入.jpg)

#### 插入已经存在的记录

![](./img/插入已经存在的记录.jpg)

## Kudu中的概念和机制

### 热点

* 当大部分的读写操作都落到同一个服务器上时，就会产生所谓的热点问题，如果想达到数据完美的分布，让所有读写请求均匀的分配在集群的所有节点上。

#### 设计表考虑的问题

* 读操作的访问模式（吞吐率和延迟）
* 写操作的访问模式（吞吐率和延迟）
* 存储开销（压缩比）

### 分区

* kudu支持范围分区和哈希分区

## 使用场景

* 流输入接近实时可用性
* 具有广泛变化的访问模式的时间序列应用
* 预测模型
* 将Kudu中的数据与旧版系统结合

# Kudu安装

## Docker安装

### 环境要求

* 4 CPUs
* 6GB Memory
* 50GB DIsk

### 创建docker-compose.yaml

```yaml
version: "3"
services:
  kudu-master-1:
    image: apache/kudu:latest
    ports:
      - "7051"
      - "8051"
    command: ["master"]
    environment:
      - KUDU_MASTERS=kudu-master-1,kudu-master-2,kudu-master-3
  kudu-master-2:
    image: apache/kudu:latest
    ports:
      - "7051"
      - "8051"
    command: ["master"]
    environment:
      - KUDU_MASTERS=kudu-master-1,kudu-master-2,kudu-master-3
  kudu-master-3:
    image: apache/kudu:latest
    ports:
      - "7051"
      - "8051"
    command: ["master"]
    environment:
      - KUDU_MASTERS=kudu-master-1,kudu-master-2,kudu-master-3
  kudu-tserver:
    image: apache/kudu:latest
    depends_on:
      - kudu-master-1
      - kudu-master-2
      - kudu-master-3
    ports:
      - "7050"
      - "8050"
    command: ["tserver"]
    environment:
      - KUDU_MASTERS=kudu-master-1,kudu-master-2,kudu-master-3
    deploy:
      replicas: 3
```

* docker-compose up -d

### 访问Web-UI

* hadoop:8050

### 校验集群健康状态

```shell
# 进入容器
docker exec -it $(docker ps -aqf "name=kudu-master-1") /bin/bash
# 校验集群健康状态
kudu cluster ksck kudu-master-1:7051,kudu-master-2:7151,kudu-master-3:7251
# 配置KUDU用户名
export KUDU_USER_NAME=kudu
kudu cluster ksck localhost:7051,localhost:7151,localhost:7251
```

## 服务器安装

### 环境要求

#### 硬件

* 一个或多个服务器运行Kudu master，如果需要高可用最好3个master
* 如果开启tablet的副本机制，最好需要3个tablet server
* ntp 时间同步
* JDK1.8

## 根据操作系统

[安装文档](https://kudu.apache.org/docs/installation.html#osx_from_source)

