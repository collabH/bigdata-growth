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

* Tez类找不到问题:移除hive-site.xml tez查询引擎配置即可