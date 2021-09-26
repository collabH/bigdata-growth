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

