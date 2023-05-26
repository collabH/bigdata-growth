# Options

* Options包含Rocksdb基础的写入配置，以及如何初始化RocksDB。

## Writer Buffer Size

* 这可以为每个数据库和/或每个列族设置。

### Column Family Write Buffer Size

* 设置列族使用的最大write buffer，它表示在转换为已排序的磁盘文件之前要在内存中建立的数据量（由磁盘上未排序的日志支持）。 默认值为 64 MB。

```java
 List<ColumnFamilyDescriptor> columnFamilyDescriptors=new ArrayList<>();
        ColumnFamilyOptions columnFamilyOptions = new ColumnFamilyOptions();
        // 默认为64MB
        columnFamilyOptions.setWriteBufferSize(64<<20);
```

### Database Write Buffer Size

* 这是数据库中所有列族的所有写缓冲区的最大大小。它表示在写入磁盘之前在所有列族的memtable中构建的数据量。默认是关闭的，也是就0.

```java
   DBOptions dbOptions = new DBOptions();
        // 默认大小是关闭的
   dbOptions.setDbWriteBufferSize(64<<30);
```

## Block Cache Size

* 您可以创建您选择的大小的块缓存来缓存未压缩的数据。推荐Block Cache Size设置为总内存的3分之1，

## Compression

* 控制前`n-1`层的压缩格式配置,推荐使用`kLZ4Compression`或`kSnappyCompression`格式

* 控制第`n`层的压缩格式配置,推荐使用`kZSTD`或`kZlibCompression`格式

```java
 private void compression() throws Exception {
        ColumnFamilyOptions columnFamilyOptions = new ColumnFamilyOptions();
        // 第n-1层压缩格式
        columnFamilyOptions.setCompressionType(CompressionType.LZ4_COMPRESSION);
        columnFamilyOptions.setCompressionType(CompressionType.SNAPPY_COMPRESSION);
        CompressionOptions compressionOptions = new CompressionOptions();
        compressionOptions.setEnabled(true);
        compressionOptions.setLevel(1);
        columnFamilyOptions.setCompressionOptions(compressionOptions);
        // 指定前n level的压缩类型
//        columnFamilyOptions.setCompressionPerLevel()

        // 第n层压缩格式
        columnFamilyOptions.setBottommostCompressionType(CompressionType.ZSTD_COMPRESSION);
        columnFamilyOptions.setBottommostCompressionType(CompressionType.ZLIB_COMPRESSION);
    }
```

## Bloom Filters

* 如果你有很多点查找操作(如Get())，那么Bloom Filter可以帮助加速这些操作，相反，如果你的大部分操作是范围扫描(如Iterator())，那么Bloom Filter将没有帮助。

## RateLimiter

* DbOptions配置，设置db的每秒处理request速率。

```java
 private void ratelimiter() throws Exception {
        DBOptions dbOptions = new DBOptions();
        // db每秒200 qps
        dbOptions.setRateLimiter(new RateLimiter(200));
    }
```

## Sst FileManager

* sst文件最终存储的地方

```java
    public static void main(String[] args) throws Exception {
        DBOptions dbOptions = new DBOptions();
        HdfsEnv hdfs = new HdfsEnv("hdfs://hostname:port/");
        hdfs.setBackgroundThreads(10);
        // 存储sstFile文件
        dbOptions.setSstFileManager(new SstFileManager(hdfs));
        RocksDB hdfsDB = RocksDB.open(dbOptions, "test", Lists.newArrayList(),
                Lists.newArrayList());
        hdfsDB.put("name".getBytes(), "hsm".getBytes());
    }
```

# MemTable

* MemTable 是一种内存数据结构，在将数据刷新到 SST 文件之前保存数据。 它同时服务于读和写——新的写入总是将数据插入到 memtable 中，而读取必须在从 SST 文件读取之前查询 memtable，因为 memtable 中的数据较新。 一旦一个 memtable 满了，它就会变得不可变并被一个新的 memtable 取代。 后台线程会将内存表的内容刷新到 SST 文件中，然后可以销毁内存表。

## 影响memtable的重要配置

* `AdvancedColumnFamilyOptions::memtable_factory:memtable` 的工厂对象。 通过指定工厂对象，用户可以更改 memtable 的底层实现，并提供特定于实现的选项（默认：SkipListFactory）。
* `ColumnFamilyOptions::write_buffer_size`:单个memtable的大小，默认64MB
* `DBOptions::db_write_buffer_size`:跨列族memtable的总大小。这可以用来管理memtable使用的总内存。(默认值:0(禁用)
* `DBOptions::write_buffer_manager`:不需要指定memtable的总大小，用户可以提供自己的写缓冲区管理器来控制memtable的总体内存使用。覆盖数据库写入缓冲区大小。(默认值:nullptr)
* `AdvancedColumnFamilyOptions::max_write_buffer_number`:内存中生成的memtable在它们刷新到SST文件之前的最大数目。(默认值:2)
* `AdvancedColumnFamilyOptions::max_write_buffer_size_to_maintain`:要在内存中维护的写入历史记录量，以字节为单位。 这包括当前的内存表大小、密封但未刷新的内存表以及保留的已刷新内存表。 RocksDB 将尝试在内存中至少保留这么多历史记录 - 如果删除刷新的 memtable 会导致历史记录低于此阈值，则不会删除它。 （默认值：0）

```java
  public static void main(String[] args) {
        Options options = new Options();
        // 指定memtable底层实现，默认为skiplist，支持hashSkipList，hashlinked，vector等
        options.setMemTableConfig(new VectorMemTableConfig());
        // 单个memtable大小 默认大小64MB
//        options.setWriteBufferSize()
        // 最多的memtable个数默认为2，超过会刷新到sst file中
        options.setMaxWriteBufferNumber(2);
        // 保留的历史的memtable
        options.setMaxWriteBufferNumberToMaintain(0);
    }
```

## Skiplist memtable

* 基于skiplist的memtable在读写、随机访问和顺序扫描方面都具有良好的性能。此外，它还提供了一些其他memtable实现目前不支持的其他有用特性，如并发插入(Concurrent Insert)和使用提示插入(Insert with Hint)。

## HashSkiplist MemTable

* HashSkipList将哈希表中的数据组织为跳跃列表，而HashLinkList将哈希表中的数据组织为排序后的单个链表。
* 当执行查找或插入键时，使用Options检索目标键的前缀。前缀提取器，用于查找散列桶。在哈希桶中，所有的比较都是使用整个(内部)键完成的，就像基于memtable的SkipList一样。
* 基于散列的memtable的最大限制是跨多个前缀进行扫描需要复制和排序，这非常慢，而且内存成本很高。

## Flush

* 触发memtable flush的场景有三种：
  * Memtable size超过ColumnFamilyOptions::write_buffer_size。
  * 所有列族的总memtable大小超过DBOptions::db_write_buffer_size，或者DBOptions::write_buffer_manager表示flush。在这种情况下，将刷新最大的memtable。
  * 总WAL文件大小超过DBOptions::max_total_wal_size。在这种情况下，带有最旧数据的memtable将被刷新，以允许清除带有该memtable数据的WAL文件。

## 并发插入

* 在不支持memtable并发插入的情况下，多线程并发写入RocksDB将会依次应用于memtable。并发memtable insert在默认情况下是启用的，可以通过`DBOptions::allow_concurrent_memtable_write`选项关闭，尽管只有基于skiplist的memtable支持该特性。

```java
 options.setAllowConcurrentMemtableWrite(true);
```

## Insert with Hint

* 就地更新可以通过切换`inplace_update_support`标志来启用。但是，这个标志默认设置为false，因为这个线程安全的就地更新支持与并发memtable写不兼容。注意，默认情况下，allow_concurrent_memtable_write的bool值设置为true。

## 不同Memtable对比

| Mem Table Type              | SkipList                                           | HashSkipList                                                 | HashLinkList                                 | Vector                                         |
| --------------------------- | -------------------------------------------------- | ------------------------------------------------------------ | -------------------------------------------- | ---------------------------------------------- |
| Optimized Use Case          | General                                            | 在特定键前缀内的范围查询                                     | 在特定的键前缀范围查询，每个前缀只有少量的行 | 随机写工作负载大                               |
| Index type                  | binary search                                      | hash + binary search                                         | hash + linear search                         | linear search                                  |
| 支持完全有序的全数据库扫描? | 天然支持                                           | 开销非常大(复制并排序以创建临时的总排序视图)                 | 开销非常大(复制并排序以创建临时的总排序视图) | 开销非常大(复制并排序以创建临时的总排序视图)   |
| 内存开销                    | 平均(每个条目约1.33个指针)                         | High (Hash Buckets + Skip List Metadata for non-empty buckets + multiple pointers per entry) | Lower (Hash buckets + pointer per entry)     | Low (pre-allocated space at the end of vector) |
| MemTable Flush              | 速度快，内存持续增加                               | 速度慢，临时内存占用率高                                     | 速度慢，临时内存占用率高                     | 速度慢，内存持续增加                           |
| Concurrent Insert           | Supported                                          | Not supported                                                | Not supported                                | Not supported                                  |
| Insert with Hint            | Supported (in case there are no concurrent insert) | Not supported                                                | Not supported                                | Not supported                                  |

* 总的来说查询多、随机读取使用SkipList，写负载大使用Vector。

# Write Ahead Log

## 概述

* RocksDB 的每次更新都会写入两个位置：1) 一个名为 memtable 的内存数据结构（稍后刷新到 SST 文件）和 2) 在磁盘上提前写入日志 (WAL)。 如果发生故障，可以使用预写日志完全恢复memtable中的数据，这是将数据库恢复到原始状态所必需的。 在默认配置中，RocksDB 通过在每次用户写入后刷新 WAL 来保证进程崩溃一致性。
* 预写日志(Write ahead log, WAL)将memtable操作序列化到日志文件中。在发生故障时，可以使用WAL文件将数据库恢复到一致状态，通过从日志中重建memtable。当memtable被安全刷新到persistent medium时，相应的WAL日志就会被废弃并被归档。最终，归档的日志在一段时间后从磁盘清除。

## Wal生命周期

* 一旦db被打开，一个新的WAL将被创建在磁盘上，以持久化所有的写操作(WAL是在所有列族之间共享的)。
* 当进行db#put操作后，WAL应该已经记录了所有写操作。WAL将保持打开状态，并继续记录未来的写操作，直到它的大小达到`DBOptions::max_total_wal_size`。
* 如果用户决定刷新一个列族的数据，1）这个列族的数据（key1 和 key3）被刷新到一个新的 SST 文件 2）一个新的 WAL 被创建，所有未来对所有列族的写入现在都转到新的 WAL 3) 旧的 WAL 不会接受新的写入，但删除可能会延迟。
* 此时会有两个 WAL，`旧的 WAL 包含 key1 到 key4，新的 WAL 包含 key5 和 key6`。 因为旧的 WAL 仍然包含`至少一个列族（“默认”）的实时数据`，所以还不能删除它。 只有当用户`最终决定刷新“默认”列族时，旧的 WAL 才能自动从磁盘归档和清除`。
* 当 1) 打开一个新数据库，2) 刷新一个列族时，就会创建一个 WAL。 当所有列族刷新超过 WAL 中包含的最大序列号时，WAL 将被删除（或归档，如果启用了归档），或者换句话说，WAL 中的所有数据都已持久化到 SST 文件。 存档的 WAL 将被移动到一个单独的位置，并在稍后从磁盘中清除。 由于复制目的，实际删除可能会延迟

## WAL配置

* `DBOptions.wal_dir`:设置RocksDB存放预写日志文件的目录，允许wal与实际数据分开存放。
* `DBOptions::WAL_ttl_seconds, DBOptions::WAL_size_limit_MB`:这两个字段会影响归档wal被删除的速度。非零值表示触发归档WAL删除的时间和磁盘空间阈值
* `DBOptions::max_total_wal_size`:为了限制wal的大小，RocksDB使用`DBOptions::max_total_wal_size`作为列族刷新的触发器。一旦wal超过这个大小，RocksDB将开始强制刷新列族，以允许删除一些最古老的wal。当以非均匀频率更新列族时，这个配置可能很有用。如果没有大小限制，当不经常更新的列族有一段时间没有刷新时，用户可能需要保留非常旧的wall。
* `DBOptions::avoid_flush_during_recovery`
* `DBOptions::manual_wal_flush`:确定 WAL 刷新是在每次写入后自动还是纯手动（用户必须调用 FlushWAL 来触发 WAL 刷新）。
* `DBOptions::wal_filter`:通过DBOptions::wal_filter，用户可以提供一个过滤器对象，以便在恢复过程中处理wal时调用。注:ROCKSDB_LITE模式不支持
* `WriteOptions::disableWAL`:不关心数据丢失可以关闭WAL

## WAL filter

### 事务日志迭代器

* 事务日志迭代器提供了在RocksDB实例之间复制数据的方法。一旦一个WAL由于列族刷新而被归档，WAL将被归档而不是立即删除。目标是允许事务日志迭代器继续读取WAL，并将其发送给关注者进行重放。

## WAL File Format

### WAL管理器

* 在WAL目录下生成的文件序号越高越好。为了重建数据库的状态，这些文件是按照序列号顺序读取的。WAL管理器提供了将WAL文件作为单个单元读取的抽象。在内部，它使用Reader或Writer抽象来打开和读取文件。

### Reader/Writer

* Writer提供了将日志记录追加到日志文件的抽象。媒体特定的内部细节由WriteableFile接口处理。类似地，Reader提供了从日志文件中顺序读取日志记录的抽象。SequentialFile接口处理内部媒体特定的细节。

### Log File Format

* 日志文件由一系列长度可变的记录组成，记录由`kBlockSize`(32k)组成。如果某条记录不能填入剩余空间，则用空数据填充剩余空间。写入器以kBlockSize的块为单位写入，读取器以kBlockSize的块为单位读取。

```
       +-----+-------------+--+----+----------+------+-- ... ----+
 File  | r0  |        r1   |P | r2 |    r3    |  r4  |           |
       +-----+-------------+--+----+----------+------+-- ... ----+
       <--- kBlockSize ------>|<-- kBlockSize ------>|

  rn = variable size records
  P = Padding
```

### Records Format

#### Legacy Record Format

```
+---------+-----------+-----------+--- ... ---+
|CRC (4B) | Size (2B) | Type (1B) | Payload   |
+---------+-----------+-----------+--- ... ---+

CRC = 32bit hash computed over the payload using CRC
Size = Length of the payload data
Type = Type of record
       (kZeroType, kFullType, kFirstType, kLastType, kMiddleType )
       The type is used to group a bunch of records together to represent
       blocks that are larger than kBlockSize
Payload = Byte stream as long as specified by the payload size
```

* 日志文件的内容是一个32KB的块序列。唯一的例外是文件的尾部可能包含部分块。每块由一下结构组成：

```c++
block := record* trailer?
record :=
  checksum: uint32	// crc32c of type and data[]
  length: uint16
  type: uint8		// One of FULL, FIRST, MIDDLE, LAST 
  data: uint8[length]
```

* FIRST、MIDDLE、LAST是用于被分割成多个片段的用户记录的类型(通常是因为块边界)。FIRST是用户记录的第一个片段的类型，LAST是用户记录的最后一个片段的类型，MID是用户记录所有内部片段的类型。FULL记录包含整个用户记录的内容。

#### Recyclabe Record Format

```
+---------+-----------+-----------+----------------+--- ... ---+
|CRC (4B) | Size (2B) | Type (1B) | Log number (4B)| Payload   |
+---------+-----------+-----------+----------------+--- ... ---+
Same as above, with the addition of
Log number = 32bit log file number, so that we can distinguish between
records written by the most recent log writer vs a previous one.
日志文件号，以便我们区分由最近的日志记录器所写的记录与以前的记录。
```

## Wal恢复模式

* 每个应用程序都是独一无二的，RocksDB需要一定的一致性保证。RocksDB中的每一条提交的记录都会被持久化。未提交的记录记录在write-ahead-log (write-ahead-log)中。当RocksDB干净地关闭时，所有未提交的数据都会在关闭前提交，因此一致性总是得到保证。当RocksDB被杀死或机器重新启动时，RocksDB需要将自己恢复到一致的状态。其中一个重要的恢复操作是在WAL中重放未提交的记录。不同的WAL恢复模式定义了WAL重放的行为。

### kTolerateCorruptedTailRecords

* 允许数据丢失，WAL重放会忽略在日志末尾发现的任何错误。其理由是，在不完全关闭时，日志的尾部可能会有不完整的写操作。这是一种启发式模式，系统无法区分日志尾部的损坏和未完成的写入。任何其他的IO错误，将被认为是数据损坏。

### kAbsoluteConsistency

* WAL重放过程中出现的任何IO错误都被认为是数据损坏。对于那些连一条记录都不能丢失的应用程序和/或有其他方法恢复未提交的数据的应用程序，这种模式是理想的。

### kSkipAnyCorruptedRecords

* 在这种模式下，读取日志时的任何IO错误都被忽略。系统试图恢复尽可能多的数据。这对于灾难恢复是理想的。

## WAL性能

### Non-Sync模式

* 当`WriteOptions.sync = false`(默认)，WAL写不同步到磁盘。除非操作系统认为它必须刷新数据(例如，太多脏页)，否则用户不需要等待任何I/O写入。
* 用户如果想减少写操作系统页面缓存所带来的CPU延迟，可以选择`Options.manual_wal_flush = true`。使用这个选项，WAL写操作甚至`不会刷新`到文件系统页面缓存，而是保留在RocksDB中。用户需要调用`DB::FlushWAL()`使缓冲条目进入文件系统。
* 用户可以通过调用`DB::SyncWAL()`强制WAL文件fsync。该函数不会阻塞正在其他线程中执行的写操作。
* 在这种模式下，WAL写不是崩溃安全的。

### Sync Mode

* `WriteOptions.sync = true`(默认)

### Group Commit

* 和其他大多数依赖日志的系统一样，RocksDB支持团队承诺提高WAL的写吞吐量，以及写放大。RocksDB的组提交以一种自然的方式实现:当不同线程同时写入同一个DB时，所有符合合并条件的未完成的写入将被合并到一起，并写入WAL一次，使用一个fsync。通过这种方式，相同数量的I/ o可以完成更多的写操作。
* 具有不同写选项的写操作可能不符合组合的要求。最大组大小为1MB。RocksDB不会试图通过主动延迟写入来增加批处理大小。

### Number of I/Os per write

* 如果`Options.recycle_log_file_num=false(默认)`，RocksDB总是为新的WAL段创建新文件。每次WAL写都会改变数据和文件大小，所以每次fsync至少会产生两个I/ o，一个用于数据，一个用于元数据。注意，RocksDB调用fallocate()来为文件预留足够的空间，但它并不会阻止fsync中的元数据I/O。
* `Options.recycle_log_file_num = true`将保留一个WAL文件池并尝试重用它们。当写入现有日志文件时，从大小为0开始使用随机写入。在写入到达文件末尾之前，文件大小不会改变，因此可以避免元数据的I/O(也取决于文件系统挂载选项)。假设大多数WAL文件都有类似的大小，元数据所需的I/O将是最小的。

### 写放大

* 注意，对于某些用例，同步WAL可能会引入一些重要的写扩展。当写操作很小的时候，因为整个块/页可能需要更新，所以即使写操作很小，我们也可能需要两次4KB的写操作(一次用于数据，一次用于元数据)。如果写仅为40字节，则更新8KB，则写放大为8KB /40字节~= 200。它甚至很容易比lsm树的写放大值还要大。

# MANIFEST

* RocksDB是文件系统和存储介质无关的。文件系统操作不是原子操作，在系统故障时很容易出现不一致。即使打开了日志记录，文件系统也不能保证不干净重启时的一致性。POSIX文件系统也不支持原子批处理操作。因此，不可能依靠嵌入在RocksDB数据存储文件中的元数据来重新启动时重建RocksDB的最后一致状态。
* RocksDB有一个内置的机制来克服POSIX文件系统的这些限制，通过使用Manifest日志文件中的`Version Edit Records保存RocksDB状态更改的事务日志`。MANIFEST用于在重启时将RocksDB恢复到最新的已知一致状态。

## 术语

* ***MANIFEST***是指在事务日志中跟踪RocksDB状态变化的系统
* ***Manifest log*** 是指包含 RocksDB 状态快照/编辑的单个日志文件
* ***CURRENT*** 是指当前最新的mainfest log

## 工作原理

* MANIFEST是RocksDB状态变化的事务日志。MANIFEST由- MANIFEST日志文件和指向最新MANIFEST文件(CURRENT)的指针组成。Manifest日志是正在滚动名为Manifest -(seq号)的日志文件。序列号总是在增加。CURRENT是一个特殊的文件，它指向最新的清单日志文件。
* 在系统(重新)启动时，最新的manifest日志包含RocksDB的一致状态。RocksDB状态的任何后续更改都记录到manifest日志文件中。当manifest日志文件超过一定大小时，将使用RocksDB状态的快照创建一个新的manifest日志文件。更新最新的清单文件指针并同步文件系统。成功更新CURRENT文件后，将清除冗余清单日志。

```
MANIFEST = { CURRENT, MANIFEST-<seq-no>* } 
CURRENT = File pointer to the latest manifest log
MANIFEST-<seq no> = Contains snapshot of RocksDB state and subsequent modifications
```

## Version Edit

* RocksDB在任何给定时间的某个状态被称为版本(又名快照)。对版本的任何修改都被认为是版本编辑。Version(或RocksDB状态快照)是通过连接一系列版本编辑来构造的。本质上，清单日志文件是一系列版本编辑。

```
version-edit      = Any RocksDB state change
version           = { version-edit* }
manifest-log-file = { version, version-edit* }
                  = { version-edit* }
```

## Version Edit Layout

* Manifest log是一个Version Edit记录的序列。这个Version Edit记录由编辑标识号标识。

### 数据类型

* 简单数据类型

```
VarX   - Variable character encoding of intX
FixedX - Fixed character encoding of intX
```

* 复杂数据类型

```
String - Length prefixed string data
+-----------+--------------------+
| size (n)  | content of string  |
+-----------+--------------------+
|<- Var32 ->|<-- n            -->|
```

# Block Cache

* 块缓存是RocksDB在内存中缓存数据用于读取的地方。用户可以将缓存对象以所需的容量(size)传递给RocksDB实例。一个Cache对象可以在同一个进程中被多个RocksDB实例共享，从而允许用户控制整个缓存容量。块缓存存储未压缩的块。用户可以选择设置第二个块缓存存储压缩块。读取将首先从未压缩的块缓存中获取数据块，然后从压缩的块缓存中获取数据块。如果使用Direct-IO，压缩块缓存可以替代操作系统页面缓存。
* RocksDB 中有两种缓存实现，分别是 LRUCache 和 ClockCache。 两种类型的缓存都被分片以减轻锁争用。 容量平均分配给每个分片，分片不共享容量。 默认情况下，每个缓存将被分片为最多 64 个分片，每个分片的容量不低于 512k 字节。

# Write Buffer Manager

* writer buffer manager帮助用户控制跨多个列族和/或数据库实例的内存表使用的总内存。 用户可以通过两种方式启用此控件：
  * 将跨多个列族和数据库的内存表总使用量限制在阈值以下。
  * 花费memtable内存使用来阻塞缓存，这样RocksDB的内存就可以被单个限制所限制。

## memtable的总内存限制

* 在创建写缓冲区管理器对象时给出内存限制。RocksDB将尝试将总内存限制在这个限制之下。
* 在5.6或更高版本中，您插入的DB的一个列族会触发flush，
  * 如果可变memtable大小超过了限制的90%
  * 如果总内存超过限制，只有当可变memtable大小也超过了限制的50%时，才会触发更激进的刷新。

# Compaction

## 压缩算法概览

* Rocksdb提供以下压缩算法：Classic Leveled, Tiered, Tiered+Leveled(Level Compaction), Leveled-N, FIFO

### Classic Leveled

```
什么是扇入和扇出？ 

在软件设计中，扇入和扇出的概念是指应用程序模块之间的层次调用情况。

按照结构化设计方法，一个应用程序是由多个功能相对独立的模块所组成。

扇入：是指直接调用该模块的上级模块的个数。扇入大表示模块的复用程序高。

扇出：是指该模块直接调用的下级模块的个数。扇出大表示模块的复杂度高，需要控制和协调过多的下级模块；但扇出过小（例如总是1）也不好。扇出过大一般是因为缺乏中间层次，应该适当增加中间层次的模块。扇出太小时可以把下级模块进一步分解成若干个子功能模块，或者合并到它的上级模块中去。
```

* 以读写放大为代价最小化空间放大，LSM树是一系列的层级，每个level都是将多个文件排序后运行。每一level都比前一level大很多，相邻能级的尺寸比有时被称为扇出，当所有能级之间使用同一个扇出时，写放大就会最小化。压缩到N级(Ln)将Ln-1中的数据合并到Ln中。压缩到Ln会重写之前合并到Ln的数据。在最坏的情况下，每个级别的写放大等于扇出，但在实践中往往比扇出少，这在Hyeontaek Lim等人的论文中解释。在最初的LSM论文中，压缩是全对全的——所有来自Ln-1的数据都与来自Ln的所有数据合并。对于LevelDB和RocksDB是一些对一些的——Ln-1中的一些数据与Ln中的一些(重叠的)数据合并。

### Leveled-N

* Leveled-N 压缩类似于leveled压缩，但写入更少，读取放大更多。 它允许每个级别有多个排序运行。 压缩将所有从 Ln-1 排序的运行合并到一个来自 Ln 的排序运行中，这是一个级别。 然后在名称中添加“-N”以表示每个级别可以有 n 次排序运行。 Dostoevsky 论文定义了一种名为 Fluid LSM 的压缩算法，其中最大级别有 1 次排序运行，但非最大级别可以有超过 1 次排序运行。 水平压缩完成到最大级别。

### Tiered

* Tiered Compaction以读和空间放大为代价最小化写放大。每个级别有 N 个排序运行。 Ln 中的每个排序运行比 Ln-1 中的排序运行大 ~N 倍。 压缩合并一个级别中的所有排序运行，以在下一个级别创建一个新的排序运行。 在这种情况下，N 类似于用于水平压缩的扇出。 合并到 Ln 时，压缩不会读取/重写 Ln 中的排序运行。 每级写入放大为 1，这远低于扇出的水平。

### Tiered+Leveled

* Tiered+Leveled 的写入放大比 leveled 小，空间放大比 tiered 小。它对较小的级别使用 tiered，对较大的级别使用 leveled。 LSM 树从分层切换到分层的级别是灵活的，Leveled compaction在Rocksdb中就是Tiered+Leveled。

### FIFO

* FIFOStyle压缩删除过时的文件，并可用于类似缓存的数据。

## Leveled Compaction

### 存储文件的结构

![](./img/level_structure.png)

* 在每个级别(除了级别0)内，数据范围被划分为多个SST文件

![](./img/level_files.png)

* level是有序的运行因为每个keys在SST都是有序的。为了确定一个键的位置，我们首先对所有文件的开始/结束键进行二分搜索以确定哪个文件可能包含该键，然后在文件内部进行二分搜索以定位确切位置。 总之，这是对level中所有键的完整二分搜索。
* 所有非 0 级别都有目标大小。 Compaction 的目标是将这些级别的数据大小限制在目标以下。 规模目标通常呈指数增长：

![](./img/level_targets.png)

### Compactions

* 当 L0 文件数量达到 `level0_file_num_compaction_trigger` 时触发 Compaction，L0 的文件将合并到 L1。后续L1超过在压缩到L2依次进行压缩

![](./img/pre_l0_compaction.png) 

* 除了L0到L1，后续level压缩可以并行执行压缩。

![](./img/pre_l1_compaction.png)

![](./img/pre_l2_compaction.png)

* 允许的最大压缩数由 `max_background_compactions` 控制。但是，默认情况下，L0 到 L1 的压缩不是并行化的。 在某些情况下，它可能成为限制总压缩速度的瓶颈。 RocksDB 仅支持 L0 到 L1 的基于子压缩的并行化。 要启用它，用户可以将 `max_subcompactions` 设置为大于 1。 然后，我们将尝试对范围进行分区并使用多个线程来执行它：

![](./img/subcompaction.png)

### Compaction Picking

* 当多个level触发了compaction条件，RocksDB需要选择一个level首先去压缩，为每个level生成一个分数：
  * 对于非0的level，这个分数是level的总大小除以目标大小。 如果已经选择了要压缩到下一级的文件，则这些文件的大小不包括在总大小中，因为它们很快就会消失。
  * 对于 0 级，分数是文件总数除以` level0_file_num_compaction_trigger` 或超过 `max_bytes_for_level_base` 的总大小，以较大者为准。 （如果文件大小小于` level0_file_num_compaction_trigger`，无论分数有多大，都不会从 level 0 触发压缩。）
* 分数越高的level最先压缩。

### 周期压缩

* 如果存在压缩过滤器，RocksDB 会确保数据在一定时间后通过压缩过滤器。 这是通过 `options.periodic_compaction_seconds` 实现的。 将其设置为 0 将禁用此功能。 保留默认值，即 UINT64_MAX - 1，表示 RocksDB 控制该功能。 目前，RocksDB 会将值更改为 30 天。 每当 RocksDB 尝试选择压缩时，超过 30 天的文件将有资格进行压缩并被压缩到相同的级别。

