# Spark实践

## 动态加载hadoop环境

```java
def chooseHadoopEnv(sparkBuilder: SparkSession.Builder, hiveConfDir: String, hadoopConfDir: String) = {
    val configuration: Configuration = new Configuration()

    // 这里的文件地址可以换成从数据库里查询
    val core = new Path(s"${hadoopConfDir}/core-site.xml")
    val hdfs = new Path(s"${hadoopConfDir}/hdfs-site.xml")
    val yarn = new Path(s"${hadoopConfDir}/yarn-site.xml")
    val hive = new Path(s"${hiveConfDir}/hive-site.xml")
    configuration.addResource(core)
    configuration.addResource(hdfs)
    configuration.addResource(yarn)
    configuration.addResource(hive)
    for (c <- configuration) {
      sparkBuilder.config(c.getKey, c.getValue)
    }
    sparkBuilder
  }
```

```java
 /**
   * 选择不同的hadoop环境
   *
   */
  def chooseHive(sparkBuilder: SparkSession.Builder, hiveMetaStoreUri: String) = {
    sparkBuilder.config("hive.metastore.uris", hiveMetaStoreUri)
  }

  def chooseHadoop(spark: SparkSession, nameSpace: String, nn1: String, nn1Addr: String, nn2: String, nn2Addr: String)
  = {
    val sc: SparkContext = spark.sparkContext
    sc.hadoopConfiguration.set(s"fs.defaultFS", s"hdfs://$nameSpace")
    sc.hadoopConfiguration.set(s"dfs.nameservices", nameSpace)
    sc.hadoopConfiguration.set(s"dfs.ha.namenodes.$nameSpace", s"$nn1,$nn2")
    sc.hadoopConfiguration.set(s"dfs.namenode.rpc-address.$nameSpace.$nn1", nn1Addr)
    sc.hadoopConfiguration.set(s"dfs.namenode.rpc-address.$nameSpace.$nn2", nn2Addr)
    sc.hadoopConfiguration.set(s"dfs.client.failover.proxy.provider.$nameSpace", "org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider")
  }
```

* Tez类找不到问题:移除hive-site.xml tez查询引擎配置即可

## Spark Structured Streaming低版本Kafka并发访问问题
* 对同一个DF进行多次action操作偶发情况下会出现类似问题，本质是底层spark kafka维护kafkaConsumer Pool的时候Key没有携带ThreadId，导致同一个线程下并发创建Consumer的问题
### 版本信息

* Spark:2.1.0
* Kafka:0.10
* Scala:2.11

### 异常堆栈
```text
java.util.ConcurrentModificationException: KafkaConsumer is not safe for multi-threaded access
```

### 源码定位

#### KafkaConsumer
* 问题出现在根本原因
```java
    private void acquire() {
        this.ensureNotClosed();
        long threadId = Thread.currentThread().getId();
        if (threadId != this.currentThread.get() && !this.currentThread.compareAndSet(-1L, threadId)) {
            throw new ConcurrentModificationException("KafkaConsumer is not safe for multi-threaded access");
        } else {
            this.refcount.incrementAndGet();
        }
    }
```

#### CachedKafkaConsumer
* 没创建一个CachedKafkaConsumer对象会创建一个KafkaConsumer
```scala
  import CachedKafkaConsumer._

  private val groupId = kafkaParams.get(ConsumerConfig.GROUP_ID_CONFIG).asInstanceOf[String]

  private var consumer = createConsumer

  /** indicates whether this consumer is in use or not */
  private var inuse = true

  /** Iterator to the already fetch data */
  private var fetchedData = ju.Collections.emptyIterator[ConsumerRecord[Array[Byte], Array[Byte]]]
  private var nextOffsetInFetchedData = UNKNOWN_OFFSET

  /** Create a KafkaConsumer to fetch records for `topicPartition` */
  private def createConsumer: KafkaConsumer[Array[Byte], Array[Byte]] = {
    val c = new KafkaConsumer[Array[Byte], Array[Byte]](kafkaParams)
    val tps = new ju.ArrayList[TopicPartition]()
    tps.add(topicPartition)
    c.assign(tps)
    c
  }

/**
 * 问题代码，并发问题导致在判断key的时候可能thread 1和 thread 2同时判断该key不包含，然后都去创建
 * kafkaConsumer，然后就导致同一个thraedId下创建多个kafkaConsumer
 * @param topic
 * @param partition
 * @param kafkaParams
 * @return
 */
def getOrCreate(
                 topic: String,
                 partition: Int,
                 kafkaParams: ju.Map[String, Object]): CachedKafkaConsumer = synchronized {
  val groupId = kafkaParams.get(ConsumerConfig.GROUP_ID_CONFIG).asInstanceOf[String]
  val topicPartition = new TopicPartition(topic, partition)
  val key = CacheKey(groupId, topicPartition)

  // If this is reattempt at running the task, then invalidate cache and start with
  // a new consumer
  if (TaskContext.get != null && TaskContext.get.attemptNumber > 1) {
    removeKafkaConsumer(topic, partition, kafkaParams)
    val consumer = new CachedKafkaConsumer(topicPartition, kafkaParams)
    consumer.inuse = true
    cache.put(key, consumer)
    consumer
  } else {
    //fixme 并发问题
    if (!cache.containsKey(key)) {
      cache.put(key, new CachedKafkaConsumer(topicPartition, kafkaParams))
    }
    val consumer = cache.get(key)
    consumer.inuse = true
    consumer
  }
}
```

#### 修复版本
* 采用原子性操作
```scala
def getOrCreate(
      topic: String,
      partition: Int,
      kafkaParams: ju.Map[String, Object]): CachedKafkaConsumer = synchronized {
    val groupId = kafkaParams.get(ConsumerConfig.GROUP_ID_CONFIG).asInstanceOf[String]
    val topicPartition = new TopicPartition(topic, partition)
    val key = CacheKey(groupId, topicPartition)

    // If this is reattempt at running the task, then invalidate cache and start with
    // a new consumer
    if (TaskContext.get != null && TaskContext.get.attemptNumber > 1) {
      removeKafkaConsumer(topic, partition, kafkaParams)
      val consumer = new CachedKafkaConsumer(topicPartition, kafkaParams)
      consumer.inuse = true
      cache.put(key, consumer)
      consumer
    } else {
//      if (!cache.containsKey(key)) {
//        cache.put(key, new CachedKafkaConsumer(topicPartition, kafkaParams))
//      }
//      val consumer = cache.get(key)
      // fix thread safe problem
      val consumer = cache.putIfAbsent(key, new CachedKafkaConsumer(topicPartition, kafkaParams))
      consumer.inuse = true
      consumer
    }
  }
```