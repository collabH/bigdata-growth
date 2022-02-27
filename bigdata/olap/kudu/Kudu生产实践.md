# Kudu生产配置

## master

```properties
# 基础配置
--master_addresses
--fs_metadata_dir
--fs_data_dirs
--log_dir
--fs_wal_dir

# rpc服务队列,根据rpcs_queue_overflow调整以下参数
--rpc_service_queue_length=50
# rpc服务线程数
--rpc_num_service_threads=20
# Timed out waiting for ts: L: 21692028104 to be safe (mode: NON-LEADER). Current safe time: L: 21691148967 Physical time difference: None (Logical clock)时钟问题，开启ntp后仍然存在
--use_hybrid_clock=true
# ntp延迟20s
--max_clock_sync_error_usec=20000000
```

## tserver

```properties
# 基础配置
--fs_metadata_dir
--fs_data_dirs
--log_dir
--fs_wal_dir
--tserver_master_addrs 默认127.0.0.1:7051
# 块缓存大小
--block_cache_capacity_mb
# 内存限制
--memory_limit_hard_bytes
# rpc服务队列,根据rpcs_queue_overflow调整以下参数
--rpc_service_queue_length=50
# rpc服务线程数
--rpc_num_service_threads=20
# ntp延迟20s
--max_clock_sync_error_usec=20000000
# 设置分散每个ts上数据的目标数据目录数量。如果数据目录的数量大于可用的数据目录的数量，那么数据将在这些可用的目录之间进行条带化（条带化（Striping）是把连续的数据分割成相同大小的数据块，把每段数据分别写入到阵列中不同磁盘上的方法。 此技术非常有用，它比单个磁盘所能提供的读写速度要快的多，当数据从第一个磁盘上传输完后，第二个磁盘就能确定下一段数据。 数据条带化正在一些现代数据库和某些RAID硬件设备中得到广泛应用。）。值0表示应该在所有正常的数据目录上进行条带化。每台tablet使用更少的数据目录意味着单个驱动器故障对给定tablet server的影响将更小。
--fs_target_data_dirs_per_tablet=0
```

# KuduClient实践

## 刷新策略

* 同步刷新: 一条一刷
* 异步刷新: 默认1000一批
* 手动控制: 手动提交flush

# 增加新Tablet Server的最佳实践

## 大致步骤

1. 确保 Kudu 安装在添加到集群的新机器上，并且新实例已正确配置为指向预先存在的集群。 然后，启动新的Tablet Server实例
2. 验证新实例是否成功与 Kudu Master 连接。 验证他们是否已成功加入现有 Master 实例的一种快速方法是查看 Kudu Master WebUI，特别是 /tablet-servers 部分，并验证新添加的实例是否已注册和心跳。
3. 一旦 tablet server 成功上线并运行良好，请按照以下步骤运行重新平衡工具，该工具会将现有的 tablet 副本传播到新添加的 tablet 服务器。
4. 在重新平衡器工具完成后，甚至在其执行期间，您可以使用 ksck 命令行实用程序检查集群的健康状况（有关更多详细信息，请参阅使用 ksck 检查集群健康状况）

## 校验集群监控运行`ksck`

```shell
sudo -u kudu kudu cluster ksck master-01.example.com,master-02.example.com,master-03.example.com
```

## 使用rebalancing tool

```shell
sudo -u kudu kudu cluster rebalance master_servers -fetch_info_concurrency 100 -tables ""
```
