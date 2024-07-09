# Flink OLAP

> OLAP（OnLine Analysis Processing）是数据分析领域的一项关键技术，通常被用来对较大的数据集进行秒级的复杂查询分析。Flink
> 作为一款流批一体的计算引擎，现在也同样支持用户将其作为一个 OLAP 计算服务来部署。

## 架构介绍
### 架构
Flink OLAP服务整体由3个部分组成，包括：客户端，Flink SQL Gateway和Flink Session Cluster
* **客户端**: 可以是任何可以和 Flink SQL Gateway 交互的客户端，包括：SQL Client，Flink JDBC Driver 等等； 
* **Flink SQL Gateway**: Flink SQL Gateway 服务主要用作 SQL 解析、元数据获取、统计信息分析、Plan 优化和集群作业提交； 
* **Flink Session Cluster**: OLAP 查询建议运行在 Session 集群上，主要是可以减少集群启动时的额外开销；

![](../img/olap-architecture.svg)

### 优势

- 并行计算架构
  - Flink 是天然的并行计算架构，执行 OLAP 查询时可以方便的通过调整并发来满足不同数据规模下的低延迟查询性能要求
- 弹性资源管理
  - Flink 的集群资源具有良好的 Min、Max 扩缩容能力，可以根据集群负载动态调整所使用的资源
- 生态丰富
  - Flink OLAP 可以复用 Flink 生态中丰富的 [连接器](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/connectors/table/overview/)
- 统一引擎
  - 支持流 / 批 / OLAP 的统一计算引擎

## 本地运行

### 下载 Flink

* 这里的方法和[本地安装](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/try-flink/local_installation/)中记录的步骤类似。Flink 可以运行在任何类 UNIX 的操作系统下面, 例如：Linux, Mac OS X 和 Cygwin (for Windows)。你需要在本地安装好 **Java 11**，可以通过下述命令行的方式检查安装好的 Java 版本：

```shell
java -version
```

* 下一步, [下载](https://flink.apache.org/downloads/) Flink 最新的二进制包并进行解压：

```shell
tar -xzf flink-*.tgz
```

### 启动本地集群

* 运行下述脚本，即可在本地启动集群：

```shell
./bin/start-cluster.sh
```

* 用户可以导航到本地的 Web UI（http://localhost:8081）来查看 Flink Dashboard 并检查集群是否已拉起和正在运行。

### 启动 SQL Client 

* 用户可以通过运行下述命令，用命令行启动内嵌了 Gateway 的 SQL Client：

```shell
./bin/sql-client.sh
```

### 运行 SQL 查询

* 通过命令行，用户可以方便的提交查询并获取结果：

```sql
SET 'sql-client.execution.result-mode' = 'tableau';

CREATE TABLE Orders (
    order_number BIGINT,
    price        DECIMAL(32,2),
    buyer        ROW<first_name STRING, last_name STRING>,
    order_time   TIMESTAMP(3)
) WITH (
  'connector' = 'datagen',
  'number-of-rows' = '100000'
);

SELECT buyer, SUM(price) AS total_cost
FROM Orders
GROUP BY  buyer
ORDER BY  total_cost LIMIT 3;
```

* 具体的作业运行信息你可以通过访问本地的 Web UI（http://localhost:8081）来获取。

## 生产环境部署

### 客户端

#### Flink JDBC Driver

* Flink JDBC Driver 提供了底层的连接管理能力，**方便用户使用并向 SQL Gateway 提交查询请求**。在实际的生产使用中，用户需要注意**如何复用 JDBC 连接，来避免 Gateway 频繁的执行 Session 相关的创建及关闭操作，从而减少端到端的作业耗时**。详细信息可以参考文档 [Flink JDBC Driver]({{ <ref “docs/dev/table/jdbcDriver”> }})。

### 集群部署

* 在生产环境中，建议**使用 Flink Session 集群、Flink SQL Gateway 来搭建 OLAP 服务**。

#### Session Cluster

* Flink Session 集群**建议搭建在 Native Kubernetes 环境下，使用 Session 模式运行**。K8S 作为一个流行的容器编排系统可以自动化的支持不同计算程序的部署、扩展和管理。通过将集群部署在 Native Kubernetes 上，Flink Session 集群**支持动态的增减 TaskManagers**。详细信息可以参考 [Native Kubernetes](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/resource-providers/native_kubernetes/)。同时，你可以在 Session 集群中配置 [slotmanager.number-of-slots.min](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#slotmanager-number-of-slots-min)，这个可以帮助你显著减少 OLAP 查询执行的冷启动时间。

#### Flink SQL Gateway

* 对于 Flink SQL Gateway，用户可以将其部署为无状态的微服务并注册到服务发现的组件上来对外提供服务，方便客户端可以进行负载均衡。详细信息可以参考 [SQL Gateway Overview](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/sql-gateway/overview/)。

### 数据源配置 

#### Catalogs 

* 在 OLAP 场景下，集群建议配置 [Catalogs](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/catalogs/) 中提供的 FileCatalogStore 作为 Catalog 选项。作为一个常驻服务，Flink OLAP 集群的元信息通常不会频繁变更而且需要支持跨 Session 的复用，这样可以减少元信息加载的冷启动时间。详细信息可以参考文档 [Catalog Store](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/catalogs/#catalog-store)。

#### 连接器 

* Session Cluster 和 SQL Gateway 都依赖连接器来获取表的元信息同时从配置好的数据源读取数据，详细信息可以参考文档 [连接器](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/connectors/table/overview/)。

### 推荐参数配置 

* 对于 OLAP 场景，合理的参数配置可以帮助用户较大的提升服务总体的可用性和查询性能，下面列了一些生产环境建议的参数配置。

#### SQL&Table 参数 

| 参数名称                                                     | 默认值 | 推荐值 |
| :----------------------------------------------------------- | :----- | :----- |
| [table.optimizer.join-reorder-enabled](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/config/#table-optimizer-join-reorder-enabled) | false  | true   |
| [pipeline.object-reuse](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#pipeline-object-reuse) | false  | true   |
| [sql-gateway.session.plan-cache.enabled](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/sql-gateway/overview/#sql-gateway-session-plan-cache-enabled) | false  | true   |

#### Runtime 参数 

| 参数名称                                                     | 默认值                 | 推荐值                                                       |
| :----------------------------------------------------------- | :--------------------- | :----------------------------------------------------------- |
| [execution.runtime-mode](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#execution-runtime-mode) | STREAMING              | BATCH                                                        |
| [execution.batch-shuffle-mode](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#execution-batch-shuffle-mode) | ALL_EXCHANGES_BLOCKING | ALL_EXCHANGES_PIPELINED                                      |
| [env.java.opts.all](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#env-java-opts-all) | {default value}        | {default value} -XX:PerMethodRecompilationCutoff=10000 -XX:PerBytecodeRecompilationCutoff=10000-XX:ReservedCodeCacheSize=512M -XX:+UseZGC |
| JDK Version                                                  | 11                     | 17                                                           |

推荐在 OLAP 生产环境中使用 JDK17 和 ZGC，ZGC 可以优化 Metaspace 区垃圾回收的问题，详见 [FLINK-32746](https://issues.apache.org/jira/browse/FLINK-32746)。同时 ZGC 在堆内内存垃圾回收时可以提供接近0毫秒的应用程序暂停时间。OLAP 查询在执行时需要使用批模式，因为 OLAP 查询的执行计划中可能同时出现 Pipelined 和 Blocking 属性的边。批模式下的调度器支持对作业分阶段调度，可以避免出现调度死锁问题。

#### Scheduling 参数

| 参数名称                                                     | 默认值            | 推荐值  |
| :----------------------------------------------------------- | :---------------- | :------ |
| [jobmanager.scheduler](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#jobmanager-scheduler) | Default           | Default |
| [jobmanager.execution.failover-strategy](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#jobmanager-execution-failover-strategy-1) | region            | full    |
| [restart-strategy.type](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#restart-strategy-type) | (none)            | disable |
| [jobstore.type](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#jobstore-type) | File              | Memory  |
| [jobstore.max-capacity](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#jobstore-max-capacity) | Integer.MAX_VALUE | 500     |

#### 网络参数 

| 参数名称                                                     | 默认值    | 推荐值     |
| :----------------------------------------------------------- | :-------- | :--------- |
| [rest.server.numThreads](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#rest-server-numthreads) | 4         | 32         |
| [web.refresh-interval](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#web-refresh-interval) | 3000      | 300000     |
| [pekko.framesize](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#pekko-framesize) | 10485760b | 104857600b |

#### 资源管理参数 

| 参数名称                                                     | 默认值 | 推荐值                                  |
| :----------------------------------------------------------- | :----- | :-------------------------------------- |
| [kubernetes.jobmanager.replicas](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#kubernetes-jobmanager-replicas) | 1      | 2                                       |
| [kubernetes.jobmanager.cpu.amount](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#kubernetes-jobmanager-cpu-amount) | 1.0    | 16.0                                    |
| [jobmanager.memory.process.size](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#jobmanager-memory-process-size) | (none) | 32g                                     |
| [jobmanager.memory.jvm-overhead.max](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#jobmanager-memory-jvm-overhead-max) | 1g     | 3g                                      |
| [kubernetes.taskmanager.cpu.amount](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#kubernetes-taskmanager-cpu-amount) | (none) | 16                                      |
| [taskmanager.numberOfTaskSlots](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#taskmanager-numberoftaskslots) | 1      | 32                                      |
| [taskmanager.memory.process.size](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#taskmanager-memory-process-size) | (none) | 65536m                                  |
| [taskmanager.memory.managed.size](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#taskmanager-memory-managed-size) | (none) | 16384m                                  |
| [slotmanager.number-of-slots.min](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/deployment/config/#slotmanager-number-of-slots-min) | 0      | {taskManagerNumber * numberOfTaskSlots} |

用户可以根据实际的生产情况把 `slotmanager.number-of-slots.min` 配置为一个合理值，并将其用作集群的预留资源池从而支持 OLAP 查询。在 OLAP 场景下，TaskManager 建议配置为较大的资源规格，因为这样可以把更多的计算放到本地从而减少网络 / 序列化 / 反序列化的开销。JobManager 因为是 OLAP 场景下的计算单点，也建议使用较大的资源规格。