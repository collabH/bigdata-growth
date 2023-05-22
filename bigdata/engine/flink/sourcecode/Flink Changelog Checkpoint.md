# 概念

![](../img/checkpoint发展进程.jpg)

* Flink Changelog Checkpoint是Flink1.15之后推出的一种基于增量Log方式的Checkpoint机制，它通过更通用的 Incremental Checkpoint 机制进一步提升了 Checkpoint 的异步性能。

## **Changelog Checkpoint的目标**

* 更稳定的Checkpoint
  * 通过解耦 Compaction 和 Checkpoint 过程，使 Checkpoint 更稳定，大幅减少 Checkpoint Duration 突增的情况，还可进一步减少 CPU 抖动，使网络带宽变得更平稳。
  * 在大规模、大状态作业上经常会出现 CPU 随着 Checkpoint 周期性抖动，进而影响作业和集群稳定性的情况。Changelog 通过解耦 Checkpoint 触发 Compaction 的过程，可以使 CPU 变得更平稳。另外，在异步过程中，Compaction 导致的大量文件同时上传有时会将网络带宽打满， 而 Changelog 是能够缓解该状况的。
* 更快速的Checkpoint
  * Checkpoint期间上传相对固定的增量数据，秒级/亚秒级完成Checkpoint
* 更小的端到端延迟
  * Flink 中实现端到端的 Exactly-once 语义主要依赖于 Checkpoint 的完成时间。Checkpoint 完成越快，Transactional sink 可以提交得更频繁，保证更好的数据新鲜度。后续可与 Paimon 结合，保证 Paimon上的数据更新鲜。
* 更少的数据追回
  * 通过设置更小的 Checkpoint Interval 加速 Failover 过程，可以减少数据回追。

## Rocksdb增量Checkpoint

### 数据写入Rocksdb的过程

* 当一条 Record 写到 RocksDB 时，首先会写到 Memtable ，数据量达到 Memtable 阈值后会 Memtable 变为 **Immutable Memtable**；当数据量再达到整个 Memory 所有 Memtable 的阈值后，会 Flush 到磁盘，形成 SST Files 。L0 的 SST files 之间是有重叠的 。Flink 默认使用 RocksDB 的 Level Compaction 机制 ，因此在 L0 达到阈值后，会继续触发 Level Compaction，与 L1 进行 Compaction ，进一步可能触发后续 Level Compaction。

### Checkpoint 同步阶段和异步阶段过程

* 在同步过程中，Checkpoint 首先会触发 Memtable 强制 Flush，这一过程可能会触发后面级联的 Level Compaction，该步骤可能导致大量文件需要重新上传。同时，同步过程中会做 Local Checkpoint ，这是 RocksDB 本地的 Checkpoint 机制，对 Rocksdb 而言其实就是硬链接一些 SST Files，是相对轻量的。异步过程会将这些 SST Files 上传，同时写入 Meta 信息。

### Rocksdb增量ck存在的问题

* 数据量达到阈值，或者 Checkpoint 的同步阶段，是会触发 Memtable Flush，进一步触发级联 Level Compation，进一步导致大量文件需要重新上传的
* 在大规模作业中，每次 Checkpoint 可能都会因为某一个 Subtask 异步时间过长而需要重新上传很多文件。端到端 Duration 会因为 Compaction 机制而变得很长。

## Changelog Checkpoint的改进

| 术语            | 描述                                                         |
| --------------- | ------------------------------------------------------------ |
| State Table     | 本地状态数据读写结构，如Rocksdb                              |
| Materialization | State table的持久化过程，目前会定时触发，在完成一次成功的Materialization(物化)后会Truncate Changelog |
| DSTL            | Durable Short-time Log(持久短时间日志).Changelog的存储组件   |
| Changelog       | 以Append-only Log形式存储的状态记录                          |

* **State Table** 是本地状态数据读写结构，比如 RocksDB。已有的 StateBackend（HashmapStateBackend/RocksDBStateBackend，或者自定义的一种StateBackend）均可以打开该功能 。而且在 1.16 中实现了 Changelog **开到关和关到开的兼容性，用户可以非常方便地在存量作业中使用**。
* Materialization **是 State Table 持久化的过程**，可以理解为 RocksDBStateBackend 或 HashmapStateBackend 做 Checkpoint 的过程。目前会定时触发，完成一次成功的 Materialization 后会 Truncate 掉 Changelog ，即做 Changelog 的清理。
* DSTL 是 Changelog 的存储组件。Changelog 的写入需要提供持久化、低延迟、一致性及并发支持。目前基于 **DFS** 实现了 DSTL。

### Changelog流程

* Changelog机制类似于WAL日志的机制，首先，在状态写入时，**会同时写到 State Table 和 DSTL**，如果 State Table 是 Rocksdb，那么它的后续流程就像我们刚才提到的一样，包括写 Memtable，Flush，触发 Compaction 等等过程。DSTL 这个部分会以操作日志的方式追加写入 DSTL，我们也支持了不同 State 类型的各种操作的写入。
* 其中 DSTL 会有一套完整的**定时持久化机制持久化到远端存储中**，所有 Changelog 将会在运行过程中连续上传，同时在 Checkpoint 上传较小的增量。
* State Table **会定时进行 Materialization**，在完成一次完整的 Materialization 后将会对 Changelog 进行 Truncate，清理掉失效的 Changelog，然后新的 Checkpoint 将以这个 Materialization 为基准继续持续上传增量。

>在状态写入时，会双写到 State Table 和 Dstl，读取时会从 State Table 中读取，即读写链路上只是多了个双写，且 Dstl 的部分是 append-only 的写入，会非常轻量级。
>
>在 Checkpoint 时，依赖于定时 Materilize State Table，以及定期 Persist Changelog，需要上传的增量会非常小，在上传小增量后只需要把 Materialization 部分的 Handle 和 Changelog 部分的 Handle 组合返回给 jm 即可。同时我们也会依赖于 Truncate 机制去及时清理无效 Changelog。
>
>在 Restore 时，我们拿到了 State Table 的 Handle 和 Changelog 的 Handle，State Table 部分会按之前的方式进行 Retsore，比如是 Rocksdb，在没开启 Local Recovery 时，会先下载远端 SST Files，再 Rebuild。Changelog 部分再没有开启 Local Recovery 时，会先下载远端 State Change，然后重新 Apply 到 State Table，Rebuild Changelog 部分。

