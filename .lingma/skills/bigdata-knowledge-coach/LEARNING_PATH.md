# 大数据学习路径指南

## 学习路线总览

```
基础阶段 → 核心技术 → 进阶专题 → 生产实践 → 架构设计
```

---

## 阶段一：基础夯实（1-2个月）

### 目标
建立计算机科学和编程基础，为大数据学习打下坚实基础。

### 学习内容

#### 1. Java基础（2周）

**核心知识点：**
- Java集合框架
- JVM内存模型
- 多线程与并发
- IO/NIO

**学习资源：**
- [认识并发编程](base/java/并发编程/认识并发编程.md)
- [并发工具包](base/java/并发编程/并发工具类concurrent.md)

**实践任务：**
- 实现线程安全的计数器
- 使用线程池处理任务
- 理解synchronized和ReentrantLock区别

---

#### 2. Linux & Shell（1周）

**核心知识点：**
- 常用Linux命令
- Shell脚本编写
- 文件权限管理
- 进程管理

**学习资源：**
- [Shell学习](devops/Shell学习.xmind)
- [Linux学习](devops/Linux学习.xmind)

**实践任务：**
- 编写自动化部署脚本
- 日志分析脚本
- 系统监控脚本

---

#### 3. 数据结构与算法（2周）

**核心知识点：**
- 数组、链表、栈、队列
- 树、图
- 排序算法
- 查找算法

**学习资源：**
- [数据结构](base/datastructure/数据结构.md)
- [算法题解](base/algorithm/算法题解.md)

**实践任务：**
- LeetCode刷题50道
- 实现常见排序算法
- 理解时间复杂度和空间复杂度

---

#### 4. 分布式理论（1周）

**核心知识点：**
- CAP定理
- BASE理论
- 一致性协议（Paxos、Raft）
- 分布式事务

**学习资源：**
- [分布式架构](base/分布式理论/分布式架构.md)
- [Raft一致性算法](base/分布式理论/Raft一致性算法.md)

**实践任务：**
- 理解Etcd的Raft实现
- 分析Zookeeper的ZAB协议

---

## 阶段二：Hadoop生态（1-2个月）

### 目标
掌握Hadoop核心组件，理解分布式存储和计算原理。

### 学习内容

#### 1. HDFS（1周）

**核心知识点：**
- NameNode和DataNode架构
- 数据块复制机制
- 读写流程
- 高可用配置

**学习资源：**
- [HDFSOverView](bigdata/hadoop/HDFS/HDFSOverView.xmind)
- [HDFS集群管理](bigdata/hadoop/HDFS/HDFS集群管理.md)

**实践任务：**
- 搭建Hadoop伪分布式环境
- 执行HDFS常用操作
- 配置HA集群

---

#### 2. MapReduce（1周）

**核心知识点：**
- Map和Reduce阶段
- Shuffle过程
- Combiner优化
- 分区策略

**学习资源：**
- [MapReduce概览](bigdata/hadoop/MapReduce/MapReduceOverView.xmind)
- [MapReduce的工作原理剖析](bigdata/hadoop/MapReduce/MapReduce的工作原理剖析.md)

**实践任务：**
- 编写WordCount程序
- 实现二次排序
- 理解MapReduce调优参数

---

#### 3. YARN（3天）

**核心知识点：**
- ResourceManager和NodeManager
- 调度器（Capacity、Fair）
- 应用提交流程

**学习资源：**
- [YARN快速入门](bigdata/hadoop/Yarn/YARN快速入门.md)

**实践任务：**
- 提交MR作业到YARN
- 配置队列和资源限制

---

#### 4. Hive（2周）

**核心知识点：**
- Hive架构
- SQL语法
- 分区表和分桶表
- 性能调优

**学习资源：**
- [HiveOverwrite](bigdata/olap/hive/HiveOverwrite.md)
- [Hive调优指南](bigdata/olap/hive/Hive调优指南.xmind)
- [Hive编程指南读书笔记](bigdata/olap/hive/hive编程指南)

**实践任务：**
- 创建分区表
- 编写复杂SQL查询
- 优化慢查询
- 理解执行计划

---

## 阶段三：计算引擎（2-3个月）

### 目标
深入掌握Spark和Flink两大计算引擎，能够开发复杂的批处理和流处理应用。

### 学习路径A：Spark（6周）

#### Week 1-2: Spark Core

**核心知识点：**
- RDD编程模型
- Transformation和Action
- 宽依赖和窄依赖
- DAG执行

**学习资源：**
- [SparkCore](bigdata/engine/spark/spark%20core/Spark%20Core.xmind)
- [SparkOperator](bigdata/engine/spark/spark%20core/Spark%20Operator.xmind)

**实践任务：**
- RDD基本操作练习
- 实现PageRank算法
- 理解缓存机制

---

#### Week 3-4: Spark SQL

**核心知识点：**
- DataFrame和Dataset API
- Catalyst优化器
- Tungsten执行引擎
- UDF开发

**学习资源：**
- [SparkSQL](bigdata/engine/spark/spark%20sql/Spark%20SQL.xmind)
- [SparkSQL优化分析](bigdata/engine/spark/spark%20sql/SparkSQL优化分析.md)

**实践任务：**
- 使用DataFrame进行数据分析
- 编写自定义UDF
- 分析SQL执行计划

---

#### Week 5: Spark Streaming

**核心知识点：**
- DStream模型
- 微批处理
- 窗口操作
- 状态管理

**学习资源：**
- [SparkStreaming](bigdata/engine/spark/spark%20streaming/Spark%20Steaming.xmind)

**实践任务：**
- 实时词频统计
- 整合Kafka消费数据

---

#### Week 6: 源码与调优

**核心知识点：**
- Spark调度系统
- Shuffle机制
- 内存管理
- 性能调优

**学习资源：**
- [从浅到深剖析Spark源码](bigdata/engine/spark/从浅到深剖析Spark源码.md)
- [Spark生产实践](bigdata/engine/spark/practice/Spark生产实践.md)

**实践任务：**
- 阅读TaskScheduler源码
- 调优Spark作业参数
- 解决数据倾斜问题

---

### 学习路径B：Flink（8周）⭐推荐重点

#### Week 1-2: Flink基础

**核心知识点：**
- Flink架构
- DataStream API
- Source、Transform、Sink
- 并行度和任务链

**学习资源：**
- [FlinkOverview](bigdata/engine/flink/core/FlinkOverview.md)
- [DataStream API](bigdata/engine/flink/core/FlinkDataStream%20API.xmind)

**实践任务：**
- 搭建Flink本地环境
- 实现WordCount
- 读取Kafka数据写入MySQL

---

#### Week 3-4: 时间与窗口

**核心知识点：**
- Event Time vs Processing Time
- Watermark机制
- Window类型（Tumbling、Sliding、Session）
- Trigger和Evictor

**学习资源：**
- [第4章时间与窗口](bigdata/engine/flink/books/Flink内核原理与实现/第4章时间与窗口.xmind)
- [Flink窗口实现应用原理](bigdata/engine/flink/sourcecode/Flink窗口实现应用原理.md)

**实践任务：**
- 实现滚动窗口聚合
- 处理乱序数据
- 自定义Watermark策略

---

#### Week 5-6: 状态与容错

**核心知识点：**
- State类型（KeyedState、OperatorState）
- StateBackend（HashMap、RocksDB）
- Checkpoint机制
- Savepoint

**学习资源：**
- [Checkpoint机制](bigdata/engine/flink/core/Checkpoint机制.md)
- [第7章状态原理](bigdata/engine/flink/books/Flink内核原理与实现/第7章状态原理.xmind)
- [FlinkCheckpoint源码分析](bigdata/engine/flink/sourcecode/FlinkCheckpoint源码分析.md)

**实践任务：**
- 使用ValueState实现去重
- 配置Checkpoint参数
- 测试故障恢复

---

#### Week 7: Flink SQL

**核心知识点：**
- Table API基础
- Flink SQL语法
- 动态表概念
- Temporal Table Join

**学习资源：**
- [TableSQLOverview](bigdata/engine/flink/core/TableSQLOverview.md)
- [FlinkSQL源码解析](bigdata/engine/flink/sourcecode/FlinkSQL源码解析.md)

**实践任务：**
- 使用Flink SQL实现ETL
- 维表关联查询
- CDC数据同步

---

#### Week 8: 高级特性与生产实践

**核心知识点：**
- CEP复杂事件处理
- ProcessFunction底层API
- 反压机制
- 性能调优

**学习资源：**
- [Flink CEP](bigdata/engine/flink/core/Flink%20Cep.xmind)
- [ProcessFunction API](bigdata/engine/flink/core/ProcessFunction%20API.xmind)
- [记录一次Flink反压问题](bigdata/engine/flink/practice/记录一次Flink反压问题.md)
- [Flink SQL调优](bigdata/engine/flink/practice/Flink%20SQL调优.xmind)

**实践任务：**
- 实现欺诈检测CEP规则
- 排查反压问题
- 优化作业性能

---

## 阶段四：数据存储（1-2个月）

### 目标
掌握各种大数据存储系统，理解其适用场景。

### 1. NoSQL数据库（2周）

#### HBase

**核心知识点：**
- RowKey设计
- Column Family
- Bloom Filter
- Compaction机制

**学习资源：**
- [HBase概览](bigdata/store/hbase/HBaseOverview.md)
- [Hbase过滤器](bigdata/store/hbase/Hbase过滤器.md)

**实践任务：**
- 设计RowKey
- 批量导入数据
- 使用过滤器查询

---

#### RocksDB

**核心知识点：**
- LSM Tree结构
- MemTable和SSTable
- Compaction策略
- Write Ahead Log

**学习资源：**
- [rocksDB概述](bigdata/store/rocksdb/RocksdbOverview.md)
- [LSM存储模型](base/计算机理论/LSM存储模型.md)

**实践任务：**
- 理解RocksDB在Flink中的应用
- 调整Compaction参数

---

### 2. OLAP引擎（2周）

#### ClickHouse

**核心知识点：**
- 列式存储
- 表引擎（MergeTree系列）
- 物化视图
- 分布式表

**学习资源：**
- [ClickHouse快速入门](bigdata/olap/clickhouse/ClickHouseOverView.md)
- [ClickHouse表引擎](bigdata/olap/clickhouse/ClickHouse表引擎.xmind)

**实践任务：**
- 创建MergeTree表
- 导入测试数据
- 性能基准测试

---

#### Kudu + Impala

**核心知识点：**
- Kudu存储架构
- Tablet和Tablet Server
- Impala MPP查询
- Predicate Pushdown

**学习资源：**
- [KuduOverView](bigdata/olap/kudu/KuduOverView.md)
- [ImpalaOverView](bigdata/olap/impala/ImpalaOverView.md)
- [Kudu论文阅读](bigdata/olap/kudu/paper/KuduPaper阅读.md)

**实践任务：**
- 创建Kudu表
- 使用Impala查询
- 测试更新性能

---

### 3. 消息队列（1周）

#### Kafka

**核心知识点：**
- Topic和Partition
- Producer和Consumer
- Consumer Group
- Rebalance机制

**学习资源：**
- [kafka概览](bigdata/mq/kafka/KafkaOverView.xmind)
- [生产者源码剖析](bigdata/mq/kafka/生产者源码剖析.md)
- [消费者源码剖析](bigdata/mq/kafka/消费者源码剖析.md)

**实践任务：**
- 创建Topic
- 生产者和消费者代码
- 监控消费者滞后

---

## 阶段五：数据湖（1个月）

### 目标
掌握现代数据湖技术，理解Lakehouse架构。

### 1. Apache Hudi（2周）

**核心知识点：**
- COW vs MOR表类型
- Timeline机制
- Index机制
- Compaction策略

**学习资源：**
- [Hudi概览](bigdata/datalake/hudi/hudiOverview.md)
- [Hudi整合Spark](bigdata/datalake/hudi/hudiWithSpark.md)
- [Hudi整合Flink](bigdata/datalake/hudi/hudiWithFlink.md)
- [Hudi原理分析](bigdata/datalake/hudi/hudi原理分析.md)

**实践任务：**
- 使用Spark写入Hudi表
- 使用Flink进行Upsert
- 测试增量查询

---

### 2. Apache Iceberg（1周）

**核心知识点：**
- Manifest文件结构
- Snapshot隔离
- Schema演进
- Partition Evolution

**学习资源：**
- [IceBerg概览](bigdata/datalake/iceberg/icebergOverview.md)
- [IceBerg整合Flink](bigdata/datalake/iceberg/icebergWithFlink.md)

**实践任务：**
- 创建Iceberg表
- 测试Schema变更
- 时间旅行查询

---

### 3. Apache Paimon（1周）

**核心知识点：**
- 主键表和非主键表
- Changelog生成
- Flink原生集成

**学习资源：**
- [Paimon概览](bigdata/datalake/paimon/PaimonOverview.md)
- [Flink操作Paimon](bigdata/datalake/paimon/PaimonOnFlink.md)

**实践任务：**
- 创建Paimon主键表
- Flink CDC写入Paimon
- 流式读取Changelog

---

## 阶段六：数据仓库建设（1-2个月）

### 目标
掌握数据仓库建模理论和实战，能够设计企业级数仓架构。

### 1. 数据建模理论（2周）

**核心知识点：**
- 维度建模
- 事实表和维度表
- 缓慢变化维（SCD）
- 总线矩阵

**学习资源：**
- [数据建模](datawarehouse/理论/DataModeler.md)
- [数据仓库建模](datawarehouse/理论/数据仓库建模.xmind)
- [数据仓库实战](datawarehouse/理论/数据仓库实战.md)

**实践任务：**
- 设计电商数仓模型
- 构建总线矩阵
- 实现拉链表

---

### 2. 离线数仓（2周）

**核心知识点：**
- 分层架构（ODS/DWD/DWS/ADS）
- ETL流程
- 任务调度
- 数据质量

**学习资源：**
- [离线数仓.jpg](datawarehouse/img/离线数仓.jpg)

**实践任务：**
- 使用Azkaban调度任务
- 实现每日ETL流程
- 数据质量校验

---

### 3. 实时数仓（2周）

**核心知识点：**
- Lambda架构
- Kappa架构
- 实时ETL
- 流批一体

**学习资源：**
- [基于Flink的实时数仓建设](datawarehouse/方案实践/基于Flink的实时数仓建设.md)
- [实时数仓架构](datawarehouse/img/实时数仓架构.jpg)

**实践任务：**
- 使用Flink CDC采集Binlog
- 实时清洗和关联
- 写入数据湖

---

### 4. 数据中台（1周）

**核心知识点：**
- 数据中台概念
- 元数据管理
- 数据资产
- 数据服务

**学习资源：**
- [数据中台设计](datawarehouse/数据中台模块设计/数据中台设计.md)
- [thoth自研元数据平台设计](datawarehouse/数据中台模块设计/thoth自研元数据平台设计.md)
- [数据中台读书笔记](datawarehouse/数据中台读书笔记.md)

**实践任务：**
- 设计元数据模型
- 构建数据目录
- 实现数据血缘

---

## 阶段七：DevOps与运维（2周）

### 目标
掌握大数据平台的部署、监控和运维技能。

### 1. 容器化部署（1周）

**核心知识点：**
- Docker基础
- Kubernetes概念
- Flink on K8s
- Spark on K8s

**学习资源：**
- [Flink On Native K8s实践](bigdata/engine/flink/devops/Flink%20On%20Native%20K8s.md)
- [Flink On K8s Operator](bigdata/engine/flink/devops/Flink%20On%20K8s%20Operator.md)
- [openshift基础命令](devops/k8s-openshift客户端命令使用.md)

**实践任务：**
- 部署K8s集群
- 运行Flink Application
- 配置HPA自动扩缩容

---

### 2. 监控告警（1周）

**核心知识点：**
- Prometheus架构
- Grafana可视化
- Flink指标监控
- Kafka监控

**学习资源：**
- [Prometheus实战](servicemonitor/Prometheus/Prometheus实战.md)
- [搭建Flink任务指标监控系统](bigdata/engine/flink/monitor/搭建Flink任务指标监控系统.md)
- [Kafka监控](bigdata/mq/kafka/Kafka监控.md)

**实践任务：**
- 部署Prometheus + Grafana
- 配置Flink监控面板
- 设置告警规则

---

## 阶段八：架构设计与进阶（持续）

### 目标
具备大数据架构设计能力，能够解决复杂业务问题。

### 学习方向

#### 1. 源码阅读

**建议顺序：**
1. Flink Checkpoint机制
2. Flink SQL执行流程
3. Kafka Producer/Consumer
4. Spark Shuffle

**学习资源：**
- [Flink内核源码分析](bigdata/engine/flink/sourcecode/Flink内核源码分析.md)
- [Flink内幕解析](bigdata/engine/flink/sourcecode/Flink内幕解析.md)

---

#### 2. 性能调优

**调优维度：**
- 资源调优
- 并行度调优
- 数据倾斜处理
- 序列化优化
- 内存管理

**学习资源：**
- [Flink Runtime核心机制浅入深出](bigdata/engine/flink/practice/Flink%20Runtime核心机制浅入深出.md)
- [Hive调优指南](bigdata/olap/hive/Hive调优指南.xmind)

---

#### 3. 架构设计

**典型场景：**
- 实时用户画像
- 推荐系统特征工程
- 风控系统
- IoT数据处理

**学习资源：**
- [数据中台设计](datawarehouse/数据中台模块设计/数据中台设计.md)

---

#### 4. 新技术跟踪

**关注方向：**
- Flink新版本特性
- 数据湖新进展
- Cloud Native大数据
- AI与大数据融合

**学习资源：**
- [Flink1.14新特性](bigdata/engine/flink/feature/Flink1.14新特性.md)

---

## 学习方法论

### 1. 理论学习

- **阅读官方文档**：第一手资料最准确
- **读书笔记**：系统化整理知识
- **技术博客**：了解最佳实践

### 2. 实践操作

- **搭建实验环境**：本地或云服务器
- **动手编码**：不要只看不练
- **复现问题**：从错误中学习

### 3. 知识输出

- **写技术博客**：费曼学习法
- **分享交流**：参加技术社区
- **制作思维导图**：梳理知识体系

### 4. 持续迭代

- **定期复习**：遗忘曲线
- **跟进新技术**：保持敏感度
- **项目实战**：学以致用

---

## 学习资源汇总

### 书籍推荐

1. **Flink**
   - 《Flink内核原理与实现》
   - 《Flink基础教程》

2. **Spark**
   - 《Spark大数据处理》
   - 《Learning Spark》

3. **Kafka**
   - 《Kafka权威指南》
   - 《深入理解Kafka》

4. **数据仓库**
   - 《数据仓库工具箱》
   - 《大数据之路》

### 在线资源

- [在线文档](https://shimin-huang.gitbook.io/doc/)
- 官方文档（Apache官网）
- GitHub开源项目
- 技术社区（知乎、掘金、InfoQ）

---

## 学习计划模板

### 每周学习计划

```markdown
# 第X周学习计划

## 学习目标
- 掌握XXX核心概念
- 完成XXX实践任务

## 周一～周三：理论学习
- [ ] 阅读相关文档（2小时/天）
- [ ] 整理笔记要点

## 周四～周五：实践操作
- [ ] 搭建实验环境
- [ ] 完成示例代码
- [ ] 记录遇到的问题

## 周末：总结复盘
- [ ] 完成自测题目
- [ ] 撰写学习总结
- [ ] 制定下周计划
```

### 每日学习时间分配

```
早上（30分钟）：复习昨日内容
中午（1小时）：理论学习
晚上（2小时）：实践操作
睡前（30分钟）：整理笔记
```

---

## 常见问题FAQ

### Q1: 应该先学Spark还是Flink？

**A:** 建议先学Flink，原因：
- Flink是真正的流处理，理念更先进
- 流批统一是趋势
- Flink社区活跃度高

如果有批处理需求，再学Spark。

---

### Q2: 需要看源码吗？

**A:** 分阶段：
- 初级：不看源码，会用即可
- 中级：看关键流程源码（如Checkpoint）
- 高级：深入源码，理解设计思想

---

### Q3: 如何避免学了就忘？

**A:** 
1. 做笔记，建立知识库
2. 定期复习（1天、3天、7天、30天）
3. 实践项目，学以致用
4. 教别人，费曼学习法

---

### Q4: 学习过程中遇到瓶颈怎么办？

**A:**
1. 暂时跳过，继续往后学
2. 换个角度，看不同资料
3. 请教他人，加入社区
4. 休息调整，劳逸结合

---

## 结语

大数据技术栈庞大且复杂，学习是一个循序渐进的过程。不要急于求成，打好基础最重要。记住：

> **"不积跬步，无以至千里；不积小流，无以成江海。"**

坚持每天进步一点点，你一定能成为大数据专家！

**加油！💪**
