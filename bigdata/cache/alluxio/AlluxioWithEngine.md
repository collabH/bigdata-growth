# Flink整合Alluxio

## 配置

* 修改hadoop的`core-site.xml`配置，增加alluxio文件系统实现

```xml
<property>
  <name>fs.alluxio.impl</name>
  <value>alluxio.hadoop.FileSystem</value>
</property>
```

* 修改`flink-conf.yaml`配置

```yaml
fs.hdfs.hadoopconf: core-site.xml配置路径
# 配置alluxio其他配置，通过env.java.opts方式添加
env.java.opts: -Dalluxio.user.file.writetype.default=CACHE_THROUGH
```

* 添加alluxio客户端jar包

  * 将`/<PATH_TO_ALLUXIO>/client/alluxio-2.8.0-SNAPSHOT-client.jar`文件放在Flink的`lib`目录下（对于本地模式以及独立集群模式）。
  * 将`/<PATH_TO_ALLUXIO>/client/alluxio-2.8.0-SNAPSHOT-client.jar`文件放在布置在Yarn中的Flink下的`ship`目录下。
  * 在`HADOOP_CLASSPATH`环境变量中指定该jar文件的路径（要保证该路径对集群中的所有节点都有效）。例如：

  ```shell
  $ export HADOOP_CLASSPATH=/<PATH_TO_ALLUXIO>/client/alluxio-2.8.0-SNAPSHOT-client.jar
  ```

## 使用案例

```shell
./bin/alluxio fs copyFromLocal LICENSE alluxio://localhost:19998/LICENSE
./bin/flink run examples/batch/WordCount.jar \
--input alluxio://localhost:19998/LICENSE \
--output alluxio://localhost:19998/output
```

# Spark整合Alluxio

* Alluxio帮助Spark在读取Hdfs或其他存储数据时提高了数据本地性的特性，从而加速Spark计算的性能与速度。

## 配置

* 下载`alluxio-version-client.jar`包
* 修改`spark-defualt.conf`配置，单个spark任务通过--conf方式设置driver和executor对应参数

```
spark.driver.extraClassPath   /<PATH_TO_ALLUXIO>/client/alluxio-2.8.0-SNAPSHOT-client.jar
spark.executor.extraClassPath /<PATH_TO_ALLUXIO>/client/alluxio-2.8.0-SNAPSHOT-client.jar
支持alluxio ha配置
spark.driver.extraJavaOptions   -Dalluxio.zookeeper.address=zkHost1:2181,zkHost2:2181,zkHost3:2181 -Dalluxio.zookeeper.enabled=true
spark.executor.extraJavaOptions -Dalluxio.zookeeper.address=zkHost1:2181,zkHost2:2181,zkHost3:2181 -Dalluxio.zookeeper.enabled=true
```

* 修改hdfs的`core-site.xml`支持alluxio ha

```xml
<configuration>
  <property>
    <name>alluxio.zookeeper.enabled</name>
    <value>true</value>
  </property>
  <property>
    <name>alluxio.zookeeper.address</name>
    <value>zkHost1:2181,zkHost2:2181,zkHost3:2181</value>
  </property>
</configuration>
```



## 使用案例

### spark-shell

```shell
# spark读取alluxio
> val s = sc.textFile("alluxio://localhost:19998/Input")
> val double = s.map(line => line + line)
> double.saveAsTextFile("alluxio://localhost:19998/Output")
# spark读取为全局配置ha的alluxio
> val s = sc.textFile("alluxio://zk@zkHost1:2181;zkHost2:2181;zkHost3:2181/Input")
> val double = s.map(line => line + line)
> double.saveAsTextFile("alluxio://zk@zkHost1:2181;zkHost2:2181;zkHost3:2181/Output")

# 缓存RDD到alluxio中1.saveAsTextFile：将 RDD 作为文本文件写入，其中每个元素都是文件中的一行， 2.saveAsObjectFile：通过对每个元素使用 Java 序列化，将 RDD 写到一个文件中。
// as text file
> rdd.saveAsTextFile("alluxio://localhost:19998/rdd1")
> rdd = sc.textFile("alluxio://localhost:19998/rdd1")

// as object file
> rdd.saveAsObjectFile("alluxio://localhost:19998/rdd2")
> rdd = sc.objectFile("alluxio://localhost:19998/rdd2")

# 缓存dataFrame到alluxio中
> df.write.parquet("alluxio://localhost:19998/data.parquet")
> df = sqlContext.read.parquet("alluxio://localhost:19998/data.parquet")
```

# Hive整合Alluxio

## 配置

* 修改`hive-env.sh`的`HIVE_AUX_JARS_PATH`环境变量

```shell
export HIVE_AUX_JARS_PATH=/<PATH_TO_ALLUXIO>/client/alluxio-2.8.0-SNAPSHOT-client.jar:${HIVE_AUX_JARS_PATH}
```

* 使用alluxio作为默认文件系统，修改`hive-site.xml`配置

```xml
<property>
   <name>fs.defaultFS</name>
   <value>alluxio://master_hostname:port</value>
</property>
<!--其他配置-->
<property>
<name>alluxio.user.file.writetype.default</name>
<value>CACHE_THROUGH</value>
</property>
```



## 使用案例

### 读取alluxio

```sql
hive> CREATE TABLE u_user (
userid INT,
age INT,
gender CHAR(1),
occupation STRING,
zipcode STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '|'
STORED AS TEXTFILE
LOCATION 'alluxio://master_hostname:port/ml-100k';
```

### 将hive hdfs表存储至alluxio

* 前置条件需要将alluxio的底层根ufs存储改为hdfs

```shell
# 修改底层data存储路径
alter table u_user set location "alluxio://master_hostname:port/user/hive/warehouse/u_user";
```