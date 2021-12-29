# 概述

* Sqoop是用于Hadoop(Hive)与传统数据库(mysql、postgresql..)间进行数据的传递，可以将一个关系型数据库中的数据导进Hadoop的HDFS中，也可以将HDFS的数据导进到关系型数据库中。
* 将导入或到处命令翻译成mapreduce程序来实现，在翻译出的mapreduce中主要是对inputformat和outputformat进行定制。

# 安装

## 环境准备

* Java环境和Hadoop环境

## 下载

* https://mirror.bit.edu.cn/apache/sqoop/1.4.7

```shell
# 解压
tar -zxvf sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz
# 配置环境变量
export SQOOP_HOME=/Users/babywang/Documents/reserch/studySummary/module/sqoop/sqoop-1.4.7
export PATH=$PATH:$SQOOP_HOME/bin
```

* 修改 sqoop-env-template.sh

```shell
mv  sqoop-env-template.sh  sqoop-env.sh

export HADOOP_COMMON_HOME=/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5
#Set path to where hadoop-*-core.jar is available
#export HADOOP_MAPRED_HOME=
export HADOOP_MAPRED_HOME=/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5
#set the path to where bin/hbase is available
#export HBASE_HOME=
export HBASE_HOME/Users/babywang/Documents/reserch/studySummary/module/hbase/hbase-2.3.0
#Set the path to where bin/hive is available
#export HIVE_HOME=
export HIVE_HOME=/Users/babywang/Documents/reserch/studySummary/bigdata/hive/apache-hive-2.3.6-bin
#Set the path for where zookeper config dir is
#export ZOOCFGDIR=
export ZOOKEEPER_HOME=/Users/babywang/Documents/reserch/middleware/zk/zookeeper-3.5.5
export ZOOCFGDIR=$ZOOKEEPER_HOME/../zkDataDir
```

* 拷贝JDBC驱动到lib下

```shell
cp $MAVEN_HOME/../maven-resp/mysql/mysql-connector-java/8.0.15/mysql-connector-java-8.0.15.jar ../lib
```

* 校验sqoop

```shell
sqoop help
```

* 测试链接mysql查看全部database

```shell
sqoop list-databases --connect jdbc:mysql://hadoop:3306/ --username root --password root
```

# 使用案例

## 导入数据

* 导入数据概念为从非大数据集群(RDBMS)向大数据集群(HDFS，Hive，HBASE)中传输数据，叫做导入，即使用import关键字

### RDBMS到HDFS

* 全部导入

```shell
sqoop import --connect jdbc:mysql://hadoop:3306/ke \
--username root --password root --table ke_metrics \
# hdfs参数配置
--target-dir /user/ke_metrics \
--delete-target-dir \
--num-mappers 1 \
--fields-terminated-by "\t"
```

* 查询导入,`$CONDITIONS`保证多map下也会保证数据顺序一致，不添加Sqoop会报错

```shell
sqoop import --connect jdbc:mysql://hadoop:3306/ke \
--username root --password root \
--target-dir /user/ke_metrics \
--delete-target-dir \
--num-mappers 1 \
--fields-terminated-by "\t" \
--query 'select * from ke_metrics where $CONDITIONS limit 200;'
```

* 导入指定的列

```shell
sqoop import --connect jdbc:mysql://hadoop:3306/ke \
--username root --password root \
--target-dir /user/ke_metrics \
--delete-target-dir \
--num-mappers 1 \
--fields-terminated-by "\t" \
--columns cluster,broker \
--table ke_metrics
```

* 按照指定条件导入

```shell
sqoop import --connect jdbc:mysql://hadoop:3306/ke \
--username root \
--password root \
--target-dir /user/ke_metrics \
--delete-target-dir \
--num-mappers 1 \
--fields-terminated-by "\t" \
--table ke_metrics \
--where 'cluster="cluster1"'
```

### RDBMS到HIVE

```shell
sqoop import --connect jdbc:mysql://hadoop:3306/ke \
--username root \
--password root \
--num-mappers 1 \
--table ke_metrics \
--hive-home /user/hive/warehouse/ \
--hive-import \
--fields-terminated-by "\t" \
--hive-overwrite \
--hive-table  ke_metrics1 \
--hive-drop-import-delims 
```

* 第一步将mysql数据导入/user/${user}文件夹下，然后在导入到hive的home目录下

### RDMS到HBase

```shell
sqoop import --connect jdbc:mysql://hadoop:3306/ke \
--username root \
--password root \
--num-mappers 1 \
--table ke_metrics \
--columns "id,name" \
--column-family "info" \
--hbase-create-table \
--hbase-row-key "id" \
--hbase-table "hbase_company" \
--split-by id
```

## 导出数据

* 导出概念为从大数据集群(HDFS、HIVE、HBASE)向非大数据集群RDBMS中传输数据，通过export关键字

### HIVE/HDFS到RDBMS

```shell
sqoop export \
--connect jdbc:mysql://hadoop:3306/ke \
--username root \
--password root \
--table ke_metrics \
--num-mappers 1 \
--export-dir /user/hive/warehouse/ke_metrics \
--input-fields-terminated-by "\t"
```



## 脚本打包

* 使用opt打包sqoop命令，执行脚本

```shell
mkdir opt
touch opt/job_HDFS2RDBMS.opt
```

* 编写sqoop脚本

```shell
export
--connect
jdbc:mysql://hadoop:3306/ke
--username
root
--password
root
--table
ke_metrics
--num-mappers
1
--export-dir
/user/hive/warehouse/ke_metrics
--input-fields-terminated-by
"\t"
```

* 执行脚本

```shell
sqoop --options-file  HDFS2DBMS.opt
```

# 参数配置

## 数据库连接

| Argument               | Description            |
| ---------------------- | ---------------------- |
| `--connect`            | 连接到关系型数据库url  |
| `--connection-manager` | 指定要使用的连接管理类 |
| `--driver`             | Hadoop根目录           |
| `--help`               | 打印帮助信息           |
| `--password`           | 连接数据库的密码       |
| `--username`           | 连接数据库的用户名     |
| `--verbose`            | 在控制台打印出详细信息 |

## import

| Argument                          | Description                                                  |
| --------------------------------- | ------------------------------------------------------------ |
| `--enclosed-by <char>`            | 给字段值前加上指定的字符                                     |
| `--escaped-by <char>`             | 对字段中的双引号加转义符                                     |
| `--fields-terminated-by <char>`   | 设定每个字段是以什么符号作为结束，默认为逗号                 |
| `--lines-terminated-by <char>`    | 设定每行记录之间的分隔符，默认是\n                           |
| `--mysql-delimiters`              | Mysql默认的分隔符设置，字段之间以逗号分隔，行之间以\n分隔，默认转义符是\，字段值以单引号包裹。 |
| `--optionally-enclosed-by <char>` | 给带有双引号或单引号的字段值前后加上指定字符。               |

## export

| Argument                              | Description                                |
| ------------------------------------- | ------------------------------------------ |
| `--input-enclosed-by <char>`          | 对字段值前后加上指定字符                   |
| `--input-escaped-by <char>`           | 对含有转移符的字段做转义处理               |
| `--input-fields-terminated-by <char>` | 字段之间的分隔符                           |
| `--input-lines-terminated-by<char>`   | 行之间的分隔符                             |
| `--input-optionally-enclosed-by`      | 给带有双引号或单引号的字段前后加上指定字符 |

## Hive

| Argument                     | Description                                                  |
| ---------------------------- | ------------------------------------------------------------ |
| `--hive-home <dir>`          | Override `$HIVE_HOME`                                        |
| `--hive-import`              | Import tables into Hive (Uses Hive’s default delimiters if none are set.) |
| `--hive-overwrite`           | Overwrite existing data in the Hive table.                   |
| `--create-hive-table`        | If set, then the job will fail if the target hive            |
|                              | table exists. By default this property is false.             |
| `--hive-table <table-name>`  | Sets the table name to use when importing to Hive.           |
| `--hive-drop-import-delims`  | Drops *\n*, *\r*, and *\01* from string fields when importing to Hive. |
| `--hive-delims-replacement`  | Replace *\n*, *\r*, and *\01* from string fields with user defined string when importing to Hive. |
| `--hive-partition-key`       | Name of a hive field to partition are sharded on             |
| `--hive-partition-value <v>` | String-value that serves as partition key for this imported into hive in this job. |
| `--map-column-hive <map>`    | Override default mapping from SQL type to Hive type for configured columns. If specify commas in this argument, use URL encoded keys and values, for example, use DECIMAL(1%2C%201) instead of DECIMAL(1, 1). |

## HBase

| Argument                     | Description                                                  |
| ---------------------------- | ------------------------------------------------------------ |
| `--column-family <family>`   | Sets the target column family for the import                 |
| `--hbase-create-table`       | If specified, create missing HBase tables                    |
| `--hbase-row-key <col>`      | Specifies which input column to use as the row key           |
|                              | In case, if input table contains composite                   |
|                              | key, then <col> must be in the form of a                     |
|                              | comma-separated list of composite key                        |
|                              | attributes                                                   |
| `--hbase-table <table-name>` | Specifies an HBase table to use as the target instead of HDFS |
| `--hbase-bulkload`           | Enables bulk loading                                         |

