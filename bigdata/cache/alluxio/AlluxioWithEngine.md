# Spark整合Alluxio

* Alluxio帮助Spark在读取Hdfs或其他存储数据时提高了数据本地性的特性，从而加速Spark计算的性能与速度。

## 整合配置

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