# 概览

## 基本程序结构

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

* 创建表执行环境

```java
    public static TableEnvironment getEnv() {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.setParallelism(1);

        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode().useBlinkPlanner().build();
        return StreamTableEnvironment.create(env, settings);
    }

    public static TableEnvironment getBatchEnv() {
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .useBlinkPlanner().inBatchMode().build();
        return TableEnvironment.create(settings);
    }
```



* 基于TableEnvironment做操作
  * 注册Catalog
  * 在Catalog中注册表
  * 执行SQL查询
  * 注册UDF

## 表（Table）

* TableEnvironment可以注册目录Catalog，并可以基于Catalog注册表
* 表是由一个标识符来指定，由catalog名、数据库名和对象名组成。
* 表可以是常规的，也可以是虚拟表（视图）
* 常规表一般可以用来描述外部数据，比如文件、数据库或消息队列数据，也可以从DataStream转换而来
* 视图可以从现有的表中创建，通常是table API或SQL查询的一个结果集。

## 动态表(Dynamic Tables)

![Dynamic tables](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/table-streaming/stream-query-stream.png)

* 动态表是Flink对流数据的Table API和SQL支持的核心概念。
* 与表示批处理数据的静态表不同，动态表随时间变化的。

### 持续查询（Continuous Query）

* 动态表可以像静态的批处理表一样进行查询，查询一个动态表产生持续查询(Continuous Query)
* 连续查询永远不会终止，并会生成另一个动态表。
* 查询会不断更新其动态结果表，以反映动态输入表上的更改。

### 流式表查询的处理过程

* 将流转换为动态表。
* 在动态表上计算一个连续查询，生成一个新的动态表。
* 生成的动态表被转换回流。

### 表到流的转换

动态表可以像普通数据库表一样通过 `INSERT`、`UPDATE` 和 `DELETE` 来不断修改。它可能是一个只有一行、不断更新的表，也可能是一个 insert-only 的表，没有 `UPDATE` 和 `DELETE` 修改，或者介于两者之间的其他表。

在将动态表转换为流或将其写入外部系统时，需要对这些更改进行编码。Flink的 Table API 和 SQL 支持三种方式来编码一个动态表的变化:

- **Append-only 流：** 仅通过 `INSERT` 操作修改的动态表可以通过输出插入的行转换为流。
- **Retract 流：** retract 流包含两种类型的 message： *add messages* 和 *retract messages* 。通过将`INSERT` 操作编码为 add message、将 `DELETE` 操作编码为 retract message、将 `UPDATE` 操作编码为更新(先前)行的 retract message 和更新(新)行的 add message，将动态表转换为 retract 流。下图显示了将动态表转换为 retract 流的过程。

![Dynamic tables](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/table-streaming/undo-redo-mode.png)

- **Upsert 流:** upsert 流包含两种类型的 message： *upsert messages* 和*delete messages*。转换为 upsert 流的动态表需要(可能是组合的)唯一键。通过将 `INSERT` 和 `UPDATE` 操作编码为 upsert message，将 `DELETE` 操作编码为 delete message ，将具有唯一键的动态表转换为流。消费流的算子需要知道唯一键的属性，以便正确地应用 message。与 retract 流的主要区别在于 `UPDATE` 操作是用单个 message 编码的，因此效率更高。下图显示了将动态表转换为 upsert 流的过程。

![Dynamic tables](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/table-streaming/redo-mode.png)