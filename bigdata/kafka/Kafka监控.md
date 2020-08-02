# Kafka Eagle

## KafkaEagle概述

![img](https://images2018.cnblogs.com/blog/666745/201807/666745-20180726155027971-1664616298.png)

## 

## 安装

### Kafka-Eagle环境准备

* clone kafka-eagle代码

```shell
git clone git@github.com:smartloli/kafka-eagle.git
```

* 修改项目build脚本

```shell
mvn clean package -DskipTests -s $MAVEN_HOME/conf/dev-settings.xml
```

* 运行build文件，进入kafka-eagle-web/target目录拷贝kafka-eagle-web.tar.gz和ke.war包

### 环境配置

* 配置JAVA_HOME和KE_HOME

```
export KE_HOME=/Users/babywang/Documents/reserch/middleware/kafka/monitor/kafka-eagle
export PATH=$PATH:$KE_HOME/bin
```

* 修改$KE_HOME/conf/system-config.properties

```properties
######################################
# multi zookeeper & kafka cluster list
# 配置多个Kafka集群所对应的Zookeeper
######################################
kafka.eagle.zk.cluster.alias=cluster1
cluster1.zk.list=hadoop:2182,hadoop:2183,hadoop:2184
#cluster2.zk.list=xdn10:2181,xdn11:2181,xdn12:2181

######################################
# broker size online list
######################################
cluster1.kafka.eagle.broker.size=20

######################################
# zk client thread limit  设置Zookeeper线程数
######################################
kafka.zk.limit.size=25

######################################
# kafka eagle webui port 设置webui端口
######################################
kafka.eagle.webui.port=8048

######################################
# kafka offset storage 设置offset存储地址
######################################
cluster1.kafka.eagle.offset.storage=kafka
# cluster2.kafka.eagle.offset.storage=zk

######################################
# kafka metrics, 15 days by default 是否启动监控图表
######################################
kafka.eagle.metrics.charts=true
kafka.eagle.metrics.retain=15


######################################
# kafka sql topic records max
# 在使用Kafka SQL查询主题时，如果遇到错误，
# 可以尝试开启这个属性，默认情况下，不开启
######################################
kafka.eagle.sql.topic.records.max=5000
kafka.eagle.sql.fix.error=true

######################################
# delete kafka topic token
######################################
kafka.eagle.topic.token=keadmin

######################################
# kafka sasl authenticate
######################################
cluster1.kafka.eagle.sasl.enable=false
cluster1.kafka.eagle.sasl.protocol=SASL_PLAINTEXT
cluster1.kafka.eagle.sasl.mechanism=SCRAM-SHA-256
cluster1.kafka.eagle.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="kafka" password="kafka-eagle";
cluster1.kafka.eagle.sasl.client.id=
cluster1.kafka.eagle.sasl.cgroup.enable=false
cluster1.kafka.eagle.sasl.cgroup.topics=

cluster2.kafka.eagle.sasl.enable=false
cluster2.kafka.eagle.sasl.protocol=SASL_PLAINTEXT
cluster2.kafka.eagle.sasl.mechanism=PLAIN
cluster2.kafka.eagle.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="kafka" password="kafka-eagle";
cluster2.kafka.eagle.sasl.client.id=
cluster2.kafka.eagle.sasl.cgroup.enable=false
cluster2.kafka.eagle.sasl.cgroup.topics=

######################################
# kafka ssl authenticate
######################################
cluster3.kafka.eagle.ssl.enable=false
cluster3.kafka.eagle.ssl.protocol=SSL
cluster3.kafka.eagle.ssl.truststore.location=
cluster3.kafka.eagle.ssl.truststore.password=
cluster3.kafka.eagle.ssl.keystore.location=
cluster3.kafka.eagle.ssl.keystore.password=
cluster3.kafka.eagle.ssl.key.password=
cluster3.kafka.eagle.ssl.cgroup.enable=false
cluster3.kafka.eagle.ssl.cgroup.topics=

######################################
# kafka sqlite jdbc driver address
######################################
kafka.eagle.driver=org.sqlite.JDBC
kafka.eagle.url=jdbc:sqlite:/hadoop/kafka-eagle/db/ke.db
kafka.eagle.username=root
kafka.eagle.password=www.kafka-eagle.org

######################################
# kafka mysql jdbc driver address
######################################
kafka.eagle.driver=com.mysql.jdbc.Driver
kafka.eagle.url=jdbc:mysql://127.0.0.1:3306/ke?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull
kafka.eagle.username=root
kafka.eagle.password=root
```

* 修改ke.sh权限

```shell
chmod +x $KE_HOME/bin/ke.sh
```

* 启动kafka-eagle

```shell
ke.sh start

# 默认账号密码
* Account:admin ,Password:123456
```

### 修改Kafka集群启动脚本配置开发JMX上报端口

```shell
vi kafka-server-start.sh

if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
    export KAFKA_HEAP_OPTS="-server -Xms2G -Xmx2G -XX:PermSize=128m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=8 -XX:ConcGCThreads=5 -XX:InitiatingHeapOccupancyPercent=70"
    export JMX_PORT="9999"
    #export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
fi
```

