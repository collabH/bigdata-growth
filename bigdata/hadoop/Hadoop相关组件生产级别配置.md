# Yarn生产配置

## 日志配置

```shell
# 开启日志聚合,默认为false
yarn.log-aggregation-enable

# 日志聚合后在HDFS上存储的目录位置，在该目录下会按application所属的用户名创建目录。默认值为/tmp/logs
yarn.nodemanager.remote-app-log-dir

# 日志目录后缀，格式为${yarn.nodemanager.remote-app-log-dir}/${user}/${yarn.nodemanager.remote-app-log-dir-suffix}
yarn.nodemanager.remote-app-log-dir-suffix

# 聚合后的日志在HDFS上的存储生命周期，超过该时间后日志会被删除。默认值为-1，表示永久存储
yarn.log-aggregation.retain-seconds

# 日志清除的检测周期，即每隔一段时间检查相关目录下是否有过期的日志，如果有则进行删除。
yarn.log-aggregation.retain-check-interval-seconds

# container运行的中间数据的存储目录
yarn.nodemanager.local-dirs

# application运行日志在nodemanager本地文件系统上的存放目录
yarn.nodemanager.log-dirs

# 未开启日志聚合的情况下，application运行日志在nodemanager节点本地文件系统上存储的生命周期
yarn.nodemanager.log.retain-seconds

# 默认值为0， 表示开启日志聚合功能的情况下，当application运行结束后，进行日志聚合，然后立马在nodemanger节点上进行删除。
yarn.nodemanager.delete.debug-delay-sec

# resourcemanager等待日志聚合状态汇报的超时时间。
yarn.log-aggregation-status.time-out.ms

# nodemanager中用于日志聚合的线程池的最大个数
yarn.nodemanager.logaggregation.threadpool-size-max

# 日志聚合文件的压缩类型，默认为空，即不进行压缩
yarn.nodemanager.log-aggregation.compression-type

# 每个application进行聚合的日志的最大个数
yarn.nodemanager.log-aggregation.num-log-files-per-app

# nodemanager进行日志聚合的时间间隔，默认值-1表示当application运行结束后立即进行日志聚合。设置大于0的值表示进行日志聚合的线程会周期性的被唤醒以进行日志的聚合。
yarn.nodemanager.log-aggregation.roll-monitoring-interval-seconds

# 日志聚合的策略
yarn.nodemanager.log-aggregation.policy.class
```

## Yarn重启应用自恢复

### 配置ResourceManager重启自动恢复

```shell
# 开启rm自动恢复
yarn.resourcemanager.recovery.enabled

# 该参数用来指定RM在重启之前将自己的状态保存在何种存储媒介上，目前有3种存储可选。
yarn.resourcemanager.store.class
1.org.apache.hadoop.yarn.server.resourcemanager.recovery.FileSystemRMStateStore
默认值，是基于文件系统的存储（本地存储或者HDFS）。可以指定yarn.resourcemanager.fs.state-store.uri作为存储路径。

2.org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore
基于ZooKeeper的存储，当启用RM高可用时，只能选择这种方式。因为两个RM都有可能是活跃的（认为自己才是真正的RM），进而发生脑裂。基于ZK的存储可以通过隔离（fence）状态数据防止脑裂。可以指定hadoop.zk.address（ZK节点地址列表）和yarn.resourcemanager.zk-state-store.parent-path（状态数据的根节点路径）参数。

3.org.apache.hadoop.yarn.server.resourcemanager.recovery.LeveldbRMStateStore
基于LevelDB的存储。它比前两种方式都更轻量级，占用的存储空间和I/O要小得多，并且支持更好的原子性操作。对性能有极致要求时采用。可以指定yarn.resourcemanager.leveldb-state-store.path作为存储路径。

# 表示从RM重启后从各个NM同步Container信息的等待时长，在此之后才会分配新的Container。默认值是10000（10秒）
yarn.resourcemanager.work-preserving-recovery.scheduling-wait-ms
```

### 配置NodeManager重启自动恢复

```shell
# 开启NM自动恢复
yarn.nodemanager.recovery.enabled

# 指定NM在重启之前，将Container的状态写入此本地路径。默认值为${hadoop.tmp.dir}/yarn-nm-recovery。
yarn.nodemanager.recovery.dir

# 该参数为NM的RPC地址，默认为${yarn.nodemanager.hostname}:0，即随机使用临时端口。一定要指定为一个固定端口（如8041），否则NM重启之后会更换端口，就无法恢复Container的状态了。
yarn.nodemanager.address
```

