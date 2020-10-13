# Zookeeper入门

## Zookeeper基本概念

### 集群角色

* Zookeeper使用Leader、Follower、Observer三种橘色，所有机器通过Leader选举过程来选定一台称为"Leader"的机器，Leader服务提供读和写服务。
* Follower和Observer都可以提供读服务，但是Observer不参与选举过程，也不参与写操作的"过半写成功"策略。

### 会话(Session)

* Zookeeper中一个客户端连接是指客户端和服务器之间的一个TCP长连接。Session的sessionTimeout时来设置客户端会话的超时时间，如果客户端由于网络原因断开链接在sessionTimeout时间内重新链接之前创建的会话仍然有效。

### 数据节点(ZNode)

* Zookeeper将所有数据存在内存中，数据模型是一棵树(Znode tree)，由"/"进行分割的路径就是一个Znode，每个Znode可以保存自己的数据内容，同时和一些列属性信息。
* Znode分为持久节点和临时节点，并且俩个类型的节点还有个属性,"SEQUENTIAL"标示是否为顺序节点。

### 版本

* Znode会维护一个Stat的数据结构，其记录了Znode的是那个数据版本分别为:version(当前ZNode的版本)、cversion(当前Znode子节点的版本)、aversion(当前Znode的ACL版本)

### Watcher

* Zookeeper运行用户在指定节点上注册一些Watcher，并且在一些特定事件触发的时候，Zookeeper服务端会将事件通知到感兴趣的客户端上去。

### ACL

* Zookeeker采用ACL策略进行权限控制，类似于UNIX文件系统的权限控制
  * CREATE:创建子节点的权限
  * READ:获取节点数据和子节点列表的权限
  * WRITE:更新节点数据的权限
  * DELETE:删除子节点的权限
  * ADMIN:设置节点ACL的权限

## Zookeeper工作机制

![Zookeeper工作机制](./img/Zookeeper工作机制.jpg)

## Zookeeper特点

* 一致性：数据一致性，数据按照顺序分批入库。
* 原子性： 事务要么成功要么失败，不会局部化（不会有部分状态不一致）。
* 单一视图： 客户端连接集群中的任意zk节点，数据都是一致的。
* 可靠性：每次对zk的操作状态都会保存在服务端。
* 实时性：客户端可以读取到zk服务端的最新数据。
* Zookeeper:一个Leader多个Follower以及ObServer。
* 集群中只要有半数以上节点存活Zookeeper集群就可以正常服务，多副本概念。
* 全局数据一致，基于ZAB原子广播协议，每个Server保存一份相同的数据副本，Client连接到那个Server，数据一致。
* 更新请求顺序执行，来自同一个client的更新请求按其发送顺序依次执行。

### 数据结构

* 按照树形结构存储数据，与Unix文件系统类似，每个节点称为一个Znode，每个Znode默认能够存储1MB的数据，每个ZNode都可以`通过其路径唯一标识`，也可以有子节点。
* 每个节点分为临时节点和永久节点，临时节点在客户端断开后消失
* 每一个zk节点都有各自的版本号，可以通过命令行来显示节点信息每当节点数据发生变化，那么该节点的版本号会累加（乐观锁）
* 删除/修改过时节点，版本号不匹配则会报错
* 每个zk节点存储的数据不宜过大，几k即可
* 节点可以设置权限acl，可以通过权限来限制用户的访问

### Znode数据结构

#### Stat结构体

 **状态信息、版本、权限相关**

| 状态属性       | 说明                                                         |
| -------------- | :----------------------------------------------------------- |
| czxit          | 节点创建时的 zxid                                            |
| mzxid          | 节点最新一次更新发生时的 zxid                                |
| ctime          | 节点创建时的时间戳.                                          |
| mtime          | 节点最新一次更新发生时的时间戳.                              |
| dataVersion    | 节点数据的更新次数.                                          |
| cversion       | 其子节点的更新次数                                           |
| aclVersion     | 节点 ACL(授权信息)的更新次数.                                |
| ephemeralOwner | 如果该节点为 ephemeral 节点, ephemeralOwner 值表示与该节点绑定的 session id. 如果该节点不是ephemeral节点, ephemeralOwner 值为 0. 至于什么是 ephemeral节点 |
| **dataLength** | 节点数据的字节数. |
| **numChildren** | 子节点个数 |

## Zookeeper参数解读

### tickTime

* 默认为200，通信心跳数，ZK服务器与客户端心跳时间，单位毫秒。ZK使用的基本时间，`服务器之间或客户端与服务器之间维持心跳的时间间隔`,每个tickTime时间就会发送一个心跳。
* 用于心跳机制，并设置最小的session超时时间为两倍心跳时间。(session的最小超时时间是2 * tickTime)

### initLimit

* 默认为10，LF初始通信时间，集群中的follower跟随者与Leader领导者服务器之间`初始化连接时`能容忍的最多心跳数(tickTime数量)，用它来限定集群中的Zookeeper服务器连接到Leader的时限，默认为(initLimit*tickTime=10 * 2s=20s)

### syncLimit

* 默认为5，LF同步通信时间，`集群中Leader与Follower之间的最大响应时间单位`,假如响应超过了syncLimit * tickTime，Leader认为Follower死掉，从服务器列表中删除Follower。

### dataDir

* 主要用于保存Zookeeper中的数据。

### clientPort

* 监听客户端连接的端口。

# Zookeeper内部原理

## 选举机制

* `半数机制:集群中半数以上集群存货，集群可用。所有Zookeeper适合安装奇数台服务器`。
* Zookeeper虽然在配置文件中没有指定`Master和Slave`。但是Zookeeper工作时是有一个节点为Leader，其他则为Follower，Leader是通过内部的选举机制临时产生的。

![Zookeeper特点](./img/Zookeeper特点.jpg)

* 服务器1启动，此时只有它一台服务器启动了，它发出去的报文没有任何响应，所以它的选举状态一直是LOOKING状态。
* 服务器2启动，它与最开始启动的服务器1进行通信，互相交换自己的选举结果，由于两者都没有历史数据，所以id值较大的服务器2胜出，`但是由于没有达到超过半数以上的因此还需要等待其他服务器`。
* 服务器3启动后，服务器1、2都将票投给myid最大的服务器索引服务器3成为Leader，后续来的服务器都是Follower节点。

## 节点类型

* 临时节点(Ephemeral):客户端和服务端断开连接后，创建的节点自己删除。
  * 临时顺序编号节点，ZNode也是按顺序增加，只不过断开连接后节点会被删除。
* 持久节点(Persistent):客户端和服务器端断开连接后，创建的节点不删除。
  * 持久化顺序节点，创建的ZNode会有一个顺序标识，znode名称会附加一个值，是一个单调递增的计数器，由父节点维护。

## 监听器原理

### 原理详解

* 首先由一个main线程
* main线程中创建Zookeeper客户端，这时会创建两个线程，一个负责网络连接通信(connect)一个负责监听(listener)
* 通过connect线程将主持的监听事件发送给Zookeeper
* 在Zookeeper的注册监听器列表中将注册的监听事件添加到列表中
* Zookeeper监听到有数据或路径变化，就会将这个消息发送给listener线程
* listener线程内部调用process方法

![Zookeeper特点](./img/监听器原理.jpg)

## 写数据流程

![Zookeeper写数据流程](./img/Zookeeper写数据流程.jpg)

# Zookeeper技术内幕

## 节点特性

### 节点类型

#### 持久节点(PERSISTENT)

* 一直存在在Zookeeper服务器上，直到有删除操作来主动清除这个节点。

#### 临时节点(EPHEMERAL)

* 生命周期与客户端的会话绑定在一起，如果客户端会话失败，这个临时节点会被自动清除。

#### 顺序节点(SEQUENTIAL)

* 每个父节点都会为它的第一级子节点维护一份顺序，用于记录下每个子节点创建的先后顺序，基于这个顺序特性，在创建子节点的时候，可以设置这个标记，创建这个节点的过程中，Zookeeper会自动为给定节点名加上一个数字后缀，作为一个新的、完整的节点名。
* 数字后缀的上限是整型的最大值。

### 状态信息

* 状态Stat包含的如下属性
  * czxid:即Created ZXID，表示该数据节点被创建时的事务ID
  * mzxid:即Modified ZXID，表示该节点最后一次被更新时的事务ID
  * ctime:即Created Time，表示节点被创建的时间
  * mtime:即Modified Time，表示该节点最后一次被更新的时间
  * version:即数据节点的版本号。
  * cversion:子节点的版本号
  * aversion:节点的ACL版本号
  * ephemeralOwner:创建该临时节点的会话的SessionId，如果该节点时持久节点，这个属性为0
  * dataLength:数据内容的长度
  * numChildren:当前节点的子节点的个数
  * pzxid:表示该节点的子节点列表最后一次被修改时的事务ID。只有子节点列表变更了才会变更pzxid，子节点内容变更不会影响pzxid

## Version

* Zookeeper在修改操作基于"CAS"乐观锁解决并发问题。

## Watcher数据变更的通知

* Zookeeper提供的一种分布式数据的发布/订阅功能，Zookeeper客户端会向服务端注册一个Watcher监听，当服务端的一些指定事件触发了这个Watcher，就会向指定客户端发送一个事件通知来实现分布式的通知功能。

![](../canal/img/Watcher机制.jpg)

* Zookeeper的Watcher机制主要包含客户端线程、客户端WatchManager和Zookeeper服务器。当Zookeeper服务器端触发Watcher事件后，会向客户端发送通知，客户端现场从WatchManager中取出对应的Watcher对象来执行回调逻辑。

### Watcher通知状态与数据类型

![](../canal/img/Watcher通知状态.jpg)

### 工作机制

* 总的分为三个过程:客户端注册Watcher、服务端处理Watcher和客户端回调Watcher。

### 特性

* 一次性
  * 无论服务端还是客户端，一旦一个Watcher被触发，Zookeeper都会将其从相应的存储中移除。
* 客户端串行执行
  * 客户端Watcher回调的过程是一个串行同步的过程，为了保证顺序。
* 轻量
  * WatchedEvent是Zookeeper整个watcher通知机制的最小通知单元，该数据包含通知状态、事件类型和节点路径。客户端向服务端注册Watcher时，并不是把Watcher对象传递到服务器，而是在客户端请求中使用boolean类型属性进行标记，同时服务端仅仅保存了当前连接的ServerCnxn对象。