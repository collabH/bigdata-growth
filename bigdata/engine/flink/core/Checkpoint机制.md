

# Checkpointing

* Flink 中的每个方法或算子都能够是**有状态的**。 状态化的方法在处理单个 元素/事件 的时候存储数据，让状态成为使各个类型的算子更加精细的重要部分。 为了让状态容错，Flink 需要为状态添加 **checkpoint（检查点）**。Checkpoint 使得 Flink 能够恢复状态和在流中的位置，从而向应用提供和无故障执行时一样的语义。

## 前提条件

* Flink的checkpoint机制需要河持久化存储进行交互，读写状态，需要具备以下能力：
  * 能够回放一段时间内数据的持久化数据源，例如持久化消息队列（例如 Apache Kafka、RabbitMQ、 Amazon Kinesis、 Google PubSub 等）或文件系统（例如 HDFS、 S3、 GFS、 NFS、 Ceph 等）。
  * 存放状态的持久化存储，通常为分布式文件系统（比如 HDFS、 S3、 GFS、 NFS、 Ceph 等）。

## 开启与配置Checkpoint

* checkpoint默认情况下`是被禁用的`。通过可调用 `StreamExecutionEnvironment` 的 `enableCheckpointing(n)` 来启用 checkpoint，里面的 *n* 是进行 checkpoint 的间隔，单位毫秒。

**Checkpoint的属性包括：**

* *Checkpoint存储：*设置检查点快照的持久化位置。默认情况下，Flink使用JobManger的堆。生产中应该为持久性文件系统。
* *精确一次（exactly-once）对比至少一次（at-least-once）*：通过 `enableCheckpointing(long interval, CheckpointingMode mode)` 方法中传入一个模式来选择使用两种保证等级中的哪一种。 对于大多数应用来说，精确一次是较好的选择。至少一次可能与某些延迟超低（始终只有几毫秒）的应用的关联较大。
* *checkpoint 超时*：如果 checkpoint 执行的时间超过了该配置的阈值，还在进行中的 checkpoint 操作就会被抛弃。
* *checkpoints 之间的最小时间*：该属性定义在 checkpoint 之间需要多久的时间，以确保流应用在 checkpoint 之间有足够的进展。如果值设置为了 *5000*， 无论 checkpoint 持续时间与间隔是多久，在前一个 checkpoint 完成时的至少五秒后会才开始下一个 checkpoint。**注意这个值也意味着并发 checkpoint 的数目是*一*。**
* *checkpoint 可容忍连续失败次数*：该属性定义可容忍多少次连续的 checkpoint 失败。超过这个阈值之后会触发作业错误 fail over。 默认次数为“0”，这意味着不容忍 checkpoint 失败，作业将在第一次 checkpoint 失败时fail over。可容忍的checkpoint失败仅适用于下列情形：Job Manager的IOException、TaskManager做checkpoint时异步部分的失败、checkpoint超时等；TaskManager做checkpoint时同步部分的失败会直接触发作业fail over。其它的checkpoint失败（如一个checkpoint被另一个checkpoint包含）会被忽略掉。
* *并发 checkpoint 的数目*: 默认情况下，在上一个 checkpoint 未完成（失败或者成功）的情况下，系统不会触发另一个 checkpoint。这确保了拓扑不会在 checkpoint 上花费太多时间，从而影响正常的处理流程。 不过允许多个 checkpoint 并行进行是可行的，**对于有确定的处理延迟（例如某方法所调用比较耗时的外部服务），但是仍然想进行频繁的 checkpoint 去最小化故障后重跑的 pipelines 来说，是有意义的。** 注意： **不能和 “checkpoints 间的最小时间"同时使用。**
* *externalized checkpoints*: 你可以配置周期存储 checkpoint 到外部系统中。Externalized checkpoints 将他们的元数据写到持久化存储上并且在 job 失败的时候*不会*被自动删除。 这种方式下，如果你的 job 失败，你将会有一个现有的 checkpoint 去恢复。
* *非对齐 checkpoints*: 你可以启用[非对齐 checkpoints](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/ops/state/checkpointing_under_backpressure/#非对齐-checkpoints) 以在背压时大大减少创建checkpoint的时间。这仅适用于精确一次（exactly-once）checkpoints 并且只有一个并发检查点。
* *部分任务结束的 checkpoints*： 默认情况下，即使DAG的部分已经处理完它们的所有记录，Flink也会继续执行 checkpoints。

```java
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

// 每 1000ms 开始一次 checkpoint
env.enableCheckpointing(1000);

// 高级选项：

// 设置模式为精确一次 (这是默认值)
env.getCheckpointConfig().setCheckpointingMode(CheckpointingMode.EXACTLY_ONCE);

// 确认 checkpoints 之间的时间会进行 500 ms
env.getCheckpointConfig().setMinPauseBetweenCheckpoints(500);

// Checkpoint 必须在一分钟内完成，否则就会被抛弃
env.getCheckpointConfig().setCheckpointTimeout(60000);

// 允许两个连续的 checkpoint 错误
env.getCheckpointConfig().setTolerableCheckpointFailureNumber(2);
        
// 同一时间只允许一个 checkpoint 进行
env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);

// 使用 externalized checkpoints，这样 checkpoint 在作业取消后仍就会被保留
env.getCheckpointConfig().setExternalizedCheckpointCleanup(
        ExternalizedCheckpointCleanup.RETAIN_ON_CANCELLATION);

// 开启实验性的 unaligned checkpoints
env.getCheckpointConfig().enableUnalignedCheckpoints();
```

### Checkpoint相关配置

| Key                                    | Default | Type       | Description                                                  |
| :------------------------------------- | :------ | :--------- | :----------------------------------------------------------- |
| state.backend.incremental              | false   | Boolean    | 是否开启增量Checkpoint，默认为false。对于增量Checkpoint，只存储与前一个Checkpoint的差异，而不是完整的Checkpoint状态。一旦启用，在web UI中显示的状态大小或从Rest API中获取的状态大小只代表增量Checkpoint大小，而不是完整的Checkpoint大小。一些状态后端可能不支持增量检查点并忽略此选项。 |
| state.backend.local-recovery           | false   | Boolean    | 状态后端是否开启本地恢复。默认情况为fasle本地恢复。目前只支持keyed state backends(包括EmbeddedRocksDBStateBackend和HashMapStateBackend)。 |
| state.checkpoint-storage               | (none)  | String     | 用于指定checkpoint所用的存储，支持'jobmanager'和'filesystem'以及'rocksdb' |
| state.checkpoint.cleaner.parallel-mode | true    | Boolean    | 是否使用并行过期状态清理器                                   |
| state.checkpoints.create-subdir        | true    | Boolean    | 是否要在'state.checkpoints.dir'下创建**由Job ID命名的子目录以存储检查点的数据文件和元数据**。默认为true，可以在相同检查点目录下运行多个作业。 |
| state.checkpoints.dir                  | (none)  | String     | 用于将检查点的数据文件和元数据存储在flink支持的文件系统中的默认目录。需要支持Taskmanger和Jobmanager访问。 |
| state.checkpoints.num-retained         | 1       | Integer    | 警告：这是一种高级配置。如果设置为false，则用户必须确保没有使用相同检查点目录运行多个作业，并且在启动新作业时恢复当前作业所需的文件之外，没有其他文件。The maximum number of completed checkpoints to retain. |
| state.savepoints.dir                   | (none)  | String     | savepoint的存储目录.                                         |
| state.storage.fs.memory-threshold      | 20 kb   | MemorySize | 状态数据文件的最小大小。小于该值的所有状态块都内联存储在根检查点元数据文件中。此配置的最大内存阈值为1MB。 |
| state.storage.fs.write-buffer-size     | 4096    | Integer    | 写入文件系统的检查点流的写缓冲区的默认大小。实际写缓冲区大小为该配置和'state.storage.fso.fs.memory-threshold'的最大值。 |
| taskmanager.state.local.root-dirs      | (none)  | String     | 为本地恢复的存储基于文件的状态定义根目录的配置参数。本地恢复目前仅涵盖键控状态后端。如果未配置，它将默认为<WORKING_DIR>/localState。可以通过`process.taskmanager.working-dir`配置<WORKING_DIR> |

* **设置重启策略**
  * noRestart
  * fallBackRestart:回滚
  * fixedDelayRestart: 固定延迟时间重启策略，在固定时间间隔内重启
  * failureRateRestart: 失败率重启

##### checkpoint存储目录

* checkpoint由元数据文件、数据文件组成。通过`state.checkpoints.dir`配置元数据文件和数据文件存储路径，也可以在代码中设置。

```shell
/user-defined-checkpoint-dir
    /{job-id}
        |
        + --shared/
        + --taskowned/
        + --chk-1/
        + --chk-2/
        + --chk-3/
        ...
```

* 其中 **SHARED** 目录保存了可能被多个 checkpoint 引用的文件，**TASKOWNED** 保存了不会被 JobManager 删除的文件，**EXCLUSIVE** 则保存那些仅被单个 checkpoint 引用的文件。

* 从保留的checkpoint中恢复状态

```shell
$ bin/flink run -s :checkpointMetaDataPath [:runArgs]
```

### 

## 容错与状态

### Checkpoint

#### 一致性检查点

![一致性检查点](../img/一致性检查点.jpg)

* Flink故障恢复机制的核心，就是应用状态的一致性检查点
* 有状态流应用的一致检查点，其实就是所有任务的状态，在某个时间点的一份拷贝；这个时间点，`应该是所有任务恰好处理完一个相同的输入数据的时候,如果各个算子单独处理对应的offset，`就会存在source端和算子端checkpoint的offset存在异常，导致数据无法恢复。

#### 从检查点恢复

* 重启应用程序，从上次保存的checkpoint恢复，当所有checkpoint恢复到各个算子中，然后开始消费并处理checkpoint到发生故障之间的所有数据，这种checkpoint的保存和恢复机制可以为程序提供"exactly-once"的一致性，所有算子都会保存checkpoint并恢复其所有状态，这样就保证了状态的最终一致性。

#### 检查点算法

* 一种简单的想法

    * 暂停应用，保存状态到检查点，再重新恢复应用。

* Flink实现方式

    * 基于`Chandy-Lamport`算法的分布式快照
    * 将检查点的保存和数据处理分离开，不暂停整个应用，对Source进行`checkpoint barrier`控制

* 检查点屏障(Checkpoint Barrier)

    * Flink的检查点算法用到一种称为屏障(barrier)的特殊数据形式，用来把一条流上数据按照不同的检查点分开。
    * Barrier之前到来的数据导致的状态更改，都会被包含在当前分界线所属的检查点中；基于barrier之后的数据导致的所有更改，就会被包含在之后的检查点中。

* **检查点barrier流程**

    * 有两个输入流的应用程序，并行的两个Source任务来读取，JobManager会向每个Source任务发送一个带有新checkpoint ID的消息，通过这种方式来启动checkpoint。
    * 数据源将它们的状态写入checkpoint，并发出一个`checkpointbarrier`，状态后端在状态存入checkpoint之后，会返回通知给source任务，source任务就会向JobManager确认checkpoint完成。
    * **barrier对齐**：barrier向下游传递，sum任务会等待所有输入分区的barrier达到，对于barrier已经到达的分区，继续到达的数据会`被缓存`，而barrier尚未到达的分区，数据会被正常处理。
    * 当收到所有输入分区的barrier时，任务就将其状态保存到`状态后端的checkpoint中`，然后将barrier继续向下游转发，下游继续正常处理数据。
    * Sink任务向JobManager确认状态保存到checkpoint完毕，当所有任务都确认已成功将状态保存到checkpoint时，checkpoint完毕。

  ![checkpoint1](../img/checkpoint1.jpg)

  ![checkpoint1](../img/checkpoint2.jpg)

  ![checkpoint1](../img/checkpoint3.jpg)

### savepoint

* Savepoint 由俩部分组成：数据二进制文件的目录（通常很大）和元数据文件（相对较小）。 数据存储的文件表示作业执行状态的数据镜像。 Savepoint 的`元数据文件以（绝对路径）的形式包含（主要）指向作为 Savepoint 一部分的所有数据文件的指针`。

#### 与checkpoint的区别

* **checkpoint**类似于恢复日志的概念(redolog), Checkpoint 的主要目的是`为意外失败的作业提供恢复机制`。 Checkpoint 的生命周期由 Flink 管理，即 Flink 创建，管理和删除 Checkpoint - 无需用户交互。 作为一种恢复和定期触发的方法，Checkpoint 实现有两个设计目标：`i）轻量级创建和 ii）尽可能快地恢复`。
* Savepoint 由用户创建，拥有和删除。 通过手动备份和恢复,恢复成本相对于checkpoint会更高一些，相对checkpoint更重量一些。

#### 分配算子ID

* 通过`uid(String)`方法手动指定算子ID，算子ID用于恢复每个算子的状态。**分配uid能够解决flink operatorchain变化时savepoint时可以根据uid找到特定operator的状态。**

```java
datasource.uid("network-source").map(new WordCountMapFunction())
                .uid("map-id")
                .keyBy((KeySelector<Tuple2<String, Integer>, Object>) stringIntegerTuple2 -> stringIntegerTuple2.f0)
                .timeWindow(Time.seconds(30))
                .reduce(new SumReduceFunction())
                .uid("reduce-id")
                .print().setParallelism(1);
```

#### savepoint操作

* 触发savepoint,`flink savepoint :jobId [:targetDirctory]`
* 使用YARN触发Savepoint,`flink savepoint :jobId [:targetDirctory] -yid :yarnAppId`
* 使用savepoint取消作业,`flink cancel -s [:targetDirectory] :jobId`
* 从savepoint恢复,`flink run -s :savepointPath [:runArgs]`
    * --allowNoRestoredState 跳过无法映射到新程序的状态
* 删除savepoint,`flink savepoint -d :savepointPath`

### 状态快照

#### 概念

- *快照* – 是 Flink 作业状态全局一致镜像的通用术语。快照包括指向每个数据源的指针（例如，数据文件或 Kafka 分区的偏移量）以及每个作业的有状态运算符的状态副本，该状态副本是处理了 sources 偏移位置之前所有的事件后而生成的状态。
- *Checkpoint* – 一种由 Flink 自动执行的快照，其目的是能够从故障中恢复。Checkpoints 可以是增量的，并为快速恢复进行了优化。
- *外部化的 Checkpoint* – 通常 checkpoints 不会被用户操纵。Flink 只保留作业运行时的最近的 *n* 个 checkpoints（*n* 可配置），并在作业取消时删除它们。但你可以将它们配置为保留，在这种情况下，你可以手动从中恢复。
- *Savepoint* – 用户出于某种操作目的（例如有状态的重新部署/升级/缩放操作）手动（或 API 调用）触发的快照。Savepoints 始终是完整的，并且已针对操作灵活性进行了优化

#### 原理

* 基于异步barrier快照(asynchronous barrier snapshotting),当 checkpoint coordinator（job manager 的一部分）指示 taskManager开始checkpoint 时，它会让所有 sources 记录它们的偏移量，并将编号的 *checkpoint barriers* 插入到它们的流中。这些 barriers 流经 job graph，标注每个 checkpoint 前后的流部分。

![Checkpoint barriers are inserted into the streams](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/stream_barriers.svg)

* barrier对齐机制

![Barrier alignment](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/stream_aligning.svg)

* 图中先到达的checkpoint barrier会将后续数据放入到buffers中，后续进行下一次checkpoint时辉县将buffer数据进行对齐。
* Flink 的 state backends 利用写时复制（copy-on-write）机制允许当异步生成旧版本的状态快照时，能够不受影响地继续流处理。只有当快照被持久保存后，这些旧版本的状态才会被当做垃圾回收。

### 大状态与Checkpoint优化

* checkpoint时间过长导致反压问题

```shell
# checkpoint开始的延迟时间
checkpoint_start_delay = end_to_end_duration - synchronous_duration - asynchronous_duration
```

* 在对齐期间缓冲的数据量，对于exactly-once语义，Flink将接收多个输入流的操作符中的流进行对齐，并缓冲一些数据以实现对齐。理想情况下，缓冲的数据量较低和较高的缓冲量意味着不同的输入流在不同的时间接收检查点屏障。

#### 优化Chckpoint

* checkpoint触发的正常间隔可以在程序配置，当一个检查点完成的时间长于检查点间隔时，下一个检查点在进程中的检查点完成之前不会被触发。默认情况下，下一个checkpoint点将在当前checkpoint完成后立即触发。
* 当检查点花费的时间经常超过基本间隔时(例如，由于状态增长超过了计划，或者检查点存储的存储空间暂时变慢)，系统就会不断地接受检查点(一旦进行，一旦完成，就会立即启动新的检查点)。这可能意味着太多的资源被持续地占用在检查点上，而算子的进展太少。此行为对使用异步检查点状态的流应用程序影响较小，但仍可能对总体应用程序性能产生影响。

```java
# 为了防止这种情况，应用程序可以定义检查点之间的最小持续时间，这个持续时间是最近的检查点结束到下一个检查点开始之间必须经过的最小时间间隔。
StreamExecutionEnvironment.getCheckpointConfig().setMinPauseBetweenCheckpoints(milliseconds)
```

![Illustration how the minimum-time-between-checkpoints parameter affects checkpointing behavior.](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/checkpoint_tuning.svg)

#### 优化RocksDB

##### 增量checkpoint

* 开启rocksDB增量checkpoint可以减少checkpoint的时间。

##### 定时器存储在RocksDB或JVM堆

* 默认情况下timers存储在rocksDB中，这是更健壮和可扩展的选择。当性能调优只有少量计时器(没有窗口，在ProcessFunction中不使用计时器)的任务时，将这些计时器放在`jvm heap`中可以提高性能。要小心使用此特性，因为基于堆的计时器可能会增加检查点时间，而且自然不能扩展到内存之外。

##### 优化RocksDB内存

* 默认情况下RocksDB状态后端使用Flink管理的RocksDBs缓冲区和缓存的内存预算`state.backend.rocksdb.memory.managed: true`
* 修改`state.backend.rocksdb.memory.write-buffer-ratio`比率，writebuffer占用总内存的比例，有助于state写入的性能

# Aligned Checkpoint和Unaligned Checkpoint

## Aligned Checkpoint

### Checkpoint导致的问题

1. Flink通过Checkpoint恢复时间长，会导致服务可用率降低。
2. 非幂等或非事务场景，导致大量业务数据重复。
3. Flink 任务如果持续反压严重，可能会进入死循环，永远追不上 lag。因为反压严重会导致 Flink Checkpoint 失败，Job 不能无限容忍 Checkpoint 失败，所以 Checkpoint 连续失败会导致 Job 失败。Job 失败后任务又会从很久之前的 Checkpoint 恢复开始追 lag，追 lag 时反压又很严重，Checkpoint 又会失败。从而进入死循环，任务永远追不上 Lag。
4. 在一些大流量场景中，SSD 成本很高，所以 Kafka 只会保留最近三小时的数据。如果 Checkpoint 持续三小时内失败，任务一旦重启，数据将无法恢复。

### Checkpoint为什么会失败？

* **Checkpoint Barrier** 从 Source 生成，并且 Barrier 从 Source 发送到 Sink Task。当 Barrier 到达 Task 时，该 Task 开始 Checkpoint。当这个 Job 的所有 Task 完成 Checkpoint 时，这个 Job 的 Checkpoint 就完成了。
* Task 必须处理完 Barrier 之前的所有数据，才能接收到 Barrier。例如 一个任务的某个 Task 处理数据慢，Task 不能快速消费完 Barrier 前的所有数据，所以不能接收到 Barrier。最终 这个Task 的 Checkpoint 就会失败，从而导致 Job 的 Checkpoint 失败。

## **Unaligned Checkpoint**

### UC Vs AC

* UC 的核心思路是 Barrier 超越这些 ongoing data，即 Buffer 中的数据，并快照这些数据。由此可见，当 Barrier 超越 ongoing data 后，快速到达了 Sink Task。与此同时，这些数据需要被快照，防止数据丢失。

![](../img/AcVsUc.jpg)

* 上图是 UC 和 AC 的简单对比，对于 AC，Offset 与数据库 Change log 类似。对于 UC，Offset 和 data 与数据库的 Change log 类似。Offset6 和 data 的组合，可以认为是 Offset4。其中，Offset4 和 Offset5 的数据从 State 中恢复，Offset6 以及以后的数据从 Kafka 中恢复。

### Unaligned Checkpoint底层原理

* 假设当前 Task 的上游 Task 并行度为 3，下游 Task 并行度为 2。Task 会有三个 InputChannel 和两个 SubPartition。紫红色框表示 Buffer 中的一条条数据。
* UC 开始后，Task 的三个 InputChannel 会陆续收到上游发送的 Barrier。如图所示，InputChannel 0 先收到了 Barrier，其他 Inputchannel 还没有收到 Barrier。当某一个 InputChannel 接收到 Barrier 时，Task 会直接开始 UC 的第一阶段，即：**UC 同步阶段**。
* 只要有任意一个 Barrier 进入 Task 网络层的输入缓冲区，Task 就会直接开始 UC，不用等其他 InputChannel 接收到 Barrier，也不需要处理完 InputChannel 内 Barrier 之前的数据。

#### UC同步阶段

![](../img/UC同步流程.jpg)

* UC 同步阶段的核心思路是：**Barrier 超越所有的 data Buffer**，并对这些**超越的 data Buffer 快照**。我们可以看到 Barrier 被直接发送到所有 SubPartition 的头部，超越了所有的 input 和 output Buffer，从而 Barrier 可以被快速发送到下游 Task。这也解释了为什么反压时 UC 可以成功：

  - 从 Task 视角来看，Barrier 可以在 Task 内部快速超车。

  - 从 Job 视角来看，如果每个 Task 都可以快速超车，那么 Barrier 就可以从 Source Task 快速超车到 Sink Task。

* 为了保证数据一致性，在 UC 同步阶段 Task 不能处理数据。同步阶段主要的流程如下。

  * Barrier 超车：保证 Barrier 快速发送到下游 Task。
  * 对 Buffer 进行引用：这里只是引用，真正的快照会在异步阶段完成。
  * 调用 Task 的 SnapshotState 方法。
  * State backend 同步快照。

#### UC异步阶段

![](../img/UC异步流程.jpg)

* 当 UC 同步阶段完成后，会继续处理数据。与此同时，开启 UC 的第二阶段：**Barrier 对齐和 UC 异步阶段。**异步阶段要**快照同步阶段引用的所有 input 和 output Buffer，以及同步阶段引用的算子内部的 State**。
* UC也需要进行Barrier对齐，当 Task 开始 UC 时，有很多 Inputchannel 没接收到 Barrier。**这些 InputChannel Barrier 之前的 Buffer，可能也 需要快照**。UC的异步阶段需要等待所有InputChannel的Barrier到达，且Barrier之前的Buffer都需要快照，这就是**UC Barrier对齐**。这个速度理论上是比较快的，只需要把Barrier超越发送到下游算子即可。
* UC 异步阶段流程。异步阶段需要写三部分数据到 FileSystem，分别是：
  - 同步阶段引用的算子内部的 State。
  - 同步阶段引用的所有 input 和 output Buffer。
  - 以及其他 input channel Barrier 之前的 Buffer。
* 当这三部分数据写完后，Task 会将结果汇报给 JobManager，Task 的异步阶段结束。其中算子 State 和汇报元数据流程与 Aligned Checkpoint 一致。

### UC性能调优

####  UC失败场景

##### output buffer不足

![](../img/UCBuffer不足.jpg)

* 如果 Task 处理一条数据并写入到 output Buffer 需要十分钟。那么在这 10 分钟期间，就算 UC Barrier 来了，Task 也不能进行 Checkpoint，所以 UC 还是会超时。通常处理一条数据不会很慢，**但写入到 output Buffer 里，可能会比较耗时。因为反压严重时，Task 的 output Buffer 经常没有可用的 Buffer，导致 Task 输出数据时经常卡在 request memory 上**。

###### 空闲buffer检测

* 社区在Flink-14396引入空闲buffer检测机制，如果buffer非空闲则不写output buffer，不做空闲检测前，Task 会卡在第五步的数据处理环节，不能及时响应 UC。空闲buffer检测后，Task 会卡在第三步，在这个环节接收到 UC Barrier 时，也可以快速开始 UC。
* 第三步，只检查是否有一个空闲 Buffer**。所以当处理一条数据需要多个 Buffer 的场景，Task 处理完数据输出结果时，可能仍然会卡在第五步，导致 Task 不能处理 UC**。例如单条数据较大，flatmap 算子、window 触发以及广播 watermark，都是处理一条数据，需要多个 Buffer 的场景。这些场景 Task 仍然会卡在 request memory 上。

######  **Overdraft Buffer**(1.6版本支持)

* Task 处理数据时有三步，即拉数据、处理数据以及输出结果。**透支 Buffer** 的思路是，在输出结果时，如果 output Buffer pool 中的 Buffer 不足，且 Task 有足够的 network Buffer。则**当前 Task 会向 TM 透支一些 Buffer**，从而完成数据处理环节，防止 Task 阻塞。
* 优化后处理一条数据需要多个 Buffer 的场景，UC 也可以较好的工作。默认每个 gate 可以透支五个 Buffer，可以调节 `taskmanager.network.memory.max-overdraft-buffers-per-gate` 参数来控制可以透支的 Buffer 量。

### UC风险点

* **Schema升级:**schema升级后，如果序列化不兼容，UC无法恢复；
* **链接改变:**算子之间的链接发送变化，UC无法恢复
* **小文件:**Data Buffer会写大量的filesystem小文件

#### 利用Aligned Timeout混合使用AC+UC

* 配置`execution.checkpointing.aligned-checkpoint-timeout` ck对齐超时时间，超时后会由AC切换至UC

#### 利用Task共享文件解决小文件问题

* 为了解决小文件的问题的优化思路是，同一个 TM 的多个 Task，不再单独创建文件，而是共享一个文件。

* 默认 **execution.checkpointing.unaligned.max-subTasks-per-channel-state-file** 是 5，即五个 Task 共享一个 UC 文件。UC 文件个数就会减少为原来的 1/5。五个 Task 只能串行写文件，来保证数据正确性，所以耗时会增加。

* 从生产经验来看，大量的 UC 小文件都会在 1M 以内，所以 20 个 Task 共享一个文件也是可以接受的。如果系统压力较小，且 Flink Job 更追求写效率，可以设置该参数为 1，表示 Task 不共享 UC 文件。

  **Flink 1.17 已经支持了 UC 小文件合并的 feature。**

# 状态一致性剖析

### 什么是状态一致性

* 有状态的流处理，内部每个算子任务都可以有自己的状态，对于流处理器内部来说，所谓的状态一致性，就是计算结果要保证准确。
* 一条数据不应该丢失也不应该重复计算，再遇到故障时可以恢复状态，恢复以后可以重新计算，结果应该也是完全正确的。

### 一致性分类

* AT-MOST-ONCE 最多一次
    * 当任务故障时，最简单的做法是什么都不干，即不恢复丢失的状态，也不重播丢失的数据。
* AT-LEAST-ONCE 至少一次
* EXACTLY-ONCE 精准一次

### 一致性检查点(Checkpoints)

* Flink使用轻量级快照机制-检查点(checkpoint)来保证exactly-once语义
* 有状态流应用的一致检查点，其实就是所有任务的状态，在某个时间点的一份拷贝，这个时间点，应该是所有任务都恰好处理完一个相同的输入数据的时候，应用状态的一致检查点是flink故障恢复机制的核心。

### 端到端状态一致性

* 前提条件Source端可以重置偏移量
* 目前flink保证了状态的一致性，但是外部的数据源和输出到持久化系统也需要保证一致性
* 端到端的一致性保证，意味着结果的正确性贯穿了整个流处理应用的始终，每个组件都需要保证自己的一致性
* 整个端到端一致性级别取决于所有组件中一致性最弱的组件

### source端

* 可重设数据的读取位置

### 内部保证

* checkpoint机制保证

### sink端

* 从故障恢复时，数据不会重复写入外部系统
* 幂等写入，依赖下游主键或其他方式
* 事务写入
    * Write-Ahead-Log WAL
        * 把结果数据先当成状态保存，然后在收到checkpoint完成的通知时，一次性写入sink系统
        * 简单已于实现，由于数据提前在状态后端中做了缓存，所以无论什么sink系统，都能一批搞定
        * DataStream API提供一个模版类:`GenericWriteAheadSink`来实现。
        * 存在的问题，延迟性大，如果存在批量写入失败时需要考虑回滚重放。
    * 2PAC（Two-Phase-Commit）
        * 对于每个checkpoint，sink任务会启动一个事务，并将接下来所有接收的数据添加到事务里。
        * 然后将这些数据写入外部sink系统，但不提交它们--这时只是"预提交"
        * 当它收到checkpoint完成的通知时，它才正式提交事务，实现结果真正写入（参考checkpoint barrier sink端写入完成后的ack checkpoint通知）
        * Flink提供`TwoPhaseCommitSinkFunction`接口,参考`FlinkKafkaProducer`
        * 对外部sink系统的要求
            * 外部sink系统提供事务支持，或者sink任务必须能够模拟外部系统上的事务
            * 在checkpoint的间隔期间，必须能够开启一个事务并接收数据写入
            * 在收到checkpoint完成的通知之前，事务必须时“等待提交”的状态。在故障恢复情况下，可能需要一些时间。如果这个时候sink系统关闭了事务，那么未提交的数据就丢失了。
            * sink任务必须能在进程失败后恢复事务，提交事务时幂等操作。

### Flink+Kafka端到端一致性保证

* 内部--利用checkpoint机制，把状态存盘，故障时可以恢复，保证内部状态一致性
* Source端---提供source端offset可以重置，checkpoint存储kafka consumer offset
* sink端---基于Flink提供的2PC机制，保证Exactly-Once

### Exactly-once两阶段提交

* JobManager协调各个TaskManager进行checkpoint存储
* checkpoint保存在StateBackend中，默认StateBackend时内存级，可以修改为文件级别的持久化保存。

#### 预提交阶段

* 当checkpoint启动时，jobmanager会将checkpoint barrier注入数据流，经过barrier对齐然后barrier会在算子间传递到下游。
* 每个算子会对当前的状态做个快照，保存到状态后端，barrier最终sink后会给JobManger一个ack checkpoint完成。
* 每个内部的transform任务遇到barrier时，都会把状态存到checkpoint里，sink任务首先把数据写入到外部kafka，这些数据都属于预提交的事务；遇到barrier时，把状态保存到状态后端，并开启新的预提交事务。
* 当所有算子任务的快照完成，也就是checkpoint完成时，jobmanager会向所有任务发送通知，确认这次checkpoint完成，sink任务收到确认通知，正式提交事务，kafka中未确认数据改为"已确认"

![kafka](../img/kafka俩阶段提交.jpg)

