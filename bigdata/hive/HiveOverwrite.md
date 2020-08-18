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
# Hive安装部署

## hive-env.sh

```shell
# 配置Hadoop Home
HADOOP_HOME=/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5
# 配置HIVE_CONF_DIR
export HIVE_CONF_DIR=/Users/babywang/Documents/reserch/studySummary/module/hive/apache-hive-2.3.6-bin/conf
```

## 集群配置

```shell
# hdfs上创建tmp和/user/hive/warehouse目录
hdfs dfs -mkdir /tmp
hdfs dfs -mkdir -p /user/hive/warehouse
# 添加组权限
hdfs dfs -chmod g+w /tmp
hdfs dfs -chmod g+w /user/hive/warehouse
```

## 配置MySql metastore

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

## 常见属性配置 

### 数据仓库位置配置 

```xml
<property> 
    <name>hive.metastore.warehouse.dir</name> 
    <value>/user/hive/warehouse</value> 
    <description>location of default database for the warehouse</description> 
</property> 
```

### 查询后信息显示配置 

```shell
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

### 运行日志配置 

```shell
1.Hive的log默认存放在/tmp/atguigu/hive.log目录下（当前用户名下）

2．修改hive的log存放日志到/opt/module/hive/logs

​	（1）修改/opt/module/hive/conf/hive-log4j.properties.template文件名称为

hive-log4j.properties

[atguigu@hadoop102 conf]$ pwd

/opt/module/hive/conf

mv hive-log4j.properties.template hive-log4j.properties

​	（2）在hive-log4j.properties文件中修改log存放位置

hive.log.dir=/opt/module/hive/logs
```

## 关闭元数据检查

* 修改hive-site.xml

```xml
<property>
    <name>hive.metastore.schema.verification</name>
    <value>false</value>
</property>
```

# Hive运行Tez

* Hive底层MR引擎

![Flow for a Hive or Pig Query on MapReduce](http://tez.apache.org/images/PigHiveQueryOnMR.png)

* Tez引擎

![Flow for a Hive or Pig Query on Tez](http://tez.apache.org/images/PigHiveQueryOnTez.png)

```latex
用Hive直接编写MR程序，假设有四个有依赖关系的MR作业，上图中，绿色是Reduce Task，云状表示写屏蔽，需要将中间结果持久化写到HDFS。
Tez可以将多个有依赖的作业转换为一个作业，这样只需写一次HDFS，且中间节点较少，从而大大提升作业的计算性能。
```

## Hive中配置Tez

### 环境准备

```shell
# 下载tez
curl https://mirrors.tuna.tsinghua.edu.cn/apache/tez/0.9.2/
```

### 配置hive-env.sh

```shell
export TEZ_HOME=/Users/babywang/Documents/reserch/studySummary/module/tez-0.9.2
export TEZ_JARS=""
# 将jar包放入TEZ_JARS变量中
for jar in `ls $TEZ_HOME |grep jar`; do
    export TEZ_JARS=$TEZ_JARS:$TEZ_HOME/$jar
done
# 将lib下的jar放入TEZ_JARS中
for jar in `ls $TEZ_HOME/lib`; do
    export TEZ_JARS=$TEZ_JARS:$TEZ_HOME/lib/$jar
done

# 放入到hive lib下
export HIVE_AUX_JARS_PATH=/Users/babywang/Documents/reserch/studySummary/module/hive/apache-hive-2.3.6-bin/lib$TEZ_JARS
```

### 配置hive-site.xml

```shell
<property>
    <name>hive.execution.engine</name>
    <value>tez</value>
</property>
```

## 配置tez

### tez-site.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>tez.lib.uris</name>    
    <value>${fs.defaultFS}/tez/tez-0.9.2,${fs.defaultFS}/tez/tez-0.9.2/lib</value>
  </property>
<property>
  <name>tez.lib.uris.classpath</name>
  <value>${fs.defaultFS}/tez/tez-0.9.2,${fs.defaultFS}/tez/tez-0.9.2/lib</value>
</property>
<property>
     <name>tez.use.cluster.hadoop-libs</name>
     <value>true</value>
</property>
<property>
     <name>tez.history.logging.service.class</name>
     <value>org.apache.tez.dag.history.logging.ats.ATSHistoryLoggingService</value>
</property>
</configuration>
```

### 上传Tez到集群

```shell
# 创建tez目录
hdfs dfs -mkdir /tez
# 上传tez
hdfs dfs -put tez-0.9.2/ /tez
```

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