[Spark内存管理详解](https://www.ibm.com/developerworks/cn/analytics/library/ba-cn-apache-spark-memory-management/index.html)

# Driver和Executor

* Driver为主控进程，负责创建Spark上下文，提交Spark作业(Job)，并将作业转化为计算任务(Task)，在各个Executor进程间协调任务的调度。
* Executor负责计算逻辑，上报自身状态给ApplicationMaster，计算结果返回给Driver，为持久化RDD提供功能。

# 堆内和堆外内存规划

* 作为JVM进程，**Executor的内存管理建立在JVM的内存管理上，Spark堆JVM的堆内(On-heap)空间进行了更为详细的分配，以充分利用内存。**Spark也引入了堆外(Off-heap)内存，使之可以直接在工作节点的系统内存中开辟空间，进一步优化了内存的使用。

* **堆内内存受到JVM统一管理，堆外内存是直接向操作系统进行内存的申请和释放。**

![堆内和堆外](./img/Executor堆外与堆内内存.jpg)

## 堆内内存 

* 堆内内存大小，由Spark应用程序启动时通过指定**--executor-memory**或**spark.executor.memory**参数配置。Executor内运行的并发任务共享JVM堆内内存，**这些任务在缓存RDD数据和广播(Broadcast)数据时占用的内存被规划为存储(Storage)内存**，**这些任务在执行Shuffle时占用的内存被规划为执行(Execution)内存，剩余部分不做特殊规划，那些Spark内部的对象实例，或者用户定义的Spark应用程序中的对象实例，均占用剩余空间。**不同的内存管理方式，三个部分占用的内存空间是不同的。

### 规划式管理

* Spark会在申请后和释放前记录这些内存

### 申请内存流程

1. Spark在代码new一个对象实例
2. 对象实例会去堆内存申请空间，并且创建对象，然后将引用返回到栈上。
3. Spark保存该对象的引用，记录该对象占用的内存。

### 释放内存

1. Spark记录该对象释放的内存，删除对象引用。
2. 此时会等待JVM的GC回收该对象在堆上占用的内存。

### OOM存在的原因

>   JVM 的对象可以以序列化的方式存储，序列化的过程是将对象转换为二进制字节流，本质上可以理解为将非连续空间的链式存储转化为连续空间或块存储，在访问时则需要进行序列化的逆过程——反序列化，将字节流转化为对象，序列化的方式可以节省存储空间，但增加了存储和读取时候的计算开销。
>    Spark 中序列化的对象，由于是字节流的形式，其占用的内存大小可直接计算，而对于非序列化的对象，其占用的内存是通过周期性地采样近似估算而得，即并不是每次新增的数据项都会计算一次占用的内存大小，这种方法降低了时间开销但是有可能误差较大，导致某一时刻的实际内存有可能远远超出预期。此外，在被 Spark 标记为释放的对象实例，很有可能在实际上并没有被 JVM 回收，导致实际可用的内存小于 Spark 记录的可用内存。所以 Spark 并不能准确记录实际可用的堆内内存，从而也就无法完全避免内存溢出（OOM, Out of Memory）的异常。
>
>   虽然不能精准控制堆内内存的申请和释放，但 Spark 通过对存储内存和执行内存各自独立的规划管理，可以决定是否要在存储内存里缓存新的 RDD，以及是否为新的任务分配执行内存，在一定程度上可以提升内存的利用率，减少异常的出现。

## 堆外内存

* 为了进一步优化shuffle时排序的效率，引入堆外内存可以直接在工作节点的系统内存中开辟空间，存储经过序列化的二进制数据。将内存对象分配在Jvm的堆以外的内存，这些内存直接受操作系统管理，从而减少JVM GC堆应用的影响。
* 默认情况下不启用堆外内存不启用，通过配置**spark.memory.offHeap.enabled**参数启用，由**spark.memory.offHeap.size**参数设定堆外空间的大小。除了没有other空间，堆外内存与堆内内存划分方式相同，所有运行中的并发任务共享存储。

## 内存管理接口

```scala
/**
 *  一个抽象内存管理器，用于强制执行和存储之间共享内存。
  *  execution memory用于shuffle，join，sort和aggregations的完成。
  *  storage memory用于缓存和广播内部的数据在集群中传递
  * 每个JVM都存在一个MemoryManager
 */
private[spark] abstract class MemoryManager(
    conf: SparkConf, //Spark配置
    numCores: Int, // 具体核数
    onHeapStorageMemory: Long,  //堆内Storage memory
    onHeapExecutionMemory: Long) //堆内 execution memory
```

### 主要方法

```scala
//申请存储内存
def acquireStorageMemory(blockId: BlockId, numBytes: Long, memoryMode: MemoryMode): Boolean
//申请展开内存
def acquireUnrollMemory(blockId: BlockId, numBytes: Long, memoryMode: MemoryMode): Boolean
//申请执行内存
def acquireExecutionMemory(numBytes: Long, taskAttemptId: Long, memoryMode: MemoryMode): Long
//释放存储内存
def releaseStorageMemory(numBytes: Long, memoryMode: MemoryMode): Unit
//释放执行内存
def releaseExecutionMemory(numBytes: Long, taskAttemptId: Long, memoryMode: MemoryMode): Unit
//释放展开内存
def releaseUnrollMemory(numBytes: Long, memoryMode: MemoryMode): Unit
```

* 这里的MemoryMode就是使用cache需要指定的内存模式，根据这个参数决定是堆内操作还是堆外操作。

# 内存空间分配

## 静态内存管理

* 早期采用的方式，**存储内存、执行内存和其他内存的大小是固定的，用户可以指定相关配置**

![静态内存管理](./img/静态内存划分.jpg)

```text
可用的存储内存 = systemMaxMemory * spark.storage.memoryFraction * spark.storage.safetyFraction
可用的执行内存 = systemMaxMemory * spark.shuffle.memoryFraction * spark.shuffle.safetyFraction

其中 systemMaxMemory 取决于当前 JVM 堆内内存的大小，最后可用的执行内存或者存储内存要在此基础上与各自的 memoryFraction 参数和 safetyFraction 参数相乘得出。上述计算公式中的两个 safetyFraction 参数，其意义在于在逻辑上预留出 1-safetyFraction 这么一块保险区域，降低因实际内存超出当前预设范围而导致 OOM 的风险（对于非序列化对象的内存采样估算会产生误差）。值得注意的是，这个预留的保险区域仅仅是一种逻辑上的规划，在具体使用时 Spark 并没有区别对待，和"其它内存"一样交给了 JVM 去管理。
```

## 堆外内存管理

* 堆外的空间分配较为简单，只有存储内存和执行内存。用的执行内存和存储内存占用的空间大小直接由参数 **spark.memory.storageFraction** 决定，由于堆外内存占用的空间可以被精确计算，所以无需再设定保险区域。

![堆外内存](./img/静态内存堆外.jpg)

* 静态内存管理机制实现起来较为简单，但如果用户不熟悉 Spark 的存储机制，或没有根据具体的数据规模和计算任务或做相应的配置，很容易造成"一半海水，一半火焰"的局面，即存储内存和执行内存中的一方剩余大量的空间，而另一方却早早被占满，不得不淘汰或移出旧的内容以存储新的内容。由于新的内存管理机制的出现，这种方式目前已经很少有开发者使用，出于兼容旧版本的应用程序的目的，Spark 仍然保留了它的实现。

## 统一内存管理

![img](./img/统一内存管理.jpg)

### 统一内存堆外管理

![堆外内存](./img/统一内存堆外管理.jpg)

### 动态内存管理

其中最重要的优化在于**动态占用机制**，其规则如下：

- 设定基本的存储内存和执行内存区域（**spark.storage.storageFraction** 参数），该设定确定了双方各自拥有的空间的范围
- 双方的空间都不足时，则存储到硬盘；若己方空间不足而对方空余时，可借用对方的空间;（存储空间不足是指不足以放下一个完整的 Block）
- 执行内存的空间被对方占用后，可让对方将占用的部分转存到硬盘，然后"归还"借用的空间
- 存储内存的空间被对方占用后，无法让对方"归还"，因为需要考虑 Shuffle 过程中的很多因素，实现起来较为复杂

![动态内存管理](./img/动态内存调用机制.jpg)

# 存储内存管理

## RDD的持久化机制

* RDD是Spark最基本的数据抽象，是只读的分区记录(Partition)集合，**只能基于在稳定存储中的数据集上创建，或者其他RDD上转换产生新的RDD。**转换后的RDD和旧的RDD存在依赖关系，构成了"血统(Lineage)"。凭借血统，Spark 保证了每一个 RDD 都可以被重新恢复。但 RDD 的**所有转换都是惰性的，即只有当一个返回结果给 Driver 的行动（Action）发生时，Spark 才会创建任务读取 RDD，然后真正触发转换的执行**。
* Task 在启动之初读取一个分区时，会先判断这个分区是否已经被持久化，如果没有则需要检查 Checkpoint 或按照血统重新计算。所以如果一个 RDD 上要执行多次行动，可以在第一次行动中使用 persist 或 cache 方法，在内存或磁盘中持久化或缓存这个 RDD，从而在后面的行动时提升计算速度。事实上，cache 方法是使用默认的 MEMORY_ONLY 的存储级别将 RDD 持久化到内存，故缓存是一种特殊的持久化。 **堆内和堆外存储内存的设计，便可以对缓存** **RDD** **时使用的内存做统一的规划和管理** 
* RDD 的持久化由 **Spark 的 Storage 模块** [7] 负责，实现了 **RDD 与物理存储的解耦合**。Storage 模块**负责管理 Spark 在计算过程中产生的数据，将那些在内存或磁盘、在本地或远程存取数据的功能封装了起来**。在具体实现时 **Driver 端和 Executor 端的 Storage 模块构成了主从式的架构**，即 **Driver 端的 BlockManager 为 Master，Executor 端的 BlockManager 为 Slave**。Storage 模块在逻辑上以 **Block 为基本存储单位，RDD 的每个 Partition 经过处理后唯一对应一个 Block**（BlockId 的格式为 rdd_RDD-ID_PARTITION-ID ）。**Master 负责整个 Spark 应用程序的 Block 的元数据信息的管理和维护，而 Slave 需要将 Block 的更新等状态上报到 Master，同时接收 Master 的命令，例如新增或删除一个 RDD**。

![Storage](./img/Spark Storage模板.jpg)