# 大数据面试题库

## Flink专题

### 基础概念

#### Q1: Flink的核心优势是什么？

**答案要点：**
- 真正的流处理（非微批）
- 低延迟、高吞吐
- 精确一次语义（Exactly-once）
- 状态管理和容错机制
- 多层API支持

**扩展：** 对比Spark Streaming的微批处理

---

#### Q2: Flink的时间语义有哪些？

**答案要点：**
1. **Event Time**：事件发生的时间
2. **Processing Time**：系统处理时间
3. **Ingestion Time**：数据进入Flink的时间

**关键点：**
- Event Time需要Watermark机制
- Watermark的作用是触发窗口计算
- 如何处理乱序数据

**相关文档：** [第4章时间与窗口](bigdata/engine/flink/books/Flink内核原理与实现/第4章时间与窗口.xmind)

---

### 核心机制

#### Q3: 详细描述Flink Checkpoint机制

**答案要点：**

1. **基本原理**
   - 基于Chandy-Lamport分布式快照算法
   - Barrier屏障机制
   - 两阶段提交（2PC）

2. **工作流程**
   ```
   Source注入Barrier → Barrier随数据流动 → 
   算子对齐Barrier → 保存状态 → 确认Checkpoint
   ```

3. **关键配置**
   ```yaml
   execution.checkpointing.interval: 60s
   execution.checkpointing.mode: EXACTLY_ONCE
   execution.checkpointing.timeout: 10min
   execution.checkpointing.max-concurrent: 1
   ```

4. **优化策略**
   - 使用增量Checkpoint
   - 调整Checkpoint间隔
   - 使用RocksDB State Backend

**相关文档：**
- [Checkpoint机制](bigdata/engine/flink/core/Checkpoint机制.md)
- [FlinkCheckpoint源码分析](bigdata/engine/flink/sourcecode/FlinkCheckpoint源码分析.md)

---

#### Q4: Flink的状态后端有哪些？如何选择？

**答案要点：**

| State Backend | 特点 | 适用场景 |
|---------------|------|----------|
| HashMapStateBackend | 状态存储在JVM堆内存 | 小状态、快速访问 |
| RocksDBStateBackend | 状态存储在本地RocksDB | 大状态、生产环境推荐 |

**选择建议：**
- 状态 < 1GB：HashMapStateBackend
- 状态 > 1GB：RocksDBStateBackend
- 需要增量Checkpoint：必须用RocksDB

**相关文档：** [RocksDB On Flink](bigdata/store/rocksdb/RocksDB%20On%20Flink.md)

---

#### Q5: Flink的反压机制是如何工作的？

**答案要点：**

1. **反压产生原因**
   - 下游处理速度慢于上游
   - 网络缓冲区满

2. **工作机制**
   - 基于Credit的流量控制
   - 从Sink向Source逐级传递
   - 自动调节数据发送速率

3. **排查方法**
   - 查看Web UI的Backpressure页面
   - 监控inPoolUsage指标
   - 检查各算子的处理时间

4. **解决方案**
   - 增加并行度
   - 优化慢算子逻辑
   - 调整网络缓冲区大小

**相关文档：**
- [记录一次Flink反压问题](bigdata/engine/flink/practice/记录一次Flink反压问题.md)
- [Flink网络流控及反压](bigdata/engine/flink/sourcecode/Flink网络流控及反压.md)

---

### Window机制

#### Q6: Flink有哪些Window类型？

**答案要点：**

1. **Tumbling Window（滚动窗口）**
   - 固定大小、不重叠
   - 适合统计固定时间段的数据

2. **Sliding Window（滑动窗口）**
   - 固定大小、可重叠
   - 适合需要频繁更新的场景

3. **Session Window（会话窗口）**
   - 基于活动间隙
   - 适合用户行为分析

4. **Global Window（全局窗口）**
   - 所有数据在一个窗口
   - 需要自定义Trigger

**代码示例：**
```java
// 滚动窗口
.window(TumblingEventTimeWindows.of(Time.minutes(5)))

// 滑动窗口
.window(SlidingEventTimeWindows.of(Time.minutes(10), Time.minutes(5)))

// 会话窗口
.window(EventTimeSessionWindows.withGap(Time.minutes(30)))
```

---

### SQL & Table API

#### Q7: Flink SQL的执行流程是怎样的？

**答案要点：**

1. **SQL解析**
   - SqlParser → SqlNode（语法树）

2. **语义分析**
   - SqlValidator → 验证SQL合法性
   - 生成RelNode（关系代数树）

3. **逻辑优化**
   - HepPlanner进行规则优化
   - 谓词下推、列裁剪等

4. **物理优化**
   - StreamProgram生成执行计划
   - 转换为Transformation

5. **代码生成**
   - Janino编译为Java代码
   - 提交到集群执行

**相关文档：**
- [FlinkSQL源码解析](bigdata/engine/flink/sourcecode/FlinkSQL源码解析.md)
- [TableSQLOverview](bigdata/engine/flink/core/TableSQLOverview.md)

---

### 生产实践

#### Q8: 如何保证端到端的Exactly-once语义？

**答案要点：**

1. **内部保证**
   - Checkpoint机制
   - Barrier对齐

2. **Source端**
   - 支持重放的数据源（Kafka）
   - 记录offset到Checkpoint

3. **Sink端**
   - 两阶段提交（2PC）
   - 幂等写入
   - 事务性写入

4. **常见Sink的Exactly-once实现**
   - Kafka Sink：使用事务
   - MySQL Sink：使用幂等INSERT或UPDATE
   - HDFS Sink：原子重命名

**相关文档：** [Flink踩坑指南](bigdata/engine/flink/practice/Flink踩坑.xmind)

---

#### Q9: Flink on K8s有哪些部署模式？

**答案要点：**

1. **Native K8s（应用模式）**
   ```bash
   ./bin/flink run-application \
     -t kubernetes-application \
     -Dkubernetes.cluster-id=my-cluster \
     local:///opt/flink/examples/streaming/WordCount.jar
   ```

2. **K8s Operator**
   - 声明式API
   - 更好的生命周期管理
   - 支持自动扩缩容

3. **Session模式**（不推荐）

**对比：**
- Native K8s：每个作业独立Pod，资源隔离好
- Operator：适合大规模部署，运维友好

**相关文档：**
- [Flink On Native K8s实践](bigdata/engine/flink/devops/Flink%20On%20Native%20K8s.md)
- [Flink On K8s Operator](bigdata/engine/flink/devops/Flink%20On%20K8s%20Operator.md)

---

#### Q10: 如何处理Flink中的数据倾斜？

**答案要点：**

1. **识别数据倾斜**
   - 观察各subtask的处理记录数
   - 监控CPU和内存使用率

2. **解决方案**

   **方案一：加盐打散**
   ```java
   // 给key添加随机前缀
   String saltedKey = originalKey + "_" + random.nextInt(10);
   ```

   **方案二：局部聚合+全局聚合**
   ```java
   // 第一层：局部聚合（加盐）
   .keyBy(saltedKey)
   .sum(count)
   
   // 第二层：全局聚合（去盐）
   .keyBy(originalKey)
   .sum(count)
   ```

   **方案三：调整并行度**
   - 增加倾斜算子的并行度

   **方案四：使用Rebalance**
   ```java
   .rebalance()  // 轮询分发
   ```

**相关文档：** [Flink SQL调优](bigdata/engine/flink/practice/Flink%20SQL调优.xmind)

---

## Spark专题

### 基础概念

#### Q1: Spark Core的核心组件有哪些？

**答案要点：**
- RDD（弹性分布式数据集）
- DAGScheduler
- TaskScheduler
- Executor

**相关文档：** [SparkCore](bigdata/engine/spark/spark%20core/Spark%20Core.xmind)

---

#### Q2: Spark的宽依赖和窄依赖有什么区别？

**答案要点：**

| 类型 | 特点 | 示例 |
|------|------|------|
| 窄依赖 | 父RDD分区只被子RDD一个分区使用 | map, filter, union |
| 宽依赖 | 父RDD分区被子RDD多个分区使用 | groupByKey, reduceByKey, join |

**重要性：**
- 窄依赖可以pipeline执行
- 宽依赖需要Shuffle，是性能瓶颈

---

### Shuffle机制

#### Q3: Spark Shuffle的发展历程？

**答案要点：**

1. **Hash Shuffle（Spark 1.2之前）**
   - 每个map task为每个reduce task创建一个文件
   - 文件数量：M * R（M=map数，R=reduce数）
   - 问题：大量小文件

2. **Sort Shuffle（Spark 1.2+）**
   - 先排序再写入
   - 引入Shuffle File合并机制
   - 减少文件数量

3. **Tungsten Sort Shuffle（Spark 1.5+）**
   - 使用堆外内存
   - 二进制序列化
   - 性能提升3-5倍

**相关文档：** [Spark计算引擎和Shuffle](bigdata/engine/spark/Spark计算引擎和Shuffle.md)

---

### 性能调优

#### Q4: Spark性能调优有哪些手段？

**答案要点：**

1. **资源调优**
   ```scala
   --executor-memory 4g
   --executor-cores 2
   --num-executors 10
   ```

2. **并行度调优**
   - 设置spark.default.parallelism
   - repartition/coalesce调整分区数

3. **数据倾斜处理**
   - 加盐打散
   - 广播小表
   - 提高shuffle并行度

4. **缓存策略**
   ```scala
   rdd.cache()        // MEMORY_ONLY
   rdd.persist(StorageLevel.MEMORY_AND_DISK)
   ```

5. **序列化优化**
   - 使用Kryo序列化
   ```scala
   spark.serializer = "org.apache.spark.serializer.KryoSerializer"
   ```

**相关文档：** [Spark生产实践](bigdata/engine/spark/practice/Spark生产实践.md)

---

## Kafka专题

### 核心概念

#### Q1: Kafka为什么这么快？

**答案要点：**

1. **顺序写磁盘**
   - 避免随机IO
   - 利用磁盘顺序写性能接近内存

2. **零拷贝技术**
   - sendfile系统调用
   - 减少内核态和用户态切换

3. **页缓存**
   - 利用操作系统Page Cache
   - 避免JVM GC问题

4. **批量发送**
   - Producer批量发送
   - Consumer批量拉取

5. **分区并行**
   - Topic分Partition
   - 并行读写

**相关文档：** [kafka权威指南读书笔记](bigdata/mq/kafka/kafka权威指南/)

---

#### Q2: Kafka如何保证消息不丢失？

**答案要点：**

1. **Producer端**
   ```properties
   acks=all  # 所有ISR副本确认
   retries=Integer.MAX_VALUE
   ```

2. **Broker端**
   ```properties
   replication.factor=3  # 副本数
   min.insync.replicas=2  # 最小同步副本数
   unclean.leader.election.enable=false  # 禁止非ISR选举
   ```

3. **Consumer端**
   - 手动提交offset
   - 处理完业务逻辑后再提交

**完整保障：**
- Producer：acks=all + 重试
- Broker：多副本 + 禁用unclean选举
- Consumer：手动提交 + 幂等处理

---

#### Q3: Kafka消费者组Rebalance机制？

**答案要点：**

1. **触发条件**
   - 消费者加入或离开
   - Topic分区数变化
   - 订阅的Topic变化

2. **Rebalance过程**
   ```
   Coordinator检测变化 → 
   通知所有消费者 → 
   停止消费 → 
   重新分配分区 → 
   恢复消费
   ```

3. **常见问题**
   - Rebalance频繁触发
   - 解决：增加session.timeout.ms
   - 解决：合理设置max.poll.interval.ms

**相关文档：** [消费者源码剖析](bigdata/mq/kafka/消费者源码剖析.md)

---

## 数据仓库专题

### 建模理论

#### Q1: 维度建模的核心概念有哪些？

**答案要点：**

1. **事实表（Fact Table）**
   - 存储业务过程的度量值
   - 包含外键指向维度表
   - 类型：事务事实表、周期快照事实表、累积快照事实表

2. **维度表（Dimension Table）**
   - 描述业务实体属性
   - 提供查询上下文
   - 缓慢变化维（SCD）处理

3. **总线矩阵**
   - 定义业务过程和维度关系
   - 确保数据一致性

**相关文档：** [数据建模](datawarehouse/理论/DataModeler.md)

---

#### Q2: 数据仓库分层架构？

**答案要点：**

```
ODS（操作数据层）
  ↓
DWD（明细数据层）
  ↓
DWS（汇总数据层）
  ↓
ADS（应用数据层）
```

**各层职责：**

1. **ODS层**
   - 原始数据备份
   - 保持与源系统一致

2. **DWD层**
   - 数据清洗、规范化
   - 维度退化、脱敏
   - 构建事务事实表

3. **DWS层**
   - 轻度汇总
   - 按主题组织
   - 构建宽表

4. **ADS层**
   - 面向应用
   - 高度聚合
   - 直接服务于报表

**相关文档：** [数据仓库实战](datawarehouse/理论/数据仓库实战.md)

---

#### Q3: 如何处理缓慢变化维（SCD）？

**答案要点：**

**SCD Type 1（覆盖）**
- 直接更新，不保留历史
- 适用：错误修正

**SCD Type 2（拉链表）**
- 新增记录，保留历史
- 字段：start_date, end_date, is_current
- 适用：需要追溯历史

**SCD Type 3（新增列）**
- 增加历史值字段
- 适用：只需保留最近一次变化

**拉链表实现：**
```sql
-- 查询当前有效记录
SELECT * FROM dim_user 
WHERE is_current = 1;

-- 查询历史某个时间点的数据
SELECT * FROM dim_user 
WHERE start_date <= '2024-01-01' 
  AND end_date > '2024-01-01';
```

**相关文档：** [拉链表.jpg](datawarehouse/img/拉链表.jpg)

---

### 实时数仓

#### Q4: 如何设计实时数仓架构？

**答案要点：**

**Lambda架构（传统）**
```
         ┌→ 批处理层（离线）
数据源 ──┤
         └→ 速度层（实时）
              ↓
         服务层合并
```

**Kappa架构（纯实时）**
```
数据源 → Kafka → Flink实时计算 → OLAP引擎
```

**现代实时数仓架构：**
```
MySQL Binlog → Canal/Debezium → Kafka
                                    ↓
                              Flink实时计算
                                    ↓
                          Hudi/Iceberg数据湖
                                    ↓
                            Presto/Impala查询
```

**关键技术：**
- CDC采集：Canal、Debezium
- 实时计算：Flink
- 数据存储：Hudi、Iceberg、Kudu
- OLAP查询：Presto、Impala、ClickHouse

**相关文档：** [基于Flink的实时数仓建设](datawarehouse/方案实践/基于Flink的实时数仓建设.md)

---

## Hadoop专题

### HDFS

#### Q1: HDFS的读写流程？

**答案要点：**

**写流程：**
```
Client → NameNode（请求创建文件）
    ↓
NameNode返回DataNode列表
    ↓
Client → DataNode（建立Pipeline）
    ↓
Client分块写入 → DataNode1 → DataNode2 → DataNode3
    ↓
逐层ACK确认
    ↓
NameNode记录元数据
```

**读流程：**
```
Client → NameNode（请求文件位置）
    ↓
NameNode返回DataNode列表（按距离排序）
    ↓
Client → 最近的DataNode读取数据
```

**相关文档：** [HDFSOverView](bigdata/hadoop/HDFS/HDFSOverView.xmind)

---

#### Q2: NameNode高可用如何实现？

**答案要点：**

1. **双NameNode架构**
   - Active NameNode
   - Standby NameNode

2. **元数据同步**
   - JournalNode集群（Quorum Journal Manager）
   - Active写入EditLog到JournalNode
   - Standby从JournalNode读取并回放

3. **故障转移**
   - ZKFC（ZK Failover Controller）
   - ZooKeeper选举
   - 自动切换Active/Standby

**相关文档：** [Hadoop高可用配置](bigdata/hadoop/Hadoop高可用配置.md)

---

## 数据湖专题

### Hudi vs Iceberg vs Paimon

#### Q1: 三大数据湖框架对比？

**答案要点：**

| 特性 | Hudi | Iceberg | Paimon |
|------|------|---------|--------|
| 诞生公司 | Uber | Netflix | Alibaba |
| 表类型 | COW/MOR | MOR思想 | PK表/非PK表 |
| 索引机制 | 有 | 无 | 有 |
| Flink集成 | 成熟 | 发展中 | 原生支持 |
| 适用场景 | 高频更新 | Schema演进 | 流式优先 |

**选型建议：**
- 高频upsert：Hudi
- 多引擎统一：Iceberg
- Flink流式场景：Paimon

**相关文档：**
- [Hudi概览](bigdata/datalake/hudi/hudiOverview.md)
- [IceBerg概览](bigdata/datalake/iceberg/icebergOverview.md)
- [Paimon概览](bigdata/datalake/paimon/PaimonOverview.md)

---

#### Q2: Hudi的COW和MOR有什么区别？

**答案要点：**

**COW（Copy On Write）**
- 更新时重写整个文件
- 读性能好，写性能差
- 适用：读多写少场景

**MOR（Merge On Read）**
- 更新时写入增量日志（Avro格式）
- 读取时合并基线和日志
- 写性能好，读性能稍差
- 适用：写多读少、近实时场景

**选择建议：**
- 低频更新（天级）：COW
- 高频更新（分钟级）：MOR

**相关文档：** [Hudi原理分析](bigdata/datalake/hudi/hudi原理分析.md)

---

## 场景设计题

### 题目1: 设计一个实时用户行为分析系统

**要求：**
- 实时统计PV、UV
- 支持多维度分析（地域、设备、渠道）
- 秒级延迟

**参考答案：**

```
架构设计：

前端埋点 → Nginx → Flume → Kafka
                              ↓
                        Flink实时计算
                              ↓
                    ┌────────┴────────┐
                    ↓                 ↓
                Redis(UV去重)    ClickHouse(多维分析)
                    ↓                 ↓
                  大屏展示          BI报表
```

**关键技术点：**
1. **UV去重**：使用Bitmap或HyperLogLog
2. **窗口设计**：1分钟滚动窗口
3. **维度关联**：使用Flink Temporal Table Join
4. **存储选型**：Redis存实时指标，ClickHouse存明细

---

### 题目2: 如何解决百亿级数据的即席查询？

**要求：**
- 数据量：100亿+
- 查询响应：< 5秒
- 支持复杂SQL

**参考答案：**

**方案一：Presto + Alluxio**
- Presto分布式查询
- Alluxio缓存热点数据
- 适用：多数据源联合查询

**方案二：ClickHouse**
- 列式存储
- 向量化执行
- 适用：单表聚合查询

**方案三：Kudu + Impala**
- Kudu实时更新
- Impala MPP查询
- 适用：实时更新+即席查询

**优化手段：**
1. 分区裁剪
2. 谓词下推
3. 列裁剪
4. 预计算物化视图
5. 智能索引

**相关文档：**
- [实时OLAP架构](datawarehouse/img/实时OLAP架构.jpg)
- [Presto架构](datawarehouse/img/presto架构.jpg)

---

## 学习建议

### 复习策略

1. **按模块复习**
   - 每次专注一个技术栈
   - 先理论后实践

2. **制作思维导图**
   - 梳理知识体系
   - 发现知识盲区

3. **刷题巩固**
   - 每天5-10道面试题
   - 录音复盘回答

4. **实战演练**
   - 搭建实验环境
   - 复现生产问题

### 重点突破

**必掌握核心：**
- Flink：Checkpoint、Window、State
- Kafka：Rebalance、Exactly-once
- 数仓：分层设计、维度建模
- Hadoop：HDFS读写、YARN调度

**加分项：**
- 源码阅读能力
- 性能调优经验
- 故障排查思路
- 架构设计能力

---

## 持续更新

本题库会根据实际面试经验持续更新，建议定期复习。

**最后更新：** 2024年

**贡献者：** 欢迎补充更多高质量面试题
