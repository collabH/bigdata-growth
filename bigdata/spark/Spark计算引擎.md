# o计算引擎概述

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

## SizeTracker

* Spark在Shuffle阶段，给map任务的输出增加了缓存、聚合的数据结构。这些数据结构将使用各种执行内存，为了对这些数据结构的大小进行计算，以便于扩充大小或在没有足够内存时溢出到磁盘，特质SizeTracker定义了对集合进行采样和估算的规范。

## WritablePartitionedPairCollection

* WritablePartitionedPairCollection是对由键值对构成的集合进行大小跟踪的通用接口。这里的每个键值对都有相关联的分区，例如，key为（0, #）, value为1的键值对，真正的键实际是#，而0则是键#的分区ID。WritablePartitionedPairCollection支持基于内存进行有效排序，并可以创建将集合内容按照字节写入磁盘的WritablePartitionedIterator。

# AppendOnlyMap

* AppendOnlyMap是在内存中对任务执行结果进行聚合运算的利器，最大可以支持375809 638（即0.7×2^29）个元素。

```scala
class AppendOnlyMap[K, V](initialCapacity: Int = 64)
  extends Iterable[(K, V)] with Serializable {

  import AppendOnlyMap._

  require(initialCapacity <= MAXIMUM_CAPACITY,
    s"Can't make capacity bigger than ${MAXIMUM_CAPACITY} elements")
  require(initialCapacity >= 1, "Invalid initial capacity")

  // 负载因子，超过该Capacity*0。7自动扩容
  private val LOAD_FACTOR = 0.7

  // 容量，转换为2的n次方，主要为了后去计算hash时可以直接将取模的逻辑运算优化为算术运算
  private var capacity = nextPowerOf2(initialCapacity)
  // 计算数据存放位置的掩码。计算mask的表达式为capacity -1。
  private var mask = capacity - 1
  // 记录当前已经放入data的key与聚合值的数量。
  private var curSize = 0
  // :data数组容量增长的阈值。计算growThreshold的表达式为grow-Threshold =LOAD_FACTOR * capacity。
  private var growThreshold = (LOAD_FACTOR * capacity).toInt

  // Holds keys and values in the same array for memory locality; specifically, the order of
  // elements is key0, value0, key1, value1, key2, value2, etc.
  // 存储数据的数组，初始化为2倍的capacity
  private var data = new Array[AnyRef](2 * capacity)

  // Treat the null key differently so we can use nulls in "data" to represent empty items.
  // 是否存在null值
  private var haveNullValue = false
  // 控制
  private var nullValue: V = null.asInstanceOf[V]

  // Triggered by destructiveSortedIterator; the underlying data array may no longer be used
  // 表示data数组是否不再使用
  private var destroyed = false
  // 当destroyed为true时，打印的消息内容为"Map state is invalid fromdestructive sorting! "。
  private val destructionMessage = "Map state is invalid from destructive sorting!"
```

## apply

* 根据key获取value

```scala
def apply(key: K): V = {
    assert(!destroyed, destructionMessage)
    val k = key.asInstanceOf[AnyRef]
    if (k.eq(null)) {
      return nullValue
    }
    // 相当于key的hashcode&cap-1 === k.hashcode % cap
    var pos = rehash(k.hashCode) & mask
    var i = 1
    while (true) {
      // 计算当前key的offset
      val curKey: AnyRef = data(2 * pos)
      // 如果k等于当前key
      if (k.eq(curKey) || k.equals(curKey)) {
        // 返回当前key的value，value存储在key的offset+1的位置
        return data(2 * pos + 1).asInstanceOf[V]
        // 如果key为null，返回null
      } else if (curKey.eq(null)) {
        return null.asInstanceOf[V]
      } else {
        val delta = i
        // pos往后移动
        pos = (pos + delta) & mask
        i += 1
      }
    }
    null.asInstanceOf[V]
  }
```

## incrementSize

```scala
 private def incrementSize() {
    // 当前size+1
    curSize += 1
    // 如果当前size大于growThreshold则扩容
    if (curSize > growThreshold) {
      growTable()
    }
  }

// growTable
protected def growTable() {
    // capacity < MAXIMUM_CAPACITY (2 ^ 29) so capacity * 2 won't overflow
    // 新的容量
    val newCapacity = capacity * 2
    // check cap
    require(newCapacity <= MAXIMUM_CAPACITY, s"Can't contain more than ${growThreshold} elements")
    // 穿件新的数组
    val newData = new Array[AnyRef](2 * newCapacity)
    // 计算新的mask
    val newMask = newCapacity - 1
    // Insert all our old values into the new array. Note that because our old keys are
    // unique, there's no need to check for equality here when we insert.
    var oldPos = 0
    // 遍历data数组
    while (oldPos < capacity) {
      // 过滤key为null的数据
      if (!data(2 * oldPos).eq(null)) {
        // 获取key
        val key = data(2 * oldPos)
        // 获取value
        val value = data(2 * oldPos + 1)
        // 重新计算新的pos
        var newPos = rehash(key.hashCode) & newMask
        var i = 1
        // 保持前进
        var keepGoing = true
        while (keepGoing) {
          // 计算新的key
          val curKey = newData(2 * newPos)
          // 如果key为null
          if (curKey.eq(null)) {
            // 赋值key和value
            newData(2 * newPos) = key
            newData(2 * newPos + 1) = value
            keepGoing = false
          } else {
            // 如果已经存在数据
            val delta = i
            // 向后移动
            newPos = (newPos + delta) & newMask
            i += 1
          }
        }
      }
      oldPos += 1
    }
    // 重新复制
    data = newData
    capacity = newCapacity
    mask = newMask
    growThreshold = (LOAD_FACTOR * newCapacity).toInt
  }
```

## update

```scala
def update(key: K, value: V): Unit = {
    assert(!destroyed, destructionMessage)
    val k = key.asInstanceOf[AnyRef]
    // 如果key为null
    if (k.eq(null)) {
      // 判断是否存在null值，如果不存在，这容量增长
      if (!haveNullValue) {
        // 判断是否需要扩容
        incrementSize()
      }
      // 为nullValue赋值
      nullValue = value
      // 设置存在key为Null的value
      haveNullValue = true
      // 返回
      return
    }
    // 计算pos
    var pos = rehash(key.hashCode) & mask
    var i = 1
    // 遍历
    while (true) {
      // 计算当前key的位置
      val curKey = data(2 * pos)
      // 如果当前key在数组中的位置不存在
      if (curKey.eq(null)) {
        // 设置值
        data(2 * pos) = k
        data(2 * pos + 1) = value.asInstanceOf[AnyRef]
        incrementSize()  // Since we added a new key
        return
        // 如果存在
      } else if (k.eq(curKey) || k.equals(curKey)) {
        // 修改value
        data(2 * pos + 1) = value.asInstanceOf[AnyRef]
        return
      } else {
        // 如果不等，则向后移动
        val delta = i
        pos = (pos + delta) & mask
        i += 1
      }
    }
  }
```

## changeValue

* 实现了缓存聚合算法

```scala
 def changeValue(key: K, updateFunc: (Boolean, V) => V): V = {
    assert(!destroyed, destructionMessage)
    val k = key.asInstanceOf[AnyRef]
    if (k.eq(null)) {
      if (!haveNullValue) {
        incrementSize()
      }
      // nullVlaue等于Null
      nullValue = updateFunc(haveNullValue, nullValue)
      haveNullValue = true
      // 返回null
      return nullValue
    }
    var pos = rehash(k.hashCode) & mask
    var i = 1
    while (true) {
      val curKey = data(2 * pos)
      if (curKey.eq(null)) {
        // newValue为null
        val newValue = updateFunc(false, null.asInstanceOf[V])
        data(2 * pos) = k
        // 设置value为null
        data(2 * pos + 1) = newValue.asInstanceOf[AnyRef]
        // 判断是否需要扩容
        incrementSize()
        return newValue
      } else if (k.eq(curKey) || k.equals(curKey)) {
        // 根据聚合函数求出来的值
        val newValue = updateFunc(true, data(2 * pos + 1).asInstanceOf[V])
        data(2 * pos + 1) = newValue.asInstanceOf[AnyRef]
        return newValue
      } else {
        val delta = i
        pos = (pos + delta) & mask
        i += 1
      }
    }
    null.asInstanceOf[V] // Never reached but needed to keep compiler happy
  }
```

## destructiveSortedIterator

* 不使用额外的内存和不牺牲AppendOnlyMap的有效性的前提下，对AppendOnlyMap的data数组中的数据进行排序的实现。

```scala
def destructiveSortedIterator(keyComparator: Comparator[K]): Iterator[(K, V)] = {
    destroyed = true
    // Pack KV pairs into the front of the underlying array
    var keyIndex, newIndex = 0
    // 遍历数组
    while (keyIndex < capacity) {
      // 如果key不为null，去掉不连续的null key
      if (data(2 * keyIndex) != null) {
        data(2 * newIndex) = data(2 * keyIndex)
        data(2 * newIndex + 1) = data(2 * keyIndex + 1)
        newIndex += 1
      }
      keyIndex += 1
    }
    assert(curSize == newIndex + (if (haveNullValue) 1 else 0))

    // 创建Sort排序起
    new Sorter(new KVArraySortDataFormat[K, AnyRef]).sort(data, 0, newIndex, keyComparator)

    new Iterator[(K, V)] {
      var i = 0
      var nullValueReady = haveNullValue
      def hasNext: Boolean = (i < newIndex || nullValueReady)
      def next(): (K, V) = {
        if (nullValueReady) {
          nullValueReady = false
          (null.asInstanceOf[K], nullValue)
        } else {
          val item = (data(2 * i).asInstanceOf[K], data(2 * i + 1).asInstanceOf[V])
          i += 1
          item
        }
      }
    }
  }
```

* 利用Sorter、KVArraySortDataFormat及指定的比较器进行排序。这其中用到了TimSort，也就是优化版的归并排序。

## AppendOnlyMap的扩展

### SizeTrackingAppendOnlyMap

* SizeTrackingAppendOnlyMap的确继承了AppendOnlyMap和Size-Tracker。SizeTrackingAppendOnlyMap采用代理模式重写了AppendOnlyMap的三个方法（包括update、changeValue及growTable）。SizeTrackingAppendOnlyMap确保对data数组进行数据更新、缓存聚合等操作后，调用SizeTracker的afterUpdate方法完成采样；在扩充data数组的容量后，调用SizeTracker的resetSamples方法对样本进行重置，以便于对AppendOnlyMap的大小估算更加准确。

```scala
private[spark] class SizeTrackingAppendOnlyMap[K, V]
  extends AppendOnlyMap[K, V] with SizeTracker
{
  override def update(key: K, value: V): Unit = {
    super.update(key, value)
    // 采样和估算自身大小
    super.afterUpdate()
  }

  override def changeValue(key: K, updateFunc: (Boolean, V) => V): V = {
    val newValue = super.changeValue(key, updateFunc)
    super.afterUpdate()
    newValue
  }

  override protected def growTable(): Unit = {
    super.growTable()
    // 重新采样
    resetSamples()
  }
}
```

### PartitionedAppendOnlyMap

*  PartitionedAppendOnlyMap实现了特质WritablePartitionedPairCol lection定义的partitionedDestructiveSortedIterator接口和insert接口。

```scala
private[spark] class PartitionedAppendOnlyMap[K, V]
  extends SizeTrackingAppendOnlyMap[(Int, K), V] with WritablePartitionedPairCollection[K, V] {

  def partitionedDestructiveSortedIterator(keyComparator: Option[Comparator[K]])
    : Iterator[((Int, K), V)] = {
    // 获取key比较器
    val comparator = keyComparator.map(partitionKeyComparator).getOrElse(partitionComparator)
    // 聚合比较器排序
    destructiveSortedIterator(comparator)
  }

  def insert(partition: Int, key: K, value: V): Unit = {
    // 带分区的排序
    update((partition, key), value)
  }
}
```

