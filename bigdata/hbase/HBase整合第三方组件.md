# HBase整合MapReduce

## 环境准备

* 添加mapreduce所需Hbase jar包

```shell
# 查看MR所需jar依赖
hbase mapredcp
```

* 环境变量导入

  * 临时生效

  ```shell
  export HBASE=HOME=/Users/babywang/Documents/reserch/studySummary/module/hbase/hbase-2.3.0
  export HADOOP_HOME=/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5
  export HADOOP_CLASSPATH=`${HBASE_HOME}/bin/hbase mapredcp`
  ```

  * 永久生效

  ```shell
  # 配置Hadoop
  export HADOOP_HOME=/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5
  export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin
  # 配置Hbase
  export HBASE_HOME=/Users/babywang/Documents/reserch/studySummary/module/hbase/hbase-2.3.0
  export PATH=$PATH:$HBASE_HOME/bin
  ```

  * 修改hadoop-env.sh配置

  

  ```shell
  # 添加配置
  export HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$HBASE_HOME/lib
  ```

## 任务执行

### 使用MR导入数据至HBase

```shell
yarn jar $HBASE_HOME/lib/hbase-server-2.3.0.jar importtsv -Dimportsv.columns=HBASE_ROW_KEY,info:name,info:color fruit hdfs:///fruit.csv
```

### 自定义MapReduceHbase

* 写数据Reducer继承TableReducer，Driver端TableMapReduceUtil.initTableMapperJob()
* 读数据Mapper继承TableMapper,Driver端TableMapReduceUtil.initTableReducerJob()

# HBase整合Hive

## 环境准备

* 修改hive-env.sh

```shell
HADOOP_HOME=/Users/babywang/Documents/reserch/studySummary/module/hadoop-2.8.5
HBASE_HOME=/Users/babywang/Documents/reserch/studySummary/module/hbase/hbase-2.3.0
```

* 修改hive-site.xml

```shell
hive.zookeeper.quorum， hbase.zookeeper.quorum
```

## 创建hive和hbase表映射

```shell
create external table t_user (
        id string,
        name string,
        sex string
)
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES ("hbase.columns.mapping" = ":key,info:name,info:sex")
TBLPROPERTIES("hbase.table.name" = "bigdata:stu")
```



