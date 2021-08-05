# Spark实践

## 动态加载hadoop环境

```java
def chooseHadoopEnv(sparkBuilder: SparkSession.Builder, hiveConfDir: String, hadoopConfDir: String) = {
    val configuration: Configuration = new Configuration()

    // 这里的文件地址可以换成从数据库里查询
    val core = new Path(s"${hadoopConfDir}/core-site.xml")
    val hdfs = new Path(s"${hadoopConfDir}/hdfs-site.xml")
    val yarn = new Path(s"${hadoopConfDir}/yarn-site.xml")
    val hive = new Path(s"${hiveConfDir}/hive-site.xml")
    configuration.addResource(core)
    configuration.addResource(hdfs)
    configuration.addResource(yarn)
    configuration.addResource(hive)
    for (c <- configuration) {
      sparkBuilder.config(c.getKey, c.getValue)
    }
    sparkBuilder
  }
```

```java
 /**
   * 选择不同的hadoop环境
   *
   */
  def chooseHive(sparkBuilder: SparkSession.Builder, hiveMetaStoreUri: String) = {
    sparkBuilder.config("hive.metastore.uris", hiveMetaStoreUri)
  }

  def chooseHadoop(spark: SparkSession, nameSpace: String, nn1: String, nn1Addr: String, nn2: String, nn2Addr: String)
  = {
    val sc: SparkContext = spark.sparkContext
    sc.hadoopConfiguration.set(s"fs.defaultFS", s"hdfs://$nameSpace")
    sc.hadoopConfiguration.set(s"dfs.nameservices", nameSpace)
    sc.hadoopConfiguration.set(s"dfs.ha.namenodes.$nameSpace", s"$nn1,$nn2")
    sc.hadoopConfiguration.set(s"dfs.namenode.rpc-address.$nameSpace.$nn1", nn1Addr)
    sc.hadoopConfiguration.set(s"dfs.namenode.rpc-address.$nameSpace.$nn2", nn2Addr)
    sc.hadoopConfiguration.set(s"dfs.client.failover.proxy.provider.$nameSpace", "org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider")
  }
```

* Tez类找不到问题:移除hive-site.xml tez查询引擎配置即可
