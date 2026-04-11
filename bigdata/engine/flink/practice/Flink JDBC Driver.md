# Flink JDBC Driver

* Flink JDBC Driver是一个JAVA库，用于链接和提交SQL语句至SQL Gateway作为JDBC服务

## 依赖

```xml
 <dependency>
      <groupId>org.apache.flink</groupId>
      <artifactId>flink-sql-jdbc-driver-bundle</artifactId>
      <version>{VERSION}</version>
    </dependency>
```

## 通过JDBC工具使用

### 通过Beeline使用

#### 使用方式

1. 从[下载页](https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-jdbc-driver-bundle/)下载flink-jdbc-driver-bundle-{VERSION}.jar并放置 `$HIVE_HOME/lib`目录下
2. 运行beeline并且链接Flink SQL gateway，由于Flink SQL网关目前忽略用户名和密码，因此将其保留为空。

```shell
beeline> !connect jdbc:flink://localhost:8083
```

3. 执行Flink SQL语句

#### 使用样例

```shell
$ ./bin/beeline
SLF4J: Class path contains multiple SLF4J bindings.
SLF4J: Found binding in [jar:file:/Users/huangshimin/Documents/dev/soft/hadoop330/share/hadoop/common/lib/slf4j-log4j12-1.7.25.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: Found binding in [jar:file:/Users/huangshimin/Documents/study/apache-hive-3.1.3-bin/lib/log4j-slf4j-impl-2.17.1.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.
SLF4J: Actual binding is of type [org.slf4j.impl.Log4jLoggerFactory]
Beeline version 3.1.3 by Apache Hive
beeline> !connect jdbc:flink://localhost:8083
Connecting to jdbc:flink://localhost:8083
Enter username for jdbc:flink://localhost:8083:
Enter password for jdbc:flink://localhost:8083:
2024-07-10 20:06:08,938 INFO  [main] gateway.ExecutorImpl (ExecutorImpl.java:<init>(196)) - Open session to http://localhost:8083 with connection version: V2.
Connected to: Flink JDBC Driver (version 1.19.1)
Driver: org.apache.flink.table.jdbc.FlinkDriver (version 1.19.1)
Transaction isolation: TRANSACTION_REPEATABLE_READ
0: jdbc:flink://localhost:8083> CREATE TABLE Orders1 (
. . . . . . . . . . . . . . . >     order_number BIGINT,
. . . . . . . . . . . . . . . >     price        DECIMAL(32,2),
. . . . . . . . . . . . . . . >     order_time   TIMESTAMP(3)
. . . . . . . . . . . . . . . > ) WITH (
. . . . . . . . . . . . . . . >   'connector' = 'datagen',
. . . . . . . . . . . . . . . >   'number-of-rows' = '100000'
. . . . . . . . . . . . . . . > );
No rows affected (0.252 seconds)
0: jdbc:flink://localhost:8083> show tables;
+-------------+
| table name  |
+-------------+
| Orders1     |
+-------------+
1 row selected (0.187 seconds)
0: jdbc:flink://localhost:8083> select * from Orders1 limit 1;
+-----------------------+------------------------------------+-------------------------+
|     order_number      |               price                |       order_time        |
+-----------------------+------------------------------------+-------------------------+
| -8925792978898634601  | 928660464768471256156493316096.00  | 2024-07-10 12:06:22.93  |
+-----------------------+------------------------------------+-------------------------+
1 row selected (0.36 seconds)
0: jdbc:flink://localhost:8083> select * from Orders1 limit 10;
+-----------------------+------------------------------------+--------------------------+
|     order_number      |               price                |        order_time        |
+-----------------------+------------------------------------+--------------------------+
| 6845947620916771601   | 152176180563691316002802368512.00  | 2024-07-10 12:06:26.328  |
| -5845531854496852353  | 874386931211298967208509571072.00  | 2024-07-10 12:06:26.328  |
| -3374204547766823026  | 700206785736831707966462754816.00  | 2024-07-10 12:06:26.328  |
| -118569789885885190   | 807206073540882538845851090944.00  | 2024-07-10 12:06:26.328  |
| 8729526272103890540   | 184570783236994272209653465088.00  | 2024-07-10 12:06:26.328  |
| -6553459492948649490  | 63523836187986851425993883648.00   | 2024-07-10 12:06:26.328  |
| 8655237525058697403   | 894404171516706202036169867264.00  | 2024-07-10 12:06:26.328  |
| 7406581249934923889   | 960741542334632237281738489856.00  | 2024-07-10 12:06:26.328  |
| -5115163396590008352  | 456873282194991668283029061632.00  | 2024-07-10 12:06:26.328  |
| -7673905736081700623  | 293902855807253851765653635072.00  | 2024-07-10 12:06:26.328  |
+-----------------------+------------------------------------+--------------------------+
10 rows selected (0.299 seconds)
0: jdbc:flink://localhost:8083>
```

## 通过应用使用

### 使用Java

* 项目中添加flink jdbc driver依赖
* java代码里链接flink sql gateway
* 执行flink sql

#### 使用JDBC Driver

```java
public static void main(String[] args) throws Exception {
        try (Connection connection = DriverManager.getConnection("jdbc:flink://localhost:8083")) {
            try (Statement statement = connection.createStatement()) {
                statement.execute("CREATE TABLE T(\n" +
                        "  a INT,\n" +
                        "  b VARCHAR(10)\n" +
                        ") WITH (\n" +
                        "  'connector' = 'datagen',\n" +
                        "  'number-of-rows' = '100000'\n"+
                        ")");
                try (ResultSet rs = statement.executeQuery("SELECT * FROM T")) {
                    while (rs.next()) {
                        System.out.println(rs.getInt(1) + ", " + rs.getString(2));
                    }
                }
            }
        }
    }
```

#### 使用Flink DataSource

```java
public static void main(String[] args) throws Exception {
    DataSource dataSource = new FlinkDataSource("jdbc:flink://localhost:8083", new Properties());
    Connection connection = dataSource.getConnection();
    Statement statement = connection.createStatement();
    statement.execute("CREATE TABLE T(\n" +
            "  a INT,\n" +
            "  b VARCHAR(10)\n" +
            ") WITH (\n" +
            "  'connector' = 'datagen',\n" +
            "  'number-of-rows' = '100000'\n"+
            ")");
    try (ResultSet rs = statement.executeQuery("SELECT * FROM T Limit 100")) {
        while (rs.next()) {
            System.out.println(rs.getInt(1) + ", " + rs.getString(2));
        }
    }
}
```

* 其他JVM语言，也可以通过上述方式通过jdbc driver提交flinksql，类似scala、kotlin和ect语言等；

# SQL客户端

* *SQL 客户端* 的目的是提供一种简单的方式来编写、调试和提交表程序到 Flink 集群上，而无需写一行 Java 或 Scala 代码。*SQL 客户端命令行界面（CLI）* 能够在命令行中检索和可视化分布式应用中实时产生的结果。

## 启动SQL客户端

* 通过执行$FLINK_HOME/bin目录下的`sql-client.sh`命令，来运行sql客户端，默认使用 `embedded` 模式

```shell
./bin/sql-client.sh
-- 显示指定sql客户端执行模式，指定embedded模式
./bin/sql-client.sh embedded
-- 指定gateway方式
./bin/sql-client.sh gateway --endpoint <gateway address>
```

## 执行SQL

### 可视化模式

* 客户端可视化模式支持3种，分别为tableau、table、changelog
  * **表格模式**（table mode）在内存中实体化结果，并将结果用规则的分页表格可视化展示出来。
  * **变更日志模式**（changelog mode）不会实体化和可视化结果，而是由插入（`+`）和撤销（`-`）组成的持续查询产生结果流。
  * **Tableau模式**（tableau mode）更接近传统的数据库，会将执行的结果以制表的形式直接打在屏幕之上。

```shell
-- table、changelog、tableau
SET 'sql-client.execution.result-mode' = 'table';
```