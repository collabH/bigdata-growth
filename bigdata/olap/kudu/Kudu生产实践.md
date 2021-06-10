# Kudu生产配置

## master

```
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
```

## tserver

```
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
```

# KuduClient实践

## 刷新策略

* 同步刷新: 一条一刷
* 异步刷新: 默认1000一批
* 手动控制: 手动提交flush

