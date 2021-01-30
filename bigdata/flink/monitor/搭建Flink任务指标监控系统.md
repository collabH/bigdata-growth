# 监控平台环境安装

## docker安装

```shell
docker pull prom/prometheus
docker pull prom/node-exporter
docker pull grafana/grafana
```

### 运行node-exporter
```shell
docker run -d -p 9100:9100 --name=node-exporter -v "/Users/babywang/Documents/reserch/studySummary/monitor/prometheus/proc:/host/proc:ro" -v "/Users/babywang/Documents/reserch/studySummary/monitor/prometheus/sys:/host/sys:ro" -v "/Users/babywang/Documents/reserch/studySummary/monitor/prometheus/:/rootfs:ro" prom/node-exporter
```

### 运行prometheus
``````shell
docker run -d -p 9090:9090 -v ~/Documents/reserch/studySummary/monitor/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml --name=prometheus prom/prometheus
``````

### 运行pushgateway

```shell
docker run -d -p 9091:9091 --name pushgateway prom/pushgateway
```



### 运行grafana

```shell
docker run -d -p 3000:3000 --name=grafana -v ~/Documents/reserch/studySummary/monitor/grafana:/var/lib/grafana grafana/grafana
```

# Flink配置

## 配置Flink指标上报Pushgateway

```properties
metrics.reporter.promgateway.class: org.apache.flink.metrics.prometheus.PrometheusPushGatewayReporter
metrics.reporter.promgateway.host: localhost
metrics.reporter.promgateway.port: 9091
metrics.reporter.promgateway.jobName: myJob
metrics.reporter.promgateway.randomJobNameSuffix: true
metrics.reporter.promgateway.deleteOnShutdown: false
metrics.reporter.promgateway.groupingKey: k1=v1;k2=v2
metrics.reporter.promgateway.interval: 60 SECONDS
```

## Flink任务指标大盘

[Databoard](https://grafana.com/grafana/dashboards?search=flink)

