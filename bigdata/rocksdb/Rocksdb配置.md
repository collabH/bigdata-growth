# 调优配置

## 如何保证数据快速写入RocksDb

1. 使用单个写入线程并且有序插入
2. 将数百个键批量写入一批
3. memtable底层数据结构使用vector
4. 确保`options.max_background_flushes`至少为4
5. 在插入数据之前，禁用自动压缩，将 options.level0_file_num_compaction_trigger、options.level0_slowdown_writes_trigger 和 options.level0_stop_writes_trigger 设置为非常大的值。 插入所有数据后，发出手动压缩。

* 如果调用`Options::PrepareForBulkLoad()`3-5条将会自动开启，如果可以离线的方式插入数据到rocksdb，有一种更快的方法：您可以对数据进行排序，并行生成具有非重叠范围的 SST 文件并批量加载 SST 文件

## 如果将计算引擎k-v数据高效写入Rocksdb

* 可以通过`SstFileWriter`,它允许您直接创建 RocksDB SST 文件并将它们添加到 RocksDB 数据库中。但是，如果你要将SST文件添加到现有的RocksDB数据库中，那么它的键范围一定不能与数据库重叠。

# 基本操作

## 迭代器

* 数据库中的所有数据都是按逻辑顺序排列的。 应用程序可以指定指定键的总排序的键比较方法。 Iterator API 允许应用程序对数据库进行范围扫描。

### Consistent View

* 如果`ReadOptions.snapshot`被设置，这个iterator将会返回这些数据的快照。如果没有设置，iterator将从创建迭代器时的隐式快照中读取。

### 范围查询

* 通过`ReadOptions.iterate_upper_bound`和`ReadOptions.iterate_lower_bound`设置iterator遍历查询的范围。

### 迭代器固定的资源和迭代器刷新

* 迭代器本身不会占用太多内存，但它可以防止某些资源被释放。这包括：
  * 迭代器创建时的 memtables 和 SST 文件。 即使某些 memtables 和 SST 文件在刷新或压缩后被删除，如果迭代器固定它们，它们仍然保留。
  * 当前迭代位置的数据块。 这些块将保存在内存中，要么固定在块缓存中，要么在未设置块缓存时在堆中。 请注意，虽然通常块很小，但在某些极端情况下，如果值非常大，单个块可能会很大。
* 所以迭代器最好保持较短的生存周期确保这些资源被释放，Iterator的创建也存在成本因此复用iterator是最合适的，在 5.7 版之前，您需要销毁迭代器并在需要时重新创建它。 从 5.7 版开始，您可以调用` API Iterator::Refresh() 来刷新它`。 通过调用这个函数，迭代器被刷新以表示最近的状态，并且先前固定的陈旧资源被释放。

### 前缀iterator

* 为了提升性能，前缀iterator运行用户使用bloom filter或者hash索引在这个iterator中。参数`total_order_seek`和`prefix_same_as_start`适用于前缀iterator。

### 预读取

* RocksDB 会自动预读并在迭代期间注意到同一表文件的 2 个以上 IO 时预取数据。 这仅适用于基于块的表格格式。 预读大小从 8KB 开始，并在每个额外的顺序 IO 上呈指数增加，最大为 BlockBasedTableOptions.max_auto_readahead_size（默认 256 KB）。 这有助于减少完成范围扫描所需的 IO 数量。 此自动预读仅在 ReadOptions.readahead_size = 0（默认值）时启用。 在 Linux 上，在 Buffered IO 模式下使用 readahead syscall，在 Direct IO 模式下使用 AlignedBuffer 来存储预取数据。 （自动迭代器预读从 5.12 开始可用于缓冲 IO，从 5.15 开始可用于直接 IO）。
* 如果您的整个用例以迭代为主，并且您依赖于操作系统页面缓存（即使用缓冲 IO），您可以通过设置 DBOptions.advise_random_on_open = false 来选择手动开启预读。 如果您在硬盘驱动器或远程存储上运行，这会更有帮助，但对直接连接的 SSD 设备可能没有太大的实际影响。
* ReadOptions.readahead_size 在 RocksDB 中为非常有限的用例提供预读支持。 此功能的局限性在于，如果打开，迭代器的恒定成本会高得多。 因此，您应该只在迭代非常大范围的数据时使用它，而不能使用其他方法来解决它。 一个典型的用例是存储是具有很长延迟的远程存储，操作系统页面缓存不可用并且将扫描大量数据。 通过启用此功能，每次读取 SST 文件都会根据此设置预读数据。 请注意，一个迭代器可以打开每个级别的每个文件，以及同时打开所有 L0 文件。 您需要为它们预算预读内存。 并且无法自动跟踪预读缓冲区使用的内存。

## 前缀查询

### 为什么要prefix seek

* 通常，当执行迭代器seek时，RocksDB需要将`每个排序运行(memtable, level-0文件，其他级别等)的位置放置到seek位置，并合并这些排序运行`。这有时会涉及几个I/O请求。对于几个数据块的解压缩和其他CPU开销，它也会占用大量的CPU。
* 前缀查找是`用于减轻某些用例的这些开销的功能`。 基本思想是，如果用户`知道迭代将在一个键前缀内，则可以使用公共前缀来降低成本`。 最常用的前缀迭代技术是`前缀布隆过滤器`。 如果许多排序运行不包含此前缀的任何条目，则可以通过布隆过滤器将其过滤掉，并且可以忽略排序运行的某些 I/O 和 CPU。

### 配置前缀bloom filter

```c++
Options options;

// Set up bloom filter
rocksdb::BlockBasedTableOptions table_options;
table_options.filter_policy.reset(rocksdb::NewBloomFilterPolicy(10, false));
table_options.whole_key_filtering = false;  // If you also need Get() to use whole key filters, leave it to true.
options.table_factory.reset(
    rocksdb::NewBlockBasedTableFactory(table_options));  // For multiple column family setting, set up specific column family's ColumnFamilyOptions.table_factory instead.

// Define a prefix. In this way, a fixed length prefix extractor. A recommended one to use.
options.prefix_extractor.reset(NewCappedPrefixTransform(3));

DB* db;
Status s = DB::Open(options, "/tmp/rocksdb",  &db);
```

* `options.perefix_extractor`指定前缀,如果这个参数改变需要重启DB，通常，最终结果是现有SST文件中的bloom过滤器在读取时会被忽略。

### Prefix bloom配置

* 设置 `read_options.total_order_seek = true` 将确保查询返回与没有前缀布隆过滤器相同的结果，忽略前缀bloom filter。
* `read_options.auto_prefix_mode = true;`防止bloom filter的"假阳性"因hash冲突导致的不存在的数据显示存在。

## SeekForPrev

* 从4.13开始，Rocksdb添加了Iterator::SeekForPrev()。与seek()相比，这个新API将查找最后一个小于或等于目标键的键。

```c++
// Suppose we have keys "a1", "a3", "b1", "b2", "c2", "c4".
auto iter = db->NewIterator(ReadOptions());
iter->Seek("a1");        // iter->Key() == "a1";
iter->Seek("a3");        // iter->Key() == "a3";
iter->SeekForPrev("c4"); // iter->Key() == "c4";
iter->SeekForPrev("c3"); // iter->Key() == "c2";

// 类似的操作，但是这样会导致iterator失效
Seek(target); 
if (!Valid()) {
  SeekToLast();
} else if (key() > target) { 
  Prev(); 
}
```

## Tailing Iterator

* 追踪迭代器可以看到iterator创建后新增的数据但是不能指定snapshot，其他iterator创建后可能读取新增的数据。
* 对于执行顺序读取，它进行了优化——在很多情况下，它可能避免在SST文件和不可变memtable上执行潜在的昂贵搜索。

### 配置

* `ReadOptions::tailing=true`开启，目前不支持Prev()和SeekToLast()
* tailingt iterator提供的俩个内部iterator
  * 可变迭代器，仅用于访问当前memtable内容
  * 一个不可变迭代器，用于从SST文件和不可变memtable中读取数据

## Compaction Filter

* RocksDB提供了一种基于自定义逻辑在后台删除或修改键/值对的方法。它可以方便地实现自定义垃圾收集，比如根据TTL删除过期的键，或者在后台删除一系列键。它还可以更新现有键的值。
* 要使用压缩过滤器，应用程序需要实现在rocksdb/compaction_filter.h 中找到的`CompactionFilter 接口并将其设置为ColumnFamilyOptions`。 或者，应用程序可以实现 CompactionFilterFactory 接口，它可以灵活地为每个（子）压缩创建不同的压缩过滤器实例。 压缩过滤器工厂还通过给定的 CompactionFilter::Context 参数从压缩中了解一些上下文（无论是完全压缩还是手动压缩）。 工厂可以根据上下文选择返回不同的压缩过滤器。

```c++
options.compaction_filter = new CustomCompactionFilter();
// or
options.compaction_filter_factory.reset(new CustomCompactionFilterFactory());
```

* 每次(子)压缩从其输入中看到一个新键，且该值是正常值时，它就调用压缩筛选器。根据压实过滤器的结果
  * 如果它决定保留key，什么都不会改变。
  * 如果请求过滤键，则该值将被删除标记替换。注意，如果压缩的输出级别是底层，则不需要输出删除标记。
  * 如果请求更改该值，则该值将被更改后的值替换。
  * 如果它请求通过返回kRemoveAndSkipUntil来删除一段键，则压缩将跳到skip_until(意味着skip_until将是压缩后的下一个可能的键输出)。这个比较棘手，因为在这种情况下，压缩不会为它跳过的键插入删除标记。这意味着旧版本的键可能会重新出现。另一方面，如果应用程序知道没有旧版本的键，或者可以重新出现旧版本，那么简单地删除键会更有效。
* 如果来自压缩输入的相同键有多个版本，则对最新版本只调用压缩筛选器一次。如果最新版本是删除标记，则不会调用压缩筛选器。但是，如果删除标记没有包含在压缩的输入中，则可能对已删除的键调用压缩筛选器。
* 当merge被使用，每个合并操作数调用压缩过滤器。 在调用合并运算符之前，将压缩过滤器的结果应用于合并操作数。

## Merge Operator

* merge operator描述了原子性的在rocksdb读取修改写入操作，如果用户操作Rocksdb存在获取、修改并且再写入，那么就需要用户来保证它的原子性，merge operator可以解决这个问题。
  * 将读-修改-写的语义封装到一个简单的抽象接口中。
  * 允许用户避免因重复Get()调用而产生额外成本。
  * 在不改变底层语义的情况下，执行后端优化以决定何时/如何组合操作数。
  * 在某些情况下，可以摊销所有增量更新的成本，以提供渐进的效率提高。

```c++
    void Merge(...) {
       if (key start with "BAL:") {
         NumericAddition(...)
       } else if (key start with "HIS:") {
         ListAppend(...);
       }
     }

 ...
    // Put/store the json string into to the database
    db_->Put(put_option_, "json_obj_key",
             "{ employees: [ {first_name: john, last_name: doe}, {first_name: adam, last_name: smith}] }");

    ...

    // Use a pre-defined "merge operator" to incrementally update the value of the json string
    db_->Merge(merge_option_, "json_obj_key", "employees[1].first_name = lucy");
    db_->Merge(merge_option_, "json_obj_key", "employees[0].last_name = dow");
```

### Demo

```java
Key: ‘Some-Key’ Value: [2], [3,4,5], [21,100], [1,6,8,9]
To store such a KV pair users would typically call the Merge API as:
a. db→Merge(WriteOptions(), 'Some-Key', '2');
b. db→Merge(WriteOptions(), 'Some-Key', '3,4,5');
c. db→Merge(WriteOptions(), 'Some-Key', '21,100');
d. db→Merge(WriteOptions(), 'Some-Key', '1,6,8,9');

// 最终得到[2,3,4,5,21,100,1,6,8,9] 
```

### 最佳实践

#### 什么时候使用merge

1. 有数据需要增加修改
2. 在知道新值是什么之前，您通常需要读取数据。

### 关联数据

1. 合并操作数的格式与Put值和相同
2. 可以将多个操作数合二为一（只要顺序相同即可）

## Column Families

* 在RocksDb3.0之后支持了列族，RocksDB 中的每个键值对都与一个列族相关联。 如果没有指定列族，键值对与列族“default”相关联。列族提供了一种对数据库进行逻辑分区的方法。 
  * 支持跨列族原子写，这个意思是可以原子写入`({cf1, key1, value1}, {cf2, key2, value2}).`
  * 跨列族的数据库一致视图。
  * 能够独立配置不同的列族。
  * 即时添加新的列族并删除它们。 这两种操作都相当快。

### 列族操作

* 读取Rocksdb时open db时需要指定全部列族

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

* 只读Db不需要指定列族`DB::ListColumnFamilies(const DBOptions& db_options, const std::string& name, std::vector<std::string>* column_families)`

### 实现原理

* 列族主要的思想是它们共享wal日志而不共享memtables和表文件。通过共享wal日志可以获的原子写的最大好处，通过分离memtables和表文件，我们可以独立配置列族并快速删除它们。
* 每次刷新单个Column Family时，都会创建一个新的WAL (write-ahead log)。所有对所有列族的新写入都转到新的 WAL。但是，我们仍然无法删除旧的 WAL，因为它包含来自其他列族的实时数据。只有当全部的列族已经被刷新和这个WAL包含的全部数据已经持久化到表文件的时候才可以删除旧的WAL文件。确保对RocksDB进行调优，以便定期刷新所有列族。另外，查看`Options::max_total_wal_size`，可以配置为自动刷新过时的列族。

## SST File

* Rocksdb提供创建SST文件的API，并且也提供了获取SST文件的API，如果你需要快速的加载数据，可以通过离线的方式创建SST文件存入RocksDB。

### 创建SST文件

* `rocksdb::SstFileWriter`可以被用于创建SST文件，创建`SstFileWriter`对象后可以打开一个文件，然后插入记录直到完毕。

```javascript
public class SstWriterFeature {
    private static final String path = "/Users/huangshimin/Documents/study/rocksdb/sst/test.sst";

    public static void main(String[] args) {
        EnvOptions envOptions = new EnvOptions();
        envOptions.allowFallocate();
        // 配置ratelimiter
//        envOptions.setRateLimiter();
        Options options = new Options();
        options.allow2pc();
        options.allowConcurrentMemtableWrite();
        try (SstFileWriter sstFileWriter = new SstFileWriter(envOptions, options)) {
            sstFileWriter.open(path);
            sstFileWriter.put(new Slice("test"), new Slice("zhangsan"));
            sstFileWriter.finish();
        } catch (RocksDBException e) {
            e.printStackTrace();
        }
    }
}
```

### 读取Sst文件

* 通过`db.ingestExternalFile)()`读取sst file

```java
 public static void main(String[] args) {
        RocksDB.loadLibrary();
        IngestExternalFileOptions ingestExternalFileOptions = new IngestExternalFileOptions();
        try (RocksDB db = RocksDB.open(dbPath)){
            db.ingestExternalFile(Lists.newArrayList(path),ingestExternalFileOptions);
            System.out.println(new String(db.get("test".getBytes()), Charset.defaultCharset()));
        } catch (RocksDBException e) {
            e.printStackTrace();
        }
    }
```

* 调用ingest的会发生如下事情：

  * 将文件复制或链接到DB目录中
  * 块(而不是跳过)写入数据库，因为我们必须保持一致的数据库状态，因此我们必须确保我们可以安全地为我们将要摄入的文件中的所有键分配正确的序列号
  * 如果文件键范围与memtable键范围重叠，则刷新memtable
  * 将文件分配到lsm树中可能的最level层
  * 分配文件一个全局序列号
  * 重写到DB

* `ingest_behind==true`跳过重复key

  ```java
   // 跳过重复key覆盖
          ingestExternalFileOptions.setIngestBehind(true);
  ```

* 回填数据库中的一些历史数据，而不覆盖现有的较新版本的数据。 只有当数据库从一开始就以 `allow_ingest_behind=true` 运行时，才能使用此选项。 所有文件都将在 `seqno=0` 的最底层摄取。

## Single Delete

* 它会删除键的最新版本，而旧版本的键是否会恢复则是未定义的。

```java
 private static void singleDelete(String key) {
        try {
            WriteOptions writeOptions = new WriteOptions();
            writeOptions.disableWAL();
            writeOptions.ignoreMissingColumnFamilies();
            db.singleDelete(key.getBytes());
            // batch中删除
            WriteBatch writeBatch = new WriteBatch();
            writeBatch.singleDelete(key.getBytes());
        } catch (RocksDBException e) {
            e.printStackTrace();
        }
    }
```

### note

1. 调用者必须确保SingleDelete只应用于未使用Delete()删除或未使用Merge()写入的键。将SingleDelete()操作与Delete()和Merge()混合会导致未定义的行为(其他键不受此影响)
2. `SingleDelete`和cuckoo hash tables不兼容，这意味着如果您使用`NewHashCuckooRepFactory` 设置 options.memtable_factory，则不应调用 SingleDelete
3. 目前不允许连续`SingleDelete`
4. 考虑设置`write_options.sync=true`

## Low Priority Write

* 如果他们尽可能快地发出后台写操作，就会触发DB的节流机制(参见Write stall)，这不仅会减慢后台写操作，还会减慢用户在线查询的速度。
* 低优先级写能够帮助用户管理写入的优先级，5.6版本之后，用户可以通过`writeOptions.setLowPri(true);`设置后台写入，RocksDB将对低优先级写入进行更积极的节流，以确保高优先级写入不会陷入停滞。
* 当DB运行时，RocksDB将通过查看未完成的L0文件和未完成的压缩字节来评估我们是否有压缩压力。如果RocksDB认为存在压缩压力，它会将人工睡眠引入到低优先级写，从而使低优先级写的总速率很小。通过这样做，总的写速率将比总的写节流条件下降得更早，因此高优先级写的服务资格更有可能得到保证。
* 在二阶段提交的时候低优先级写是在准备阶段完成的而不是提交阶段。

## Time to Live

* 设置ttl时间后这个db插入的key-value会在ttl时候后过期。

```java
Options options = new Options();
options.setTtl(1001);
db = RocksDB.open(options,dbPath);
```

### 配置概念

1. TTL是秒级别
2. put的值后缀会携带创建的时间戳Timestamp
3. 过期的TTL值只会在compaction的时候删除:(Timestamp+ttl<time_now)
4. GET/Iterator可能返回过期的条目，因为compaction还没有运行
5. 不同的TTL可以在不同的open使用
   1. 例如：Open1 at t=0 with ttl=4 and insert k1,k2, close at t=2. Open2 at t=3 with ttl=5. Now k1,k2 should be deleted at t>=5
6. 只读库compaction不被触发，因此不会删除过期的条目。
7. 不要指定ttl为负值

### 注意点

1. 直接调用DB::Open来重新打开由这个API创建的DB将得到损坏的值(带有时间戳后缀)，并且在第二次Open期间没有ttl效应，所以使用这个TTL API来打开DB
2. 传递ttl时要小心，因为整个数据库可能会在很短的时间内被删除

## 事务

* RocksDB支持事务，使用`TransactionDb`或`OptimisticTransactionDB`可以开启事务，事务支持简单的`BEGIN/COMMIT/ROLLBACK`API并且允许应用程序同时修改它们的数据，同时让RocksDB处理冲突检查。RocksDB支持悲观并发控制和乐观并发控制。
* 当通过`WriteBatch`写入多个key的时候默认是原子性的，事务提供了一种方法来保证只在没有冲突的情况下才写入一批写入。与WriteBatch类似，在事务被写入(提交)之前，其他线程无法看到事务中的变化。

### TransactionDB

* 使用`TransactionDB`的时候所有写入的键都被RocksDB在内部锁定，以执行冲突检测。如果一个key不能被locked，这个操作将会返回错误。当事务被提交，只要能够写入数据库，就可以保证成功。
* 与OptimisticTransactionDB相比，TransactionDB更适合并发性强的工作负载。但是，在使用 TransactionDB 时会有少量的锁开销。 TransactionDB 将对所有写操作（Put、Delete 和 Merge）进行冲突检查，包括在事务之外执行的写操作。

```java
public static void main(String[] args) throws RocksDBException {
        Options options = new Options();
        options.setCreateIfMissing(true);
        TransactionDBOptions transactionOptions = new TransactionDBOptions();
        TransactionDB.loadLibrary();
        TransactionDB transactionDB = TransactionDB.open(options, transactionOptions, dbPath);
        WriteOptions writeOptions = new WriteOptions();
        writeOptions.ignoreMissingColumnFamilies();
        ReadOptions readOptions = new ReadOptions();
        // 开启事务
        Transaction transaction = transactionDB.beginTransaction(writeOptions);
        transaction.put("name".getBytes(), "hsm".getBytes());
        System.out.println(new String(transaction.get(readOptions, "name".getBytes()), Charset.defaultCharset()));
//        transaction.merge("name".getBytes(),"wy".getBytes());
//        transaction.delete("name".getBytes());
        System.out.println(new String(transaction.get(readOptions, "name".getBytes()), Charset.defaultCharset()));
        transaction.commit();
        transaction.close();
        transactionDB.close();
    }
```

