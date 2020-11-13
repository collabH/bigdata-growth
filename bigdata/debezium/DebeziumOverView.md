# 架构设计

* source connector从debezium发送消息到kafka
* sink connector将记录从kafka中发送到其他系统接收器

![Debezium Architecture](https://debezium.io/documentation/reference/1.4/_images/debezium-architecture.png)

## Debezium Server

* 使用Debezium Server部署Debezium，这个Server是可配置的。

![Debezium Architecture](https://debezium.io/documentation/reference/1.4/_images/debezium-server-architecture.png)

# Configuration

## Avro序列化

* Debezium的序列化根据Kafka配置的序列化方式

```properties
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
```

### 关闭schemas的传递

* `key.converter.schemas.enable`：设置为false关闭key的schema传递
* `value.converter.schemas.enable`：设置为false关闭value的schema传递

### Avro序列化的优势

* Avro二进制格式是紧凑和有效的，并且可以保证每条记录的数据格式的正确。
* 这对于Debezium连接器非常重要，它将动态生成每条记录的模式，以匹配已更改的数据库表的结构。
* 变更的事件记录写入相同的topic可能有相同的schema不同的版本，avro更容易适用于变更的记录schema

### APIicurio API Schema Registry使用

* 使用avro序列化必须部署一个schema registry为了管理Avro消息schemas和他们的版本。

1. 部署Apicurio API和Schema Registy实例,[Apicurio API](https://github.com/Apicurio/apicurio-registry)
2. 安装[Avro converter](https://repo1.maven.org/maven2/io/apicurio/apicurio-registry-distro-connect-converter/1.3.0.Final/apicurio-registry-distro-connect-converter-1.3.0.Final-converter.tar.gz)
3. 配置一个Debezium connector实例去使用Avro Schema

```properties
key.converter=io.apicurio.registry.utils.converter.AvroConverter
key.converter.apicurio.registry.url=http://apicurio:8080/api
key.converter.apicurio.registry.global-id=io.apicurio.registry.utils.serde.strategy.GetOrCreateIdStrategy
value.converter=io.apicurio.registry.utils.converter.AvroConverter
value.converter.apicurio.registry.url=http://apicurio:8080/api
value.converter.apicurio.registry.global-id=io.apicurio.registry.utils.serde.strategy.GetOrCreateIdStrategy
```

### Confluent Schema Registry

* debezium connector配置

```properties
key.converter=io.confluent.connect.avro.AvroConverter
key.converter.schema.registry.url=http://localhost:8081
value.converter=io.confluent.connect.avro.AvroConverter
value.converter.schema.registry.url=http://localhost:8081
```

* 部署Confluent实例

```
docker run -it --rm --name schema-registry \
    --link zookeeper \
    -e SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL=zookeeper:2181 \
    -e SCHEMA_REGISTRY_HOST_NAME=schema-registry \
    -e SCHEMA_REGISTRY_LISTENERS=http://schema-registry:8081 \
    -p 8181:8181 confluentinc/cp-schema-registry
```

## Topic路由

* 每个kafka记录包含一个数据变更事件有一个默认定义的topic。如果需要重新发送到其他topic需要在在记录到kafkaConnector之前指定一个topic。
* debezium提供的topic路由是单独消息转换，配置这个转换器在debezium的kafkaConnect配置中
  * 一个用于标识要重路由的记录的表达式
  * 一个解析到目标主题的表达式
  * 如何确保重新路由到目标主题的记录之间有唯一的密钥

### Use case

* 默认debezium提供的topic的名字为:`debeziumname.database.tablename`
* 对于PG的分区表关闭添加唯一键行为:`key.enforce.uniqueness=false` 

### re route配置

```properties
transforms=Reroute
transforms.Reroute.type=io.debezium.transforms.ByLogicalTableRouter
# 匹配*customers_shard*相关的表，比如myserver.mydb.customers_shard1、myserver.mydb.customers_shard2
transforms.Reroute.topic.regex=(.*)customers_shard(.*)
transforms.Reroute.topic.replacement=$1customers_all_shards
```

#### topic.regex

* 指定将转换应用于每个更改事件记录的正则表达式，以确定是否应将其路由到特定主题。

#### topic.replacement

* 指定表示目标主题名称的正则表达式。转换将每个匹配的记录路由到由该表达式标识的主题。

### 满足唯一键

* 一个debezium变更事件的key使用的是表的列作为表的主键，对于分库的表来说可能debezium的key是重复的。为了满足每个相同的key发送到相同的topic，topic路由转换插入一个字段`__dbz__physicalTableIdentifier`来保证，其默认为目标topic名称。
* `transforms.Reroute.key.field.name=shard_id`设置其他唯一key名称。
* 如果表包含全局唯一键，并且不需要更改键结构，则可以设置`key. enforcement.uniqueness`选项为false

## 新记录状态提取

### 改变时间结构

* Debezium生成的数据变更事件是一个复杂的结构，每个事件包含三个部分
  * Metadata:进行更改的操作\数据源信息比如database、table名称/变更时间/可选的转换信息等
  * before变更记录
  * after变更记录

```json
{
	"op": "u",
	"source": {
		...
	},
	"ts_ms" : "...",
	"before" : {
		"field1" : "oldvalue1",
		"field2" : "oldvalue2"
	},
	"after" : {
		"field1" : "newvalue1",
		"field2" : "newvalue2"
	}
}
```

### 配置

* [相关配置](https://debezium.io/documentation/reference/1.3/configuration/event-flattening.html)

```properties
transforms=unwrap,...
# 指定提取类
transforms.unwrap.type=io.debezium.transforms.ExtractNewRecordState
# 在事件流中保留删除操作的逻辑删除记录。
transforms.unwrap.drop.tombstones=false
# 为删除操作提供"__deleted"标示
transforms.unwrap.delete.handling.mode=rewrite
# 添加表和lsn字段的更改事件元数据。
transforms.unwrap.add.fields=table,lsn
```

* `transforms.unwrap.delete.handling.mode=rewrite`，添加`__deleted`标示

```json
"value": {
  "pk": 2,
  "cola": null,
  "__deleted": "true"
}
```

* `transforms.unwrap.add.fields`  在metadata中添加字段，包括`table`/`lsn`等

```json
{
 ...
	"__op" : "c",
	"__table": "MY_TABLE",
	"__lsn": "123456789",
	"__source_ts_ms" : "123456789",
 ...
}
```

## 自定义Topic自动创建

* topic动态为offsets，connector status，config storge和history topics创建内部topics。目标topics为了捕获逼表将会动态创建一个默认的配置当kafka brokers的配置`auto.create.topics.enable`设置为`true`时
* 发送`POST`请求的请求体配置

### 配置Kafka Connect

```properties
# 开启动态topic创建
topic.creation.enable = true
```

#### 默认group配置

```json
{
    ...

    "topic.creation.default.replication.factor": 3,  
    "topic.creation.default.partitions": 10,  
    "topic.creation.default.cleanup.policy": "compact",  
    "topic.creation.default.compression.type": "lz4"  

     ...
}
```

#### 自定义group配置

```json
{
    ...

    // 不同的库定义不同的group策略
    "topic.creation.inventory.include": "dbserver1\\.inventory\\.*",  
    "topic.creation.inventory.partitions": 20,
    "topic.creation.inventory.cleanup.policy": "compact",
    "topic.creation.inventory.delete.retention.ms": 7776000000,

    
    "topic.creation.applicationlogs.include": "dbserver1\\.logs\\.applog-.*",  
    "topic.creation.applicationlogs.exclude": "dbserver1\\.logs\\.applog-old-.*",  
    "topic.creation.applicationlogs.replication.factor": 1,
    "topic.creation.applicationlogs.partitions": 20,
    "topic.creation.applicationlogs.cleanup.policy": "delete",
    "topic.creation.applicationlogs.retention.ms": 7776000000,
    "topic.creation.applicationlogs.compression.type": "lz4",

     ...
}
```

#### 注册自定义group

```json
{
    ...

    "topic.creation.groups": "inventory,applicationlogs",

     ...
}
```

#### 完整的配置

```json
{
    "topic.creation.default.replication.factor": 3,
    "topic.creation.default.partitions": 10,
    "topic.creation.default.cleanup.policy": "compact",
    "topic.creation.default.compression.type": "lz4"
    "topic.creation.groups": "inventory,applicationlogs",
    "topic.creation.inventory.include": "dbserver1\\.inventory\\.*",
    "topic.creation.inventory.replication.factor": 3,
    "topic.creation.inventory.partitions": 20,
    "topic.creation.inventory.cleanup.policy": "compact",
    "topic.creation.inventory.delete.retention.ms": 7776000000,
    "topic.creation.applicationlogs.include": "dbserver1\\.logs\\.applog-.*",
    "topic.creation.applicationlogs.exclude": "dbserver1\\.logs\\.applog-old-.*",
    "topic.creation.applicationlogs.replication.factor": 1,
    "topic.creation.applicationlogs.partitions": 20,
    "topic.creation.applicationlogs.cleanup.policy": "delete",
    "topic.creation.applicationlogs.retention.ms": 7776000000,
    "topic.creation.applicationlogs.compression.type": "lz4"
}
```

# Connector

## MySQL Connector

* 由于通常将MySQL设置为在指定的时间段后清除二进制日志，因此MySQL连接器会对每个数据库执行初始的一致快照。 MySQL连接器从创建快照的位置读取binlog。
* 当连接器崩溃或正常停止后重新启动时，连接器从特定位置(即从特定时间点)开始读取binlog。连接器通过读取数据库`历史Kafka topic`并`解析所有DDL语句`，重新构建了此时存在的表结构，直到binlog中连接器开始的位置。
* database的history topic仅提供给connector使用，connnctor可以选择性的生成schema变更事件对于不同的topic提供给应用程序使用。

### 执行database快照

* 当连接器第一次启动时，它会对你的数据库执行一个初始一致的快照。

#### 初始化快照执行流程

1. 获取阻止其他数据库客户端写操作的全局读锁。
2. 使用可重复读语义启动事务，以确保事务内的所有后续读取都针对一致快照执行。
3. 读取当前binlog的position
4. 读取连接器配置允许的数据库和表的模式。
5. 释放全局读锁。这现在允许其他数据库客户端写入数据库。
6. 将DDL更改写入schema变更topic，包括所有必要的删除和创建DDL语句。
7. 扫描数据库表并为每一行生成表特定Kafka topic上的CREATE事件。
8. 提交事务
9. 在连接器偏移中记录完成的快照。

#### connector初始化过程失败

* 如果连接器发生故障、停止或在生成初始快照时重新平衡，则连接器在重新启动后将创建一个新快照。一旦初始快照完成，Debezium MySQL连接器就会从binlog中的相同位置重新启动，这样它就不会错过任何更新。
* 如果connector停止或者中断过程，mysql的binlog被清空，那么就会在发生一次初始化快照的过程。

#### 全局读锁

* 有些环境不允许全局读锁。如果Debezium MySQL连接器检测到不允许全局读锁，连接器将使用表级锁，并使用该方法执行快照。

### 暴露Schema变更

* 通过配置Debezium MySQL连接器去提供schema变更事件，其中包括应用于MySQL服务器数据库的所有DDL语句这个连接器写入这些事件到名为"serverName"的kafka topic中，serverName通过`database.server.name`配置

#### schema变更topic结构

* schema变更topic的key

```json
{
  "schema": {
    "type": "struct",
    "name": "io.debezium.connector.mysql.SchemaChangeKey",
    "optional": false,
    "fields": [
      {
        "field": "databaseName",
        "type": "string",
        "optional": false
      }
    ]
  },
  "payload": {
    "databaseName": "inventory"
  }
}
```

* schema变更topic的value

```java
{
  "schema": {
    "type": "struct",
    "name": "io.debezium.connector.mysql.SchemaChangeValue",
    "optional": false,
    "fields": [
      {
        "field": "databaseName",
        "type": "string",
        "optional": false
      },
      {
        "field": "ddl",
        "type": "string",
        "optional": false
      },
      {
        "field": "source",
        "type": "struct",
        "name": "io.debezium.connector.mysql.Source",
        "optional": false,
        "fields": [
          {
            "type": "string",
            "optional": true,
            "field": "version"
          },
          {
            "type": "string",
            "optional": false,
            "field": "name"
          },
          {
            "type": "int64",
            "optional": false,
            "field": "server_id"
          },
          {
            "type": "int64",
            "optional": false,
            "field": "ts_sec"
          },
          {
            "type": "string",
            "optional": true,
            "field": "gtid"
          },
          {
            "type": "string",
            "optional": false,
            "field": "file"
          },
          {
            "type": "int64",
            "optional": false,
            "field": "pos"
          },
          {
            "type": "int32",
            "optional": false,
            "field": "row"
          },
          {
            "type": "boolean",
            "optional": true,
            "default": false,
            "field": "snapshot"
          },
          {
            "type": "int64",
            "optional": true,
            "field": "thread"
          },
          {
            "type": "string",
            "optional": true,
            "field": "db"
          },
          {
            "type": "string",
            "optional": true,
            "field": "table"
          },
          {
            "type": "string",
            "optional": true,
            "field": "query"
          }
        ]
      }
    ]
  },
  "payload": {
    "databaseName": "inventory",
    "ddl": "CREATE TABLE products ( id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255) NOT NULL, description VARCHAR(512), weight FLOAT ); ALTER TABLE products AUTO_INCREMENT = 101;",
    "source" : {
      "version": "0.10.0.Beta4",
      "name": "mysql-server-1",
      "server_id": 0,
      "ts_sec": 0,
      "gtid": null,
      "file": "mysql-bin.000003",
      "pos": 154,
      "row": 0,
      "snapshot": true,
      "thread": null,
      "db": null,
      "table": null,
      "query": null
    }
  }
}
```

## 事件

### create event

```json
{
  "schema": { 
    "type": "struct",
    "fields": [
      {
        "type": "struct",
        "fields": [
          {
            "type": "int32",
            "optional": false,
            "field": "id"
          },
          {
            "type": "string",
            "optional": false,
            "field": "first_name"
          },
          {
            "type": "string",
            "optional": false,
            "field": "last_name"
          },
          {
            "type": "string",
            "optional": false,
            "field": "email"
          }
        ],
        "optional": true,
        "name": "mysql-server-1.inventory.customers.Value", 
        "field": "before"
      },
      {
        "type": "struct",
        "fields": [
          {
            "type": "int32",
            "optional": false,
            "field": "id"
          },
          {
            "type": "string",
            "optional": false,
            "field": "first_name"
          },
          {
            "type": "string",
            "optional": false,
            "field": "last_name"
          },
          {
            "type": "string",
            "optional": false,
            "field": "email"
          }
        ],
        "optional": true,
        "name": "mysql-server-1.inventory.customers.Value",
        "field": "after"
      },
      {
        "type": "struct",
        "fields": [
          {
            "type": "string",
            "optional": false,
            "field": "version"
          },
          {
            "type": "string",
            "optional": false,
            "field": "connector"
          },
          {
            "type": "string",
            "optional": false,
            "field": "name"
          },
          {
            "type": "int64",
            "optional": false,
            "field": "ts_sec"
          },
          {
            "type": "boolean",
            "optional": true,
            "default": false,
            "field": "snapshot"
          },
          {
            "type": "string",
            "optional": false,
            "field": "db"
          },
          {
            "type": "string",
            "optional": true,
            "field": "table"
          },
          {
            "type": "int64",
            "optional": false,
            "field": "server_id"
          },
          {
            "type": "string",
            "optional": true,
            "field": "gtid"
          },
          {
            "type": "string",
            "optional": false,
            "field": "file"
          },
          {
            "type": "int64",
            "optional": false,
            "field": "pos"
          },
          {
            "type": "int32",
            "optional": false,
            "field": "row"
          },
          {
            "type": "int64",
            "optional": true,
            "field": "thread"
          },
          {
            "type": "string",
            "optional": true,
            "field": "query"
          }
        ],
        "optional": false,
        "name": "io.debezium.connector.mysql.Source", 
        "field": "source"
      },
      {
        "type": "string",
        "optional": false,
        "field": "op"
      },
      {
        "type": "int64",
        "optional": true,
        "field": "ts_ms"
      }
    ],
    "optional": false,
    "name": "mysql-server-1.inventory.customers.Envelope" 
  },
  "payload": { 
    "op": "c", 
    "ts_ms": 1465491411815, 
    "before": null, 
    "after": { 
      "id": 1004,
      "first_name": "Anne",
      "last_name": "Kretchmar",
      "email": "annek@noanswer.org"
    },
    "source": { 
      "version": "1.3.0.Final",
      "connector": "mysql",
      "name": "mysql-server-1",
      "ts_sec": 0,
      "snapshot": false,
      "db": "inventory",
      "table": "customers",
      "server_id": 0,
      "gtid": null,
      "file": "mysql-bin.000003",
      "pos": 154,
      "row": 0,
      "thread": 7,
      "query": "INSERT INTO customers (first_name, last_name, email) VALUES ('Anne', 'Kretchmar', 'annek@noanswer.org')"
    }
  }
}
```

### update event

```json
{
  "schema": { ... },
  "payload": {
    "before": { 
      "id": 1004,
      "first_name": "Anne",
      "last_name": "Kretchmar",
      "email": "annek@noanswer.org"
    },
    "after": { 
      "id": 1004,
      "first_name": "Anne Marie",
      "last_name": "Kretchmar",
      "email": "annek@noanswer.org"
    },
    "source": { 
      "version": "1.3.0.Final",
      "name": "mysql-server-1",
      "connector": "mysql",
      "name": "mysql-server-1",
      "ts_sec": 1465581,
      "snapshot": false,
      "db": "inventory",
      "table": "customers",
      "server_id": 223344,
      "gtid": null,
      "file": "mysql-bin.000003",
      "pos": 484,
      "row": 0,
      "thread": 7,
      "query": "UPDATE customers SET first_name='Anne Marie' WHERE id=1004"
    },
    "op": "u", 
    "ts_ms": 1465581029523
  }
}
```

### delete event

```json
{
  "schema": { ... },
  "payload": {
    "before": { 
      "id": 1004,
      "first_name": "Anne Marie",
      "last_name": "Kretchmar",
      "email": "annek@noanswer.org"
    },
    "after": null, 
    "source": { 
      "version": "1.3.0.Final",
      "connector": "mysql",
      "name": "mysql-server-1",
      "ts_sec": 1465581,
      "snapshot": false,
      "db": "inventory",
      "table": "customers",
      "server_id": 223344,
      "gtid": null,
      "file": "mysql-bin.000003",
      "pos": 805,
      "row": 0,
      "thread": 7,
      "query": "DELETE FROM customers WHERE id=1004"
    },
    "op": "d", 
    "ts_ms": 1465581902461 
  }
}
```

#### 墓碑event

* 当一行被删除时，delete事件值仍然在日志压缩中工作，因为Kafka可以删除所有具有相同键的早期消息。然而，Kafka删除所有具有相同密钥的消息，消息值必须为空。为了实现这一点，Debezium s MySQL连接器发出delete事件后，连接器发出一个特殊的tombstone事件，该事件具有相同的键，但为空值。

## 映射数据类型

* **literal type** : 值如何表示使用Kafka连接schema类型
* **semantic type** : Kafka连接模式如何捕获字段(schema名)的含义

| MySQL type          | Literal type        | Semantic type                                                |
| :------------------ | :------------------ | :----------------------------------------------------------- |
| `BOOLEAN, BOOL`     | `BOOLEAN`           | *n/a*                                                        |
| `BIT(1)`            | `BOOLEAN`           | *n/a*                                                        |
| `BIT(>1)`           | `BYTES`             | `io.debezium.data.Bits`The `length` schema parameter contains an integer that represents the number of bits. The `byte[]` contains the bits in *little-endian* form and is sized to contain the specified number of bits.example (where n is bits)`numBytes = n/8 + (n%8== 0 ? 0 : 1)` |
| `TINYINT`           | `INT16`             | *n/a*                                                        |
| `SMALLINT[(M)]`     | `INT16`             | *n/a*                                                        |
| `MEDIUMINT[(M)]`    | `INT32`             | *n/a*                                                        |
| `INT, INTEGER[(M)]` | `INT32`             | *n/a*                                                        |
| `BIGINT[(M)]`       | `INT64`             | *n/a*                                                        |
| `REAL[(M,D)]`       | `FLOAT32`           | *n/a*                                                        |
| `FLOAT[(M,D)]`      | `FLOAT64`           | *n/a*                                                        |
| `DOUBLE[(M,D)]`     | `FLOAT64`           | *n/a*                                                        |
| `CHAR(M)]`          | `STRING`            | *n/a*                                                        |
| `VARCHAR(M)]`       | `STRING`            | *n/a*                                                        |
| `BINARY(M)]`        | `BYTES` or `STRING` | *n/a*Either the raw bytes (the default), a base64-encoded String, or a hex-encoded String, based on the [binary handling mode](https://debezium.io/documentation/reference/1.3/connectors/mysql.html#mysql-property-binary-handling-mode) setting |
| `VARBINARY(M)]`     | `BYTES` or `STRING` | *n/a*Either the raw bytes (the default), a base64-encoded String, or a hex-encoded String, based on the [binary handling mode](https://debezium.io/documentation/reference/1.3/connectors/mysql.html#mysql-property-binary-handling-mode) setting |
| `TINYBLOB`          | `BYTES` or `STRING` | *n/a*Either the raw bytes (the default), a base64-encoded String, or a hex-encoded String, based on the [binary handling mode](https://debezium.io/documentation/reference/1.3/connectors/mysql.html#mysql-property-binary-handling-mode) setting |
| `TINYTEXT`          | `STRING`            | *n/a*                                                        |
| `BLOB`              | `BYTES` or `STRING` | *n/a*Either the raw bytes (the default), a base64-encoded String, or a hex-encoded String, based on the [binary handling mode](https://debezium.io/documentation/reference/1.3/connectors/mysql.html#mysql-property-binary-handling-mode) setting |
| `TEXT`              | `STRING`            | *n/a*                                                        |
| `MEDIUMBLOB`        | `BYTES` or `STRING` | *n/a*Either the raw bytes (the default), a base64-encoded String, or a hex-encoded String, based on the [binary handling mode](https://debezium.io/documentation/reference/1.3/connectors/mysql.html#mysql-property-binary-handling-mode) setting |
| `MEDIUMTEXT`        | `STRING`            | *n/a*                                                        |
| `LONGBLOB`          | `BYTES` or `STRING` | *n/a*Either the raw bytes (the default), a base64-encoded String, or a hex-encoded String, based on the [binary handling mode](https://debezium.io/documentation/reference/1.3/connectors/mysql.html#mysql-property-binary-handling-mode) setting |
| `LONGTEXT`          | `STRING`            | *n/a*                                                        |
| `JSON`              | `STRING`            | `io.debezium.data.Json`Contains the string representation of a `JSON` document, array, or scalar. |
| `ENUM`              | `STRING`            | `io.debezium.data.Enum`The `allowed` schema parameter contains the comma-separated list of allowed values. |
| `SET`               | `STRING`            | `io.debezium.data.EnumSet`The `allowed` schema parameter contains the comma-separated list of allowed values. |
| `YEAR[(2|4)]`       | `INT32`             | `io.debezium.time.Year`                                      |
| `TIMESTAMP[(M)]`    | `STRING`            | `io.debezium.time.ZonedTimestamp`In [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html) format with microsecond precision. MySQL allows `M` to be in the range of `0-6`. |

## 表对应的topic

* 一个表对应一个topic，格式为`serverName.databaseName.tableName`

## 支持的MySQL拓扑

### *Standalone*

* 当使用一个MySQL服务器时，该服务器必须启用binlog(可选启用GTIDs)，以便Debezium MySQL连接器可以监视服务器。这通常是可以接受的，因为二进制日志还可以用作增量备份。在这种情况下，MySQL连接器总是连接并遵循这个独立的MySQL服务器实例。

### *Primary and replica*

* Debezium MySQL连接器可以跟随一个主服务器或一个副本(如果该副本启用了binlog)，但是连接器只能看到集群中对该服务器可见的更改。通常，除了多主拓扑之外，这不是问题。
* 连接器记录其在服务器binlog中的位置，这在集群中的每个服务器上都是不同的。因此，连接器将只需要遵循一个MySQL服务器实例。如果该服务器发生故障，必须重新启动或恢复该服务器，连接器才能继续运行。

### *High available clusters*

* MySQL有各种各样的高可用性解决方案，它们使其更容易容忍，几乎可以立即从问题和故障中恢复。大多数HA MySQL集群使用GTIDs，以便副本能够跟踪任何主服务器上的所有更改。

### *Multi-primary*

### *Hosted*

## 配置MYSQL服务端

### 为Debezium创建一个MySQL用户

```sql
-- 创建用户
CREATE USER 'user'@'localhost' IDENTIFIED BY 'password';
-- 授予权限，查询，RELOAD:FLUSH语句来清除或重新加载内部缓存、刷新表或获取锁,
--REPLICATION SLAVE：启用连接器连接和读取MySQL服务器binlog。
-- REPLICATION CLIENT:允许使用SHOW MASTER STATUS/SHOW SLAVE STATUS/SHOW BINARY LOGS语句
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'user' IDENTIFIED BY 'password';
-- 刷新权限
FLUSH PRIVILEGES;
```

### 开启binlog

```sql
-- 检查log-bin是否开启
SELECT variable_value as "BINARY LOGGING STATUS (log-bin) ::" FROM information_schema.global_variables WHERE variable_name='log_bin';
```

* 开启binlog，修改`/etc/my.cnf`

```
server-id         = 223344 
log_bin           = mysql-bin 
binlog_format     = ROW 
binlog_row_image  = FULL 
expire_logs_days  = 10 
```

### 开启全局事务标识

* 全局事务标识符(GTIDs)唯一地标识集群内服务器上发生的事务。虽然Debezium MySQL连接器不需要GTIDs，但使用GTIDs可以简化复制，并允许您更容易地确认主服务器和副本服务器是否一致。

```sql
gtid_mode=ON
enforce_gtid_consistency=ON
-- 校验
show global variables like '%GTID%';
```

### 设置会话超时时间

```
interactive_timeout=<duration-in-seconds>
wait_timeout= <duration-in-seconds>
```

### 开启查询log event

```sql
binlog_rows_query_log_events=ON
```

## 部署Mysql connector

### 安装Mysql Connector

#### 必需环境

* zk、kafka、kafka-connect、Mysql Server

#### 提供

* 将[mysql connector插件](https://repo1.maven.org/maven2/io/debezium/debezium-connector-mysql/1.3.0.Final/debezium-connector-mysql-1.3.0.Final-plugin.tar.gz)放入到kafkaConnect环境中
* 添加kafka connect配置`plugin.path=/kafka/connect`

### 配置Mysql connector

* 监听`inventory`库

```json
{
  "name": "inventory-connector", 
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector", 
    "database.hostname": "192.168.99.100", 
    "database.port": "3306", 
    "database.user": "debezium-user", 
    "database.password": "debezium-user-pw", 
    "database.server.id": "184054", 
    "database.server.name": "fullfillment", 
    "database.include.list": "inventory", 
    "database.history.kafka.bootstrap.servers": "kafka:9092", 
    "database.history.kafka.topic": "dbhistory.fullfillment", 
    "include.schema.changes": "true" 
  }
}
```

* 将配置添加至kafka connect
  * 使用[kafka connect restful api](https://kafka.apache.org/documentation/#connect_rest)

```
1. Method：POST，URL：http://ip:port/connectors 提交connector

2. Method：GET，URL：http://ip:port/connectors 获取所有connector

3. Method：DELETE，URL：http://ip:port/connectors/{connector name} 删除指定的connector name的connector

4. Method：GET，URL：http://ip:port/connectors/{connector name}/status 获取指定connecto name的运行状态

5. Method：POST，URL：http://ip:port/connectors/{connector name}/restart 重启指定connector name的connector

6. Method：GET，URL：http://ip:port/connectors/{connector name}/tasks/{task id}/status 获取指定task的运行状态

7. Method：GET，URL：http://ip:port/connector-plugins/ 获取kafka connect环境中的所有可执行connector plugins
```

