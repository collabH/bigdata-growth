# DataStream

## 流批一体

* 通过指定参数配置可以使得流批处理一体
* 支持通过批处理获取一个savepoint在流处理中恢复这个savepoint，后期可能会过时。

### 配置流批设置

* 通过`execution.runtime-mode`指定配置`STREAMING`、`BATCH`、`AUTOMATIC`

```shell
bin/flink run -Dexecution.runtime-mode=BATCH examples/streaming/WordCount.jar
```

* java代码

```java
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
env.setRuntimeMode(RuntimeExecutionMode.BATCH);
```

### 状态后端

#### Stream

* 和1.12版本前一直使用StateBackend来存储State和恢复

#### Batch

* 在批处理模式下，将忽略配置的状态后端。相反，key操作的输入是按键分组的(使用排序)，然后我们依次处理键的所有记录。这允许在同一时间只保留一个key的状态。当移动到下一个key时，给定key的状态将被丢弃。

### Event Time/WaterMark

#### Stream

* 仍然使用1.12版本前的Watermark和timestamp来包装数据的顺序

#### Batch

* 使用`perfect watermarks`来替代，需要一个`MAT_WATERMARK`在每个流的末尾处，在该方案中，所有注册的计时器将在时间结束时触发，而忽略用户自定义的水印分配器或水印策略。

### Processing Time

* Batch模式运行用户使用processing time和注册processing timer，但是event time所注册的timer只会在输入结束后触发。

### Failure Recovery

* 在BATCH执行模式中，Flink将尝试并回溯到中间结果仍然可用的前一个处理阶段。潜在地，只有失败的任务(或图中它们的前身)必须重新启动，与从检查点重新启动所有任务相比，这可以提高处理效率和作业的总体处理时间。

### 批模式的变更

* 对于`reduce`、`sum`算子批处理只会输出最终结果

#### 不支持特性

* 不支持checkpoint，任何依赖checkpoint的算子都不能工作
* 不支持状态后端
* 不支持迭代流。

# Table&SQL Connector

## Formats

### Confluent Avro

* 增加Avro Schema Registry，支持读取kafka avro格式，需要配置registry地址和subject

```sql
CREATE TABLE user_behavior (
  user_id BIGINT,
  item_id BIGINT,
  category_id BIGINT,
  behavior STRING,
  ts TIMESTAMP(3)
) WITH (
  'connector' = 'kafka',
  'properties.bootstrap.servers' = 'localhost:9092',
  'topic' = 'user_behavior'
  'format' = 'avro-confluent',
  'avro-confluent.schema-registry.url' = 'http://localhost:8081',
  'avro-confluent.schema-registry.subject' = 'user_behavior'
)
```

## Kafka

### 新特性

* 增加获取kafka元数据的参数配置以及format对应的元数据配置
* 提供kafka record中key和value相关配置

## Upsert Kafka

* 作为 source，upsert-kafka 连接器生产 changelog 流，其中每条数据记录代表一个更新或删除事件。更准确地说，数据记录中的 value 被解释为同一 key 的最后一个 value 的 UPDATE，如果有这个 key（如果不存在相应的 key，则该更新被视为 INSERT）。用表来类比，changelog 流中的数据记录被解释为 UPSERT，也称为 INSERT/UPDATE，因为任何具有相同 key 的现有行都被覆盖。另外，value 为空的消息将会被视作为 DELETE 消息。
* 作为 sink，upsert-kafka 连接器可以消费 changelog 流。它会将 INSERT/UPDATE_AFTER 数据作为正常的 Kafka 消息写入，并将 DELETE 数据以 value 为空的 Kafka 消息写入（表示对应 key 的消息被删除）。Flink 将根据主键列的值对数据进行分区，从而保证主键上的消息有序，因此同一主键上的更新/删除消息将落在同一分区中。

### key和value格式

```java
CREATE TABLE KafkaTable (
  `ts` TIMESTAMP(3) METADATA FROM 'timestamp',
  `user_id` BIGINT,
  `item_id` BIGINT,
  `behavior` STRING,
  PRIMARY KEY (`user_id`) NOT ENFORCED
) WITH (
  'connector' = 'upsert-kafka',
  ...

  'key.format' = 'json',
  'key.json.ignore-parse-errors' = 'true',

  'value.format' = 'json',
  'value.json.fail-on-missing-field' = 'false',
  'value.fields-include' = 'EXCEPT_KEY'
)
```

### 主键约束

* Upsert Kafka 始终以 upsert 方式工作，并且需要在 DDL 中定义主键。在具有相同主键值的消息按序存储在同一个分区的前提下，在 changlog source 定义主键意味着 在物化后的 changelog 上主键具有唯一性。定义的主键将决定哪些字段出现在 Kafka 消息的 key 中。