# Kafka&Zookeeper监控

## 开启Zookeeper监控

### 修改zk-Server.sh文件

* JMXPORT端口

```shell
-Dcom.sun.management.jmxremote.port=$JMXPORT
```

* JMXAUTH

```shell
-Dcom.sun.management.jmxremote.authenticate=$JMXAUTH
```

* JMXSSL

```shell
-Dcom.sun.management.jmxremote.ssl=$JMXSSL
```

* JMXLOG4J

```shell
-Dzookeeper.jmx.log4j.disable=$JMXLOG4J
```

### 修改zkEnv.sh文件

```shell
JMXPORT=21811
JMXSSL=false
JMXAUTH=false
JMXLOG4J=false
```

## 开启Kafka监控

### 查看kafka-run-class.sh

* JMX_PORT

```shell
-Dcom.sun.management.jmxremote.port=$JMX_PORT
```

* KAFKA_JMX_OPTS

```shell
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
```

### 修改kafka-start-server.sh

```shell
if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
    export KAFKA_HEAP_OPTS="-server -Xms2G -Xmx2G -XX:PermSize=128m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=8 -XX:ConcGCThreads=5 -XX:InitiatingHeapOccupancyPercent=70"
    export JMX_PORT="9999"
    # export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
fi
```

## 开启Kafka Connect JMX

* 下载`jmx_prometheus_javaagent-0.3.1.jar`
* 配置`config.yml`

```yaml
startDelaySeconds: 0
ssl: false
jmxUrl: service:jmx:rmi:///jndi/rmi://127.0.0.1:19092/jmxrmi
lowercaseOutputName: false
lowercaseOutputLabelNames: false
rules:
- pattern : "kafka.connect<type=connect-worker-metrics>([^:]+):"
  name: "kafka_connect_connect_worker_metrics_$1"
- pattern : "kafka.connect<type=connect-metrics, client-id=([^:]+)><>([^:]+)"
  name: "kafka_connect_connect_metrics_$2"
  labels:
    client: "$1"
- pattern: "debezium.([^:]+)<type=connector-metrics, context=([^,]+), server=([^,]+), key=([^>]+)><>RowsScanned"
  name: "debezium_metrics_RowsScanned"
  labels:
    plugin: "$1"
    name: "$3"
    context: "$2"
    table: "$4"
- pattern: "debezium.([^:]+)<type=connector-metrics, context=([^,]+), server=([^>]+)>([^:]+)"
  name: "debezium_metrics_$4"
  labels:
    plugin: "$1"
    name: "$3"
    context: "$2"
```



### 修改connect-distributed.sh

```shell
# 修改KAFKA_HEAP_OPTS环境变量
  export KAFKA_HEAP_OPTS="-server -Xms2G -Xmx2G -XX:PermSize=128m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=8 -XX:ConcGCThreads=5 -XX:InitiatingHeapOccupancyPercent=70"
# 添加JMX_PORT
 export JMX_PORT="19092"
# 添加KAFKA_OPTS
 export KAFKA_OPTS="-javaagent:/opt/cloudera/parcels/CDH/lib/kafka/monitor/jmx_prometheus_javaagent-0.3.1.jar=8080:/opt/cloudera/parcels/CDH/lib/kafka/monitor/config.yml"
```