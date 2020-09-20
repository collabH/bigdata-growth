# 计算引擎概述

* 计算引擎包括执行内存和Shuffle两部分

## 执行内存

```reStructuredText
   执行内存主要包括执行内存、任务内存管理器（TaskMemoryManager）、内存消费者（MemoryConsumer）等内容。执行内存包括在JVM堆上进行分配的执行内存池（ExecutionMemoryPool）和在操作系统的内存中进行分配的Tungsten。内存管理器将提供API对执行内存和Tungsten进行管理（包括申请内存、释放内存等）。因为同一节点上能够运行多次任务尝试，所以需要每一次任务尝试都有单独的任务内存管理器为其服务。任务尝试通过任务内存管理器与内存管理器交互，以申请任务尝试所需要的执行内存，并在任务尝试结束后释放使用的执行内存。一次任务尝试过程中会有多个组件需要使用执行内存，这些组件统称为内存消费者。内存消费者多种多样，有对map任务的中间输出数据在JVM堆上进行缓存、聚合、溢出、持久化等处理的ExternalSorter，也有在操作系统内存中进行缓存、溢出、持久化处理的ShuffleExternalSorter，还有将key/value对存储到连续的内存块中的RowBasedKeyValueBatch。消费者需要的执行内存都是向任务内存管理器所申请的。
```

![执行内存](./img/计算引擎执行内存体系.jpg)

## Shuffle

* Shuffle是所有MapReduce计算框架必须面临的执行阶段，Shuffle用于打通map任务的输出与reduce任务的输入，map任务的中间输出结果按照指定的分区策略（例如，按照key值哈希）分配给处理某一个分区的reduce任务

### Spark早期Shuffle

![](./img/Saprk早期Shuffle.jpg)

1. map任务会为每一个reduce任务创建一个bucket。假设有M个map任务，R个reduce任务，则map阶段一共会创建M× R个桶（bucket）。
2. map任务会将产生的中间结果按照分区（partition）写入到不同的bucket中。
3. reduce任务从本地或者远端的map任务所在的BlockManager获取相应的bucket作为输入。

#### 存在的问题

1. map任务的中间结果首先存入内存，然后才写入磁盘。这对于内存的开销很大，当一个节点上map任务的输出结果集很大时，很容易导致内存紧张，进而发生内存溢出（Out Of Memory，简称OOM）。
2. 每个map任务都会输出R（reduce任务数量）个bucket。假如M等于1000, R也等于1000，那么共计生成100万个bucket，在bucket本身不大，但是Shuffle很频繁的情况下，磁盘I/O将成为性能瓶颈。

#### 解决方法

1. 将map任务给每个partition的reduce任务输出的bucket合并到同一个文件中，这解决了bucket数量很多，但是数据本身的体积不大时，造成Shuffle频繁，磁盘I/O成为性能瓶颈的问题。
2. map任务逐条输出计算结果，而不是一次性输出到内存，并使用AppendOnlyMap缓存及其聚合算法对中间结果进行聚合，这大大减小了中间结果所占的内存大小。
3. 对SizeTrackingAppendOnlyMap、SizeTrackingPairBuffer及Tungsten的Page进行溢出判断，当超出溢出限制的大小时，将数据写入磁盘，防止内存溢出。
4. reduce任务对拉取到的map任务中间结果逐条读取，而不是一次性读入内存，并在内存中进行聚合（其本质上也使用了AppendOnlyMap缓存）和排序，这也大大减小了数据占用的内存大小。
5. reduce任务将要拉取的Block按照BlockManager地址划分，然后将同一Block Manager地址中的Block累积为少量网络请求，减少网络I/O。

## Spark Shuffle流程

```
  map任务在输出时会进行分区计算并生成数据文件和索引文件等步骤，可能还伴随有缓存、排序、聚合、溢出、合并等操作。reduce任务将map任务输出的Block划分为本地和远端的Block，对于远端的Block，需要使用ShuffleClient从远端节点下载，而对于本地的Block，只需要从本地的存储体系中读取即可。reduce任务读取到map任务输出的数据后，可能进行缓存、排序、聚合、溢出、合并等操作，最终输出结果。
```

# 内存管理器与Tungsten

## Memoryblock

* 操作系统中的Page是一个内存块，在Page中可以存放数据，操作系统中会有多种不同的Page。操作系统对数据的读取，往往是先确定数据所在的Page，然后使用Page的偏移量（offset）和所读取数据的长度（length）从Page中读取数据。
* 在Tungsten中实现了一种与操作系统的内存Page非常相似的数据结构，这个对象就是MemoryBlock。MemoryBlock中的数据可能位于JVM的堆上，也可能位于JVM的堆外内存（操作系统内存）中。

### MemoryLocation

```java
public class MemoryLocation {

  /**
   * 这里为null的主要原因是，当数据存储在offheap时，jvm堆内是不存在数据的，只存储对应的offset
   */
  @Nullable
  Object obj;

  long offset;

  public MemoryLocation(@Nullable Object obj, long offset) {
    this.obj = obj;
    this.offset = offset;
  }

  public MemoryLocation() {
    this(null, 0);
  }

  public void setObjAndOffset(Object newObj, long newOffset) {
    this.obj = newObj;
    this.offset = newOffset;
  }

  public final Object getBaseObject() {
    return obj;
  }

  public final long getBaseOffset() {
    return offset;
  }
}
```

### MemoryBlock

```java
public class MemoryBlock extends MemoryLocation {

  /** Special `pageNumber` value for pages which were not allocated by TaskMemoryManagers */
  public static final int NO_PAGE_NUMBER = -1;

  /**
   * Special `pageNumber` value for marking pages that have been freed in the TaskMemoryManager.
   * We set `pageNumber` to this value in TaskMemoryManager.freePage() so that MemoryAllocator
   * can detect if pages which were allocated by TaskMemoryManager have been freed in the TMM
   * before being passed to MemoryAllocator.free() (it is an error to allocate a page in
   * TaskMemoryManager and then directly free it in a MemoryAllocator without going through
   * the TMM freePage() call).
   */
  public static final int FREED_IN_TMM_PAGE_NUMBER = -2;

  /**
   * Special `pageNumber` value for pages that have been freed by the MemoryAllocator. This allows
   * us to detect double-frees.
   */
  public static final int FREED_IN_ALLOCATOR_PAGE_NUMBER = -3;

  // 当前MemoryBlock的连续内存块的长度
  private final long length;

  /**
   * Optional page number; used when this MemoryBlock represents a page allocated by a
   * TaskMemoryManager. This field is public so that it can be modified by the TaskMemoryManager,
   * which lives in a different package.
   */
  //当前MemoryBlock的页号。TaskMemoryManager分配由MemoryBlock表示的Page时，将使用此属性。
  public int pageNumber = NO_PAGE_NUMBER;

  public MemoryBlock(@Nullable Object obj, long offset, long length) {
    super(obj, offset);
    this.length = length;
  }

  /**
   * MemoryBlock的大小，即length。
   * Returns the size of the memory block.
   */
  public long size() {
    return length;
  }

  /**
   * 创建一个指向由长整型数组使用的内存的MemoryBlock。
   * Creates a memory block pointing to the memory used by the long array.
   */
  public static MemoryBlock fromLongArray(final long[] array) {
    return new MemoryBlock(array, Platform.LONG_ARRAY_OFFSET, array.length * 8L);
  }

  /**
   * 以指定的字节填充整个MemoryBlock，即将obj对象从offset开始，长度为length的堆内存替换为指定字节的值。Platform中封装了对sun.misc.Unsafe[插图]的API调用，Platform的setMemory方法实际调用了sun.misc.Unsafe的setMemory方法。
   * Fills the memory block with the specified byte value.
   */
  public void fill(byte value) {
    Platform.setMemory(obj, offset, length, value);
  }
}
```

# IndexShuffleBlockResolver

* ShuffleBlockResolver定义了对Shuffle Block进行解析的规范，包括获取Shuffle数据文件、获取Shuffle索引文件、删除指定的Shuffle数据文件和索引文件、生成Shuffle索引文件、获取Shuffle块的数据等。
* ShuffleBlockResolver目前只有IndexShuffleBlockResolver这唯一的实现类。IndexShuffleBlockResolver用于创建和维护Shuffle Block与物理文件位置之间的映射关系。

```scala
private[spark] class IndexShuffleBlockResolver(
    conf: SparkConf,
    _blockManager: BlockManager = null)
  extends ShuffleBlockResolver
  with Logging {

  private lazy val blockManager = Option(_blockManager).getOrElse(SparkEnv.get.blockManager)

  // shuffle 网络配置
  private val transportConf = SparkTransportConf.fromSparkConf(conf, "shuffle")

  /**
   * 获取data文件
   * @param shuffleId
   * @param mapId
   * @return
   */
  def getDataFile(shuffleId: Int, mapId: Int): File = {
    // 获取data文件
    blockManager.diskBlockManager.getFile(ShuffleDataBlockId(shuffleId, mapId, NOOP_REDUCE_ID))
  }

  private def getIndexFile(shuffleId: Int, mapId: Int): File = {
    // 获取index文件
    blockManager.diskBlockManager.getFile(ShuffleIndexBlockId(shuffleId, mapId, NOOP_REDUCE_ID))
  }

  /**
   * 用于删除Shuffle过程中包含指定map任务输出数据的Shuffle数据文件和索引文件。
   * Remove data file and index file that contain the output data from one map.
   */
  def removeDataByMap(shuffleId: Int, mapId: Int): Unit = {
    // 获取data文件
    var file: File = getDataFile(shuffleId, mapId)
    if (file.exists()) {
      if (!file.delete()) {
        logWarning(s"Error deleting data ${file.getPath()}")
      }
    }
    // 获取index文件
    file = getIndexFile(shuffleId, mapId)
    if (file.exists()) {
      if (!file.delete()) {
        logWarning(s"Error deleting index ${file.getPath()}")
      }
    }
  }

  /**
   * 校验index和data文件
   * Check whether the given index and data files match each other.
   * If so, return the partition lengths in the data file. Otherwise return null.
   */
  private def checkIndexAndDataFile(index: File, data: File, blocks: Int): Array[Long] = {
    // the index file should have `block + 1` longs as offset.
    if (index.length() != (blocks + 1) * 8L) {
      return null
    }
    val lengths = new Array[Long](blocks)
    // Read the lengths of blocks
    val in = try {
      new DataInputStream(new NioBufferedFileInputStream(index))
    } catch {
      case e: IOException =>
        return null
    }
    try {
      // Convert the offsets into lengths of each block
      var offset = in.readLong()
      if (offset != 0L) {
        return null
      }
      var i = 0
      while (i < blocks) {
        val off = in.readLong()
        lengths(i) = off - offset
        offset = off
        i += 1
      }
    } catch {
      case e: IOException =>
        return null
    } finally {
      in.close()
    }

    // the size of data file should match with index file
    if (data.length() == lengths.sum) {
      lengths
    } else {
      null
    }
  }

  /**
   * Write an index file with the offsets of each block, plus a final offset at the end for the
   * end of the output file. This will be used by getBlockData to figure out where each block
   * begins and ends.
   *
   * It will commit the data and index file as an atomic operation, use the existing ones, or
   * replace them with new ones.
   *
   * Note: the `lengths` will be updated to match the existing index file if use the existing ones.
   */
  def writeIndexFileAndCommit(
      shuffleId: Int,
      mapId: Int,
      lengths: Array[Long],
      dataTmp: File): Unit = {
    val indexFile = getIndexFile(shuffleId, mapId)
    // 创建indexTmp
    val indexTmp = Utils.tempFileWith(indexFile)
    try {
      // data文件
      val dataFile: File = getDataFile(shuffleId, mapId)
      // There is only one IndexShuffleBlockResolver per executor, this synchronization make sure
      // the following check and rename are atomic.
      synchronized {
        val existingLengths = checkIndexAndDataFile(indexFile, dataFile, lengths.length)
        if (existingLengths != null) {
          // Another attempt for the same task has already written our map outputs successfully,
          // so just use the existing partition lengths and delete our temporary map outputs.
          System.arraycopy(existingLengths, 0, lengths, 0, lengths.length)
          if (dataTmp != null && dataTmp.exists()) {
            dataTmp.delete()
          }
        } else {
          // This is the first successful attempt in writing the map outputs for this task,
          // so override any existing index and data files with the ones we wrote.
          val out = new DataOutputStream(new BufferedOutputStream(new FileOutputStream(indexTmp)))
          Utils.tryWithSafeFinally {
            // We take in lengths of each block, need to convert it to offsets.
            var offset = 0L
            out.writeLong(offset)
            for (length <- lengths) {
              offset += length
              out.writeLong(offset)
            }
          } {
            out.close()
          }

          if (indexFile.exists()) {
            indexFile.delete()
          }
          if (dataFile.exists()) {
            dataFile.delete()
          }
          if (!indexTmp.renameTo(indexFile)) {
            throw new IOException("fail to rename file " + indexTmp + " to " + indexFile)
          }
          if (dataTmp != null && dataTmp.exists() && !dataTmp.renameTo(dataFile)) {
            throw new IOException("fail to rename file " + dataTmp + " to " + dataFile)
          }
        }
      }
    } finally {
      if (indexTmp.exists() && !indexTmp.delete()) {
        logError(s"Failed to delete temporary index file at ${indexTmp.getAbsolutePath}")
      }
    }
  }

  /**
   *  获取shuffleBlock
   * @param blockId
   * @return
   */
  override def getBlockData(blockId: ShuffleBlockId): ManagedBuffer = {
    // The block is actually going to be a range of a single map output file for this map, so
    // find out the consolidated file, then the offset within that from our index
    // 获取IndexFile
    val indexFile: File = getIndexFile(blockId.shuffleId, blockId.mapId)

    // SPARK-22982: if this FileInputStream's position is seeked forward by another piece of code
    // which is incorrectly using our file descriptor then this code will fetch the wrong offsets
    // (which may cause a reducer to be sent a different reducer's data). The explicit position
    // checks added here were a useful debugging aid during SPARK-22982 and may help prevent this
    // class of issue from re-occurring in the future which is why they are left here even though
    // SPARK-22982 is fixed.
    val channel: SeekableByteChannel = Files.newByteChannel(indexFile.toPath)
    channel.position(blockId.reduceId * 8L)
    val in = new DataInputStream(Channels.newInputStream(channel))
    try {
      val offset = in.readLong()
      val nextOffset = in.readLong()
      val actualPosition = channel.position()
      val expectedPosition = blockId.reduceId * 8L + 16
      if (actualPosition != expectedPosition) {
        throw new Exception(s"SPARK-22982: Incorrect channel position after index file reads: " +
          s"expected $expectedPosition but actual position was $actualPosition.")
      }
      new FileSegmentManagedBuffer(
        transportConf,
        // 获取dataFile
        getDataFile(blockId.shuffleId, blockId.mapId),
        offset,
        nextOffset - offset)
    } finally {
      in.close()
    }
  }

  override def stop(): Unit = {}
}
```



