# 安装
## Docker安装
```shell
docker pull prom/prometheus
docker pull prom/node-exporter
docker pull grafana/grafana
```
### 运行node-exporter
```docker run -d -p 9100:9100 --name=node-exporter -v "/Users/babywang/Documents/reserch/studySummary/monitor/prometheus/proc:/host/proc:ro" -v "/Users/babywang/Documents/reserch/studySummary/monitor/prometheus/sys:/host/sys:ro" -v "/Users/babywang/Documents/reserch/studySummary/monitor/prometheus/:/rootfs:ro" prom/node-exporter```
### 运行prometheus
```docker run -d -p 9090:9090 -v ~/Documents/reserch/studySummary/monitor/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml --name=prometheus prom/prometheus```
### 运行grafana
```docker run -d -p 3000:3000 --name=grafana -v ~/Documents/reserch/studySummary/monitor/grafana:/var/lib/grafana grafana/grafana```

