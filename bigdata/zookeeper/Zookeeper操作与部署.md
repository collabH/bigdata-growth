# 分布式部署

## 集群规划

* hadoop1、hadoop2、hadoop3

## 环境准备

* 安装JDK环境
* 下载Zookeeper安装包
* 不同服务器创建zkData，用于存储Zookeeper数据目录
* 在`zkData下创建对应的服务器编号文件myid`，按照服务器来指定并且`不能重复`。
* 配置集群间通信

```properties
# server.服务器编号=服务器ip地址:服务器与集群中Leader服务器交换信息的端口，客户端端口:leader挂掉后用于重新选举的选举端口
server.1=localhost:2888:3888
server.2=localhost:2889:3889
server.3=localhost:2890:3890
```

## 配置

### Hadoop1

```properties
admin.serverPort=10001
tickTime=2000
dataDir=/Users/babywang/Documents/reserch/middleware/zk/zkCluster/zookeeper_data1
# 事务日志存储目录
dataLogDir=/Users/babywang/Documents/reserch/middleware/zk/zkCluster/zookeeper
_tx_data1
clientPort=2182
# 默认值为10，用于Leader服务器等待Follower启动，并完成数据同步的时间，Follower服务器启动的过程中，会与Leader建立链接并完成对数据的同步，从而确定自己对外提供服务的起始状态。Leader服务器运行Follower在initLimit时间内完成这个工作。
initLimit=20
# 默认值为5，用于Leader服务器和Follower之间进行心跳检测的最大延迟时间，在ZK运行过程中，Leader会与所有Follower进行心态检查来确定该服务器是否存活，Le如果Leader服务器在syncLimit无法获取Follower的心跳检查响应，就会认为该Follower服务器下线了。
syncLimit=5
# 默认为100000，用于配置相邻两次数据快照之间的事务操作次数，即zk会在sanpCount次事务操作之后进行一次数据快照。
snapCount=100000
# 默认为65536单位KB，即64MB。用于ZK事务日志文件预分配的磁盘空间大小。
preAllocSize=65536
# 默认为2 会话超时时间，用于限制服务端对客户端会话的超时时间。
minSessionTimeout=2
# 默认为20
maxSessionTimeout=20
# 默认为60 从Socket层面限制单个客户端与单台服务器之间的并发连接数，即以IP地址的力度来进行连接数的限制。如果设置为0即对连接数不做任何限制
maxClientCnxns=60
# 默认1048575字节，单个数据节点(ZNode)上可以存储的最大数据量大小。
jute.maxbuffer=1048575
# sever.id=host:port:port 第一个port指定Follower服务器与Leader进行运行时通信和数据同步的短裤，第二个端口用于Leader选举过程中的投票通信
server.1=localhost:2888:3888
server.2=localhost:2889:3889
server.3=localhost:2890:3890
# 默认为3，对历史事务日志和快照日志自动清理时需要保留的快照数据文件和对应事务日志文件的数量。
autopurge.snapRetainCount=3
# 默认为0，单位小时，配置历史文件自动清理的频率，如果为0或者负数，则不需要开启定时清理功能。
autopurge.purgeInterval=0
# 默认1000ms，事务日志进行fsync操作时消耗时间的报警阈值，一旦fsync操作的耗时超过这个阈值就会在日志中打出警告
fsync.warningthresholdms=1000
# 默认为yes，可选配置为yes和no，用于服务器是否在事务提交的时候将日志写入操作强制刷入磁盘
forceSync=yes
# 默认为yes，可以选配no，表示Leader服务器是否能够接受客户端链接，默认情况下为yes表示leader服务器可以接受并处理客户端的所有读写请求
leaderSevers=yes
# 默认为5000ms，代表在leader选举过程中，各个服务器之间进行TCP链接创建的超时时间
cnxTimeout=5000
# zk选举算法，3.4.0后0，1，2被移除，目前只提供tcp版本的FastLeaderElection算法
electionAlg
```

### Hadoop2

```properties
tickTime=2000
dataDir=/Users/babywang/Documents/reserch/middleware/zk/zkCluster/zookeeper_data2
# 事务日志存储目录
dataLogDir=/Users/babywang/Documents/reserch/middleware/zk/zkCluster/zookeeper
_tx_data2
clientPort=2183
initLimit=20
syncLimit=5
server.1=localhost:2888:3888
server.2=localhost:2889:3889
server.3=localhost:2890:3890
```

### Hadoop3

```properties
tickTime=2000
dataDir=/Users/babywang/Documents/reserch/middleware/zk/zkCluster/zookeeper_data3
# 事务日志存储目录
dataLogDir=/Users/babywang/Documents/reserch/middleware/zk/zkCluster/zookeeper
_tx_data3
clientPort=2184
initLimit=20
syncLimit=5
server.1=localhost:2888:3888
server.2=localhost:2889:3889
server.3=localhost:2890:3890
```

## 开启ZookeeperJMX

* ZK默认开启了JMX功能，但是只支持本地连接,修改bin目录下的zkServer.sh

### 默认JMX配置

```properties
-Dcom.sum.management.jmxremote.port=5000
-Dcom.sum.management.jmxremote.ssl=false
-Dcom.sum.management.jmxremote.authenticate=false
```

# Shell操作

```shell
# 链接客户端
zkCli.sh -server ip:port
```

## create 

```
create [-s] [-e] [-c] [-t ttl] path [data] [acl] 
```

* 创建顺序节点 
```
create -s /name huangsm 
```
* 创建临时节点 
```
create -e /name huangsm 
当客户端断开连接后，心跳机制就会断开，然后临时节点就会自动删除 
```
* 创建持久节点 
```
create /name huangsm 
```
**通过ephemeralOwner来判断是否是临时节点，如果ephemeralOwner不是0x0则为临时节点** 

* 创建多级目录

```shell
create /name/hsm hhh
```

## set 

```
set [-s] [-v version] path data 
```
* 修改节点的值

```
set /name "wbd"
```

## delete 

```shell
delete [-v version] path 
deleteall path 
```
## watcher 

```shell
get [-s] [-w] path 
-w设置watcher  -s表示顺序节点 
```

* 父节点 增删改操作触发 
* 子节点 增删改操作触发 
* 创建父节点触发：nodeCreated 
```shell
stat -w /name  设置NodeCreated事件 
create /name 123 
WATCHER:: 
WatchedEvent state:SyncConnected type:NodeCreated path:/name 
Created /name 
```

* 修改父节点触发：NodeDataChanged 
```shell
设置修改事件 
[zk: localhost:2181(CONNECTED) 39] get -w /name 
456 
[zk: localhost:2181(CONNECTED) 40] set -s /name hsm 
WATCHER:: 
WatchedEvent state:SyncConnected type:NodeDataChanged path:/name 
cZxid = 0xd4 
ctime = Sun Sep 15 23:34:52 CST 2019 
mZxid = 0xd7 
mtime = Sun Sep 15 23:36:31 CST 2019 
pZxid = 0xd4 
cversion = 0 
dataVersion = 3 
aclVersion = 0 
ephemeralOwner = 0x0 
dataLength = 3 
numChildren = 0 
```

* 删除父节点触发：NodeDelete 
```shell
设置删除事件 
[zk: localhost:2181(CONNECTED) 42] ls -w /name 
[] 
[zk: localhost:2181(CONNECTED) 43] delete /name 
WATCHER:: 
WatchedEvent state:SyncConnected type:NodeDeleted path:/name 
```
## ACL 


* getAcl：获取某个节点的acl权限信息 
```shell
getAcl [-s] path 
```
* setAcl：设置某个节点的acl权限信息 
```shell
setAcl [-s] [-v version] [-R] path acl 
```

* addauth:输入认证授权信息，注册时输入明文密码（登录），但是在zk的系统里，密码是以加密的形式存在的 
```shell
addauth scheme auth 
```
### acl的构成

* zk的acl通过[scheme:id​ : id:permissions]来构成权限列表 
    * scheme:代表采用的某种权限机制 
        * world：world下只有一个id，即只有一个用户，也就是anyone，那么组合的写法就是world：anyone:[permissions] 
        * auth:代表认证登录，需要需要注册用户权限就可以，形式为auth:user:password:[permissions] 
        * digest:需要对密码加密才能访问,组合形式为：degest:username:BASE64(SHA1(password)):[permissions] 
        * ip:设置为ip指定的ip地址，此时限制ip进行访问，比如ip:127.0.0.1:[permissions] 
        * super:代表超级管理员,拥有所有的权限 
    * id：代表允许访问的用户 
    * permissions：权限组合字符串 
        * 权限字符串缩写crdwa 
            * CREATE:创建子节点 
            * READ：获取节点/子节点 
            * WRITE：设置节点数据 
            * DELETE：删除子节点 
            * ADMIN：设置权限 
### 设置权限 


* 第一种的world 
```
setAcl /name/abc world:anyone:crwa 
设置创建、读、写、设置权限 
```

* 第二种auth 
```
auth:user:pwd:cdrwa 
user和pwd都代表第一个注册的用户和密码 
```
* 第三种digest 
```
digest:user:BASE64(SHA1(pwd)):cdrwa 
//登录用户 
addauth digest user:pwd 
```

* 第四种ip 
```
ip:127.0.0.1:cdrwa 
```

* 第五种super 
```
Super 
1 修改zkServer.sh增加super管理员 
2 重启zkServer 
```
![图片](https://uploader.shimo.im/f/XrWogcx6pqkMm2YL.png!thumbnail)


1. zk四字命令Four letter worlds 
```properties
#添加四字命令白名单 
4lw.commands.whitelist=* 
```

* zk可以通过它自身提供的简写命令来和服务器进行交互 
* 需要使用到nc命令，安装：yum install nc 
* echo[command]|nc [ip][port] 
```properties
[stat] 查看zk的状态信息，以及是否mode 
[ruok] 查看当前zkserver是否启动，返回imok 
[dump] 列出未经处理的会话和临时节点 
[conf] 查看服务器配置 
[cons] 展示连接到服务器的客户端信息 
[envi] 环境变量 
[mntr] 监控zk健康信息 
[wchs] 展示watch的信息 
[wchc]与[wchp] session与watch及path与watch信息 
```
# 原生API使用

## 创建连接

```java
public class ZookeeperConnection implements Watcher {
    final static Logger log = LoggerFactory.getLogger(ZookeeperConnection.class);

    public static final String zkServerPath = "127.0.0.1:2181";
    public static final Integer timeout = 5000;

    public static void main(String[] args) throws Exception {
        /**
         * 客户端和zk服务端链接是一个异步的过程
         * 当连接成功后后，客户端会收的一个watch通知
         *
         * 参数：
         * connectString：连接服务器的ip字符串，
         * 		比如: "192.168.1.1:2181,192.168.1.2:2181,192.168.1.3:2181"
         * 		可以是一个ip，也可以是多个ip，一个ip代表单机，多个ip代表集群
         * 		也可以在ip后加路径
         * sessionTimeout：超时时间，心跳收不到了，那就超时
         * watcher：通知事件，如果有对应的事件触发，则会收到一个通知；如果不需要，那就设置为null
         * canBeReadOnly：可读，当这个物理机节点断开后，还是可以读到数据的，只是不能写，
         * 					       此时数据被读取到的可能是旧数据，此处建议设置为false，不推荐使用
         * sessionId：会话的id
         * sessionPasswd：会话密码	当会话丢失后，可以依据 sessionId 和 sessionPasswd 重新获取会话
         */
        ZooKeeper zk = new ZooKeeper(zkServerPath, timeout, new ZookeeperConnection());

        log.warn("客户端开始连接zookeeper服务器...");
        log.warn("连接状态：{}", zk.getState());

        Thread.sleep(2000);

        log.warn("连接状态：{}", zk.getState());
    }

    public void process(WatchedEvent watchedEvent) {
        log.warn("接受到watch通知：{}", watchedEvent);
    }
}


```

## 会话重连

```java
public class ZkConnectionSessionWatcher implements Watcher {
    final static Logger log = LoggerFactory.getLogger(ZkConnectionSessionWatcher.class);

    public static final String zkServerPath = "127.0.0.1:2181";
    public static final Integer timeout = 5000;

    public static void main(String[] args) throws Exception {

        ZooKeeper zk = new ZooKeeper(zkServerPath, timeout, new ZkConnectionSessionWatcher());
        long sessionId = zk.getSessionId();
        byte[] sessionPasswd = zk.getSessionPasswd();
        log.warn("客户端开始连接zookeeper服务器...");
        log.warn("连接状态：{}session id:{},pwd:{}", zk.getState(),sessionId,sessionPasswd);
        Thread.sleep(2000);
        log.warn("连接状态：{}session id:{},pwd:{}", zk.getState(),sessionId,sessionPasswd);
        zk = new ZooKeeper(zkServerPath, timeout, new ZkConnectionSessionWatcher(), sessionId, sessionPasswd);
        log.warn("重新连接状态：{}", zk.getState());
        Thread.sleep(2000);
        log.warn("重新连接状态：{}", zk.getState());
    }

    public void process(WatchedEvent watchedEvent) {
        log.warn("接受到watch通知：{}", watchedEvent);
    }
}
```

## 节点增删改查

```java
public class ZkNodeOperator implements Watcher {
    private ZooKeeper zk = null;
    private static final Integer timeout = 5000;
    private static final String zkServerPath = "127.0.0.1:2181";

    public ZkNodeOperator() {

    }

    public ZkNodeOperator(String connectString) {
        try {
            zk = new ZooKeeper(connectString, timeout, this);
        } catch (IOException e) {
            log.warn("e", e);
            if (zk != null) {
                try {
                    zk.close();
                } catch (InterruptedException ex) {
                    log.warn("e", e);
                }
            }
        }
    }


    public String createNode(String path, byte[] data, List<ACL> aclList) {
        String result = "";
        /**
         * 同步或者异步创建节点，都不支持子节点的递归创建，异步有一个callback函数
         * 参数：
         * path：创建的路径
         * data：存储的数据的byte[]
         * acl：控制权限策略
         * 			Ids.OPEN_ACL_UNSAFE --> world:anyone:cdrwa
         * 			CREATOR_ALL_ACL --> auth:user:password:cdrwa
         * createMode：节点类型, 是一个枚举
         * 			PERSISTENT：持久节点
         * 			PERSISTENT_SEQUENTIAL：持久顺序节点
         * 			EPHEMERAL：临时节点
         * 			EPHEMERAL_SEQUENTIAL：临时顺序节点
         */
        //同步创建临时节点
//            result = zk.create(path, data, aclList, CreateMode.EPHEMERAL);
        try {
            String ctx = "{'create':'success'}";
            zk.create(path, data, aclList, CreateMode.PERSISTENT, (rc, p, c, name) -> {
                log.warn("创建节点:{}", path);
                log.warn("rc:{},ctx:{},name:{}", rc, c, name);
            }, ctx);
            log.warn("create result:{}", result);
            //fixme 睡眠为了防止节点还没创建成功，zk客户端就断开连接
            Thread.sleep(2000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        return result;

    }

    /**
     * 修改节点数据
     *
     * @param path
     * @param data
     * @param version
     */
    public void setNode(String path, byte[] data, int version) {/*
        try {

            //同步修改
            Stat stat = zk.setData(path, data, version);

            log.warn("stat:{}", stat);
        } catch (KeeperException | InterruptedException e) {
            e.printStackTrace();
        }*/
        //异步修改
        String ctx = "{'create':'success'}";
        zk.setData(path, data, version, (rc, p, c, name) -> {
            log.warn("创建节点:{}", p);
            log.warn("rc:{},ctx:{},name:{}", rc, c, name);
        }, ctx);
        try {
            Thread.sleep(10000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    public void deleteNode(String path, int version) {
        try {
            //同步删除
            zk.delete(path, version);
            //异步删除
            //zk.delete(path, version, (i, s, o) -> log.warn("创建节点:{},{}.{}", i,s,o), "zhangsan");
        } catch (InterruptedException | KeeperException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void process(WatchedEvent watchedEvent) {
        log.warn("event:{}", watchedEvent);
    }

    public static void main(String[] args) {
        ZkNodeOperator zkNodeOperator = new ZkNodeOperator(zkServerPath);
        //zkNodeOperator.createNode("/test1", "zhangsan".getBytes(), ZooDefs.Ids.OPEN_ACL_UNSAFE);
        //zkNodeOperator.setNode("/test1", "luoquanwg".getBytes(), 1);
        zkNodeOperator.deleteNode("/test1", 1);
    }

}

```

### 节点查询和监听

```java
public class QueryAndWatch{
    private static final CountDownLatch LATCH = new CountDownLatch(1);
     private static final Stat stat = new Stat();
    
     /**
         * 查询
         *
         * @param path
         * @param stat
         * @return
         */
        public byte[] queryNode(String path, boolean watch, Stat stat) {
            byte[] data = new byte[0];
            try {
                /**
                 * 参数
                 * path:节点路径
                 * watch:true或false 注册一个watch事件
                 * stat:状态
                 */
                data = zk.getData(path, watch, stat);
                log.warn(new String(data, Charset.defaultCharset()));
                log.warn("version :{}", stat.getVersion());
                LATCH.await();
    
            } catch (KeeperException e) {
                e.printStackTrace();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
    
            return data;
        }
    
        @Override
        public void process(WatchedEvent watchedEvent) {
            log.warn("event:{}", watchedEvent);
            try {
                switch (watchedEvent.getType()) {
                    case NodeDataChanged:
                        byte[] bytes = zk.getData("/name", false, stat);
                        log.warn(new String(bytes, Charset.defaultCharset()));
                        log.warn("version变化:{}", stat.getVersion());
                        LATCH.countDown();
                        break;
                    case NodeCreated:
                        break;
                    case NodeDeleted:
                        break;
                    case NodeChildrenChanged:
                        break;
                    default:
                        break;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
}
    
```

### 子节点查询和监听

```java
public class ZKGetChildrenList implements Watcher {

    private ZooKeeper zookeeper = null;

    public static final String zkServerPath = "localhost:2181";
    public static final Integer timeout = 5000;

    public ZKGetChildrenList() {
    }

    public ZKGetChildrenList(String connectString) {
        try {
            zookeeper = new ZooKeeper(connectString, timeout, new ZKGetChildrenList());
        } catch (IOException e) {
            e.printStackTrace();
            if (zookeeper != null) {
                try {
                    zookeeper.close();
                } catch (InterruptedException e1) {
                    e1.printStackTrace();
                }
            }
        }
    }

    private static CountDownLatch countDown = new CountDownLatch(1);

    public static void main(String[] args) throws Exception {

        ZKGetChildrenList zkServer = new ZKGetChildrenList(zkServerPath);

        /**
         * 参数：
         * path：父节点路径
         * watch：true或者false，注册一个watch事件
         */
//		List<String> strChildList = zkServer.getZookeeper().getChildren("/name", true);
//		for (String s : strChildList) {
//			System.out.println(s);
//		}

        // 异步调用
        String ctx = "{'callback':'ChildrenCallback'}";
//		zkServer.getZookeeper().getChildren("/name", true, new ChildrenCallBack(), ctx);
        zkServer.getZookeeper().getChildren("/name", true, (i, s, o, s1) -> {
            log.warn("{},{},{},{}", i, s, o, s1);
        }, ctx);

        countDown.await();
    }

    @Override
    public void process(WatchedEvent event) {
        try {
            //监听子节点变化
            if (event.getType() == EventType.NodeChildrenChanged) {
                System.out.println("NodeChildrenChanged");
                ZKGetChildrenList zkServer = new ZKGetChildrenList(zkServerPath);
                List<String> strChildList = zkServer.getZookeeper().getChildren(event.getPath(), false);
                for (String s : strChildList) {
                    System.out.println(s);
                }
                countDown.countDown();
            } else if (event.getType() == EventType.NodeCreated) {
                System.out.println("NodeCreated");
            } else if (event.getType() == EventType.NodeDataChanged) {
                System.out.println("NodeDataChanged");
            } else if (event.getType() == EventType.NodeDeleted) {
                System.out.println("NodeDeleted");
            }
        } catch (KeeperException e) {
            e.printStackTrace();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    public ZooKeeper getZookeeper() {
        return zookeeper;
    }

    public void setZookeeper(ZooKeeper zookeeper) {
        this.zookeeper = zookeeper;
    }

}

```

# Curator

## 创建会话

```java
public static void createClient() {
        // 创建curator客户端
        CuratorFramework client = CuratorFrameworkFactory.newClient("hadoop:2181", new RetryNTimes(3, 5000));

        // 启动
        client.start();
    }
```

## 创建节点

```java
public static void createNode() throws Exception {
        CuratorFramework client = createClient();
        String path = client.create()
                .creatingParentsIfNeeded()
                .withMode(CreateMode.PERSISTENT)
                .forPath("/create-node/hello", "hello".getBytes());
        System.out.println(path);
    }
```

## 删除节点

```java
 public static void deleteNode() throws Exception {
        CuratorFramework client = createClient();

        client.delete()
                .guaranteed() //保证强制删除node
                .deletingChildrenIfNeeded() //递归删除全部路径
                .withVersion(0)
                .inBackground(new BackgroundCallback() {
                    @Override
                    public void processResult(CuratorFramework client, CuratorEvent event) throws Exception {
                        System.out.println(event.toString());
                    }
                })
                .forPath("/create-node/hello");
    }
```

## 读取数据

```java
  public static void readNode() throws Exception {
        CuratorFramework client = createClient();
        Stat stat = new Stat();
        byte[] bytes = client.getData()
                // 读取该节点的stat
                .storingStatIn(stat)
                .forPath("/create-node/hello");

        System.out.println(new String(bytes, Charset.defaultCharset()));
        System.out.println(stat.toString());
    }
```

## 修改数据

```java
 public static void updateNode() throws Exception {
        CuratorFramework client = createClient();

        client.setData()
                .withVersion(0)
                .forPath("/create-node/hello", "zhangsan".getBytes());
    }
```

## Watcher

### 添加节点监听器

```java
 public static void addWatcher() throws Exception {
        CuratorFramework client = CuratorClient.createClient();

        client.create()
                .creatingParentsIfNeeded()
                .withMode(CreateMode.EPHEMERAL)
                .forPath("/watcher", "hello".getBytes());

        NodeCache nodeCache = new NodeCache(client, "/watcher", false);

        nodeCache.start();
        nodeCache.getListenable().addListener(new NodeCacheListener() {
            @Override
            public void nodeChanged() throws Exception {
                System.out.println("我变化了");
            }
        });

        client.setData().forPath("/watcher", "test".getBytes());

        Thread.sleep(2000);
        client.delete().deletingChildrenIfNeeded().forPath("/watcher");

        Thread.sleep(Integer.MAX_VALUE);
    }
```

### 添加子节点监听器

```java
public static void createChildrenNode() throws Exception {
        CuratorFramework client = CuratorClient.createClient();

        client.create()
                .creatingParentsIfNeeded()
                .withMode(CreateMode.EPHEMERAL)
                .forPath("/childwatcher/test", "hello".getBytes());

        PathChildrenCache childrenCache = new PathChildrenCache(client, "/childwatcher", true);
        childrenCache.start();

        childrenCache.getListenable().addListener(new PathChildrenCacheListener() {
            @Override
            public void childEvent(CuratorFramework curatorFramework, PathChildrenCacheEvent pathChildrenCacheEvent) throws Exception {
                System.out.println(pathChildrenCacheEvent.getType());
            }
        });

        Thread.sleep(2000);

        // update
        client.setData()
                .withVersion(0)
                .forPath("/childwatcher/test", "hh".getBytes());

        // 添加新的子节点
        client.create()
                .creatingParentsIfNeeded()
                .withMode(CreateMode.EPHEMERAL)
                .forPath("/childwatcher/test1", "hello".getBytes());


        // 删除子节点
        client.delete()
                .withVersion(0)
                .forPath("/childwatcher/test1");

        Thread.sleep(Integer.MAX_VALUE);
    }
```

## Master选举机制

```java
public class MasterLeaderSelector {
    public static void main(String[] args) throws InterruptedException {
        CuratorFramework client = CuratorClient.createClient();

        LeaderSelector leaderSelector = new LeaderSelector(client, "/leaderselector/master", new LeaderSelectorListener() {
            // 成为leader
            @Override
            public void takeLeadership(CuratorFramework client) throws Exception {
                System.out.println("成为Master");
                Thread.sleep(3000);
                System.out.println("完成master操作 释放master权力");
            }

            // 状态变更
            @Override
            public void stateChanged(CuratorFramework client, ConnectionState newState) {
                if (newState == ConnectionState.SUSPENDED || newState == ConnectionState.LOST) {
                    throw new CancelLeadershipException();
                }
            }
        });
        leaderSelector.autoRequeue();
        leaderSelector.start();
        Thread.sleep(Integer.MAX_VALUE);
    }
}
```

