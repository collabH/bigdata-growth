# 本地部署

* 下载相关二进制包，配置ssh链接localhost，配置alluxio环境变量

## 使用姿势

```shell
# 挂载RAMFS文件系统
alluxio-mount.sh SudoMount
# 格式化文件系统,类似与hdfs在第一次使用的时候需要格式化
alluxio format
# 启动本地文件系统,为挂载ramdisk或重新挂载
alluxio-start.sh local SudoMount
# 如果已经挂载了直接启动即可
alluxio-start.sh local 
# 验证alluxio是否运行
alluxio runTests
# 关闭alluxio
alluxio-stop.sh local
```

# 集群部署

## 基本配置

* 在master节点创建`alluxio-site.properties`配置

```shell
cp conf/alluxio-site.properties.template conf/alluxio-site.properties
# 设置masterhostname&底层根目录挂载UFS地址,要保证worker和master节点都可以共享访问这个底层存储
alluxio.master.hostname=<MASTER_HOSTNAME>
alluxio.master.mount.table.root.ufs=<STORAGE_URI>
# 配置raft方式的ha节点，例如alluxio.master.embedded.journal.addresses=master_hostname_1:19200，master_hostname_2:19200，master_hostname_3:19200
alluxio.master.embedded.journal.addresses=<EMBEDDED_JOURNAL_ADDRESS>
# zk方式ha
alluxio.zookeeper.enabled=true
alluxio.zookeeper.address=<ZOOKEEPER_ADDRESS>
alluxio.master.journal.type=UFS
alluxio.master.journal.folder=<JOURNAL_URI>
# 配置master nameservice
alluxio.master.nameservices.my-alluxio-cluster=master1,master2,master3
alluxio.master.rpc.address.my-alluxio-cluster.master1=master1:19998
alluxio.master.rpc.address.my-alluxio-cluster.master2=master2:19998
alluxio.master.rpc.address.my-alluxio-cluster.master3=master3:19998
```

* 将worker节点的ip添加至conf的worker文件中

```shell
# 将master节点的配置复制到所有worker节点
alluxio copyDir conf/
```

## 启动步骤

```shell
# 格式化master节点
alluxio formatMaster
# master节点启动alluxio集群&验证集群
alluxio-start.sh all SudoMount
alluxio runTests
# 停止全部节点或workers、masters节点
alluxio-stop.sh all
alluxio-stop.sh masters
alluxio-stop.sh workers
# 去特定机器停止特定节点
alluxio-stop.sh master
alluxio-stop.sh worker
# 验证ha节点
alluxio fs leader
```

## 客户端访问

```properties
# 设置master地址
alluxio.master.rpc.addresses=master_hostname_1:19998,master_hostname_2:19998,master_hostname_3:19998
# spark方式使用spark.executor.extraJavaOptions和spark.driver.extraJavaOptions:
-Dalluxio.master.rpc.addresses=master_hostname_1:19998,master_hostname_2:19998,master_hostname_3:19998
# 程序中通过path读取
alluxio://master_hostname_1:19998,master_hostname_2:19998,master_hostname_3:19998/path
```



