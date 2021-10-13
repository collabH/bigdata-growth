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