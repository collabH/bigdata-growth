#  概览

## 基本程序结构

![](../img/blinkcalctie.jpg)

* Flink SQL基于Calcite实现，Calcite将SQL转换成关系代数或则通过Calcite提供的API直接创建它。
* Table API和SQL的程序结构，与流式处理的程序结构十分类似

```java
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode()
                .useBlinkPlanner()
                .build();
StreamTableEnvironment tableEnvironment = StreamTableEnvironment.create(env,settings);
tableEnvironment.createTemporaryView();
Table table=tableEnvironment.from("tableName").select($("id"));
table.executeInsert()
```

## 创建TableEnvironment

* `TableEnvironment` 是 Table API 和 SQL 的核心概念。它负责:
  - 在内部的 catalog 中注册 `Table`
  - 注册外部的 catalog
  - 加载可插拔模块
  - 执行 SQL 查询
  - 注册自定义函数 （scalar、table 或 aggregation）
  - `DataStream` 和 `Table` 之间的转换(面向 `StreamTableEnvironment` )
* `Table` 总是与特定的 `TableEnvironment` 绑定。 不能在同一条查询中使用不同 TableEnvironment 中的表，例如，对它们进行 join 或 union 操作。 `TableEnvironment` 可以通过静态方法 `TableEnvironment.create()` 创建。

```java
          EnvironmentSettings settings = EnvironmentSettings
              .newInstance()
              .inStreamingMode()
              //.inBatchMode()
              .build();

          TableEnvironment tEnv = TableEnvironment.create(settings);
```

* 或者，用户可以从现有的 `StreamExecutionEnvironment` 创建一个 `StreamTableEnvironment` 与 `DataStream` API 互操作。

```java
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;

StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
StreamTableEnvironment tEnv = StreamTableEnvironment.create(env);
```

## 在Catalog中创建表

* `TableEnvironment` 维护着一个由标识符（identifier）创建的表 catalog 的映射。标识符由三个部分组成：catalog 名称、数据库名称以及对象名称。如果 catalog 或者数据库没有指明，就会使用当前默认值:"default_catalog"、"default_database"
* `Table` 可以是虚拟的（视图 `VIEWS`）也可以是常规的（表 `TABLES`）。视图 `VIEWS`可以从已经存在的`Table`中创建，一般是 Table API 或者 SQL 的查询结果。 表`TABLES`描述的是外部数据，例如文件、数据库表或者消息队列。

### 临时表（Temporary Table）和永久表（Permanent Table）

* 表可以是临时的，**并与单个 Flink 会话（session）的生命周期相关**，也可以是永久的，**并且在多个 Flink 会话和群集（cluster）中可见**。
* 永久表需要 [catalog](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/catalogs/)（例如 Hive Metastore）以维护表的元数据。**一旦永久表被创建，它将对任何连接到 catalog 的 Flink 会话可见且持续存在，直至被明确删除**。
* 临时表通常**保存于内存中并且仅在创建它们的 Flink 会话持续期间存在**。这些表对于其它会话是不可见的。它们不与任何 catalog 或者数据库绑定但可以在一个命名空间（namespace）中创建。即使它们对应的数据库被删除，临时表也不会被删除。

#### 屏蔽

* 可以使用与已存在的永久表相同的标识符去注册临时表。**临时表会屏蔽永久表，并且只要临时表存在，永久表就无法访问**。
* 这可能对实验（experimentation）有用。它允许先对一个临时表进行完全相同的查询，例如只有一个子集的数据，或者数据是不确定的。一旦验证了查询的正确性，就可以对实际的生产表进行查询。

### 创建表

#### 创建临时表

```java
// 创建 table 执行环境
TableEnvironment tableEnv = ...;

// 读取X表的xx字段
Table projTable = tableEnv.from("X").select(...);

// 注册X表的结果projTable为临时表projectedTable
tableEnv.createTemporaryView("projectedTable", projTable);
```

**注意：** 从传统数据库系统的角度来看，`Table` 对象与 `VIEW` 视图非常像。也就是，定义了 `Table` 的查询是没有被优化的， 而且会被内嵌到另一个引用了这个注册了的 `Table`的查询中。如果多个查询都引用了同一个注册了的`Table`，那么它会被内嵌每个查询中并被执行多次， 也就是说注册了的`Table`的结果**不会**被共享。

#### 通过Connector Tables

* Connector 描述了存储表数据的外部系统。存储系统例如 Apache Kafka 或者常规的文件系统都可以通过这种方式来声明。

```java
// 使用TableDescriptor定义datagen Connector表
final TableDescriptor sourceDescriptor = TableDescriptor.forConnector("datagen")
    .schema(Schema.newBuilder()
    .column("f0", DataTypes.STRING())
    .build())
    .option(DataGenConnectorOptions.ROWS_PER_SECOND, 100L)
    .build();

// 创建表
tableEnv.createTable("SourceTableA", sourceDescriptor);
tableEnv.createTemporaryTable("SourceTableB", sourceDescriptor);

// 使用DDL创建Connector表
tableEnv.executeSql("CREATE [TEMPORARY] TABLE MyTable (...) WITH (...)");
```

### 扩展表标识符

* 表通过三元标识符注册，包括 catalog 名、数据库名和表名。用户可以指定一个catalog和database作为当前catalog和database，后续读表只需要关注其下的表名即可。如果前两部分的标识符没有指定， 那么会使用当前的 catalog 和当前数据库。

```java
// 设置当前catalog和database
TableEnvironment tEnv = ...;
tEnv.useCatalog("custom_catalog");
tEnv.useDatabase("custom_database");

Table table = ...;


// custom_catalog的custom_database下注册exampleView临时表
tableEnv.createTemporaryView("exampleView", table);

// 在custom_catalog的other_database下注册exampleView临时表
tableEnv.createTemporaryView("other_database.exampleView", table);

// custom_catalog的custom_database下注册example.View临时表
tableEnv.createTemporaryView("`example.View`", table);

// 在other_catalog的other_database下注册exampleView临时表
tableEnv.createTemporaryView("other_catalog.other_database.exampleView", table);
```

## 查询表

* Table API

```java
// scan registered Orders table
Table orders = tableEnv.from("Orders");
// compute revenue for all customers from France
Table revenue = orders
  .filter($("cCountry").isEqual("FRANCE"))
  .groupBy($("cID"), $("cName"))
  .select($("cID"), $("cName"), $("revenue").sum().as("revSum"));
```

* SQL

```java
// 查询表
Table revenue = tableEnv.sqlQuery(
    "SELECT cID, cName, SUM(revenue) AS revSum " +
    "FROM Orders " +
    "WHERE cCountry = 'FRANCE' " +
    "GROUP BY cID, cName"
  );
// 插入数据
tableEnv.executeSql(
    "INSERT INTO RevenueFrance " +
    "SELECT cID, cName, SUM(revenue) AS revSum " +
    "FROM Orders " +
    "WHERE cCountry = 'FRANCE' " +
    "GROUP BY cID, cName"
  );
```

* Flink也支持Table API和SQL混用
  * 可以在 SQL 查询返回的 `Table` 对象上定义 Table API 查询。
  * 在 `TableEnvironment` 中注册的[结果表](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/common/#register-a-table)可以在 SQL 查询的 `FROM` 子句中引用，通过这种方法就可以在 Table API 查询的结果上定义 SQL 查询。

## 输出表

* `Table` 通过写入 `TableSink` 输出。`TableSink` 是一个通用接口，用于支持多种文件格式（如 CSV、Apache Parquet、Apache Avro）、存储系统（如 JDBC、Apache HBase、Apache Cassandra、Elasticsearch）或消息队列系统（如 Apache Kafka、RabbitMQ）。
* 批处理 `Table` 只能写入 `BatchTableSink`，而流处理 `Table` 需要指定写入 `AppendStreamTableSink`，`RetractStreamTableSink` 或者 `UpsertStreamTableSink`。
* `Table.insertInto(String tableName)` 定义了一个完整的端到端管道将源表中的数据传输到一个被注册的输出表中。 该方法通过名称在 catalog 中查找输出表并确认 `Table` schema 和输出表 schema 一致。 可以通过方法 `TablePipeline.explain()` 和 `TablePipeline.execute()` 分别来解释和执行一个数据流管道。

```java
// 定义schema
final Schema schema = Schema.newBuilder()
    .column("a", DataTypes.INT())
    .column("b", DataTypes.STRING())
    .column("c", DataTypes.BIGINT())
    .build();

// 创建csv格式的table sink
tableEnv.createTemporaryTable("CsvSinkTable", TableDescriptor.forConnector("filesystem")
    .schema(schema)
    .option("path", "/path/to/file")
    .format(FormatDescriptor.forFormat("csv")
        .option("field-delimiter", "|")
        .build())
    .build());

// 输入结果表
Table result = ...;

// 结果表写csv table sink
TablePipeline pipeline = result.insertInto("CsvSinkTable");

// 打印执行计划
pipeline.printExplain();

// 执行etl任务
pipeline.execute();
```

## explain与execute

* 不论输入数据源是流式的还是批式的，Table API 和 SQL 查询都会被转换成 [DataStream](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/datastream/overview/) 程序。 查询在内部表示为逻辑查询计划，并被翻译成两个阶段：
  * 优化逻辑执行计划
  * 翻译成 DataStream程序

* Table API 或者 SQL 查询在下列情况下会被翻译：

  - 当 `TableEnvironment.executeSql()` 被调用时。该方法是用来执行一个 SQL 语句，一旦该方法被调用， SQL 语句立即被翻译。

  - 当 `TablePipeline.execute()` 被调用时。该方法是用来执行一个源表到输出表的数据流，一旦该方法被调用， TABLE API 程序立即被翻译。

  - 当 `Table.execute()` 被调用时。该方法是用来将一个表的内容收集到本地，一旦该方法被调用， TABLE API 程序立即被翻译。

  - 当 `StatementSet.execute()` 被调用时。`TablePipeline` （通过 `StatementSet.add()` 输出给某个 `Sink`）和 INSERT 语句 （通过调用 `StatementSet.addInsertSql()`）会先被缓存到 `StatementSet` 中，`StatementSet.execute()` 方法被调用时，所有的 sink 会被优化成一张有向无环图。

  - 当 `Table` 被转换成 `DataStream` 时。转换完成后，它就成为一个普通的 DataStream 程序，并会在调用 `StreamExecutionEnvironment.execute()` 时被执行。

## 查询优化

* Apache Flink **使用并扩展了 Apache Calcite 来执行复杂的查询优化**。 这包括一系列基于规则和成本的优化，例如：

  - 基于 Apache Calcite 的子查询解相关

  - 投影剪裁 （Projection）

  - 分区剪裁

  - 过滤器下推 （PushDown）

  - 子计划消除重复数据以避免重复计算

  - 特殊子查询重写，包括两部分：
    - 将 IN 和 EXISTS 转换为 left semi-joins
    - 将 NOT IN 和 NOT EXISTS 转换为 left anti-join

  - 可选 join 重新排序
    - 通过 `table.optimizer.join-reorder-enabled` 启用

**注意：** 当前仅在子查询重写的结合条件下支持 IN / EXISTS / NOT IN / NOT EXISTS。

* 优化器不仅基于计划，而且还基于可从数据源获得的丰富统计信息以及每个算子（例如 io，cpu，网络和内存）的细粒度成本来做出明智的决策。
* 高级用户可以通过 `CalciteConfig` 对象提供自定义优化，可以通过调用 `TableEnvironment＃getConfig＃setPlannerConfig` 将其提供给 TableEnvironment。

## 查看执行计划

* Table API可以通过`Table.explain()` 方法或者 `StatementSet.explain()` 方法来查看对应的执行计划，`Table.explain()` 返回一个 Table 的计划。`StatementSet.explain()` 返回多 sink 计划的结果。它返回一个描述三种计划的字符串：
  * 关系查询的抽象语法树（the Abstract Syntax Tree），即未优化的逻辑查询计划，
  * 优化的逻辑查询计划，以及
  * 物理执行计划。

```java
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
StreamTableEnvironment tEnv = StreamTableEnvironment.create(env);

DataStream<Tuple2<Integer, String>> stream1 = env.fromElements(new Tuple2<>(1, "hello"));
DataStream<Tuple2<Integer, String>> stream2 = env.fromElements(new Tuple2<>(1, "hello"));

// explain Table API
Table table1 = tEnv.fromDataStream(stream1, $("count"), $("word"));
Table table2 = tEnv.fromDataStream(stream2, $("count"), $("word"));
Table table = table1
  .where($("word").like("F%"))
  .unionAll(table2);

System.out.println(table.explain());

// Explain执行计划
== Abstract Syntax Tree ==
LogicalUnion(all=[true])
:- LogicalFilter(condition=[LIKE($1, _UTF-16LE'F%')])
:  +- LogicalTableScan(table=[[Unregistered_DataStream_1]])
+- LogicalTableScan(table=[[Unregistered_DataStream_2]])

== Optimized Physical Plan ==
Union(all=[true], union=[count, word])
:- Calc(select=[count, word], where=[LIKE(word, _UTF-16LE'F%')])
:  +- DataStreamScan(table=[[Unregistered_DataStream_1]], fields=[count, word])
+- DataStreamScan(table=[[Unregistered_DataStream_2]], fields=[count, word])

== Optimized Execution Plan ==
Union(all=[true], union=[count, word])
:- Calc(select=[count, word], where=[LIKE(word, _UTF-16LE'F%')])
:  +- DataStreamScan(table=[[Unregistered_DataStream_1]], fields=[count, word])
+- DataStreamScan(table=[[Unregistered_DataStream_2]], fields=[count, word])
```

## DataStream API整合

### Table和Datastream转换

#### 依赖

```xml
<dependency>
  <groupId>org.apache.flink</groupId>
  <artifactId>flink-table-api-java-bridge_2.12</artifactId>
  <version>1.19.0</version>
  <scope>provided</scope>
</dependency>
```

#### import

```java
// imports for Java DataStream API
import org.apache.flink.streaming.api.*;
import org.apache.flink.streaming.api.environment.*;

// imports for Table API with bridging to Java DataStream API
import org.apache.flink.table.api.*;
import org.apache.flink.table.api.bridge.java.*;
```

#### append-only和insert-only的stream-to-table

```java
// create environments of both APIs
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);

// create a DataStream
DataStream<String> dataStream = env.fromElements("Alice", "Bob", "John");

// interpret the insert-only DataStream as a Table
Table inputTable = tableEnv.fromDataStream(dataStream);

// register the Table object as a view and query it
tableEnv.createTemporaryView("InputTable", inputTable);
Table resultTable = tableEnv.sqlQuery("SELECT UPPER(f0) FROM InputTable");

// interpret the insert-only Table as a DataStream again
DataStream<Row> resultStream = tableEnv.toDataStream(resultTable);

// add a printing sink and execute in DataStream API
resultStream.print();
env.execute();

// prints:
// +I[ALICE]
// +I[BOB]
// +I[JOHN]
```

#### changlog的stream-to-table

```java
// create environments of both APIs
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);

// create a DataStream
DataStream<Row> dataStream = env.fromElements(
    Row.of("Alice", 12),
    Row.of("Bob", 10),
    Row.of("Alice", 100));

// interpret the insert-only DataStream as a Table
Table inputTable = tableEnv.fromDataStream(dataStream).as("name", "score");

// register the Table object as a view and query it
// the query contains an aggregation that produces updates
tableEnv.createTemporaryView("InputTable", inputTable);
Table resultTable = tableEnv.sqlQuery(
    "SELECT name, SUM(score) FROM InputTable GROUP BY name");

// interpret the updating Table as a changelog DataStream
DataStream<Row> resultStream = tableEnv.toChangelogStream(resultTable);

// add a printing sink and execute in DataStream API
resultStream.print();
env.execute();

// prints:
// +I[Alice, 12]
// +I[Bob, 10]
// -U[Alice, 12]
// +U[Alice, 112]
```

# 流式概念

## 流式概念

* Flink的Table API和SQL是流批一体API，这就表示Table API&SQL在无论有限的批式输入还是无限的流式输入下，都具有相同的语义。

### 状态管理

* 流模式下运行的表利用Flink作为有状态处理器的所有能力，一个表程序可以配置一个state backend和多个不同的checkpoint配置以处理对不同状态大小和容错需求，这可以对正在运行的Table API&SQL管道生产Savepoint，并在之后恢复应用程序的状态。

#### 状态使用

* 由于 Table API & SQL 程序是声明式的，管道内的状态会在哪以及如何被使用并不明确。 Planner 会确认是否需要状态来得到正确的计算结果， 管道会被现有优化规则集优化成尽可能少地使用状态。

##### **状态算子**

* 包含join、聚合或去重等操作的SQL语句都需要在Flink中保存状态结果
  * 例如对两个表进行join操作的普调SQL需要算子保存两个表的全部输入，基于正确的SQL语义，运行时假设两表会在任意时间点进行匹配。Flink提供了优化窗口和internval join聚合来利用watermarks概念来保持较小的状态存储。
  * 聚合方式计算词频，案例如下：`word` 是用于分组的键，连续查询（Continuous Query）维护了每个观察到的 `word` 次数。 输入 `word` 的值随时间变化。由于这个查询一直持续，Flink 会为每个 `word` 维护一个中间状态来保存当前词频，因此总状态量会随着 `word` 的发现不断地增长。![](../img/wordGroupState.jpg)

```sql
CREATE TABLE doc (
    word STRING
) WITH (
    'connector' = '...'
);
CREATE TABLE word_cnt (
    word STRING PRIMARY KEY NOT ENFORCED,
    cnt  BIGINT
) WITH (
    'connector' = '...'
);

INSERT INTO word_cnt
SELECT word, COUNT(1) AS cnt
FROM doc
GROUP BY word;
```

* 例如`SELECT .... FROM .... WHERE`这种场景的源表的消息类型只包含 *INSERT*，*UPDATE_AFTER* 和 *DELETE*，然而下游要求完整的 changelog（包含 *UPDATE_BEFORE*）。 所以虽然查询本身没有包含状态计算，但是优化器依然隐式地推导出了一个 ChangelogNormalize 状态算子来生成完整的 changelog。

##### 状态空闲维持时间

* 通过`table.exec.state.ttl`来定义状态的键在被更新后要保持多长时间才被移除。例如上述案例word的数目会在配置的时间内未更新时立刻被移除。通过移除状态的键，连续查询会完全忘记历史的键，如果一个状态带有历史被移除状态的键，这条记录将被认为是对应键的第一条记录，例如上述统计词频的cnt将被设置为0开始重新计数；

##### 指定状态TTL的不同方式

| 配置方式                           | TableAPI/SQL 支持    | 生效范围                                                     | 优先级                                                       |
| :--------------------------------- | :------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| SET 'table.exec.state.ttl' = '...' | **TableAPI** **SQL** | 作业粒度，默认情况下所有状态算子都会使用该值控制状态生命周期 | 默认配置，可被覆盖                                           |
| SELECT /*+ STATE_TTL(...) */ ...   | **SQL**              | 有限算子粒度，当前支持连接和分组聚合算子                     | 该值将会优先作用于相应算子的状态生命周期。查阅[状态生命周期提示](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/sql/queries/hints/#状态生命周期提示)获取更多信息。 |
| 修改序列化为 JSON 的 CompiledPlan  | **TableAPI** **SQL** | 通用算子粒度, 可修改任一状态算子的生命周期                   | table.exec.state.ttl 和 STATE_TTL 的值将会序列化到 CompiledPlan，如果作业使用 CompiledPlan 提交，则最终生效的生命周期由最后一次修改的状态元数据决定。 |

##### 配置算子状态粒度的TTL

* 从 Flink v1.18 开始，Table API & SQL 支持配置细粒度的状态 TTL 来优化状态使用，可配置粒度为每个状态算子的入边数。具体而言，`OneInputStreamOperator` 可以配置一个状态的 TTL，而 `TwoInputStreamOperator`（例如双流 join）则可以分别为左状态和右状态配置 TTL。更一般地，对于具有 K 个输入的 `MultipleInputStreamOperator`，可以配置 K 个状态 TTL。

  - 为 [双流 Join](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/sql/queries/joins/#regular-joins) 的左右流配置不同 TTL。 双流 Join 会生成拥有两条输入边的 `TwoInputStreamOperator` 的状态算子，它用到了两个状态，分别来保存来自左流和右流的更新。

  - 在同一个作业中为不同的状态计算设置不同 TTL。 举例来说，假设一个 ETL 作业使用 `ROW_NUMBER` 进行[去重](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/sql/queries/deduplication/)操作后， 紧接着使用 `GROUP BY` 语句进行[聚合](https://nightlies.apache.org/flink/flink-docs-release-1.19/zh/docs/dev/table/sql/queries/group-agg/)操作。 该作业会分别生成两个拥有单条输入边的 `OneInputStreamOperator` 状态算子。您可以为去重算子和聚合算子的状态分别设置不同的 TTL。

**生成Compiled Plan**

> COMPILE PLAN不支持查询语句SELECT....FROM...

* 指定`COMPILE PLAN`语句

```java
TableEnvironment tableEnv = TableEnvironment.create(EnvironmentSettings.inStreamingMode());
tableEnv.executeSql(
    "CREATE TABLE orders (order_id BIGINT, order_line_id BIGINT, buyer_id BIGINT, ...)");
tableEnv.executeSql(
    "CREATE TABLE line_orders (order_line_id BIGINT, order_status TINYINT, ...)");
tableEnv.executeSql(
    "CREATE TABLE enriched_orders (order_id BIGINT, order_line_id BIGINT, order_status TINYINT, ...)");

// CompilePlan#writeToFile only supports a local file path, if you need to write to remote filesystem,
// please use tableEnv.executeSql("COMPILE PLAN 'hdfs://path/to/plan.json' FOR ...")
CompiledPlan compiledPlan = 
    tableEnv.compilePlanSql(
        "INSERT INTO enriched_orders \n" 
       + "SELECT a.order_id, a.order_line_id, b.order_status, ... \n" 
       + "FROM orders a JOIN line_orders b ON a.order_line_id = b.order_line_id");

compiledPlan.writeToFile("/path/to/plan.json");
```

* SQL语法,该语句会在指定位置 `/path/to/plan.json` 生成一个 JSON 文件。

```sql
COMPILE PLAN [IF NOT EXISTS] <plan_file_path> FOR <insert_statement>|<statement_set>;

statement_set:
    EXECUTE STATEMENT SET
    BEGIN
    insert_statement;
    ...
    insert_statement;
    END;

insert_statement:
    <insert_from_select>|<insert_from_values>
```

**修改 Compiled Plan**

* 每个状态算子会显式地生成一个名为 “state” 的 JSON 数组，具有如下结构。 理论上一个拥有 k 路输入的状态算子拥有 k 个状态。

```json
"state": [
    {
      "index": 0,
      "ttl": "0 ms",
      "name": "${1st input state name}"
    },
    {
      "index": 1,
      "ttl": "0 ms",
      "name": "${2nd input state name}"
    },
    ...
  ]
```

* 找到您需要修改的状态算子，将 TTL 的值设置为一个正整数，注意需要带上时间单位毫秒。举例来说，如果想将当前状态算子的 TTL 设置为 1 小时，您可以按照如下格式修改 JSON：

```json
{
  "index": 0,
  "ttl": "3600000 ms",
  "name": "${1st input state name}"
}
```

* 保存好文件，然后使用 `EXECUTE PLAN` 语句来提交作业。理论上，**下游状态算子的 TTL 不应小于上游状态算子的 TTL**。

**执行 Compiled Plan**

* `EXECUTE PLAN` 语句将会反序列化上述 JSON 文件，进一步生成 JobGraph 并提交作业。 通过 `EXECUTE PLAN` 语句提交的作业，其状态算子的 TTL 的值将会从文件中读取，配置项 `table.exec.state.ttl` 的值将会被忽略。
* table API

```java
TableEnvironment tableEnv = TableEnvironment.create(EnvironmentSettings.inStreamingMode());
tableEnv.executeSql(
    "CREATE TABLE orders (order_id BIGINT, order_line_id BIGINT, buyer_id BIGINT, ...)");
tableEnv.executeSql(
    "CREATE TABLE line_orders (order_line_id BIGINT, order_status TINYINT, ...)");
tableEnv.executeSql(
    "CREATE TABLE enriched_orders (order_id BIGINT, order_line_id BIGINT, order_status TINYINT, ...)");

// PlanReference#fromFile only supports a local file path, if you need to read from remote filesystem,
// please use tableEnv.executeSql("EXECUTE PLAN 'hdfs://path/to/plan.json'").await();
tableEnv.loadPlan(PlanReference.fromFile("/path/to/plan.json")).execute().await();
```

* SQL语法

```sql
EXECUTE PLAN [IF EXISTS] <plan_file_path>;
```

## 动态表(Dynamic Tables)

![Dynamic tables](../img/stream-query-stream.png)

* 动态表是Flink对流数据的Table API和SQL支持的核心概念。
* 与表示批处理数据的静态表不同，动态表随时间变化的。

### 持续查询（Continuous Query）

* 动态表可以像静态的批处理表一样进行查询，查询一个动态表产生持续查询(Continuous Query)
* 连续查询永远不会终止，并会生成另一个动态表。
* 查询会不断更新其动态结果表，以反映动态输入表上的更改。

![Continuous Non-Windowed Query](../img/query-groupBy-cnt.png)

### 流式表查询的处理过程

* 将流转换为动态表。
* 在动态表上计算一个连续查询，生成一个新的动态表。
* 生成的动态表被转换回流。

### 表到流的转换

动态表可以像普通数据库表一样通过 `INSERT`、`UPDATE` 和 `DELETE` 来不断修改。它可能是一个只有一行、不断更新的表，也可能是一个 insert-only 的表，没有 `UPDATE` 和 `DELETE` 修改，或者介于两者之间的其他表。

在将动态表转换为流或将其写入外部系统时，需要对这些更改进行编码。Flink的 Table API 和 SQL 支持三种方式来编码一个动态表的变化:

- **Append-only 流：** 仅通过 `INSERT` 操作修改的动态表可以通过输出插入的行转换为流。
- **Retract 流：** retract 流包含两种类型的 message： *add messages* 和 *retract messages* 。通过将`INSERT` 操作编码为 add message、将 `DELETE` 操作编码为 retract message、将 `UPDATE` 操作编码为更新(先前)行的 retract message 和更新(新)行的 add message，将动态表转换为 retract 流。下图显示了将动态表转换为 retract 流的过程。

![Dynamic tables](../img/undo-redo-mode.png)

- **Upsert 流:** upsert 流包含两种类型的 message： *upsert messages* 和*delete messages*。转换为 upsert 流的动态表需要(可能是组合的)唯一键。通过将 `INSERT` 和 `UPDATE` 操作编码为 upsert message，将 `DELETE` 操作编码为 delete message ，将具有唯一键的动态表转换为流。消费流的算子需要知道唯一键的属性，以便正确地应用 message。与 retract 流的主要区别在于 `UPDATE` 操作是用单个 message 编码的，因此效率更高。下图显示了将动态表转换为 upsert 流的过程。

![Dynamic tables](../img/redo-mode.png)

# Flink SQL架构

## Old Planner架构

![](../img/Oldplannerr架构.jpg)

* 存在的问题:虽然面向用户的 Table API & SQL 是统一的，但是流式和批式任务在翻译层分别对应了 DataStreamAPI 和 DataSetAPI，在 Runtime 层面也要根据不同的 API 获取执行计划，两层的设计使得整个架构能够复用的模块有限，不易扩展。

## Blink Planner架构

* Blink Planner将批 SQL 处理作为流 SQL 处理的特例，尽量对通用的处理和优化逻辑进行抽象和复用，通过 Flink 内部的 Stream Transformation API 实现流 & 批的统一处理，替代原 Flink Planner 将流 & 批区分处理的方式。
* 从SQL语句到Operation，再转换为Transformation，最后转换为Execution执行。

![](../img/BlinkPlanner架构.jpg)

### 从SQL到Operation

* Blink ParserImpl#parse将SQL语句生成为Operation树，生成新的Table对象。
  * 1） 解析SQL字符串转换为QueryOperation。2） SQL字符串解析为SqlNode。3）校验SqlNode。4）调用Calcite SQLToRelConverter将SqlNode转换为RelNode逻辑树。5）RelNode转换为Operation。

### Operation到Transformation

* DQL、DML转换，ModifyOperation→RelNode→FlinkPhysicalRel→ExecNode→Transformation。

### Blink优化

#### 优化器

* Blink没有使用Calcite的优化器，而是通过规则组合和Calcite优化器的组合，分为流和批实现了自定义的优化器。

![](../books/Flink内核原理与实现/img/Blink优化器.jpg)

#### 代价计算

* 代价计算通过数据量、CPU资源使用、内存资源使用、IO资源使用和网络资源使用来进行计算。

## Flink SQL工作流

![](../img/FlinkSQL工作流.jpeg)

* 将Flink SQL/Table API程序转换为可执行的JobGraph经历以下阶段
  * 将SQL文本/TableAPI代码转化为逻辑执行计划(Logical Plan)
  * Logical Plan通过优化器优化为物理执行计划(Physical Plan)
  * 通过代码生成技术生成Transformations后进一步编译为可执行的JobGraph提交运行

### Logical Planning

* Flink SQL 引擎使用 Apache Calcite SQL Parser 将 SQL 文本解析为词法树，SQL Validator 获取 Catalog 中元数据的信息进行语法分析和验证，转化为关系代数表达式（RelNode），再由 Optimizer 将关系代数表达式转换为初始状态的逻辑执行计划。

![](../img/LogicalPlan.jpg)

#### Flink SQL优化器优化方式

##### Expression Reduce（Spark类似操作，常数优化）

* 表达式（Expression） 是 SQL 中最常见的语法。比如 t1.id 是一个表达式， 1 + 2 + t1.value 也是一个表达式。优化器在优化过程中会递归遍历树上节点，尽可能预计算出每个表达式的值，这个过程就称为表达式折叠。这种转换在逻辑上等价，通过优化后，真正执行时不再需要为每一条记录都计算一遍 1 + 2。

##### PushDown Optimization(Rule-Based Optimization(RBO))

* 下推优化是指在保持关系代数语义不变的前提下将 SQL 语句中的变换操作尽可能下推到靠近数据源的位置以获得更优的性能，常见的下推优化有谓词下推（Predicate Pushdown），投影下推（Projection Pushdown，有时也译作列裁剪）等。
* Predicate Pushdown（谓词下推）
  * WHERE 条件表达式中 t2.id < 1000 这个过滤条件描述的是对表 t2 的约束，跟表 t1 无关，完全可以下推到 JOIN 操作之前完成。假设表 t2 中有一百万行数据，但是满足 id < 1000 的数据只有 1,000 条，则通过谓词下推优化后到达 JOIN 节点的数据量降低了1,000 倍，极大地节省了 I / O 开销，提升了 JOIN 性能。
  * 谓词下推（Predicate Pushdown）是优化 SQL 查询的一项基本技术，谓词一词来源于数学，指能推导出一个布尔返回值（TRUE / FALSE）的函数或表达式，通过判断布尔值可以进行数据过滤。谓词下推是指保持关系代数语义不变的前提下将 Filter 尽可能移至靠近数据源的位置（比如读取数据的 SCAN 阶段）来降低查询和传递的数据量（记录数）。
* Projection Pushdown（列裁剪）
  * 列裁剪是 Projection Pushdown 更直观的描述方式，指在优化过程中去掉没有使用的列来降低 I / O 开销，提升性能。但与谓词下推只移动节点位置不同，投影下推可能会增加节点个数。比如最后计算出的投影组合应该放在 TableScan 操作之上，而 TableScan 节点之上没有 Projection 节点，优化器就会显式地新增 Projection 节点来完成优化。另外如果输入表是基于列式存储的（如 Parquet 或 ORC 等），优化还会继续下推到 Scan 操作中进行。

### Physical Planning on Batch

* 逻辑执行计划描述了执行步骤和每一步需要完成的操作，但没有描述操作的具体实现方式。而物理执行计划会考虑物理实现的特性，生成每一个操作的具体实现方式。比如 Join 是使用 SortMergeJoin、HashJoin 或 BroadcastHashJoin 等。优化器在生成逻辑执行计划时会计算整棵树上每一个节点的 Cost，对于有多种实现方式的节点（比如 Join 节点），优化器会展开所有可能的 Join 方式分别计算。最终整条路径上 Cost 最小的实现方式就被选中成为 Final Physical Plan。Cost-Based Optimization(CBO)

### Translation&Code Generation

* 从 Physical Plan 到生成 Transformation Tree 过程中就使用了 Code Generation，将各种优化后的物理执行计划动态生成Transformations，最终在转换为StreamGraph-》VerxtGraph-》JobGraph

### Physical Planning on Stream

#### **Retraction Mechanism**（撤回流）

* Retraction 是流式数据处理中撤回过早下发（Early Firing）数据的一种机制，类似于传统数据库的 Update 操作。级联的聚合等复杂 SQL 中如果没有 Retraction 机制，就会导致最终的计算结果与批处理不同，这也是目前业界很多流计算引擎的缺陷。
* Flink SQL 在流计算领域中的一个重大贡献就是首次提出了这个机制的具体实现方案。Retraction 机制又名 Changelog 机制，因为某种程度上 Flink 将输入的流数据看作是数据库的 Changelog，每条输入数据都可以看作是对数据库的一次变更操作，比如 Insert，Delete 或者 Update。以 MySQL 数据库为例，其Binlog 信息以二进制形式存储，其中 Update_rows_log_event 会对应 2 条标记 Before Image （BI） 和 After Image （AI），分别表示某一行在更新前后的信息。
* 在 Flink SQL 优化器生成流作业的 Physical Plan 时会判断当前节点是否是更新操作，如果是则会同时发出 2 条消息 update_before 和 update_after 到下游节点，update_before 表示之前“错误”下发的数据，需要被撤回，update_after 表示当前下发的“正确”数据。下游收到后，会在结果上先减去 update_before，再加上 update_after。
* update_before 是一条非常关键的信息，相当于标记出了导致当前结果不正确的那个“元凶”。不过额外操作会带来额外的开销，有些情况下不需要发送 update_before 也可以获得正确的结果，比如下游节点接的是 UpsertSink（MySQL 或者 HBase的情况下，数据库可以按主键用 update_after 消息覆盖结果）。是否发送 update_before 由优化器决定，用户不需要关心。

####  **Update_before Decision**

1. 确定每个节点对应的changelog变更类型
   * 数据库中最常见的三种操作类型分别是 Insert （记为 [I]），Delete（记为 [D]），Update（记为 [U]）。优化器首先会自底向上检查每个节点，判断它属于哪（几）种类型，分别打上对应标记。
2. **确定每个节点发送的消息类型**
   * 在 Flink 中 Update 由两条 update_before（简称 UB）和 update_after （简称 UA）来表示，其中 UB 消息在某些情况下可以不发送，从而提高性能。
   * 在1 中优化器自底向上推导出了每个节点对应的 Changelog 变更操作，这一步里会先自顶向下推断当前节点需要父节点提供的消息类型，直到遇到第一个不需要父节点提供任何消息类型的节点，再往上回推每个节点最终的实现方式和需要的消息类型。

## Flink SQL内部优化

### 查询优化器

* 查询优化器分为两类：基于规则的优化器(Rule-Base Optimizer,RBO)和基于代价的优化器(Cost-Based Optimizer,CBO);

#### RBO（Rule-Based Optimization）

* RBO根据事先设定好的优化规则对SQL计划树进行转换，降低计算成本。只要SQL语句相同，应用完规则就会得到相同的SQL物理执行计划，也就是说RBO并不考虑数据的规模、数据倾斜等问题，对数据不敏感，导致优化后的执行计划往往并不是最优的。这就要求SQL的使用者了解更多的RBO的规则，使用门槛更高。

#### CBO（Cost-Based Optimization）

* CBO优化器根据事先设定好的优化规则对SQL计划树反复应用规则，SQL语句生成一组可能被使用的执行计划，然后CBO会根据统计信息和代价模型（Cost Model）计算每个执行计划的代价，从中挑选代价最小的执行计划。由上可知，CBO中有两个依赖：统计信息和代价模型。统计信息的准确与否、代价模型的合理与否都会影响CBO选择最优计划。
* 一般情况下，CBO是优于RBO的，原因是RBO是一种只认规则，只针对数据不敏感的过时的优化器。在实际场景中，数据往往是有变化的，通过RBO生成的执行计划很有可能不是最优的。

### BinaryRow

* Flink1.9.x前，Flink Runtime层各算子间传递的数据结构是Row，其内部实现是 Object[]，因此需要维护额外的Object Metadata，计算过程中还涉及到大量序列化/反序列化（特别是只需要处理某几个字段时需要反序列化整个 Row），primitive 类型的拆 / 装箱等，都会带来大量额外的性能开销。 
* Blink Planner使用二进制数据结构的BinaryRow来表示Record。BinaryRow 作用于默认大小为 32K 的 Memory Segment，直接映射到内存。BinaryRow 内部分为 Header，定长区和变长区。Header 用于存储 Retraction 消息的标识，定长区使用 8 个 bytes 来记录字段的 Nullable 信息及所有 primitive 和可以在 8 个 bytes 内表示的类型。其它类型会按照基于起始位置的 offset 存放在变长区。
* 首先存储上更为紧凑，去掉了额外开销；其次在序列化和反序列化上带来的显著性能提升，可根据 offset 只反序列化需要的字段，在开启 Object Reuse 后，序列化可以直接通过内存拷贝完成。

![](../img/BinaryRow.jpg)

### Mini-batch Processing

* 在内存中 buffer 一定量的数据，预先做一次聚合后再更新 State，则不但会降低操作 State 的开销，还会有效减少发送到下游的数据量，提升吞吐量，降低两层聚合时由 Retraction 引起的数据抖动, 这就是 Mini-batch 攒批优化的核心思想。
* 把所有的数据先聚合一次，类似一个微批处理，然后再把这个数据写到 State 里面，或者在从 State 里面查出来，这样可以大大的减轻对 State 查询的压力。
* 通过以下配置设置:

```properties
SET table.exec.mini-batch.enabled=true;
SET table.exec.mini-batch.allow-latency="5 s";
SET table.exec.mini-batch.size=5000;
```



![img](https://mmbiz.qpic.cn/mmbiz_gif/8AsYBicEePu5KNuaibsibpYmAJ1cm1apjUicDic2QTTU5ueDVEBezeervrG84lNVyREu8JpRGUTT2ygZDhKWErnajrQ/640?wx_fmt=gif&tp=webp&wxfrom=5&wx_lazy=1)

### 数据倾斜处理

* 对于数据倾斜的优化，主要分为是否带 DISTINCT 去重语义的两种方式。对于普通聚合的数据倾斜，Flink 引入了 Local-Global 两阶段优化，类似于 MapReduce 增加 Local Combiner 的处理模式。
* 通过以下配置设置:

```properties
# 开启local-global二阶段优化
SET table.optimizer.agg-phase-strategy=TWO_PHASE
```

![img](../img/local_agg.png)

* 而对于带有去重的聚合，Flink 则会将用户的 SQL 按原有聚合的 key 组合再加上 DISTINCT key 做 Hash 取模后改写为两层聚合来进行打散。

```properties
# distinct key
SET table.optimizer.distinct-agg.split.enabled=true
SET table.optimizer.distinct-agg.split.bucket-num=1024，默认1024个bucket
```

![](../img/distinct_split.png)

* distinct key案例

```sql
-- 原始sql
SELECT day, COUNT(DISTINCT user_id)
FROM T
GROUP BY day
-- 开启SET table.optimizer.distinct-agg.split.bucket-num=1024，默认1024个bucket后的sql
SET table.optimizer.distinct-agg.split.enabled=true;
SET table.optimizer.distinct-agg.split.bucket-num=1024;
SELECT day, SUM(cnt)
FROM (
    SELECT day, COUNT(DISTINCT user_id) as cnt
    FROM T
    GROUP BY day, MOD(HASH_CODE(user_id), 1024)
)
GROUP BY day
```

### Top-N重写

```sql
SELECT *
FROM(
  SELECT *, -- you can get like shopId or other information from this
    ROW_NUMBER() OVER (PARTITION BY category ORDER BY sales DESC) AS rowNum
  FROM shop_sales ) 
WHERE rowNum <= 3
```

* 在生成 Plan 方面，ROW_NUMBER 语义对应 OverAggregate 窗口节点和一个过滤行数的 Calc 节点，而这个窗口节点在实现层面需要为每一个到达的数据重新将 State 中的历史数据拿出来排序，这显然不是最优解。
* 我们知道流式场景求解极大 / 小值的最优操作是通过维护一个 size 为 N 的 minHeap / maxHeap。由实现反推出我们需要在优化器上新增一条规则，在遇到 ROW_NUMBER 生成的逻辑节点后，将其优化为一个特殊的 Rank 节点，对应上述的最优实现方式（当然这只是特殊 Rank 对应的其中一种实现）。这便是 Top-N Rewrite 的核心思想。

# Table&SQL API

## Table API类型转换

* WindowTable在1.13后发生改变，对window语法也进行了修改。

![](../img/TableAPi.png)

* Table:Table API核心接口
* GroupedTable:在Table上使用列、表达式(不包含时间窗口)、两者组合进行分组之后的Table，可以理解为对Table进行GroupBy运算。
* GroupWindowedTable:使用格式将窗口分组后的Table，按照时间对数据进行切分，**时间窗口**必须是GroupBy中的第一项，且每个GroupBy只支持一个窗口。
* WindowedGroupTable:GroupWindowdTable和WindowedGroupTable一般组合使用，在GroupWindowedTable上再按照字段进行GroupBy运算后的Table
* AggregatedTable:对分组之后的Table（如GroupedTable和WindowedGroupTable）执行AggregationFunction聚合函数的结果
* FlatAggregateTable:对分组之后的Table（如GroupedTable和WindowedGroupTable）执行TableAggregationFunction（表聚合函数）的结果

## Flink SQL

* DQL：查询语句
* DML：INSERT语句，不包含UPDATE、DELETE语句，后面这两类语句的运算实际上在Flink SQL中也有体现，通过Retract召回实现了流上的UPDATE和DELETE。
* DDL：Create、Drop、Alter语句

### Hints

#### 动态表选项

* 语法

```sql
table_path /*+ OPTIONS(key=val [, key=val]*) */

key:
    stringLiteral
val:
    stringLiteral
```

* 案例

```sql
CREATE TABLE kafka_table1 (id BIGINT, name STRING, age INT) WITH (...);
CREATE TABLE kafka_table2 (id BIGINT, name STRING, age INT) WITH (...);

-- 覆盖查询语句中源表的选项
select id, name from kafka_table1 /*+ OPTIONS('scan.startup.mode'='earliest-offset') */;

-- 覆盖 join 中源表的选项
select * from
    kafka_table1 /*+ OPTIONS('scan.startup.mode'='earliest-offset') */ t1
    join
    kafka_table2 /*+ OPTIONS('scan.startup.mode'='earliest-offset') */ t2
    on t1.id = t2.id;

-- 覆盖插入语句中结果表的选项
insert into kafka_table1 /*+ OPTIONS('sink.partitioner'='round-robin') */ select * from kafka_table2;
```

#### Query Hints

* 语法

```sql
# Query hints:
SELECT /*+ hint [, hint ] */ ...

hint:
        hintName
    |   hintName '(' optionKey '=' optionVal [, optionKey '=' optionVal ]* ')'
    |   hintName '(' hintOption [, hintOption ]* ')'

optionKey:
        simpleIdentifier
    |   stringLiteral

optionVal:
        stringLiteral

hintOption:
        simpleIdentifier
    |   numericLiteral
    |   stringLiteral
```

##### Join Hints

* 联接提示（`Join Hints`）是查询提示（`Query Hints`）的一种，该提示允许用户手动指定表联接（join）时使用的联接策略，来达到优化执行的目的。Flink 联接提示现在支持 `BROADCAST`， `SHUFFLE_HASH`，`SHUFFLE_MERGE` 和 `NEST_LOOP`。

**BROADCAST**

`BROADCAST` 推荐联接使用 `BroadCast` 策略。如果该联接提示生效，不管是否设置了 `table.optimizer.join.broadcast-threshold`， 指定了联接提示的联接端（join side）都会被广播到下游。所以当该联接端是小表时，更推荐使用 `BROADCAST`。

> 注意： BROADCAST 只支持等值的联接条件，且不支持 Full Outer Join。

```sql
CREATE TABLE t1 (id BIGINT, name STRING, age INT) WITH (...);
CREATE TABLE t2 (id BIGINT, name STRING, age INT) WITH (...);
CREATE TABLE t3 (id BIGINT, name STRING, age INT) WITH (...);

-- Flink 会使用 broadcast join，且表 t1 会被当作需 broadcast 的表。
SELECT /*+ BROADCAST(t1) */ * FROM t1 JOIN t2 ON t1.id = t2.id;

-- Flink 会在两个联接中都使用 broadcast join，且 t1 和 t3 会被作为需 broadcast 到下游的表。
SELECT /*+ BROADCAST(t1, t3) */ * FROM t1 JOIN t2 ON t1.id = t2.id JOIN t3 ON t1.id = t3.id;

-- BROADCAST 只支持等值的联接条件
-- 联接提示会失效，只能使用支持非等值条件联接的 nested loop join。
SELECT /*+ BROADCAST(t1) */ * FROM t1 join t2 ON t1.id > t2.id;

-- BROADCAST 不支持 `Full Outer Join`
-- 联接提示会失效，planner 会根据 cost 选择最合适的联接策略。
SELECT /*+ BROADCAST(t1) */ * FROM t1 FULL OUTER JOIN t2 ON t1.id = t2.id;
```

**SHUFFLE_HASH**

`SHUFFLE_HASH` 推荐联接使用 `Shuffle Hash` 策略。如果该联接提示生效，指定了联接提示的联接端将会被作为联接的 build 端。 该提示在被指定的表较小（相较于 `BROADCAST`，小表的数据量更大）时，表现得更好。

> 注意：SHUFFLE_HASH 只支持等值的联接条件。

```sql
CREATE TABLE t1 (id BIGINT, name STRING, age INT) WITH (...);
CREATE TABLE t2 (id BIGINT, name STRING, age INT) WITH (...);
CREATE TABLE t3 (id BIGINT, name STRING, age INT) WITH (...);

-- Flink 会使用 hash join，且 t1 会被作为联接的 build 端。
SELECT /*+ SHUFFLE_HASH(t1) */ * FROM t1 JOIN t2 ON t1.id = t2.id;

-- Flink 会在两个联接中都使用 hash join，且 t1 和 t3 会被作为联接的 build 端。
SELECT /*+ SHUFFLE_HASH(t1, t3) */ * FROM t1 JOIN t2 ON t1.id = t2.id JOIN t3 ON t1.id = t3.id;

-- SHUFFLE_HASH 只支持等值联接条件
-- 联接提示会失效，只能使用支持非等值条件联接的 nested loop join。
SELECT /*+ SHUFFLE_HASH(t1) */ * FROM t1 join t2 ON t1.id > t2.id;
```

**SHUFFLE_MERGE**

`SHUFFLE_MERGE` 推荐联接使用 `Sort Merge` 策略。该联接提示适用于联接两端的表数据量都非常大，或者联接两端的表都有序的场景。

> 注意：SHUFFLE_MERGE 只支持等值的联接条件。

```sql
CREATE TABLE t1 (id BIGINT, name STRING, age INT) WITH (...);
CREATE TABLE t2 (id BIGINT, name STRING, age INT) WITH (...);
CREATE TABLE t3 (id BIGINT, name STRING, age INT) WITH (...);

-- 会使用 sort merge join。
SELECT /*+ SHUFFLE_MERGE(t1) */ * FROM t1 JOIN t2 ON t1.id = t2.id;

-- Sort merge join 会使用在两次不同的联接中。
SELECT /*+ SHUFFLE_MERGE(t1, t3) */ * FROM t1 JOIN t2 ON t1.id = t2.id JOIN t3 ON t1.id = t3.id;

-- SHUFFLE_MERGE 只支持等值的联接条件，
-- 联接提示会失效，只能使用支持非等值条件联接的 nested loop join。
SELECT /*+ SHUFFLE_MERGE(t1) */ * FROM t1 join t2 ON t1.id > t2.id;
```

**NEST_LOOP**

`NEST_LOOP` 推荐联接使用 `Nested Loop` 策略。如无特殊的场景需求，不推荐使用该类型的联接提示。

> 注意：NEST_LOOP 同时支持等值的和非等值的联接条件。

```sql
CREATE TABLE t1 (id BIGINT, name STRING, age INT) WITH (...);
CREATE TABLE t2 (id BIGINT, name STRING, age INT) WITH (...);
CREATE TABLE t3 (id BIGINT, name STRING, age INT) WITH (...);

-- Flink 会使用 nest loop join，且 t1 会被作为联接的 build 端。
SELECT /*+ NEST_LOOP(t1) */ * FROM t1 JOIN t2 ON t1.id = t2.id;

-- Flink 会在两次联接中都使用 nest loop join，且 t1 和 t3 会被作为联接的 build 端。
SELECT /*+ NEST_LOOP(t1, t3) */ * FROM t1 JOIN t2 ON t1.id = t2.id JOIN t3 ON t1.id = t3.id;
```

**LOOKUP**

* 仅支持Streaming模式

LOOKUP 联接提示允许用户建议 Flink 优化器:

1. 使用同步或异步的查找函数
2. 配置异步查找相关参数
3. 启用延迟重试查找策略

**LOOKUP 提示选项：**

| 选项类型       | 选项名称        | 必选     | 选项值类型 | 默认值                                                       | 选项说明                                                     |
| -------------- | --------------- | -------- | ---------- | ------------------------------------------------------------ | :----------------------------------------------------------- |
| table          | table           | Y        | string     | N/A                                                          | 查找源表的表名                                               |
| async          | async           | N        | boolean    | N/A                                                          | 值可以是 'true' 或 'false', 以建议优化器选择对应的查找函数。若底层的连接器无法提供建议模式的查找函数，提示就不会生效 |
| output-mode    | N               | string   | ordered    | 值可以是 'ordered' 或 'allow_unordered'，'allow_unordered' 代表用户允许不保序的输出, 在优化器判断不影响 正确性的情况下会转成 `AsyncDataStream.OutputMode.UNORDERED`， 否则转成 `ORDERED`。 这与作业参数 `ExecutionConfigOptions#TABLE_EXEC_ASYNC_LOOKUP_OUTPUT_MODE` 是一致的 |                                                              |
| capacity       | N               | integer  | 100        | 异步查找使用的底层 `AsyncWaitOperator` 算子的缓冲队列大小    |                                                              |
| timeout        | N               | duration | 300s       | 异步查找从第一次调用到最终查找完成的超时时间，可能包含了多次重试，在发生 failover 时会重置 |                                                              |
| retry          | retry-predicate | N        | string     | N/A                                                          | 可以是 'lookup_miss'，表示在查找结果为空是启用重试           |
| retry-strategy | N               | string   | N/A        | 可以是 'fixed_delay'                                         |                                                              |
| fixed-delay    | N               | duration | N/A        | 固定延迟策略的延迟时长                                       |                                                              |
| max-attempts   | N               | integer  | N/A        | 固定延迟策略的最大重试次数                                   |                                                              |

> 注意：其中
>
> - ’table’ 是必选项，需要填写目标联接表的表名（和 FROM 子句引用的表名保持一致），注意当前不支持填写表的别名（这将在后续版本中支持）。
> - 异步查找参数可按需设置一个或多个，未设置的参数按默认值生效。
> - 重试查找参数没有默认值，在需要开启时所有参数都必须设置为有效值。

```sql
-- 建议优化器选择同步查找
LOOKUP('table'='Customers', 'async'='false')

-- 建议优化器选择异步查找
LOOKUP('table'='Customers', 'async'='true')

```

# Catalogs

* Catalog 提供了元数据信息，例如数据库、表、分区、视图以及数据库或其他外部系统中存储的函数和信息。

## Catalog类型

### GenericInMemoryCatalog

* `GenericInMemoryCatalog` 是基于内存实现的 Catalog，所有元数据只在 session 的生命周期内可用。

### JdbcCatalog

* `JdbcCatalog` 使得用户可以将 Flink 通过 JDBC 协议连接到关系数据库。`PostgresCatalog` 是当前实现的唯一一种 JDBC Catalog。

### HiveCatalog

* `HiveCatalog` 有两个用途：作为原生 Flink 元数据的持久化存储，以及作为读写现有 Hive 元数据的接口。

### 用户自定义 Catalog

* Catalog 是可扩展的，用户可以通过实现 `Catalog` 接口来开发自定义 Catalog。 想要在 SQL CLI 中使用自定义 Catalog，用户除了需要实现自定义的 Catalog 之外，还需要为这个 Catalog 实现对应的 `CatalogFactory` 接口。
* `CatalogFactory` 定义了一组属性，用于 SQL CLI 启动时配置 Catalog。 这组属性集将传递给发现服务，在该服务中，服务会尝试将属性关联到 `CatalogFactory` 并初始化相应的 Catalog 实例。

## 创建Flink表注册到Catalog中

### 使用SQL DDL

```java
// Create a HiveCatalog 
Catalog catalog = new HiveCatalog("myhive", null, "<path_of_hive_conf>");

// Register the catalog
tableEnv.registerCatalog("myhive", catalog);

// Create a catalog database
tableEnv.executeSql("CREATE DATABASE mydb WITH (...)");

// Create a catalog table
tableEnv.executeSql("CREATE TABLE mytable (name STRING, age INT) WITH (...)");

tableEnv.listTables(); 
```

### 使用Java

```java
// Create a catalog database
catalog.createDatabase("mydb", new CatalogDatabaseImpl(...));

// Create a catalog table
TableSchema schema = TableSchema.builder()
    .field("name", DataTypes.STRING())
    .field("age", DataTypes.INT())
    .build();

catalog.createTable(
        new ObjectPath("mydb", "mytable"),
        new CatalogTableImpl(
            schema,
            new Kafka()
                .version("0.11")
                ....
                .startFromEarlist()
                .toProperties(),
            "my comment"
        ),
        false
    );

List<String> tables = catalog.listTables("mydb");
```

## Catalog API

### 数据库操作

```java
// create database
catalog.createDatabase("mydb", new CatalogDatabaseImpl(...), false);

// drop database
catalog.dropDatabase("mydb", false);

// alter database
catalog.alterDatabase("mydb", new CatalogDatabaseImpl(...), false);

// get databse
catalog.getDatabase("mydb");

// check if a database exist
catalog.databaseExists("mydb");

// list databases in a catalog
catalog.listDatabases("mycatalog");
```

### 表操作

```java
// create table
catalog.createTable(new ObjectPath("mydb", "mytable"), new CatalogTableImpl(...), false);

// drop table
catalog.dropTable(new ObjectPath("mydb", "mytable"), false);

// alter table
catalog.alterTable(new ObjectPath("mydb", "mytable"), new CatalogTableImpl(...), false);

// rename table
catalog.renameTable(new ObjectPath("mydb", "mytable"), "my_new_table");

// get table
catalog.getTable("mytable");

// check if a table exist or not
catalog.tableExists("mytable");

// list tables in a database
catalog.listTables("mydb");
```

### 视图操作

```java
// create view
catalog.createTable(new ObjectPath("mydb", "myview"), new CatalogViewImpl(...), false);

// drop view
catalog.dropTable(new ObjectPath("mydb", "myview"), false);

// alter view
catalog.alterTable(new ObjectPath("mydb", "mytable"), new CatalogViewImpl(...), false);

// rename view
catalog.renameTable(new ObjectPath("mydb", "myview"), "my_new_view", false);

// get view
catalog.getTable("myview");

// check if a view exist or not
catalog.tableExists("mytable");

// list views in a database
catalog.listViews("mydb");
```

### 分区操作

```java
// create view
catalog.createPartition(
    new ObjectPath("mydb", "mytable"),
    new CatalogPartitionSpec(...),
    new CatalogPartitionImpl(...),
    false);

// drop partition
catalog.dropPartition(new ObjectPath("mydb", "mytable"), new CatalogPartitionSpec(...), false);

// alter partition
catalog.alterPartition(
    new ObjectPath("mydb", "mytable"),
    new CatalogPartitionSpec(...),
    new CatalogPartitionImpl(...),
    false);

// get partition
catalog.getPartition(new ObjectPath("mydb", "mytable"), new CatalogPartitionSpec(...));

// check if a partition exist or not
catalog.partitionExists(new ObjectPath("mydb", "mytable"), new CatalogPartitionSpec(...));

// list partitions of a table
catalog.listPartitions(new ObjectPath("mydb", "mytable"));
  
// list partitions of a table under a give partition spec
catalog.listPartitions(new ObjectPath("mydb", "mytable"), new CatalogPartitionSpec(...));

// list partitions of a table by expression filter
catalog.listPartitions(new ObjectPath("mydb", "mytable"), Arrays.asList(epr1, ...));
```

### 函数操作

```java
// create function
catalog.createFunction(new ObjectPath("mydb", "myfunc"), new CatalogFunctionImpl(...), false);

// drop function
catalog.dropFunction(new ObjectPath("mydb", "myfunc"), false);

// alter function
catalog.alterFunction(new ObjectPath("mydb", "myfunc"), new CatalogFunctionImpl(...), false);

// get function
catalog.getFunction("myfunc");

// check if a function exist or not
catalog.functionExists("myfunc");

// list functions in a database
catalog.listFunctions("mydb");
```

# 流式聚合

* 存在的问题

```
默认情况下，无界聚合算子是逐条处理输入的记录，即：（1）从状态中读取累加器，（2）累加/撤回记录至累加器，（3）将累加器写回状态，（4）下一条记录将再次从（1）开始处理。这种处理模式可能会增加 StateBackend 开销（尤其是对于 RocksDB StateBackend ）。此外，生产中非常常见的数据倾斜会使这个问题恶化，并且容易导致 job 发生反压。
```

## MiniBatch 聚合

* `将一组输入的数据缓存在聚合算子内部的缓冲区中`，当输入的数据被触发处理时，每个key只需一个操作即可访问状态，这样可以大大减少状态开销并获得更好的吞吐量。
* 但是，这可能会增加一些延迟，因为它会缓冲一些记录而不是立即处理它们。这是吞吐量和延迟之间的权衡。

![img](../img/minibatch_agg.png)

### 参数配置开启

```java
// access flink configuration
Configuration configuration = tEnv.getConfig().getConfiguration();
// set low-level key-value options
configuration.setString("table.exec.mini-batch.enabled", "true"); // enable mini-batch optimization
configuration.setString("table.exec.mini-batch.allow-latency", "5 s"); // use 5 seconds to buffer input records
configuration.setString("table.exec.mini-batch.size", "5000"); // the maximum number of records can be buffered by each aggregate operator task
```

## Local-Global 聚合

* Local-global聚合是为解决数据倾斜问题，通过将一组聚合氛围两个阶段，首先在上游进行本地聚合，然后在下游进行全局聚合，类似于MR中的**Combine+Reduce**模式。
* 每次本地聚合累积的输入数据量基于 mini-batch 间隔。

![img](../img/local_agg.png)

### 开启配置

```java
// access flink configuration
Configuration configuration = tEnv.getConfig().getConfiguration();
// set low-level key-value options
configuration.setString("table.exec.mini-batch.enabled", "true"); // local-global aggregation depends on mini-batch is enabled
configuration.setString("table.exec.mini-batch.allow-latency", "5 s");
configuration.setString("table.exec.mini-batch.size", "5000");
configuration.setString("table.optimizer.agg-phase-strategy", "TWO_PHASE"); // enable two-phase, i.e. local-global aggregation
```

## 在 distinct 聚合上使用 FILTER 修饰符

```sql
SELECT
 day,
 COUNT(DISTINCT user_id) AS total_uv,
 COUNT(DISTINCT user_id) FILTER (WHERE flag IN ('android', 'iphone')) AS app_uv,
 COUNT(DISTINCT user_id) FILTER (WHERE flag IN ('wap', 'other')) AS web_uv
FROM T
GROUP BY day
```

# 执行配置

## 获取配置

```java
 public static void main(String[] args) {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // 获取执行配置
        ExecutionConfig config = env.getConfig();

        // 级别设置，
        // 默认为ClosureCleanerLevel.RECURSIVE 递归地清除所有字段。
        // TOP_LEVEL:只清理顶级类，不递归到字段中
        config.setClosureCleanerLevel(ExecutionConfig.ClosureCleanerLevel.TOP_LEVEL);
        // 设置并行度
        config.setParallelism(3);
        // 为作业设置默认的最大并行度。此设置确定最大并行度，并指定动态缩放的上限。
        config.setMaxParallelism(6);
        //设置失败任务重新执行的次数。值为零有效地禁用了容错。值-1表示应该使用系统默认值(如配置中定义的)。这个配置过期可以设置重启策略
        config.setNumberOfExecutionRetries(3);
        // 默认模式PIPELINED，设置执行模式执行程序，执行模式定义数据交换是以批处理方式执行还是以流水线方式执行。
        config.setExecutionMode(ExecutionMode.PIPELINED_FORCED);

        config.disableForceKryo();
        config.disableForceAvro();
        config.disableObjectReuse();

        // 开启JobManager状态system.out.print日志
        config.enableSysoutLogging();
        config.disableSysoutLogging();

        // 设置全局Job参数
//        config.setGlobalJobParameters();

        // 添加默认kryo序列化器
//        config.addDefaultKryoSerializer()
        //设置连续尝试取消正在运行的任务之间的等待间隔(以毫秒为单位)。当一个任务被取消时，会创建一个新线程，如果该任务线程在一定时间内没有终止，该线程会定期调用interrupt()。这个参数指的是连续调用interrupt()之间的时间，默认设置为30000毫秒，即30秒。
        config.setTaskCancellationInterval(1000);

    }
```

## 打印执行计划

```java
final ExecutionEnvironment env = ExecutionEnvironment.getExecutionEnvironment();

...

System.out.println(env.getExecutionPlan());
```

## Task故障恢复

### Restart Stragtegies

* none,off,disable:不设置重启策略
* fixeddelay,fixed-delay:固定延迟重启策略

```yaml
# 重试次数
restart-strategy.fixed-delay.attempts: 3
# 失败重试间隔
restart-strategy.fixed-delay.delay: 10 s

# Java
ExecutionEnvironment env = ExecutionEnvironment.getExecutionEnvironment();
env.setRestartStrategy(RestartStrategies.fixedDelayRestart(
  3, // 尝试重启的次数
  Time.of(10, TimeUnit.SECONDS) // 延时
));
```

* failurerate,failure-rate:失败比率重启策略

```yaml
# 最大失败次数
restart-strategy.failure-rate.max-failures-per-interval: 3
# 失败间隔
restart-strategy.failure-rate.failure-rate-interval: 5 min
# 
restart-strategy.failure-rate.delay: 10 s

# Java
ExecutionEnvironment env = ExecutionEnvironment.getExecutionEnvironment();
env.setRestartStrategy(RestartStrategies.failureRateRestart(
  3, // 每个时间间隔的最大故障次数
  Time.of(5, TimeUnit.MINUTES), // 测量故障率的时间间隔
  Time.of(10, TimeUnit.SECONDS) // 延时
));
```

