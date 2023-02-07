# Flink SQL Gateway

## 概览

* SQL Gateway支持多种客户端远程并行的执行SQL的服务，它提供了一种提交Flink Job、查找元数据和在线分析数据的简单方法。SQL Gateway由可插拔的endpoint和SqlGatewayService组成。SqlGatewayService是一个被endpoint重用来处理请求的处理器。endpoint是允许用户连接的入口点。根据endpoint类型，用户可以使用不同的工具进行连接。

![](../img/sql gateway.jpg)

## 快速开始

* 启动flink集群&sql gateway

```shell
-- 启动flink standalone集群
./bin/start-cluster.sh
-- 启动sql gateway service，指定endpoint为本地
./bin/sql-gateway.sh start -Dsql-gateway.endpoint.rest.address=localhost
```

* 查看sql gateway版本

```shell
 curl http://localhost:8083/v1/info
 
 -- output
 {"productName":"Apache Flink","version":"1.16.1"}%
```

* 运行SQL

```shell
-- 开启会话
curl --request POST http://localhost:8083/v1/sessions
--output
{"sessionHandle":"472a226c-993d-4af0-822e-961493dfbc49"}%

-- 运行sql，传入sessionHandle
curl --request POST http://localhost:8083/v1/sessions/${sessionHandle}/statements/ --data '{"statement": "SELECT 1"}'
--demo
curl --request POST http://localhost:8083/v1/sessions/472a226c-993d-4af0-822e-961493dfbc49/statements/ --data '{"statement": "SELECT 1"}'
--output
{"operationHandle":"bb2e730d-a5ab-4dc2-b2c0-7d49e939f0a2"}%

-- 拉取结果 传入sessionHandle和operationHandle
curl --request GET http://localhost:8083/v1/sessions/${sessionHandle}/operations/${operationHandle}/result/0
--demo
curl --request GET http://localhost:8083/v1/sessions/472a226c-993d-4af0-822e-961493dfbc49/operations/bb2e730d-a5ab-4dc2-b2c0-7d49e939f0a2/result/0
--output
{"results":{"columns":[{"name":"EXPR$0","logicalType":{"type":"INTEGER","nullable":false},"comment":null}],"data":[{"kind":"INSERT","fields":[1]}]},"resultType":"PAYLOAD","nextResultUri":"/v1/sessions/472a226c-993d-4af0-822e-961493dfbc49/operations/bb2e730d-a5ab-4dc2-b2c0-7d49e939f0a2/result/1"}%

—— 获取下一行结果，窜如nextResultUri
curl --request GET ${nextResultUri}
--demo
curl --request GET http://localhost:8083/v1/sessions/472a226c-993d-4af0-822e-961493dfbc49/operations/bb2e730d-a5ab-4dc2-b2c0-7d49e939f0a2/result/1

```

## 配置

### SQL Gateway命令配置

```shell
./bin/sql-gateway.sh --help

Usage: sql-gateway.sh [start|start-foreground|stop|stop-all] [args]
  commands:
    start               - Run a SQL Gateway as a daemon
    start-foreground    - Run a SQL Gateway as a console application
    stop                - Stop the SQL Gateway daemon
    stop-all            - Stop all the SQL Gateway daemons
    -h | --help         - Show this help message
```

### SQL Gateway Configuration

```shell
$ ./sql-gateway -Dkey=value
```

| Key                                | Default | Type     | Description                                                  |
| :--------------------------------- | :------ | :------- | :----------------------------------------------------------- |
| sql-gateway.session.check-interval | 1 min   | Duration | 空闲session超时校验间隔，设置为0和负数表示关闭               |
| sql-gateway.session.idle-timeout   | 10 min  | Duration | session的空闲超时时间，设置为0和负数表示不会超时             |
| sql-gateway.session.max-num        | 1000000 | Integer  | sql gateway最大的session个数                                 |
| sql-gateway.worker.keepalive-time  | 5 min   | Duration | Keepalive time for an idle worker thread. When the number of workers exceeds min workers, excessive threads are killed after this time interval. |
| sql-gateway.worker.threads.max     | 500     | Integer  | The maximum number of worker threads for sql gateway service. |
| sql-gateway.worker.threads.min     | 5       | Integer  | The minimum number of worker threads for sql gateway service. |

## 支持的Endpoint

* hiveserver2

```shell
./bin/sql-gateway.sh start -Dsql-gateway.endpoint.type=hiveserver2
```

## RestFul Endpoint

* [操作文档](https://nightlies.apache.org/flink/flink-docs-release-1.16/zh/docs/dev/table/sql-gateway/rest/)

## HiveServer2 Endpoint

**注意:**将flink-sql-hive依赖放入flinkHome/lib目录下，否则启动hiveServer2时报错找不到factory

### 配置HiveSever2 Endpoint

* 启动sql gateway service指定

```shell
$ ./bin/sql-gateway.sh start -Dsql-gateway.endpoint.type=hiveserver2 -Dsql-gateway.endpoint.hiveserver2.catalog.hive-conf-dir=<path to hive conf>
```

* 配置在flink-conf.yaml下

```yaml
sql-gateway.endpoint.type: hiveserver2
sql-gateway.endpoint.hiveserver2.catalog.hive-conf-dir: <path to hive conf>
```

### 通过hive beeline连接HiveServer2

```shell
./beeline
```

### HiveSever2配置

| Key                                                          | Required | Default   | Type         | Description                                                  |
| :----------------------------------------------------------- | :------: | :-------- | :----------- | :----------------------------------------------------------- |
| sql-gateway.endpoint.type                                    | required | "rest"    | List<String> | rest或hiveserver2                                            |
| sql-gateway.endpoint.hiveserver2.catalog.hive-conf-dir       | required | (none)    | String       | URI to your Hive conf dir containing hive-site.xml. The URI needs to be supported by Hadoop FileSystem. If the URI is relative, i.e. without a scheme, local file system is assumed. If the option is not specified, hive-site.xml is searched in class path. |
| sql-gateway.endpoint.hiveserver2.catalog.default-database    | optional | "default" | String       | The default database to use when the catalog is set as the current catalog. |
| sql-gateway.endpoint.hiveserver2.catalog.name                | optional | "hive"    | String       | Name for the pre-registered hive catalog.                    |
| sql-gateway.endpoint.hiveserver2.module.name                 | optional | "hive"    | String       | Name for the pre-registered hive module.                     |
| sql-gateway.endpoint.hiveserver2.thrift.exponential.backoff.slot.length | optional | 100 ms    | Duration     | Binary exponential backoff slot time for Thrift clients during login to HiveServer2,for retries until hitting Thrift client timeout |
| sql-gateway.endpoint.hiveserver2.thrift.host                 | optional | (none)    | String       | The server address of HiveServer2 host to be used for communication.Default is empty, which means the to bind to the localhost. This is only necessary if the host has multiple network addresses. |
| sql-gateway.endpoint.hiveserver2.thrift.login.timeout        | optional | 20 s      | Duration     | Timeout for Thrift clients during login to HiveServer2       |
| sql-gateway.endpoint.hiveserver2.thrift.max.message.size     | optional | 104857600 | Long         | Maximum message size in bytes a HS2 server will accept.      |
| sql-gateway.endpoint.hiveserver2.thrift.port                 | optional | 10000     | Integer      | The port of the HiveServer2 endpoint.                        |
| sql-gateway.endpoint.hiveserver2.thrift.worker.keepalive-time | optional | 1 min     | Duration     | Keepalive time for an idle worker thread. When the number of workers exceeds min workers, excessive threads are killed after this time interval. |
| sql-gateway.endpoint.hiveserver2.thrift.worker.threads.max   | optional | 512       | Integer      | The maximum number of Thrift worker threads                  |
| sql-gateway.endpoint.hiveserver2.thrift.worker.threads.min   | optional | 5         | Integer      | The minimum number of Thrift worker threads                  |

### 客户端&工具

* HiveServer2 Endpoint与HiveServer2有线协议兼容。因此，管理Hive SQL的工具也适用于带有HiveServer2 Endpoint的SQL Gateway。目前，Hive JDBC, Hive Beeline, Dbeaver, Apache Superset等正在测试能够连接到Flink SQL网关与HiveServer2端点并提交SQL。

#### Hive JDBC

* 引入依赖

```xml
<dependency>
    <groupId>org.apache.hive</groupId>
    <artifactId>hive-jdbc</artifactId>
    <version>${hive.version}</version>
</dependency>
```

* 编写Java代码连接hiveserver2

```java

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

public class JdbcConnection {
    public static void main(String[] args) throws Exception {
        try (
                // Please replace the JDBC URI with your actual host, port and database.
                Connection connection = DriverManager.getConnection("jdbc:hive2://{host}:{port}/{database};auth=noSasl");
                Statement statement = connection.createStatement()) {
            statement.execute("SHOW TABLES");
            ResultSet resultSet = statement.getResultSet();
            while (resultSet.next()) {
                System.out.println(resultSet.getString(1));
            }
        }
    }
}
```

