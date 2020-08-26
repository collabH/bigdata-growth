# 参数配置

## spark-defaults.conf

```properties
# 资源配置
spark.executor.memory 8g
spark.driver.memory 2g
spark.yarn.am.memory 2g

# 设定spark history server的地址
spark.yarn.historyServer.address hostname
spark.history.fs.logDirectory hdfs://hadoop:8020/user/spark/applicationHistory

# 指定log的目录
spark.eventLog.dir hdfs://hadoop:8020/user/spark/applicationHistory
spark.eventLog.enabled true

# 指定master
spark.master spark://hadoop:7077
```

## 动态载入属性

```shell
spark-submit --name "test" --master spark://hadoop:7077 --conf spark.eventLog.enabled=false --conf spark.executor.memory=8g test.jar
```

## 代码设置

```scala
val conf=new SparkConf()
.setMaster=("spark://hadoop:7077")
.setAppName("test")
.set("spark.executor.memory","8g")
```

# 调优

## 序列化调优

### Java序列化

* 默认情况下，Java采用Java的ObjectOutputStream序列化一个对象。该方式适用于所有实现的java.io.Serializable的类。通过继承`java.io.Externalizable`，能进一步控制序列化的性能。Java序列化非常灵活，但是速度较慢，序列化结果也较大会产生一些spark不需要的类的相关信息。

### Kryo序列化

* Spark也支持Kryo序列化对象，Kryo速度快，产结果也更为紧凑。`Kryo并不支持所有类型，为了获得更好的性能，开发者需要提前注册程序中使用的类`。

#### 设置Kryo序列化

```scala
 # 切换序列化方式
 System.setProperty("spark.serializer","spark.KryoSerializer")
```

* Kryo序列化器会作用于worker节点数据的shuffle以及RDD序列化到磁盘，适合用`网络密集型`应用。

#### Kryo注册序列化类

```scala
 new SparkConf()
      .registerKryoClasses(Array(classOf[MyClass], classOf[MyClass2]))
```

* 序列化对象过大时可以使用spark.kryoserializer.buffer.mb的值，该属性的默认值时32，但是该属性需要足够大，以便能偶容纳需要序列化的最大对象。

## 内存优化

* 对象站用的内存
* 访问对象的消耗
* 垃圾回收占用的内存开销

```
java对象的访问速度虽然快，但是占用的空间通常比内部的属性数据大2～5倍，属于空间换时间的策略。

1.Java对象包含一个“对象头部（object header），该头部大约占16字节，包含了指向对象对应的类的指针等信息。”
2. Java String在实际的字符串数据之外，还需要大约40字节的额外开销（因为String将字符串保存在Char数组利，还需要保存类似长度等的其他数据）；同时，因为Unicode编码，一个字符占2个字节，一个长度10的字符串需要占60个字节。
3. 通用的集合类，如HashMap、LinkedList都采用了链表数据结构，对每个条目(entry)都进行了包装(wrapper)。每个条目有对象头，还有下一个条目的指针。
4. 几本类型的集合通常保存为对应的类，一些包装类，内部有一些CachePool等对象。
```

### 确定内存消耗

* 计算数据集所需内存大小是创建一个RDD，将其放入缓存，然后观察Spark history webUI的Storage页面，该页面会列出RDD各项信息。
* 估算一个特殊对象的内存消耗，可以使用SizeEstimator类的estimate方法，可以降低不同数据布局的内存消耗，还可以决定广播变量在每个executor heap上所占内存大小。

### 优化调整数据结构

* 使用对象数组以及原始类型的数组代替Java或Scala集合类。fastuitl库为原始类型提供了方便的集合类，同时这些集合兼容Java标准类库。
* 避免使用含有指针和小对象的嵌套结构
* 考虑采用数字ID或枚举代替String类型的key
* 当内存少于32GB时，可设置JVM参数为-XX:+UseCompressedOps，以便与江8字节指针修改为4字节。设置JVM参数-XX:+UseCompressedStrings，以8bit来编码每一个ASCII自负。

### 序列化RDD存储

* 采用RDD持久化API的序列化StorageLevel，如Memory_ONLY_SER。将RDD序列化为byte数组存储，使用时间换空间策略，此时可以使用Kryo序列化器来降低对象大小和加快访问速度。

### 优化GC

* 内存回收信息，开启gc参数

```shell
-verbose:gc -XX:+PrintGCDetails -XX:+PrintGCTimeStamps添加到SPARK_JAVA_OPTS中，设置后Spark作业可以看到每次内存回收信息。
```

* 缓存大小优化

```
这里涉及到Spark的存储方案，分为Storage和Execution内存区域，分配好Storage内存区域既可以控制缓存内存大小。
如果程序频繁发生gc可以降低缓存大小。
```

* 内存回收优化

## 数据本地化

* 数据本地化堆Spark job有着重要的影响，如果数据和计算逻辑放在一起那么运算速度会更快减少了数据的网络传输。

### Spark的本地化层级

* PROCESS_LOCAL:数据和运行代码位于同一个JVM实例中，性能最好的本地化。
* NODE_LOCAL:数据和运行代码位于同一个节点，比如在同一个节点上的HDFS中或者同一个节点的其他executor中。
* NO_PREF:数据可以从任何地方以同等速度访问，并且不倾向于本地化。
* RACK_LOCAL:数据位于同一机架。数据位于同一机架上的不同server上，因此需要通过网络传输。
* ANY数据位于不同机架。

### Spark的本地化选择

* Spark优先层级高的位置，当空闲的executor上不存在未被处理的数据时，Spark专向更低的存储层级。通常选择为俩种：
  * 等待忙碌的CPU闲下来，然后启动同一个server上的数据关联的任务。
  * 在远离数据的地方立即启动任务，这需要移动数据。
* Spark一般使用的策略是等待忙碌的CPU闲置，一旦等待时间超时，它会将数据移动到远端闲置CPU。不同层级的回滚等待时间可以单独配置参考`spark.locality`部分。

## 其他优化

### 并行度设置

* 通常集群中为每个CPU核分配2～3个任务比较合适。

### Reduce Task的内存使用

* 任务遇到大结果集导致的OOM，并非RDD不能加载导致的，而是因为Spark shuffle操作导致的需要为每个任务创建哈希表导致的OOM，可以通过增大并行度修复。

### 任务执行速度倾斜

#### 数据倾斜

* 一般为partition key取的存在问题，替换其他的并行处理方式，中间可以加入一步aggregation。

#### worker倾斜

* 设置`spark.speculation=true`，持续慢的node去掉。

### shuffle磁盘IO时间长

* 设置组磁盘。`spark.local.dir=/dir1,/dir2,/dir3`

