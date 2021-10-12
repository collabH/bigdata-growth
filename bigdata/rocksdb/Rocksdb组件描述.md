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

