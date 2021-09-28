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