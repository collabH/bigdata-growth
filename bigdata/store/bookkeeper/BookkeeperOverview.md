# 概览

* 一种可扩展、容错、低延迟的存储服务，针对实时工作负载进行了优化。它为构建可靠的实时应用程序提供了持久性、复制性和强一致性。

## 快速上手

### 安装

**环境依赖**

* unix环境
* jdk 1.8+

**下载二进制包**

* https://bookkeeper.apache.org/releases/

### 启动本地bookie

```shell
# 启动10个bookie
bin/bookkeeper localbookie 10
```

## 概念和架构

* BookKeeper是一种服务，它以[ledgers](https://bookkeeper.apache.org/docs/getting-started/concepts/#ledgers)的顺序提供日志条目流(又名记录)的持久存储。BookKeeper跨多个服务器复制存储的entity。

### 基本术语

* 日志的每个基本单元是一个entry(又名记录)
* 日志entry的流叫做ledgers
* 存储entry的ledger的独立服务叫做bookies

BookKeeper的设计是可靠的和高容错。Bookies可以出故障、错误数据或者丢弃数据，但是只要在集合中有足够多的bookies行为正确，整个服务就会正常运行。

### Entries

> **Entries**包含写入Ledgers的实际数据以及一些重要的元数据信息

Bookkeeper的entries是按照字节序列写入ledgers的，每个entry有以下字段：

| 字段名              | java类型 | 描述                                                         |
| ------------------- | -------- | ------------------------------------------------------------ |
| Ledger number       | `long`   | entry写入的ledger id                                         |
| Entry number        | `long`   | entry的唯一id                                                |
| Last confirmed (LC) | `long`   | 最后记录entry的ID                                            |
| Data                | `byte[]` | The entry's data (written by the client application)         |
| Authentication code | `byte[]` | The message auth code, which includes *all* other fields in the entry |

### Ledgers

> **Ledgers**是Bookkeeper的基本存储单位

Legders是entries的序列，每个entry的字节序列，entries被写入到ledger里:

* 按顺序
* 最多一次

这意味着legders具有*append-only* 的语义。entries一旦写入legders就不能修改。确定正确的写顺序是客户端应用程序的责任。

### Clients和Api

> Bookkeeper的客户端有俩种主要角色：可以创建和删除ledger，也可以从ledger读写entries。BookKeeper为ledger交互提供了低级和高级API。

* ledger API是一个低级API能够直接和ledger交互
* DistributedLog API是高级API，它使您可以使用BookKeeper而不直接与ledger交互。

### Bookies

> Bookies是处理Ledgers(更具体地说，是分类账的片段)的单个BookKeeper服务器。Bookies函数是一个整体的一部分。

* 一个Bookie升级一个单独的Bookkeeper存储服务，单个bookies存储ledgers的片段，而不是整个ledgers(为了性能考虑)。
* 每当将entry写入ledger时，这些entry将在整个集合中进行**条带化**(将entry写入bookies的子组而不是所有bookies)。

### Bookkeeper特点

* Bookkeeper起初借鉴NameNode的可以记录整个集群所有操作来保持容错的方式来设计，但是Bookkeeper的能力不限于NameNode，Bookkeeper支持以下特点:
  * 高效写入
  * 通过bookies集合内复制消息来实现高容错性
  * 通过**条带化**实现写操作的高吞吐量(可以跨任意多个bookies)

> 条带化技术就是**一种自动的将I/O 的负载均衡到多个物理磁盘上的技术**，条带化技术就是将一块连续的数据分成很多小部分并把他们分别存储到不同磁盘上去。 这就能使多个进程同时访问数据的多个不同部分而不会造成磁盘冲突，而且在需要对这种数据进行顺序访问的时候可以获得最大程度上的I/O 并行能力，从而获得非常好的性能。

### 元数据存储

* Bookkeeper的元数据存储主要维护Bookkeeper集群的全部元数据，例如ledger元数据、可用bookies等，当前Bookkeeper使用Zookeeper作为元数据存储。

### Bookies的数据管理

* Bookies以日志结构的方式管理数据，它使用三种类型的文件来实现:
  * journals
  * entry logs
  * index files

#### Journals

* journal文件包含BookKeeper事务日志.在对ledger进行任何更新之前，bookie确保将描述更新的事务写入非易失性存储。一旦bookie启动或旧的日志文件达到日志文件大小阈值，就会创建一个新的日志文件。

#### entry logs

* entry日志文件管理从BookKeeper客户端收到的被写入entry，来自不同ledger的entry按顺序聚合和写入，而它们的偏移量作为指针保存在ledger缓存中，以便快速查找。
* 一旦bookie启动或旧的entry日志文件达到entry日志大小阈值，就会创建一个新的entry日志文件。旧的entry日志文件一旦不与任何活动ledger相关联，就由垃圾收集器线程删除。（类似kafka底层segment）

#### Index file

* 为每个ledger创建一个index file，它包括一个header和几个固定长度的索引页，这些索引页记录存储在entry log文件中的数据偏移量。
* 由于更新索引文件会引入随机磁盘I/O，因此索引文件由在后台运行的同步线程惰性地更新。这确保了更新的快速性能。在将索引页持久化到磁盘之前，将它们收集到ledger cache中以供查找。

#### Ledger cache

* Ledger索引页被缓存再内存池中，这样可以更高效地管理磁盘磁头调度。

#### Adding entries

* 当客户端指定一个bookie写一个entry到ledger时，entry将会经过一下几个步骤被持久化到磁盘里:
  * entry被增量写入entry log里
  * entry的索引被更新到ledger cache里
  * entry更新相关的事务操作增量写入journal文件里
  * 想Bookkeeper客户端发送响应
* 出于性能原因，entry日志在内存中缓冲entries并批量提交它们，而ledger cache在内存中保存索引页并惰性地刷新它们。

#### Data Flush

* 在以下两种情况下，Ledger索引页会刷新到索引文件

  * ledger cache内存超过内存限制。没有更多的可用空间来容纳新的索引页。脏索引页将从ledger cache中驱逐并保存到索引文件中。
  * 后台线程同步方式负责定期刷新来自ledger cache的索引页到索引文件。

* 除了刷新索引页以外，同步线程还负责滚动journal文件，以防journal文件占用过多的磁盘空间。同步线程中的数据刷新流如下所示:

  * `LastLogMark`记录在内存中,`LastLogMark`表示在它之前的那些entries已经被持久化(保存到索引和entry file中)，它包含两个部分:
    * `txnLogId`(journal的文件ID)
    * `txnLogPos`(journal中的偏移量)
  * 脏索引页从ledger cache刷新到索引文件，并刷新entry log文件，以确保entry log文件中的所有缓冲entry都持久化到磁盘。

  理想情况下，bookie只需要刷新包含在**LastLogMark**之前的条目的索引页和entry log文件。但是，在与日志文件对应的ledger和entry日志中没有这样的信息。因此，线程在这里完全刷新ledger cache和entry日志，并可能刷新**LastLogMark**之后的entry。不过，多刷新不是问题，只是多余。

  * **LastLogMark**被持久化到磁盘，这意味着在**LastLogMark**之前添加的entry，其entry数据和索引页也被持久化到磁盘。现在是时候安全地删除在**txnLogId**之前创建的日志文件了。

* 如果Bookie在将LastLogmark持续到磁盘之前崩溃了，它仍然具有日记文件，其中包含entry、索引页可能没有持久化。因此，当该bookie重新启动时，它会检查日记文件以还原这些entry和数据。

* 使用上述数据flush机制，同步线程在Bookie关闭时跳过数据flush是安全的。但是，在entry记录器中，它使用缓冲通道分批编写entries，并且在关闭时可能会在缓冲通道中缓冲数据。Bookie需要确保进入journal在关闭过程中汇总其缓冲数据。否则，输入journal file会被部分entry损坏。

#### Data Compaction

* 在Bookies上，不同ledgers的entry在entry log文件中交织在一起。bookies运行垃圾收集器线程来删除不关联的entry log文件以回收磁盘空间。如果给定的entry log文件包含未被删除的ledgers中的entry，则entry log文件将永远不会被删除，占用的磁盘空间也永远不会被回收。为了避免这种情况，bookie服务器在垃圾收集器线程中compaction entry log文件以回收磁盘空间。
* 有两种运行频率不同的compaction方式:minor compaction和major compaction.。minor compaction和major compaction的区别在于它们的阈值和压缩间隔不同:
  * 垃圾收集阈值是那些未删除的ledgers占用的entry log文件的大小百分比。默认的minor compaction阈值为0.2，而major compaction阈值为0.8。
  * 垃圾收集间隔是运行压缩的频率。默认的minor compaction间隔为1小时，而major compaction阈值为1天。
* 如果相关阈值设置为0或负数，则表示关闭data compaction
* data compaction流程如下：
  * 线程扫描entry log文件以获取它们的entry log元数据，元数据记录了包含entry log及其相应百分比的ledgers列表。
  * 使用正常的垃圾收集流，一旦bookie确定ledgers已被删除，ledgers将从entry log元数据中删除，并且entry log的大小将减小。
  * 如果entry log文件的剩余大小达到指定的阈值，则entry log中的活动ledgers entry将被复制到新的entry log文件中。
  * 复制完所有有效entry后，将删除旧的entry log文件。

### Zookeeper metadata

* Bookkeeper需要Zookeeper存储ledger元数据，因此当你构建一个Bookkeeper客户端对象时需要传递Zookeeper服务器列表如下:

```java
String zkConnectionString = "127.0.0.1:2181";
BookKeeper bkClient = new BookKeeper(zkConnectionString);
```

### Ledger Manger

* ledger管理器处理ledger的元数据(存储在Zookeeper中)，Bookkeeper提供俩种类型的ledger管理器：flat ledger manger和hierarchical ledger manager，其都是继承`AbstractZkLedgerManager`抽象类

#### Hierarchical ledger manager

* 默认ledger manager，能够管理大于50000个的Bookkeeper ledgers元数据

# 部署

## 手动部署

Bookkeeper主要需要俩个组件：

* 一个ZooKeeper集群，用于配置和协调相关的任务
* 一个bookies集合

### 安装Zookeeper

[zookeeper安装文档](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html)

### 设置集群元数据

* 修改`bookkeeper-server/conf/bk_server.conf`配置文件

```shell
metadataServiceUri=zk+hierarchical://localhost:2181/ledgers
```

* 启动集群元数据服务

```shell
./bin/bookkeeper shell metaformat
```

* `metaformat`表示初始化集群元数据，每个只需要在Bookkeeper的任何一个bookie运行一次

### 启动Bookies

* 通过`bookkeeper`命令启动任意个bookie组成Bookkeeper集群，通过增加bookie个数可以获取高吞吐，bookie数量没有限制

```shell
bin/bookkeeper bookie
```

# 管理

## 管理Bookkeeper

* 这一part主要介绍如何部署、管理以及维护Bookkeeper，主要包含最佳实践和通用问题

### 前置条件

* 典型的Bookkeeper安装包含一组bookies和ZooKeeper quorum，bookie的确切数量取决于您选择的quorum模式、期望的吞吐量以及同时使用该安装的客户机数量。
* 最小的bookie数量取决于安装的类型:
  * 对于 *self-verifying* entry，应该运行至少三个bookies。在这种模式下，客户端将消息身份验证代码与每个entry一起存储。
  * 对于*generic* entry，需要最少运行4个bookies
* bookies的数量没有上限，区域于你需要的吞吐量

#### 性能

* 为了达到最佳性能，BookKeeper要求每个服务器**至少有两个磁盘**。也可以在单个磁盘上运行bookie，**但是性能会显著降低**。

#### Zookeeper

* 你可以使用BookKeeper运行ZooKeeper节点的数量没有限制。一台机器以独立模式运行ZooKeeper对BookKeeper来说就足够了，但为了提高弹性，我们建议在多台服务器上以 [quorum](https://zookeeper.apache.org/doc/current/zookeeperStarted.html#sc_RunningReplicatedZooKeeper)模式运行ZooKeeper。

### 启动停止Bookie

* 使用`nohup`来后台方式启动bookie，本地开发可以通过`localbookie`
* 前台方式启动bookie

```shell
bin/bookkeeper bookie
```

* 后台方式启动bookie

```shell
bin/bookkeeper-daemon.sh start bookie
```

#### Local Bookie

* 启动6个本地bookie，虽然是6个bookie，但是本质上在一个JVM进程内

```shell
bin/bookkeeper localbookie 6
```

### 配置Bookie

* 修改`conf/bk_server.conf`配置bookie

| Parameter           | Description                                                  | Default          |
| ------------------- | ------------------------------------------------------------ | ---------------- |
| `bookiePort`        | The TCP port that the bookie listens on                      | `3181`           |
| `zkServers`         | A comma-separated list of ZooKeeper servers in `hostname:port` format | `localhost:2181` |
| `journalDirectory`  | The directory where the [log device](https://bookkeeper.apache.org/docs/getting-started/concepts#log-device) stores the bookie's write-ahead log (WAL) | `/tmp/bk-txn`    |
| `ledgerDirectories` | The directories where the [ledger device](https://bookkeeper.apache.org/docs/getting-started/concepts#ledger-device) stores the bookie's ledger entries (as a comma-separated list) | `/tmp/bk-data`   |

* `journalDirectory`和`ledgerDirectories`的存储位置建议位于不同的磁盘上

### 日志配置

* Bookkeeper默认使用slf4j日志，要启用bookie的日志记录，需要创建`log4j.properties`文件，将BOOKIE_LOG_CONF环境变量指向配置文件。

```shell
export BOOKIE_LOG_CONF=/some/path/log4j.properties
bin/bookkeeper bookie
```

### 升级

* BookKeeper提供了一个用于升级文件系统的实用程序。您可以使用`bookkeeper`命令行工具的`upgrade`命令进行升级。当运行`bookkeeper upgrade`时，支持以下三种类型:

| Flag         | Action                                     |
| ------------ | ------------------------------------------ |
| `--upgrade`  | 执行升级操作                               |
| `--rollback` | 回滚到文件系统的初始版本                   |
| `--finalize` | Marks the upgrade as complete 标识升级完成 |

#### 升级模式

* 一个标准的Bookkeeper升级模式为先执行upgrade，再执行finalize，最后再启动bookie

```shell
bin/bookkeeper upgrade --upgrade
```

* 然后检查一切是否正常，然后干掉那个bookie。如果一切正常，完成升级

```shell
bin/bookkeeper upgrade --finalize
```

* 重启服务

```shell
bin/bookkeeper bookie
```

* 如果出现了错误，可以执行回滚

```shell
bin/bookkeeper upgrade --rollback
```

