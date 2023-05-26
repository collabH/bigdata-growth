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

