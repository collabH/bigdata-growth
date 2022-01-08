# 概述

# 特点

## 特点

![Ecosystem](https://d39kqat1wpn1o5.cloudfront.net/app/uploads/2021/07/alluxio-overview-r071521.png)

* **内存速度 I/O**：Alluxio 能够用作分布式共享缓存服务，这样与 Alluxio 通信的计算应用程序可以透明地缓存频繁访问的数据（尤其是从远程位置），以提供内存级 I/O 吞吐率。此外，Alluxio的层次化存储机制能够充分利用内存、固态硬盘或者磁盘，降低具有弹性扩张特性的数据驱动型应用的成本开销。
* **简化云存储和对象存储接入**：与传统文件系统相比，云存储系统和对象存储系统使用不同的语义，这些语义对性能的影响也不同于传统文件系统。在云存储和对象存储系统上进行常见的文件系统操作（如列出目录和重命名）通常会导致显著的性能开销。当访问云存储中的数据时，应用程序没有节点级数据本地性或跨应用程序缓存。将 Alluxio 与云存储或对象存储一起部署可以缓解这些问题，因为这样将从 Alluxio 中检索读取数据，而不是从底层云存储或对象存储中检索读取。
* **简化数据管理**：Alluxio 提供对多数据源的单点访问。除了连接不同类型的数据源之外，Alluxio 还允许用户同时连接同一存储系统的不同版本，如多个版本的 HDFS，并且无需复杂的系统配置和管理。
* **应用程序部署简易**：Alluxio 管理应用程序和文件或对象存储之间的通信，将应用程序的数据访问请求转换为底层存储接口的请求。Alluxio 与 Hadoop 生态系统兼容，现有的数据分析应用程序，如 Spark 和 MapReduce 程序，无需更改任何代码就能在 Alluxio 上运行。

## 快速搭建

* max os系统需要安装ssh（一般安装过hadoop环境的这个都已经安装了）
* 下载allux并且配置环境变量，[alluxio下载地址](https://www.alluxio.io/download/)，修改相应配置

```shell
tar -xzf alluxio-2.7.2-bin.tar.gz
cd alluxio-2.7.2
# 配置${ALLUXIO_HOME}
export ALLUXIO_HOME=$MODULE_HOME/alluxio-2.7.2
export PATH=$PATH:$ALLUXIO_HOME/bin

# 修改conf
cp conf/alluxio-site.properties.template conf/alluxio-site.properties
echo "alluxio.master.hostname=localhost" >> conf/alluxio-site.properties
```

* 验证Alluxio运行环境

```shell
alluxio validateEnv local
```

* 启动Alluxio

```shell
# 格式化alluxio
alluxio format
# 本地运行1master和1worker
alluxio-start.sh local SudoMount
```

* 使用alluxio shell

```shell
alluxio fs copyFromLocal LICENSE /LICENSE

$ alluxio fs ls /
-rw-r--r--  xiamuguizhi    staff                    27040       PERSISTED 01-05-2022 23:33:15:361 100% /LICENSE
```

**默认情况：**alluxio使用的本地系统为底层文件系统(UFS)，默认路径为`./underFSStorage`,端口`19999`查看alluxio文件目录

* 挂在hdfs上的数据到alluxio中

```shell
# 创建一个目录作为挂载点
alluxio fs mkdir /mnt
alluxio fs mount --readonly alluxio://localhost:19998/mnt/hdfs hdfs://hadoop:8020/user/flink/hudi_user
```

* 使用Alluxio加速数据访问,如果ls文件状态下显示100%则代表文件已经完全加载至`alluxio`则可以利用`alluxio`来加速读取。

# 核心功能

## 缓存

* 
# 核心功能

## 缓存

### 概述

* Alluxio将存储分为俩个类别的方式来帮助统一跨各种平台用户数据的同时还有助于为用户提升总体I / O吞吐量。
  * **UFS(底层文件系统，底层存储)**:表示不受Alluxio管理的空间，UFS存储可能来自外部文件系统，如HDFS或S3， 通常，UFS存储旨在相当长一段时间持久存储大量数据。
  * **Alluxio存储**
    * alluxio作为一个分布式缓存来管理Alluxio workers本地存储，包括内存。这个在用户应用程序与各种底层存储之间的快速数据层带来的是显著提高的I / O性能。
    * Alluxio存储主要用于存储热数据，暂态数据，而不是长期持久数据存储。
    * 每个Alluxio节点要管理的存储量和类型由用户配置决定。
    * 即使数据当前不在Alluxio存储中，通过Alluxio连接的UFS中的文件仍然 对Alluxio客户可见。当客户端尝试读取仅可从UFS获得的文件时数据将被复制到Alluxio存储中（这里体现在alluxio文件目录下的进度条）

![](img/alluxio存储图.png)

* Alluxio存储通过将数据`存储在计算节点内存`中来提高性能。Alluxio存储中的数据可以被`复制来形成"热"数据`，更易于I/O并行操作和使用。
* Alluxio中的`数据副本独立于UFS中可能已存在的副本`。 Alluxio存储中的数据副本数是由集群活动动态决定的。 由于Alluxio依赖底层文件存储来存储大部分数据， Alluxio不需要`保存未使用的数据副本`。
* Alluxio还支持让系统存储软件可感知的分层存储，使类似L1/L2 CPU缓存一样的数据存储优化成为可能。

### 配置Alluxio存储

#### 单层存储

* Alluxio默认为单层存储，Alluxio将在每个worker节点上发放一个ramdisk并占用一定比例的系统的总内存。 此`ramdisk`将用作分配给每个Alluxio worker的唯一存储介质。
* 通过修改`alluxio-site.properties`

```properties
# 设置每个worker的ramdisk大小
alluxio.worker.ramdisk.size=16GB
# 指定worker多个存储介质
alluxio.worker.tieredstore.level0.dirs.path=/mnt/ramdisk,/mnt/ssd1,/mnt/ssd2
alluxio.worker.tieredstore.level0.dirs.mediumtype=MEM,SSD,SSD
# 多个存储介质分配worker使用大小
alluxio.worker.tieredstore.level0.dirs.quota=16GB,100GB,100GB
```

#### 多层存储

* 通常建议异构存储介质也使用单个存储层。 在特定环境中，工作负载将受益于基于I/O速度存储介质明确排序。 Alluxio假定根据按I/O性能从高到低来对多层存储进行排序。 例如，用户经常指定以下层：
  * MEM(内存)
  * SSD(固态存储)
  * HDD(硬盘存储)

##### 写数据

* 写新的数据块时默认情况下会先向顶层存储写如果顶层没有足够的空间则会尝试向下一层存储写，如果所有层都没有空间，因为alluxio的设计是`易失性存储`，Alluxio会`释放空间来存储新写入的数据块`。 根据块注释策略，空间释放操作会从work中释放数据块。 如果空间释放操作无法释放新空间，则`写数据将失败`。
* 修改配置`alluxio.worker.tieredstore.free.ahead.bytes`(默认值：0)配置为每次释放超过释放空间请求所需字节数来保证有多余的已释放空间满足写数据需求。

##### 读取数据

* 如果数据已经存在于Alluxio中则客户端将简单地从已存储的数据块读取数据，如果将Alluxio配置为多层，则不一定是从顶层读取数据块，因为数据可能已经透明地挪动到更低的存储层。用`ReadType.CACHE_PROMOTE`读取数据将在从worker读取数据前尝试首先将数据块挪到 顶层存储。也可以将其用作为一种数据管理策略 明确地将`热数据`移动到更高层存储读取。

##### 配置分层存储

* 双层配置清单

```properties
# configure 2 tiers in Alluxio
alluxio.worker.tieredstore.levels=2
# the first (top) tier to be a memory tier
alluxio.worker.tieredstore.level0.alias=MEM
# defined `/mnt/ramdisk` to be the file path to the first tier
alluxio.worker.tieredstore.level0.dirs.path=/mnt/ramdisk
# defined MEM to be the medium type of the ramdisk directory
alluxio.worker.tieredstore.level0.dirs.mediumtype=MEM
# set the quota for the ramdisk to be `100GB`
alluxio.worker.tieredstore.level0.dirs.quota=100GB
# configure the second tier to be a hard disk tier
alluxio.worker.tieredstore.level1.alias=HDD
# configured 3 separate file paths for the second tier
alluxio.worker.tieredstore.level1.dirs.path=/mnt/hdd1,/mnt/hdd2,/mnt/hdd3
# defined HDD to be the medium type of the second tier
alluxio.worker.tieredstore.level1.dirs.mediumtype=HDD,HDD,HDD
# define the quota for each of the 3 file paths of the second tier
alluxio.worker.tieredstore.level1.dirs.quota=2TB,5TB,500GB
```

* 典型的配置将具有三层，分别是内存，SSD和HDD。 要在HDD层中使用多个硬盘存储，需要在配置`alluxio.worker.tieredstore.level{x}.dirs.path`时指定多个路径。

#### 块注释策略

* Alluxio从v2.3开始使用块注释策略来维护存储中数据块的严格顺序。 注释策略定义了跨层块的顺序，并在以下操作过程中进行用来参考: -释放空间 -动态块放置。

* 与写操作同步发生的释放空间操作将尝试根据块注释策略强制顺序删除块并释放其空间给写操作。注释顺序的最后一个块是第一个释放空间候选对象，无论它位于哪个层上。

* 开箱即用的注释策略实施包括:

  - **LRUAnnotator**:根据最近最少使用的顺序对块进行注释和释放。 **这是Alluxio的默认注释策略**。

  - **LRFUAnnotator**:根据配置权重的最近最少使用和最不频繁使用的顺序对块进行注释。
    - 如果权重完全偏设为最近最少使用，则行为将与LRUAnnotator相同。
    - 适用的配置属性包括`alluxio.worker.block.annotator.lrfu.step.factor` `alluxio.worker.block.annotator.lrfu.attenuation.factor`。

* workers选择使用的注释策略由Alluxio属性 `alluxio.worker.block.annotator.class`决定。 该属性应在配置中指定完全验证的策略名称。当前可用的选项有:

  - `alluxio.worker.block.annotator.LRUAnnotator`

  - `alluxio.worker.block.annotator.LRFUAnnotator`

#### 分层存储管理

* 每个单独层管理任务都遵循以下配置:

  - `alluxio.worker.management.task.thread.count`:管理任务所用线程数。 (默认值:CPU核数)

  - `alluxio.worker.management.block.transfer.concurrency.limit`:可以同时执行多少个块传输。 (默认:`CPU核数`/2)

##### 块对齐

* Alluxio将动态地跨层移动数据块，以使块组成与配置的块注释策略一致。为了辅助块对齐，Alluxio会监视I/O模式并会跨层重组数据块，以确保 **较高层的最低块比下面层的最高块具有更高的次序**。
* `alluxio.worker.management.tier.align.enabled`:是否启用层对齐任务。 (默认: `true`)
* `alluxio.worker.management.tier.align.range`:单个任务运行中对齐多少个块。 (默认值:`100`)
* `alluxio.worker.management.tier.align.reserved.bytes`:配置多层时，默认情况下在所有目录上保留的空间大小。 (默认:1GB) 用于内部块移动。
* `alluxio.worker.management.tier.swap.restore.enabled`:控制一个特殊任务，该任务用于在内部保留空间用尽时unblock层对齐。 (默认:true) 由于Alluxio支持可变的块大小，因此保留空间可能会用尽，因此，当块大小不匹配时在块对齐期间在层之间块交换会导致一个目录保留空间的减少。

##### 块升级

* 当较高层具有可用空间时，低层的块将向上层移动，以便更好地利用较快的磁盘介质，因为假定较高的层配置了较快的磁盘介质。
* `alluxio.worker.management.tier.promote.enabled`:是否启用层升级任务。 (默认: `true`)
* `alluxio.worker.management.tier.promote.range`:单个任务运行中升级块数。 (默认值:`100`)
* `alluxio.worker.management.tier.promote.quota.percent`:每一层可以用于升级最大百分比。 一旦其已用空间超过此值，向此层升级将停止。 (0表示永不升级，100表示总是升级。)

### Alluxio中数据生命周期管理

* 基础概念
  * free：释放alluxio缓存中的数据，并不会删除UFS中的数据，释放后的数据会从UFS中拉取性能会下降。
  * load：将数据从UFS复制到Alluxio缓存中。
  * persist：将Alluxio存储中可能被修改或未修改的数据写回UFS，这样在alluxio节点发生故障时数据仍然可以恢复。
  * TTL(time to Live):文件和目录的生存时间。在数据超过其生存时间时将它们从Alluxio空间中删除。还可以配置 TTL来删除存储在UFS中的相应数据。

```shell
# 释放数据
alluxio fs free /tmp/data
# 加载数据
alluxio fs load /LICENSE
# 持久化数据
alluxio fs persist /LICENSE
# 修改alluxio-site.properties
## 设置ttl检查间隔,每间隔多久检查一次ttl是否过期
alluxio.master.ttl.checker.interval=10m
## 设置文件ttl
alluxio.user.file.create.ttl=3m
## 设置ttl过期后的action
alluxio.user.file.create.ttl.action=DELETE
# 使用ttl api设置
SetTTL(path，duration，action)
`path` 		Alluxio命名空间中的路径
`duration`	TTL动作生效前的毫秒数，这会覆盖任何先前的设置
`action`	生存时间过去后要执行的`action`。 `FREE`将导致文件
            从Alluxio存储中删除释放，无论其目前的状态如何。 `DELETE`将导致
            文件从Alluxio命名空间和底层存储中删除。
            注意:`DELETE`是某些命令的默认设置，它将导致文件被
            永久删除。
```

### 在Alluxio中管理数据复制

#### 被动复制

* Alluxio中的每个文件都包含一个或多个分布在集群中存储的存储块。默认情况下，Alluxio可以根据工作负载和存储容量自动调整不同块的复制级别，默认情况下，此复制或征回决定以及相应的数据传输 对访问存储在Alluxio中数据的用户和应用程序完全透明。

#### 主动复制

* `alluxio.user.file.replication.min`是此文件的最小副本数。 默认值为0，即在默认情况下，Alluxio可能会在文件变冷后从Alluxio管理空间完全删除该文件。 通过将此属性设置为正整数，Alluxio 将定期检查此文件中所有块的复制级别。当某些块的复制数不足时，Alluxio不会删除这些块中的任何一个，而是主动创建更多 副本以恢复其复制级别。
* `alluxio.user.file.replication.max`是最大副本数。一旦文件该属性 设置为正整数，Alluxio将检查复制级别并删除多余的副本。将此属性设置为-1为不设上限(默认情况)，设置为0以防止 在Alluxio中存储此文件的任何数据。注意，`alluxio.user.file.replication.max`的值必须不少于`alluxio.user.file.replication.min`。

```shell
# 设置file的复制副本区间在3~5，max为-1表示复制无上限
alluxio fs setReplication --min 3 --max 5 /file
# 使用—R设置/dir目录下所有文件复制级别
alluxio fs setReplication --min 3 --max -5 -R /dir
# 检查复制状态,查看replicationMin和replicationMax字段。
alluxio fs stat /foo
```

### 检查Alluxio缓存容量和使用情况

```shell
alluxio fsadmin report
# 获取使用的总字节数
alluxio fs getUsedBytes
# 获取总容量，单位字节
alluxio fs getCapacityBytes
```

## 统一命名空间

### 概述

#### 统一命名空间

* 用户可以通过统一的alluxio命令来访问多个外部存储。

![](./img/统一命名空间.png)

#### UFS命名空间

* 每个已挂载的基础文件系统 在Alluxio命名空间中有自己的命名空间； 称为UFS命名空间。

### 透明命名机制

* 透明命名机制保证alluxio和底层存储系统命名空间身份一致，当用户在 Alluxio命名空间中对一个持久化的对象进行重命名或者删除操作时，底层存储系统中也会对其执行相同的重命名或删除操作。

![](./img/透明命名机制.png)

### 挂载底层存储系统

#### 根挂载点

* 将一个HDFS路径挂在到Alluxio命名空间的根目录

```shell
alluxio.master.mount.table.root.ufs=hdfs://hadoop:8020
# 根据配置前缀来配置根挂载点的挂在选项alluxio.master.mount.table.root.option.<some alluxio property>
alluxio.master.mount.table.root.option.aws.accessKeyId=<AWS_ACCESS_KEY_ID>
alluxio.master.mount.table.root.option.aws.secretKey=<AWS_SECRET_ACCESS_KEY>
alluxio.master.mount.table.root.option.alluxio.security.underfs.hdfs.kerberos.client.principal=client
alluxio.master.mount.table.root.option.alluxio.security.underfs.hdfs.kerberos.client.keytab.file=keytab
alluxio.master.mount.table.root.option.alluxio.security.underfs.hdfs.impersonation.enabled=true
alluxio.master.mount.table.root.option.alluxio.underfs.version=2.7
```

#### 嵌套挂载点

* 除了根挂载点之外，其他底层文件系统也可以挂载到Alluxio命名空间中。 这些额外的挂载点可以通过`mount`命令在运行时添加到Alluxio。 `--option`选项允许用户传递挂载操作的附加参数，如凭证。

```shell
# 挂载hdfs
alluxio fs mount /mnt/hdfs hdfs://host1:9000/data/
# 挂载s3存储
alluxio fs mount \
  --option aws.accessKeyId=<accessKeyId> --option aws.secretKey=<secretKey> \
  /mnt/s3 s3://data-bucket/
```

* 注意，挂载点也允许嵌套。 例如，如果将UFS挂载到 `alluxio:///path1`，可以在`alluxio:///path1/path2`处挂载另一个UFS。

### UDFS元数据同步

* 当Alluxio扫描UFS目录并加载其子目录元数据时， 它将创建元数据的副本，以便将来无需再从UFS加载。 元数据的缓存副本将根据 `alluxio.user.file.metadata.sync.interval`客户端属性配置的间隔段刷新，默认值`-1`表示在初始加载后不会再重新同步元数据。

```shell
# 同步特定目录元数据
alluxio fs startSync /syncdir
alluxio fs stopSync /syncdir
# 获取同步列表
alluxio fs getSyncPathList
```



## Catalog

