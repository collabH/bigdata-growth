# 生产者原理分析

## 整体架构

![整体](./img/生产者整体架构.jpg)

* 整个生产者客户端由两个线程协调运行，这两个线程分别为主线程和Sender线程（发送线程）。在主线程中由KafkaProducer创建消息，然后通过可能的拦截器、序列化器和分区器的作用之后缓存到消息累加器（RecordAccumulator，也称为消息收集器）中。Sender 线程负责从RecordAccumulator中获取消息并将其发送到Kafka中。
* RecordAccumulator 主要`用来缓存消息以便 Sender 线程可以批量发送`，进而减少网络传输的资源消耗以提升性能。RecordAccumulator 缓存的大小可以`通过生产者客户端参数buffer.memory 配置，默认值为 33554432B，即 32MB。`如果生产者发送消息的速度超过发送到服务器的速度，则会导致生产者空间不足，这个时候KafkaProducer的send（）方法调用要么被阻塞，要么抛出异常，这个取决于参数max.block.ms的配置，此参数的默认值为60000，即60秒。
* 在RecordAccumulator的内部还有一个BufferPool，它主要用来`实现ByteBuffer的复用，以实现缓存的高效利用`。不过BufferPool`只针对特定大小的ByteBuffer进行管理，而其他大小的ByteBuffer不会缓存进BufferPool中`，这个特定的大小由`batch.size`参数来指定，默认值为16384B，即16KB。我们可以适当地调大batch.size参数以便多缓存一些消息。如果发送的消息不超过`batch.size`可以按照`batch.size`创建ProducerBatch，并且可以通过BufferPool进行复用，如果超过则没办法进行复用。

## 元数据更新

* 当客户端中没有需要使用的元数据信息时，比如没有指定的主题信息，或者超过metadata.max.age.ms 时间没有更新元数据都会引起元数据的更新操作。客户端参数metadata.max.age.ms的默认值为300000，即5分钟。元数据的更新操作是在客户端内部进行的，对客户端的外部使用者不可见。当需要更新元数据时，会先挑选出leastLoadedNode，然后向这个Node发送MetadataRequest请求来获取具体的元数据信息。这个更新操作是由Sender线程发起的，在创建完MetadataRequest之后同样会存入InFlightRequests，之后的步骤就和发送消息时的类似。元数据虽然由Sender线程负责更新，但是主线程也需要读取这些信息，这里的数据同步通过synchronized和final关键字来保障。

# 生产者参数

## acks

* acks=1。默认值即为1。生产者发送消息之后，只要分区的leader副本成功写入消息，那么它就会收到来自服务端的成功响应。如果消息无法写入leader副本，比如在leader 副本崩溃、重新选举新的leader 副本的过程中，那么生产者就会收到一个错误的响应，为了避免消息丢失，生产者可以选择重发消息。如果消息写入leader副本并返回成功响应给生产者，且在被其他follower副本拉取之前leader副本崩溃，那么此时消息还是会丢失，因为新选举的leader副本中并没有这条对应的消息。acks设置为1，是消息可靠性和吞吐量之间的折中方案。
*  acks=0。生产者发送消息之后不需要等待任何服务端的响应。如果在消息从发送到写入Kafka的过程中出现某些异常，导致Kafka并没有收到这条消息，那么生产者也无从得知，消息也就丢失了。在其他配置环境相同的情况下，acks 设置为 0 可以达到最大的吞吐量。
*  acks=-1或acks=all。生产者在消息发送之后，需要等待ISR中的所有副本都成功写入消息之后才能够收到来自服务端的成功响应。在其他配置环境相同的情况下，acks 设置为-1（all）可以达到最强的可靠性。但这并不意味着消息就一定可靠，因为ISR中可能只有leader副本，这样就退化成了acks=1的情况。要获得更高的消息可靠性需要配合 `min.insync.replicas `等参数的联动

## max.request.size

* 限制生产者客户端能发送的消息的最大值，默认值为 1048576B，即 1MB。
* 如果broker端的message.max.bytes参数，如果配置错误可能会引起一些不必要的异常。比如将broker端的message.max.bytes参数配置为10，而max.request.size参数配置为20，那么当我们发送一条大小为15B的消息时，生产者客户端就会报出异常。

## retries和retry.backoff.ms

* retries参数用来配置生产者重试的次数，默认值为0，即在发生异常的时候不进行任何重试动作。消息在从生产者发出到成功写入服务器之前可能发生一些临时性的异常，比如网络抖动、leader副本的选举等，这种异常往往是可以自行恢复的，生产者可以通过配置retries大于0的值，以此通过内部重试来恢复而不是一味地将异常抛给生产者的应用程序。如果重试达到设定的次数，那么生产者就会放弃重试并返回异常。不过并不是所有的异常都是可以通过重试来解决的，比如消息太大，超过max.request.size参数配置的值时，这种方式就不可行了。
* 重试还和另一个参数retry.backoff.ms有关，这个参数的默认值为100，它用来设定两次重试之间的时间间隔，避免无效的频繁重试。在配置 retries 和 retry.backoff.ms之前，最好先估算一下可能的异常恢复时间，这样可以设定总的重试时间大于这个异常恢复时间，以此来避免生产者过早地放弃重试。
* 当`max.in.flight.requests.per.connection`配置大于1，出现重试时会出现错序。

## compression.type

* 这个参数用来指定消息的压缩方式，默认值为“none”，即默认情况下，消息不会被压缩。该参数还可以配置为“gzip”“snappy”和“lz4”。对消息进行压缩可以极大地减少网络传输量、降低网络I/O，从而提高整体的性能。消息压缩是一种使用时间换空间的优化方式，如果对时延有一定的要求，则不推荐对消息进行压缩。

## connections.max.idle.ms

* 这个参数用来指定在多久之后关闭限制的连接，默认值是540000（ms），即9分钟。

## linger.ms

* 这个参数用来指定生产者发送 ProducerBatch 之前等待更多消息（ProducerRecord）加入ProducerBatch 的时间，默认值为 0。生产者客户端会在 ProducerBatch 被填满或等待时间超过linger.ms 值时发送出去。增大这个参数的值会增加消息的延迟，但是同时能提升一定的吞吐量。这个linger.ms参数与TCP协议中的Nagle算法有异曲同工之妙。

## receive.buffer.bytes

* 这个参数用来设置Socket接收消息缓冲区（SO_RECBUF）的大小，默认值为32768（B），即32KB。如果设置为-1，则使用操作系统的默认值。如果Producer与Kafka处于不同的机房，则可以适地调大这个参数值。

## send.buffer.bytes

* 这个参数用来设置Socket发送消息缓冲区（SO_SNDBUF）的大小，默认值为131072（B），即128KB。与receive.buffer.bytes参数一样，如果设置为-1，则使用操作系统的默认值。

## request.timeout.ms

* 这个参数用来配置Producer等待请求响应的最长时间，默认值为30000（ms）。请求超时之后可以选择进行重试。注意这个参数需要比broker端参数replica.lag.time.max.ms的值要大，这样可以减少因客户端重试而引起的消息重复的概率。

# 消费者和消费组

* 消费者（Consumer）负责订阅Kafka中的主题（Topic），并且从订阅的主题上拉取消息。与其他一些消息中间件不同的是：在Kafka的消费理念中还有一层消费组（Consumer Group）的概念，每个消费者都有一个对应的消费组。当消息发布到主题后，只会被投递给订阅它的每个消费组中的一个消费者。

## 分区分配策略

* 通过`partition.assignment.strategy`设置，默认为Robin，支持radom和Robin俩种方式。

## 消息投递方式

* 两种消息投递模式：点对点（P2P，Point-to-Point）模式和发布/订阅（Pub/Sub）模式。点对点模式是基于队列的，消息生产者发送消息到队列，消息消费者从队列中接收消息。发布订阅模式定义了如何向一个内容节点发布和订阅消息，这个内容节点称为主题（Topic），主题可以认为是消息传递的中介，消息发布者将消息发布到某个主题，而消息订阅者从主题中订阅消息。主题使得消息的订阅者和发布者互相保持独立，不需要进行接触即可保证消息的传递，发布/订阅模式在消息的一对多广播时采用，Kafka 同时支持两种消息投递模式。
* 如果所有的消费者都隶属于同一个消费组，那么所有的消息都会被均衡地投递给每一个消费者，即每条消息只会被一个消费者处理，这就相当于点对点模式的应用。
*  如果所有的消费者都隶属于不同的消费组，那么所有的消息都会被广播给所有的消费者，即每条消息会被所有的消费者处理，这就相当于发布/订阅模式的应用。

# 主题和分区

## 分区Leader选举

### 自动选举

* `auto.leader.rebalance.enable`默认为true，但是生产环境中不建议开启自动leader选举，这样可能会阻塞正常的使用。

### 手动选举

* 使用`kafka-perferred-replica-election.sh`脚本进行手动副本选举，这里会将Kafka的具体的元数据存储在Zookeeper的`/admin/preferred_replica_election`节点上，如果数据大小超过Zk的限制则会选举失败，默认为`1MB`。
* 可以创建一个json文件指定需要选举的分区清单，通过`--path-to-json-file`参数制定

```json
{
  "partitiuons":[
    {
      "partition":0,
      "topic": "test"
    }, 
    {
      "partition":1,
      "topic": "test"
    }
  ]
}
```

## 分区重分配

### kafka-reassign-partitions.sh

* 创建需要进行分区重新分配的topic

```json
{
		"topics":[
      {
        "topic":"test"
      }
    ],
  "version": 1
}
```

* kafka-reassign-partitions.sh --zookeeper localhost:2181/kafka --generate --topics-to-move-json-file test.json --broker-list 0,2