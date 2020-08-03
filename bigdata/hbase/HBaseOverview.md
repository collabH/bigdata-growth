# 概述

## 定义

* Hbase是一个在HDFS上开发的面向列的分布式、可扩展支持海量数据存储的NoSQL数据库，如果需要实时访问超大规模数据集可以使用。
* 自底向上地进行构建，能够简单地通过增加节点来达到线性扩展。概念

## 数据模型

* 逻辑上，Hbase的数据模型同关系型数据库很类似，数据存储在一张表中，有行有列。但从Hbase的底层物理存储结构(K-V)来看，Hbase更像是一个`multi-dimensional map`

### Hbase的逻辑结构

![Hbase逻辑结构](./img/Hbase数据结构.png)

* 按照RowKey横向切分成一个个的Region，按照列族纵向切分。
* Store为真正存储到HDFS的数据。

### 物理结构

![物理存储结构](./img/Hbase物理存储结构.jpg)

### 数据模型

#### Name Sparce

* 命名空间，类似于关系型数据库的`database`概念，每个命名空间下有多个表。Hbase有`两个自带的命名空间`，分别为hbase和default，`hbase中存放的是Hbase内置的表，default表示用户默认使用的命名空间`。

#### Region

* 类似于关系型数据库的表概念，不同的是，Hbase定义表时只需要声明`列族`即可，不需要声明具体的列。这意味着Hbase写入数据时，字段可以`动态，按需`指定。因此，和关系型数据库相比，Hbase能够处理字段变更场景。
* Region也相当于表的切片，按照RowKey来切分Hbase的表。

#### Row

* HBase表中的每行数据都由一个`RowKey`和多个`Column(列)`组成，数据是按照RowKey的`字典顺序存储`的，并且查询数据时只能根据RowKey进行检索，所有RowKey的设计十分重要。

#### Column

* Hbase中的每个列都由`Column Family(列族)`和`Column Qualifier(列限定符)`进行限定，列入info:name, info:age。建表时，只需要指明列族，而列限定符无需预先定义。

#### Time Stamp

* 用于标识数据的不同版本(version),每条数据写入时，如果不指定时间戳，系统会指定为其加上该字段，其值为写入Hbase的时间。

#### Cell

* 由{rowdy,column Family:column Qualifier,time Stamp}唯一确定的单元。cell中的数据时没有类型的，全部是字节码形式存储。

## Hbase的基本架构

### HBase架构(不完整版)

![Hbase架构图](./img/HBase架构(不完整).jpg)

### Region Server

* Region Server为Region的管理者，其实现类为`HRegionServer`,主要作用如下:对于数据的操作:get、put、delete。

### Master

* Master是所有Region Server的管理者，其实现类为`HMaster`,监控每个RegionServer的状态，负载均衡和故障转移。

### Zookeeper

* HBase通过Zookeeper来做master的高可用、RegionServer的监控、元数据的入口以及

集群配置的维护等工作。

### HDFS

* HDFS为HBase提供最终的底层数据存储服务，同为HBase提供高可用的支持。

# HBase快速入门

## Hbase按照部署

### 下载Hbase压缩包

```shell
curl https://mirror.bit.edu.cn/apache/hbase/2.3.0/
```

### 修改配置

* 修改regionservers

```
hadoop
```

* 修改hbase-env.sh

```properties
# 添加JAVA_HOME
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_221.jdk/Contents/Home
# 不使用HBase内置的ZK
export HBASE_MANAGES_ZK=false
```

* 修改hbase-site.xml

```xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
-->
<configuration>
  <!--
    The following properties are set for running HBase as a single process on a
    developer workstation. With this configuration, HBase is running in
    "stand-alone" mode and without a distributed file system. In this mode, and
    without further configuration, HBase and ZooKeeper data are stored on the
    local filesystem, in a path under the value configured for `hbase.tmp.dir`.
    This value is overridden from its default value of `/tmp` because many
    systems clean `/tmp` on a regular basis. Instead, it points to a path within
    this HBase installation directory.

    Running against the `LocalFileSystem`, as opposed to a distributed
    filesystem, runs the risk of data integrity issues and data loss. Normally
    HBase will refuse to run in such an environment. Setting
    `hbase.unsafe.stream.capability.enforce` to `false` overrides this behavior,
    permitting operation. This configuration is for the developer workstation
    only and __should not be used in production!__

    See also https://hbase.apache.org/book.html#standalone_dist
  -->
  <!--开启分布式模式-->
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
  <!--添加hbase数据存储目录为HDFS-->
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://hadoop:8020/hbase</value>
  </property>
  <!--hbase zk地址配置-->
   <property>
    <name>hbase.zookeeper.quorum</name>
    <value>hadoop:2182,hadoop:2183,hadoop:2184</value>
  </property>
  <!--Hbase  Master绑定端口-->
  <property >
    <name>hbase.master.port</name>
    <value>16000</value>
  </property>
  <!--Master的web ui端口-->
  <property>
    <name>hbase.master.info.port</name>
    <value>16010</value>
  </property>
  <!--zk工作目录-->
   <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/Users/babywang/Documents/reserch/middleware/zk/zkCluster/zookeeper_data1,/Users/babywang/Documents/reserch/middleware/zk/zkCluster/zookeeper_data2,/Users/babywang/Documents/reserch/middleware/zk/zkCluster/zookeeper_data3</value>
  </property>
</configuration>
```

### 配置Hbase环境变量

```shell
# 配置Hbase
export HBASE_HOME=/Users/babywang/Documents/reserch/studySummary/module/hbase/hbase-2.3.0
export PATH=$PATH:$HBASE_HOME/bin
```

## 启动Hbase

* 启动Master

```shell
hbase-daemon.sh start master
```

* 启动regionServer

```shell
hbase-daemon.sh start regionserver

# 如果RegionServer和Master时间不一致则无法启动RegionServer
```

