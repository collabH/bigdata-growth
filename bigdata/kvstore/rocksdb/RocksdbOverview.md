# 概述

* RocksDB是基于key/value的存储引擎，其中键和值是任意字节流。它是在Facebook上基于LevelDB开发的，并为LevelDB api提供向后兼容支持。它支持点查找和范围扫描，并提供不同类型的ACID保证。
* RocksDB有三种基本的数据结构：mentable，sstfile以及logfile。mentable是一种内存数据结构——所有写入请求都会进入mentable，然后选择性进入logfile。logfile是一种有序写存储结构。当mentable被填满的时候，他会被刷到sstfile文件并存储起来，然后相关的logfile会在之后被安全地删除。sstfile内的数据都是排序好的，以便于根据key快速搜索。

![](./img/Rocksdb结构.png)

## 特性

### 列族

* RocksDB支持将一个数据库实例按照许多列族进行分片。所有数据库创建的时候都会有一个用"default"命名的列族，如果某个操作不指定列族，他将操作这个default列族。
* RocksDB在开启WAL的时候保证即使crash，列族的数据也能保持一致性。通过WriteBatch API，还可以实现跨列族的原子操作。

### 更新操作

* 调用Put API可以将一个键值对写入数据库。如果该键值已经存在于数据库内，之前的数据会被覆盖。调用Write API可以将多个key原子地写入数据库。数据库`保证在一个write调用中，要么所有键值都被插入，要么全部都不被插入`。如果其中的一些key在数据库中存在，之前的值会被覆盖。

### get,iterators以及Snapshots

* 键值对的数据都是按照二进制处理的。键值都没有长度的限制。Get API允许应用从数据库里面提取一个键值对的数据。MultiGet API允许应用一次从数据库获取一批数据。使用MultiGet API获取的`所有数据保证相互之间的一致性（版本相同）`。
* 数据库中的所有数据都是逻辑上排好序的。应用可以指定`一种键值压缩算法来对键值排序`。Iterator API允许对database做RangeScan。Iterator可以指定一个key，然后应用程序就可以从这个key开始做扫描。Iterator API还可以用来对数据库内已有的key生成一个预留的迭代器。一个在指定时间的一致性的数据库视图会在Iterator创建的时候被生成。所以，通过Iterator返回的所有键值都是来自一个一致的数据库视图的。
* Snapshot API允许应用创建一个`指定时间的数据库视图`。Get，Iterator接口可以用于`读取一个指定snapshot数据`。当然，Snapshot和Iterator都提供一个指定时间的数据库视图，但是他们的内部实现不同。`短时间内存在的/前台的扫描最好使用iterator，长期运行/后台的扫描最好使用snapshot`。Iterator会对`整个指定时间的数据库相关文件保留一个引用计数，这些文件在Iterator释放前，都不会被删除`。另一方面，`snapshot不会阻止文件删除`;作为交换，压缩过程需要知道有snapshot正在使用某个版本的key，并且保证不会在压缩的时候删除这个版本的key。
* Snapshot在数据库重启过程不能保持存在：reload RocksDB库会释放所有之前创建好的snapshot。

### 事务

* RocksDB支持多操作事务。其分别支持`乐观模式和悲观模式`

### Prefix Iterators

* 多数LSM引擎无法支持高效的`RangeScan API`，因为他需要对每个文件都进行搜索。不过多数程序也不需要对数据库进行纯随机的区间扫描；多数情况下，应用程序只需要扫描指定前缀的键值即可。RocksDB
  就利用了这一点。应用可以指定一个`键值前缀，配置一个前缀提取器`。针对`每个键值前缀，RockDB都会其来存储bloomfilter`。通过bloom，迭代器在扫描指定前缀的键值的时候，就可以避免扫描那些没有这种前缀键值的文件了。

### Persistence

*  RocksDB有一个Write Ahead Log(WAL).所有的写操作(Put, Delete和Merge)都存储在内存中称为memtable的缓冲区中，也可以插入到WAL中，当重启的时候，它重新处理日志中记录的所有事务。
* WAL日志可以通过配置，存储到跟SST文件不同的目录中。对于那些将所有数据存储在非持续性快速存储介质的情况，这是非常有必要的。同时，你可以通过`往较慢但是持续性好的存储介质上写事务日志，来保证数据不会丢失`。
* 每次写操作都有一个标志位，通过WriteOptions来设置，允许指定这个Put操作是不是需要写事务日志。WriteOptions同时允许指定在Put返回成功前，是不是需要调用sync。
* 在内部，RocksDB使用批处理提交机制将事务批处理到日志中，这样它就可以使用一个fsync调用提交多个事务。

### 数据校验

* RocksDB使用校验和来检测存储中的损坏。这些校验和针对每个SST文件块(通常在4K到128K之间)。块一旦写入存储，就永远不会被修改。RocksDB还维护一个完整的文件校验和。
* RocksDB动态检测并利用CPU校验和卸载支持。

### 多线程压缩

* 如果应用程序对已经存在的key进行了覆盖，就需要使用压缩将多余的拷贝删除。压缩还会处理删除的键值。如果配置得当，压缩可以通过多线程同时进行。
* 整个数据库都被按顺序排列在一系列的sstfile里面。当`memtable写满，他的内容就会被写入一个在Level-0（L0）的文件。被刷入L0的时候，RocksDB删除在memtable里重复的被覆盖的键值。有些文件会被周期性地读入，然后合并为一些更大的文件——这就叫压缩`。
* 一个LSM数据库的`写吞吐量`跟`压缩发生的速度`有直接的关系，特别是当数据被存储在高速存储介质，如SSD和RAM的时候。RocksDB可以配置为通过多线程进行压缩。当使用多线程压缩的时候，跟单线程压缩相比，在SSD介质上的数据库可以看到`数十倍的写速度增长`。

### 压缩方式

* 一次全局压缩发生在完整的排序好的数据，他们要么是一个L0文件，要么是L1+的某个Level的所有文件。一次压缩会取`部分按顺序排列好的连续的文件，把他们合并然后生成一些新的运行数据`。
* 分层压缩会将数据存储在数据库的好几层。`越新的数据，会在越接近L0层，越老的数据越接近Lmax层`。L0层的文件会有些重叠的键值，但是其他层的数据不会。一次压缩过程会从`Ln层取一个文件，然后把所有与这个文件的key有交集的Ln＋1层的文件都处理一次，然后生成一个新的Ln+1层的文件`。与分层压缩模式相比，`全局压缩一般有更小的写放大，但是会有更大的空间，读放大`。
* `先进先出型`压缩会将在老的文件被淘汰的时候删除它，适用于缓存数据。
* 我们还允许开发者开发和测试自己定制的压缩策略。为此，RocksDB设置了合适的钩子来关停内建的压缩算法，然后使用其他API来允许应用使用他们自己的压缩算法。选项`disable_auto_compaction`如果被设置为真，将关闭自带的压缩算法。`GetLiveFilesMetaData API`允许外部部件查找所有正在使用的文件，并且决定哪些文件需要被合并和压缩。有需要的时候，可以调用CompactFiles对本地文件进行压缩。DeleteFile接口允许应用程序删除已经被认为过期的文件。

### 元数据存储

* 数据库的MANIFEST文件`会记录数据库的状态`。压缩过程会增加新的文件，然后删除原有的文件，然后通过写MAINFEST文件来持久化这些操作。MANIFEST文件里面`需要记录的事务会使用一个批量提交算法来减少重复syncs带来的代价`。

### 避免低速

* 我们还可以使用后台压缩线程将memtable里的数据刷入存储介质的文件上。`如果后台压缩线程忙于处理长时间压缩工作，那么一个爆发写操作将很快填满memtable，使得新的写入变慢`。可以通过配置`部分线程为保留线程`来避免这种情况，这些线程`将总是用于将memtable的数据刷入存储介质`。

### 压缩过滤器(compaction filter)

* 某些应用可能需要在压缩的时候对键的内容进行处理。比如，某些数据库，如果提供了生存时间（time-to-live,TTL)功能，可能需要删除已经过期的key。这就可以通过程序定义的压缩过滤器来完成。`如果程序希望不停删除已经晚于某个时间的键，就可以使用压缩过滤器丢掉那些已经过期的键`。RocksDB的压缩过滤器允许应用程序在压缩过程修改键值内容，甚至删除整个键值对。例如，应用程序可以在压缩的同时进行数据清洗等。

### 只读模式

* 一个数据库可以用只读模式打开，此时数据库保证应用程序将无法修改任何数据库相关内容。这会带来`非常高的读性能，因为它完全无锁`

### 数据库调试日志

* RocksDB会写很详细的日志到LOG＊文件里面。 这些信息经常被用于调试和分析运行中的系统。日志可以配置为按照特定周期进行翻滚.

### 数据压缩

* RocksDB支持snappy，zlib，bzip2，lz4，lz4_hc以及zstd压缩算法。RocksDB可以在不同的层配置不同的压缩算法。通常，`90%的数据会落在Lmax层`。一个典型的安装会使用ZSTD（或者Zlib，如果没有ZSTD的话）`给最下层做压缩算法，然后在其他层使用LZ4（或者snappy，如果没有LZ4）`

### 全量备份，增量备份以及复制

* RocksDB支持`增量备份`。BackupableDB会生成RocksDB备份样本
* 增量拷贝需要能找到并且附加上最近所有对数据库的修改。`GetUpdatesSince`允许应用获取RocksDB最后的几条事务日志。它可以不断获得RocksDB里的事务日志，然后把他们作用在一个远程的备份或者拷贝。
* 典型的复制系统会希望给每个`Put`加上一些元数据。这些元数据可以帮助检测复制流水线是不是有回环。还可以用于给事务打标签，排序。为此，RocksDB支持一种名为`PutLogData`的API，应用程序可以用这个`给每个Put操作加上元数据`。这些元数据只会存储在`事务日志`而不会存储在数据文件里。使用PutLogData插入的元数据可以通过`GetUpdatesSince`接口获得。
* RocksDB的事务日志会创建在数据库文件夹。当一个日志文件不再被需要的时候，他会被放倒归档文件夹。之所以把他们放在归档文件夹，是因为后面的某些复制流可能会需要获取这些已经过时的日志。使用GetSotredWalFiles可以获得一个事务日志文件列表。

### 在同一个进程支持多个嵌入式数据库

* 一个RocksDB的常见用法是，应用内给他们的数据进行逻辑上的分片。这项技术允许程序做合适的负载均衡以及快速出错恢复。这意味着一个服务器进程可能需要`同时操作多个RocksDB数据库`。这可以通过一个名为`Env
  `的环境对象来实现。例如说，`一个线程池会和一个Env关联。如果多个应用程序希望多个数据库实例共享一个线程池（用于后台压缩），那么就应该用同一个Env对象来打开这些数据库`。

### 缓存块——已经压缩以及未压缩的数据

* RocksDB对块使用LRU算法来做读缓存。这个块缓存会被分为两个独立的RAM缓存：第一部分缓存未压缩的块，然后第二部分缓存压缩的块。如果配置了使用压缩块缓存，用户应该同时配置开启direct IO，而不使用操作系统的页缓存，以避免`对压缩数据的双缓存问题`。

### 表缓存

* 表缓存是缓存打开文件描述符的结构。 这些文件描述符用于sstfile。 应用程序可以指定表缓存的最大大小，或者将RocksDB配置为始终保持所有文件打开，以实现更好的性能

### IO控制

* RocksDB允许用户以不同的方式配置SST文件的I / O。 用户可以启用direct I / O，以便RocksDB可以完全控制I / O和缓存。 一种替代方法是利用某些选项，以允许用户提示应如何执行I / O。 他们可以建议RocksDB在文件中调用fadvise以进行读取，在附加的文件中调用周期性范围同步，启用直接I / O，等等。

### StackableDB

* RocksDB内带一套封装好的机制，允许在数据库的核心代码上按层添加功能。这个功能通过StackabDB接口实现，比如RocksDB的存活时间功能，就是通过StackableDB接口实现的，他并不是RocksDB的核心接口。这种设计让核心代码可模块化，并且整洁易读。

### memtable

#### 插件式的Memtable

* RocksDB的memtable的默认实现是`跳表（skiplist）`。跳表是一个有序集，如果应用的负载主要是区间查询和写操作的时候，非常高效。然而，有些程序压力不是主要写操作和扫描，他们可能根本不用区间扫描。对于这些应用，一个有序集可能不能提供最好的性能。为此，RocksDB提供一个插件式API，允许应用提供自己的memtable实现。这个库自带三种memtable实现：`skiplist实现`，`vector实现`以及`前缀哈希`实现的memtable。vector实现的memtable适用于`需要大批量加载数据到数据库的情况`。每次写入新的数据都是在vector的末尾追加新数据，`当我们需要把memtable的数据刷入L0的时候，我们才进行一次排序`。一个前缀哈希的memtable对`get，put，以及键值前缀扫描拥有较好的性能`。

#### memtable流水线

* RocksDB允许为一个数据库设定任意数量的memtable。当memtable写满的时候，他会被修改为不可变memtable，然后一个后台线程会开始将他的内容刷入存储介质中。同时，新写入的数据将会累积到新申请的memtable里面。如果新的memtable也写入到他的数量限制，他也会变成不可变memtable，然后插入到刷存储流水线。后台线程持续地将流水线里的不可变memtable刷入存储介质中。这个流水线会增加RocksDB的写吞吐，特别是当他在一个比较慢的存储介质上工作的时候。

#### memtable写存储的时候的垃圾回收工作

* 当一个memtable被刷入存储介质，一个内联压缩过程会删除输出流里的重复记录。类似的，如果早期的put操作最后被delete操作隐藏，那么这个put
  操作的结果将完全不会写入到输出文件。这个功能大大减少了存储数据的大小以及写放大。当RocksDB被用于一个生产者——消费者队列的时候，这个功能是非常必要的，特别是当队列里的元素存活周期非常短的时候。

### 合并操作符

* RocksDB天然支持三种类型的纪录，Put记录，Delete记录，Merge记录。当压缩过程遇到Merge记录的时候，他会调用一个应用程序定义的，名为Merge操作符的方法。`一个Merge可以把许多Put和Merge操作合并为一个操作`。这项强大的功能允许那些`需要读——修改——写的应用彻底避免读`。它允许应用把操作的意图纪录为一个Merge记录，然后RocksDB的压缩过程会用懒操作将这个意图应用到原数值上。这个功能在[合并操作符](https://rocksdb.org.cn/doc/.html)里面有详细说明。

### DB ID

* 在数据库创建时创建的全局唯一ID，默认情况下存储在DB文件夹中的标识文件中。可选地，它只能存储在清单文件中。建议存储在清单文件中。

## 工具

* 有一系列的有趣的工具可以用于支持生产环境的数据库。sst_dump工具可以导出一个sst文件里的所有kv键值对。ldb工具可以对数据库进行get，put，scan操作。ldb工具同时还可以导出MANIFEST文件的内容，还可以用于修改数据库的层数。还可以用于强制压缩一个数据库。

## 术语

* **迭代器(Iterator)**： 迭代器被用户用于按顺序查询一个区间内的键值
* **点查询**：在RocksDB，点查询意味着通过 Get()读取一个键的值。
* **区间查询**：区间查询意味着通过迭代器读取一个区间内的键值。
* **SST文件（数据文件/SST表）**:SST是Sorted Sequence Table（排序队列表）。他们是排好序的数据文件。在这些文件里，所有键都按key排序好的顺序组织，一个键或者一个迭代位置可以通过二分查找进行定位。
* **索引(Index)**： SST文件里的数据块索引。他会被保存成SST文件里的一个索引块。默认的索引是二分搜索索引。
* **分区索引(Partitioned Index)**：被分割成许多更小的块的二分搜索索引。
* **LSM树**：参考定义：https://en.wikipedia.org/wiki/Log-structured_merge-tree，RocksDB是一个基于LSM树的存储引擎
* **前置写日志(WAL)或者日志(LOG)**：一个在RocksDB重启的时候，用于恢复没有刷入SST文件的数据的文件。
* **memtable/写缓冲(write buffer)**：在内存中存储最新更新的数据的数据结构。通常它会按顺序组织，并且会包含一个二分查找索引。
* **memtable切换**：在这个过程，**当前活动的memtable**（现在正在写入的那个）被关闭，然后转换成 **不可修改memtable**。同时，我们会关闭当前的WAL文件，然后打开一个新的。
* **不可修改memtable**：一个已经关闭的，正在等待被落盘的memtable。
* **序列号(SeqNum/SeqNo)**：数据库的每个写入请求都会分配到一个自增长的ID数字。这个数字会跟键值对一起追加到WAL文件，memtable，以及SST文件。序列号用于实现snapshot读，压缩过程的垃圾回收，MVCC事务和其他一些目的。
* **恢复**：在一次数据库崩溃或者关闭之后，重新启动的过程。
* **落盘，刷新(flush)**：将memtable的数据写入SST文件的后台任务。
* **压缩**：将一些SST文件合并成另外一些SST文件的后台任务。LevelDB的压缩还包括落盘。在RocksDB，我们进一步区分两个操作。
* **分层压缩或者基于分层的压缩方式**：RocksDB的默认压缩方式。
* **全局压缩方式**：一种备选的压缩算法。
* **比较器(comparator)**：一种插件类，用于定义键的顺序。
* **列族(column family)**：列族是一个DB里的独立键值空间。尽管他的名字有一定的误导性，他跟其他存储系统里的“列族”没有任何关系。RocksDB甚至没有“列”的概念。
* **快照(snapshot)**：一个快照是在一个运行中的数据库上的，在一个特定时间点上，逻辑一致的，视图。
* **检查点(checkpoint)**：一个检查点是一个数据库在文件系统的另一个文件夹的物理镜像映射。
* **备份(backup)**：RocksDB有一套备份工具用于帮助用户将数据库的当前状态备份到另一个地方，例如HDFS。
* **版本(Version)**：这个是RocksDB内部概念。一个版本包含某个时间点的所有存活SST文件。一旦一个落盘或者压缩完成，由于存活SST文件发生了变化，一个新的“版本”会被创建。一个旧的“版本”还会被仍在进行的读请求或者压缩工作使用。旧的版本最终会被回收。
* **超级版本(super version)**：RocksDB的内部概念。一个超级版本包含一个特定时间的 的 一个SST文件列表（一个“版本”）以及一个存活memtable的列表。不管是压缩还是落盘，亦或是一个memtable切换，都会生成一个新的“超级版本”。一个旧的“超级版本”会被继续用于正在进行的读请求。旧的超级版本最终会在不再需要的时候被回收掉。
* **块缓存(block cache)**：用于在内存缓存来自SST文件的热数据的数据结构。
* **统计数据(statistics)**：一个在内存的，用于存储运行中数据库的累积统计信息的数据结构。
* **性能上下文(perf context)**：用于衡量本地线程情况的内存数据结构。通常被用于衡量单请求性能。
* **DB属性（DB properties）**：一些可以通过DB::GetProperty()获得的运行中状态。
* **表属性(table properites)**：每个SST文件的元数据。包括一些RocksDB生成的系统属性，以及一些通过用户定义回调函数生成的，用户定义的表属性。
* **写失速(write stall)**：如果有大量落盘以及压缩工作被积压，RocksDB可能会主动减慢写速度，确保落盘和压缩可以按时完成。
* **前缀bloom filter**：一种特殊的bloom filter，只能在迭代器里被使用。通过前缀提取器，如果某个SST文件或者memtable里面没有指定的前缀，那么可以避免这部分文件的读取。
* **前缀提取器(prefix extractor)**：一个用于提取一个键的前缀部分的回调类。
* **基于块的bloom filter或者全bloom filter**： 两种不同的SST文件里的bloom filter存储方式。
* **分片过滤器(partitioned Filters)**：分片过滤器是将一个全bloom filter分片进更小的块里面
* **压缩过滤器(compaction filter)**：一种用户插件，可以用于在压缩过程中，修改，或者丢弃一些键。
* **合并操作符(merge operator)**：RocksDB支持一种特殊的操作符Merge()，可以用于对现存数据进行差异纪录，合并操作。合并操作符是一个用户定义类，可以合并合并 操作。
* **基于块的表(block-based table)**：默认的SST文件格式。
* **块(block)**：SST文件的数据块。在SST文件里，一个块以压缩形式存储。
* **平表(plain table)**：另一种SST文件格式，针对ramfs优化。
* **前向/反向迭代器**：一种特殊的迭代器选项，针对特定的使用场景进行优化。
* **单点删除**：一种特殊的删除操作，只在用户从未更新过某个存在的键的时候被使用。
* **限速器(rate limiter)**：用于限制落盘和压缩的时候写文件系统的速度。
* **悲观事务**：用锁来保证多个并行事务的独立性。默认的写策略是WriteCommited。
* **两阶段提交(2PC,two phase commit)**：悲观事务可以通过两个阶段进行提交：先准备，然后正式提交。
* **提交写(WriteCommited)**：悲观事务的默认写策略，会把写入请求缓存在内存，然后在事务提交的时候才写入DB。
* **预备写(WritePrepared)**：一种悲观事务的写策略，会把写请求缓存在内存，如果是二阶段提交，就在准备阶段写入DB，否则，在提交的时候写入DB。
* **未预备写(WriteUnprepared)**：一种悲观事务的写策略，由于这个是事务发送过来的请求，所以直接写入DB，以此避免写数据的时候需要使用过大的内存。

# RocksJava

## 快速开始

### Maven依赖

```xml
<dependency>
  <groupId>org.rocksdb</groupId>
  <artifactId>rocksdbjni</artifactId>
  <version>6.6.4</version>
</dependency>
```

### 打开一个Database

```java
public class RocksDbTest {
    private static final String DB_PATH = "/Users/babywang/Desktop/testrocksdb";

    public static void main(String[] args) {
        // 一个静态方法加载RocksDB C++ lib
        RocksDB.loadLibrary();
        try (final Options options = new Options().setCreateIfMissing(true)) {
            try (RocksDB open = RocksDB.open(options, DB_PATH)) {
               // do something
            }
        } catch (RocksDBException e) {
            e.printStackTrace();
        }
    }
}
```

### Reads和Write

```java
public class RocksDbTest {
    private static final String DB_PATH = "/Users/babywang/Desktop/testrocksdb";

    public static void main(String[] args) {
        // 一个静态方法加载RocksDB C++ lib
        RocksDB.loadLibrary();
        try (final Options options = new Options().setCreateIfMissing(true)) {
            try (RocksDB open = RocksDB.open(options, DB_PATH)) {
                open.put("a".getBytes(), "hehe".getBytes(StandardCharsets.UTF_8));
                open.flush(new FlushOptions().setWaitForFlush(true));
                System.out.println(Arrays.toString(open.get("a".getBytes())));
            }
        } catch (RocksDBException e) {
            e.printStackTrace();
        }
    }
}
```

### 通过列族开启一个Db

```java
 public void openDataBaseWithColumnFamilies() {
        RocksDB.loadLibrary();
        try (final ColumnFamilyOptions columnFamilyOptions = new ColumnFamilyOptions().optimizeUniversalStyleCompaction()) {
            final List<ColumnFamilyDescriptor> cfDes = Arrays.asList(new ColumnFamilyDescriptor(RocksDB.DEFAULT_COLUMN_FAMILY, columnFamilyOptions),
                    new ColumnFamilyDescriptor("my-first-columnfamily".getBytes(), columnFamilyOptions));
            final List<ColumnFamilyHandle> columnFamilyHandleList =
                    new ArrayList<>();
            try (final DBOptions options = new DBOptions()
                    .setCreateIfMissing(true)
                    .setCreateMissingColumnFamilies(true);
                 final RocksDB db = RocksDB.open(options,
                         DB_PATH, cfDes,
                         columnFamilyHandleList)) {
                try {

                    // do something


                } finally {

                    // NOTE frees the column family handles before freeing the db
                    for (final ColumnFamilyHandle columnFamilyHandle :
                            columnFamilyHandleList) {
                        columnFamilyHandle.close();
                    }
                } // frees the db and the db options
            } catch (RocksDBException e) {
                e.printStackTrace();
            }
        }
    }
```

