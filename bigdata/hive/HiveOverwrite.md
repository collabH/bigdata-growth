# Hive架构图 

![图片](https://uploader.shimo.im/f/bsvvnL6jg8gzvrMQ.png!thumbnail)

## Client 


* hive shell、JDBC/ODBC(java访问hive)、WEBUI 
## 元数据:Meta store 


* 表名、表所属数据库、表的拥有者、列/分区字段、表的类型、表的数据所在目录 
## Driver 


* 解析器：将SQL字符串转换成抽象语法树AST，一般使用antlr对AST进行语法分析，比如表是否存在等 
* 编译器:将AST编译生成执行计划 
* 优化器：对逻辑执行计划进行优化 
* 执行器：基于MR/Spark做计算 
# Hive的运行机制 

![图片](https://uploader.shimo.im/f/gBD9rs2oeDjRwgDR.png!thumbnail)

# Hive和数据库比较 

## 查询语言 


* Hive提供类SQL的语言，HQL。 
## 数据存储位置 


* Hive存在在Hadoop的HDFS或者其他分布式文件系统中，数据库存放在数据库中 
## 数据更新 


* Hive适合读多写少的，Hive不建议对数据进行改写，所有数据都在加载确定好的，数据库则适合传统的curd。 
## 索引 


* Hive在加载数据的过程中不会对数据做任何处理，甚至不会对数据进行扫描，因此也没有对数据的某些key建立索引。Hive要访问数据中满足条件的特定值时，需要暴力扫描整个目录的数据。但是Hive可以基于Spark、MR做并行访问数据，因此可以支持大量数据访问。Hive支持BitMap和Compact索引。 
# 配置MySql metastore 

```xml
<?xml version="1.0"?> 
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?> 
<configuration> 
　<property> 
　　<name>javax.jdo.option.ConnectionURL</name> 
　　<value>jdbc:mysql://db1.mydomain.pvt/hive_db?createDatabaseIfNotExist=true</value> 
　</property> 
　　<property> 
　　<name>javax.jdo.option.ConnectionDriverName</name> 
　　<value>com.mysql.jdbc.Driver</value> 
　</property> 
　<property> 
　　<name>javax.jdo.option.ConnectionUserName</name> 
　　<value>database_user</value> 
　</property> 
　<property> 
　　<name>javax.jdo.option.ConnectionPassword</name> 
　　<value>database_pass</value> 
　</property> 
</configuration> 
```

* 将mysql驱动放入hive的lib目录下 
* $HIVE_HOME/scripts/metastore/upgrade/mysql找到对应版本的scheme.sql 
# 加载数据的方式 

## 加载本地数据 


* load data local inpath 'pat' into table tablename; 
* hdfs dfs -put tes.txt path; 
```plain
hdfs dfs -put text.txt /user/hive/warehouse/test/a.txt;  
```

* hdfs dfs -copyFromLocal text.txt path; 
```shell
hdfs dfs -copyFromLocal text.txt /user/hive/warehouse/test/b.txt; 
```
## 远程加载数据 


* load data inpath 'path' into table tablename; 
# 常见属性配置 

## 数据仓库位置配置 

```plain
<property> 
    <name>hive.metastore.warehouse.dir</name> 
    <value>/user/hive/warehouse</value> 
    <description>location of default database for the warehouse</description> 
</property> 
```
## 查询后信息显示配置 

```plain
# 查询显示列名 
<property> 
    <name>hive.cli.print.header</name> 
    <value>true</value> 
    <description>Whether to print the names of the columns in query output.</description> 
  </property> 
# 查询显示当前数据库 
 <property> 
    <name>hive.cli.print.current.db</name> 
    <value>true</value> 
    <description>Whether to include the current database in the Hive prompt.</description> 
  </property> 
```
## 运行日志配置 


* hive的默认日志存储在当前用户名下 
* 修改hive的log存放位置 
```plain
1.修改hive-log4j.properties文件的hive.log.dir地址 
```
