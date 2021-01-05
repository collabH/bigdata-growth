# Kudu优势

## Kudu的特点

![img](https://pic2.zhimg.com/80/v2-bb7f77cd4fabae4cd312d8fdeb67ab65_1440w.jpg)

## 解决的问题

* 打通历史数据和实时数仓的界限，将实时数据和历史数据放在同一个存储中，并且进行分析。

# Kudu原理配置

## Table Schema

* Kudu支持显式的Table Schema，用户可以细粒度指定列的类型和压缩格式，不同于HBase，Kudu对于BI系统交互优势更大

### Kudu主键的含义

* Kudu必须指定主键，主键在LSM(log-structed-merge-tree)存储模型很重要，有主键可以对数据块进行排序，而排过序的数据块使用很少的内存便可以 Merge，Kudu 也是使用类 LSM 模型。
* 另外，主键可以完成数据去重，这对于实现严格一次(Exactly Once)语义非常有帮助。
* 另外主键是 Kudu 支持随机存取的重要工具，同时可以提升 Scan 性能 

## Write operations

* 写操作需要通过客户端进行，包括 Java/Python/C++
* 写操作必须指明主键
* 支持 bulk 操作以降低批量处理网络开销
* 不支持跨行的事务

## **Read operations**

- 支持 Scan 操作读取数据
- Scan 操作可以支持谓词下推(Predicate pushdown)
- 支持两种谓词操作: 1. 字段与常数的比较 2. 主键键值Range扫描
- 谓词下推直接透传到Kudu后台，以便减少磁盘和网络开销
- 支持 `projection`, 也就是仅选择需要的字段，这也是列式存储的核心能力

## **Consistency Model**

* Kudu 提供两种一致性模型: `(快照一致性)snapshot consistency` 和 `(外部一致性)external consistency guarantee`
* 快照一致性提供的级别是: 客户端可以读到自己写的，但是不能实时读到别人写的 (read-your-writes)。
* 而外部一致性则是需要用户额外的代码实现的(client propagate)，会复杂很多。Kudu 参考 Span，额外提供了一个 `commit-wait` 的外部一致性选项。这个方案相比 client propagate 会简单很多，但是要求服务器配置 NTP 服务做时间校准。

## Kudu Master

* Kudu Master做一些轻负载任务，如下
  * Catalog manager，对表进行管理，包括表的Schema，副本级别等。当表创建/删除/更新时，Master 会协调这些操作对所有的 tablets 生效
  * Cluster coordinator，跟踪 Tablet Server 是否存活，当 Server 节点挂掉时候，对数据副本进行调度维持期望副本数。
  * Tablet directory，跟踪每个 Tablet server 有哪些 tablet 副本。这样客户端就可以知道应该去哪里读取数据。

### Catalog manager

* Kudu Master 内部维护了一个 单tablet 的 Catalog table, 用于记录表meta信息(不能被用户访问)。
* Catalog table 将会一直在内存缓存，并且维护了一些最基础的信息，如当前表的状态(running, deleting ...)、Table 包含哪些 tablet。
* Catalog table 和其余的表一样通过 Raft 协议进行多副本同步，但不同的是，Follower 不参与处理请求。所以 Master Leader 节点将会是系统的一个单点瓶颈。
* Kudu 在 Client 进行了一些缓存，避免 Client 需要频繁与 Master 进行交互。

### Cluster Corrdination

和 HDFS 一样，Tablet server 会在启动时向所有的 Master 汇报自己的负责的 Tablets 集合(这就要求在 Tablet server 启动时，所有的 Master 都是可以 Ping 通的)。

与多数分布式系统不同的是，Kudu Master 对系统更像是一个观察者。Master 并不会去主动探测副本状态，坏掉的副本是通过以下方式提交给 Master:

- 首先 tablet 的多个副本通关 Raft 协议进行复制
- 当一个副本宕掉时(一段时间没有心跳)，tablet leader 会发起提议，驱逐宕掉的副本
- 一旦提议通过，tablet leader 会将副本被驱逐报告给 Master，由 Master 做进一步处理
- Master 根据集群的全局视野，选取一个合适的服务节点放置新的副本，并建议 tablet leader 进行配置
- tablet leader 会发起新的提议，尝试将新的副本加入，最后报告给 Master

当副本数多于预期时(由于提议，该副本应该删除)，Master 会发送 DeleteTablet RPC 给对应的 Node 直到 PRC 成功。

可以看到 Kudu Master 角色承担的角色会比 HDFS NameNode 要轻量很多，NameNode 因为需要直接维护Block 的复制，在集群文件非常多时，NameNode 直接成为系统瓶颈 (HDFS 目前文件数量基本上不能超过 1 亿，并且在超过千万级时，已经需要数分钟重启，如果shutdown时未能保存 cache，甚至需要数小时来重启)。

### Tablet Directory

Kudu 虽说有多个 Master，但是仅有 Leader 可以处理客户端请求 (可能考虑到强一致性模型会降低可用性)，这就要求 Leader 的工作要非常轻量。

对应的，Kudu 的 Client 端要复杂一些，需要 Cache 最近访问的 Tablet 信息，例如 分区的Key或者Raft配置。

如果客户端的信息已经失效 (例如去访问Tablet Leader 写数据，但是对方已经不是 Leader)，服务端会直接拒绝请求，然后客户端需要和 Master 更新最新的配置信息。

因为 Master 的数据会全部 Cache 到内存里面，就算是单节点，可以支撑非常大的 QPS。并且在之前的讨论已经可以看到，Master 的配置就算落后历史版本，客户端依然会重试获取最新版本，所以其实 Master 并不要求强一致性，所以 Master 其他副本实际上也可以处理请求 (只是服务质量会变差，一般不需要这样)

# Tablet存储相关

## 设计相关

* 在 HDFS 和 HBase 之间取得一个比较好的折衷
* 尽可能快的扫描数据(支持按列)，甚至比 HDFS 扫描还要快
* 尽可能快的随机读写，ms 级响应时延
* 高可用、容错、持久性、响应时长稳定
* 可以充分利用现代化的硬件设施，如 SSD NVMe

## RowSet

因为需要支持 OLAP，列式存储是刚需。

同大多数面向列式存储的格式一样，数据被分成数个大小近似的块，在 Kudu 中这些块成为 RowSets, 在 HBase 中为 Region, 在 Parquet 为 Row Group, 在 ORC 中为 Stripe。

但列式存储并不可以逐行写入，需要内存 Cache 一段时间，再批量 Flush 到磁盘。因此数据会由在磁盘的RowSets(DiskRowSets) 和在内存中的 RowSets (MemRowSets) 组成。

后台有任务，定期将 MemRowSets 刷写到 Disk。MemRowSets 刷写肯定是需要时间的，期间新的插入怎么办？Kudu 的做法是:

1. 刷写开始时，立即启用一个新的 MemRowSets，用于接收用户写入
2. 旧的 MemRowSets 依然可以被读取数据
3. 期间对 旧的 MemRowSets 的操作，同样会被追加到刷写后的 DiskRowSets

## MemRowSet实现

![img](https://pic2.zhimg.com/80/v2-c74cf1feda96eb38805ee245fd835f9d_1440w.jpg)

MemRowSet 因为需要快速支持随机存储及主键范围扫描，所以需要是顺序组织在内存中，Tree 可以算是一个比较理想的数据结构。

为了提升查询效率，选择了 B-tree (基于 MassTree 的改良版本)，进行了一些优化:

- 不支持删除，因为对于 Kudu 来说，删除是追加记录 (在后续的 Table Compact 中真正被删除)
- 对存储数据的 Leaf Node 增加了一个 Next 指针，一般的数据库系统都是增加这个优化，用于提升 Scan 性能。

MemRowSet 并不是以列式存储在内存中, 而是正常的 行式存储, 即 B-Tree 有指针指向单行数据。

## DiskRowSet实现

![img](https://pic4.zhimg.com/80/v2-ab89f645dd7087e3b4fa98e8242f403f_1440w.jpg)

因为列式存储是很难去更新的，因此，目前的方案都是追加新的记录。所以宏观上 DiskRowSets 有下面的特征:

- 会分成多个 32MB 的文件，MemRowSets 在刷写为 DiskRowSets 时，会按照 32 MB 的大小分成多个文件输出
- 每个文件包含 Base Data、Delta Stores 两部分。Base Data 是原始数据，Delta Stores 是更新/删除记录。

### Base Data

* Base Data (如上图所示) 按照列式存储，并且对每种数据类型，辅以不同的编码。这也是和 HBase 一个显著的不同点，HBase 只有二进制数据类型，因此并不能对每种数据选择更合适的编码。另外，可选择进一步压缩 (gzip, bzip2 ...), Kudu在列式存储上的能力基本和 Parquet 是类似的。
* 除了用户定一个列外，Kudu 额外将编码过的 Primary key 索引，以及针对这个索引的`Bloom filter`。Bloom filter 可以辅助 Insert 操作，判断`待插入的 key` 是否在当前的 DiskRowSet 存在。

### **Delta Stores**

* 更新/删除的部分，会放在 Delta Stores (如上图所示) 部分，其分为 DeltaMemStore(B-Tree) 和 DeltaFile 两部分。
* Delta Stores 的 key 并不是 Primary key 而是 row-offset。这里算是 Kudu 牺牲写性能以优化读性能。

### 更新流程

- 首先通过 Primary key 的 Bloom filter 索引确定待修改的 Primary key 是否可能在当前的 DiskRowSet
- 如果存在，查找 Primary key B-Tree 索引，找到对应的 Page
- 对 Page 内容进行二分查找(内存中)，找到 Primary key 后便可以计算出 row-offset
- 将 row-offset 及对应的修改操作 append 到 Delta Stores 末尾

## Delta Flushes

* Delta Stores 在内存中的形式为 DeltaMemStore，也会定期刷写到磁盘成为 DeltaFile。这部分流程和之前的 MemRowSets 刷写 DiskRowSets 非常相似。

## INSERT path

### **Kudu 仅允许相同主键出现一次，但如何实现呢？**

* 数据从 MemRowSets 落地到 DiskRowSets, 多个 DiskRowSets 的数据并非是全局有序的。意味着要确定待插入的 Primary key 是否已经存在，需要遍历所有的 DiskRowSets。因为一个 Tablet 可能有成百上千的 DiskRowSets，所以要求这个速度应该尽量的快。
* 因此，上文提到的 Primary key Bloom Filter 便派上了用场。需要注意的是 Bloom Filter 只能确保 Primary key 不存在，但是不能保证 Primary key 一定存在。因此 Bloom Filter 实际上相当于一个剪枝(Purning)的作用。
* Primary key Bloom Filter 会以 LRU Cache 在内存中，Kudu 会尽量保证 Bloom Filter 会一直存放在内存中。
* 此外，就像Parquet/ORC一样，DiskRowSet 存储了 Primary key 的最大值/最小值，并且这些范围值使用 interval tree去组织起来，这样可以在针对 Primary key 的查询时做进一步的剪枝。并且interval tree可以作为 compaction 时选取特定几个 DiskRowSet 的依据。
* 对于不能被剪枝的 DiskRowSet，需要使用 Primary key (B-Tree) 去判断是非已经存在。这当然是很慢的，考虑到局部性原理，所以 Kudu 会缓存被访问过的 Primary key page。

## Read Path

* Kudu 数据读取，在内存中的数据结构，和 DiskRowSet 相似为列式结构，这有助于提高读取效率。
* 同 Parquet/ORC 一样，Kudu 支持谓词下推。Kudu 会首先检查是否与 Primary key 相关的谓词，如果有，就可以对缩小所需要扫描的行范围。最终 Primary key range => row-offset range 然后进行下一步查询。
* 然后 Kudu 对每一列进行扫描 (当然仅获取projection所需的字段)，并且进行必要的解码。
* 最好，需要查询 Delta Store 去看对这些行是否有额外的更新，对照当前的 MVCC 快照版本，选取更改项并应用于加载到内存中的数据。因为 Delta Store 是以 row-offset 作为主键，所以这个过程会更快 (相比于 Primary key)，这就是为什么插入时要费那么多功夫去获取 row-offset，可以理解为 Kudu 在 Insert/Read 的性能平衡中更倾向于优化 Read 性能。
* 最后 Kudu tablet server 响应 PRC 请求，对于 Scan 来说，肯定需要多次 PRC 请求，服务端会记录当前的 scaner 状态，客户端需要请求同一个 tablet server 来快速获取后续的数据。

## **Delta Compaction**

* 从之前的读取路径，我们知道每次读取数据，都需要加载 Delta Store 以将更改应用到查询的数据行上。让 Delta Store 变得非常大的时候，这显然是一个非常严重的性能问题。因此 Kudu 会定期进行一个叫 `Delta Compaction` 的操作，目的便是将 Delta Store 的数据合并到 Base Data 里面。
* 这个合并的时机通过 Delta Store 行数与 Base Data 行数的比例来确定。Delta Store 行数占比过多便会执行合并。
* 并且 `Delta Compaction` 进行了一些细节优化以提升性能。例如会识别这些更改是否大部分都是针对于某一列进行的更改，如果是，便可以仅重写对应的列，而不动其他的列，以提升性能 (个人感觉这个优化复杂度颇高啊，并且只能适用于那些长度不会变的字段，如果要直接追加的话，感觉存储又会比较浪费)

## **RowSet Compaction**

![img](https://pic3.zhimg.com/80/v2-fce7c3b9a57fa0b4808178496afab256_1440w.jpg)

* Compaction 是 LSM 数据模型的典型操作。因为数据是经过排序的，所以多个 RowSets 只需要很少的运行时内存便可以完成 Compaction。
* Compaction 主要达到下面的目标:
  - 真正物理移除待删除数据行
  - 减少多个 RowSets Primary Key 的交叉

### **减少多个 RowSets Primary Key 的交叉的好处**

- 数据插入更快，Primary Key 的 Bloom Filter 的剪枝效果会更明显
- 数据查询会更快，例如上图中，查询 key = 29999 的记录，Compaction 之前需要在所有 DiskRowSets 遍历，之后直接去中间的 DiskRowSet 就可以了

但是对于列式存储来说，Compaction 也是一个昂贵的操作，具体如何选择被 Compaction 的 RowSet 也是问题

## 后台调度任务

* MemRowSets 刷写磁盘变为 DiskRowSets的任务
* MemDeltaStore 刷写磁盘变为 DeltaFiles的任务
* Delta Compaction: 将 Delta Store 部分数据合并到 Base Data 提升读性能
* RowSet Compaction: 将多个 Disk Rowsets 进行 Compaction, 提升读写效率，物理删除数据行

这些任务会被后台线程调度。注意这些调度不是周期性或者被动触发，而是被工作线程主动调度，并且后台工作线程会一直处于工作状态。

* 前文所提到的一个问题: 具体如何选择被 Compaction 的 RowSet ? Kudu 的解决方案是将其转化为一个背包问题。每个 DiskRowset 都需要衡量如果被 Compaction，所带来的收益有多高。进而演化成典型的背包问题。(但这里其实有一个不理解的地方，像减少 Primary Key 交叉这种情况，并不是单个 DiskRowset 可以衡量出来的啊，有空需要看下源码)
* 后台工作线程会一直处于工作状态，当插入操作比较频繁时，会更多时间片用于 MemRowSets 刷写磁盘变为 DiskRowSets，当插入操作比较少时候，会花更多时间片用于 Delta Compaction/RowSet Compaction，以提升长久的读取和插入性能。

# Hadoop支持

Kudu 可以与 MapReduce、Spark 进行联动，并支持下面的特性:

- 数据局部性 (Data Locality)
- 选取特定列 (Columnar Projection)
- 谓词下推 (Predicate pushdown)

Kudu 与 Impala 结合更为紧密，额外提供下面的能力:

- 数据表定义/修改 (DDL extensions)
- 数据曾删除查改 (DML extensions)