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

