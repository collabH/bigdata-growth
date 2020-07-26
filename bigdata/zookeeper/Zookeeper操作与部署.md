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
clientPort=2182
initLimit=20
syncLimit=5
server.1=localhost:2888:3888
server.2=localhost:2889:3889
server.3=localhost:2890:3890
```

### Hadoop2

```properties
tickTime=2000
dataDir=/Users/babywang/Documents/reserch/middleware/zk/zkCluster/zookeeper_data2
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
clientPort=2184
initLimit=20
syncLimit=5
server.1=localhost:2888:3888
server.2=localhost:2889:3889
server.3=localhost:2890:3890
```

# Shell操作

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
# API使用

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

