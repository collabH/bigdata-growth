# 概述

## 工作原理

* Canal的核心思想是模拟MySQL Slave的交互协议，将自己伪装成一个MySQL的Slave机器，然后不断地向Master服务器发送Dump请求。Master收到Dump请求后，就会开始推送相应的Binlog给该Slave(也就是Canal)。Canal收到Binlog，解析出相应的Binlog对象后就可以进行二次消费了。

![](./img/Canal工作原理.jpg)

### Canal Server主备切换设计

* 在Canal设计中，基于容灾的考虑会配置多个Canal Server来负责一个MySQL数据库实例的数据增量复制。为了减少Canal Server的Dump请求对MySQL Master带来的性能影响，要求`不同的Canal Server上的instance在同一时刻只能有一个处于Running状态，其他的instance都处于Standby状态，这可以让Canal拥有主备自动切换的能力`。主要依赖于Zookeeper的Watcher来完成的主备自动切换能力。

![](./img/Canal Server主备切换机制.jpg)

1. 尝试启动
   * 每个Canal Server在启动某个Canal instance的时候都会首先向Zookeeper进行一次尝试启动判断。向Zookeeper创建一个相同的临时节点，哪个Canal Server创建成功了，就让哪个Canal Server启动。
2. 启动instance
   * 假设最终IP地址为10.21.144.51的Canal Server成功创建了该节点，那么它就会将自己的机器信息写入到该节点中去:"{"active":true,"address":"10.20.144.51:11111","cid":1}",并同时启动instance。其他Canal Server由于没有成功创建节点，会讲自己的状态设置为Standby，同时对"/otter/canal/destinations/example/running"节点注册Watcher监听，以监听该节点变化情况。
3. 主备切换
   * Canal Server运行时期突然宕机的话会自动进行主备切换，基于Zookeeper临时节点的特点，客户端断开链接会自动删除临时节点，StandBy状态的Canal Server会收到Watcher的通知然后创建临时节点成为新的Active节点。

* 避免"脑裂"策略，每个Standby会延迟一段时间再去成为Active，原本是Active节点可以无需延迟直接继续成为Active，延迟时间默认为5秒，即Running节点针对假死状态的保护期为5秒。

### Canal Client的HA设计

1. 从Zookeeper中读取出当前处于Running状态的Server。
   * Canal Client在启动的时候，会从"/otter/canal/destinations/example/running"节点上读取出当前处于Running状态的Canal Server。同时，客户端也会将自己的信息注册到Zookeeper的"/otter/canal/destinations/example/1001/running"节点上，其中"1001"代表客户端的唯一标识，内容为"{"active":true,"address":"10.12.48.171:50544","clientId":1001}"
2. 注册Running节点数据变化的Watcher
   * Canal Server会存在挂掉的问题，Canal Client需要监听Canal Server运行的节点，如果该节点发生变化可以通知到客户端。
3. 连接对应的Running Server进行数据消费。

### 数据消费位点记录

* Canal Client存在重启或其他变化，为了避免数据消费的重复性和顺序错乱，Canal必须对数据消费的位点进行实时记录。数据消费成功后，Canal Server会在Zookeeper中记录下当前最后一次消费成功的Binary Log位点，一旦发生Client重启，只需要从这个最后一个位点继续进行消费即可。
* 具体是在Zookeeper的"/otter/canal/destinations/example/1001/cursor"节点记录下客户端消费的详细位点新鲜。

```json
{
  "@type":"com.alibaba.otter.canal.protocol.postion.LogPosition",
  "identity":{"slaveId":-1,"sourceAddress":{"address":"10.20.144.15","port":"3306"}},
  "postition":{"included":false,"journalName":"mysql-bin.002253","position":2574756,"timestamp":1363688722000}
}
```

