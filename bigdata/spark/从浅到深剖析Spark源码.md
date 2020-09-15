# 从Spark Shell剖析

## 修改spark shell日志

```properties
log4j.logger.org.apache.spark.repl.Main=INFO
```

## Spark shell核心对象

* 运行SparkShell查看打印日志
  * SecurityManager
  * SparkEnv
  * BlockManagerMasterEndpoint
  * DiskBlockManager
  * MemoryStore
  * SparkUI
  * Executor
  * NettyBlockTransferService
  * BlockManager
  * BlockManagerMaster
  * SingleEventLogFileWriter

## spark-shell的main方法

```shell
sfunction main() {
  if $cygwin; then
    stty -icanon min 1 -echo > /dev/null 2>&1
    export SPARK_SUBMIT_OPTS="$SPARK_SUBMIT_OPTS -Djline.terminal=unix"
    "${SPARK_HOME}"/bin/spark-submit --class org.apache.spark.repl.Main --name "Spark shell" "$@"
    stty icanon echo > /dev/null 2>&1
  else
    export SPARK_SUBMIT_OPTS
    "${SPARK_HOME}"/bin/spark-submit --class org.apache.spark.repl.Main --name "Spark shell" "$@"
  fi
}
```

* 从最终设置的SPARK_SUBMIT_OPTS变量，最终是通过spark-submit启动`org.apache.spark.repl.Main`类来运行Spark-shell，本质上spark-shell启动的就是一个sparkSubmit进程。

## spark-submit

```shell
if [ -z "${SPARK_HOME}" ]; then
  source "$(dirname "$0")"/find-spark-home
fi

# disable randomized hash for string in Python 3.3+
export PYTHONHASHSEED=0

exec "${SPARK_HOME}"/bin/spark-class org.apache.spark.deploy.SparkSubmit "$@"
```

* 从命令行看出，最终是通过spark-class调用`org.apache.spark.deploy.SparkSubmit`类

## spark-class脚本

```shell
#!/usr/bin/env bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if [ -z "${SPARK_HOME}" ]; then
  source "$(dirname "$0")"/find-spark-home
fi

. "${SPARK_HOME}"/bin/load-spark-env.sh

# Find the java binary
if [ -n "${JAVA_HOME}" ]; then
  RUNNER="${JAVA_HOME}/bin/java"
else
  if [ "$(command -v java)" ]; then
    RUNNER="java"
  else
    echo "JAVA_HOME is not set" >&2
    exit 1
  fi
fi

# Find Spark jars.
if [ -d "${SPARK_HOME}/jars" ]; then
  SPARK_JARS_DIR="${SPARK_HOME}/jars"
else
  SPARK_JARS_DIR="${SPARK_HOME}/assembly/target/scala-$SPARK_SCALA_VERSION/jars"
fi

if [ ! -d "$SPARK_JARS_DIR" ] && [ -z "$SPARK_TESTING$SPARK_SQL_TESTING" ]; then
  echo "Failed to find Spark jars directory ($SPARK_JARS_DIR)." 1>&2
  echo "You need to build Spark with the target \"package\" before running this program." 1>&2
  exit 1
else
  LAUNCH_CLASSPATH="$SPARK_JARS_DIR/*"
fi

# Add the launcher build dir to the classpath if requested.
if [ -n "$SPARK_PREPEND_CLASSES" ]; then
  LAUNCH_CLASSPATH="${SPARK_HOME}/launcher/target/scala-$SPARK_SCALA_VERSION/classes:$LAUNCH_CLASSPATH"
fi

# For tests
if [[ -n "$SPARK_TESTING" ]]; then
  unset YARN_CONF_DIR
  unset HADOOP_CONF_DIR
fi

# The launcher library will print arguments separated by a NULL character, to allow arguments with
# characters that would be otherwise interpreted by the shell. Read that in a while loop, populating
# an array that will be used to exec the final command.
#
# The exit code of the launcher is appended to the output, so the parent shell removes it from the
# command array and checks the value to see if the launcher succeeded.
build_command() {
  "$RUNNER" -Xmx128m $SPARK_LAUNCHER_OPTS -cp "$LAUNCH_CLASSPATH" org.apache.spark.launcher.Main "$@"
  printf "%d\0" $?
}

# Turn off posix mode since it does not allow process substitution
set +o posix
CMD=()
DELIM=$'\n'
CMD_START_FLAG="false"
while IFS= read -d "$DELIM" -r ARG; do
  if [ "$CMD_START_FLAG" == "true" ]; then
    CMD+=("$ARG")
  else
    if [ "$ARG" == $'\0' ]; then
      # After NULL character is consumed, change the delimiter and consume command string.
      DELIM=''
      CMD_START_FLAG="true"
    elif [ "$ARG" != "" ]; then
      echo "$ARG"
    fi
  fi
done < <(build_command "$@")

COUNT=${#CMD[@]}
LAST=$((COUNT - 1))
LAUNCHER_EXIT_CODE=${CMD[$LAST]}

# Certain JVM failures result in errors being printed to stdout (instead of stderr), which causes
# the code that parses the output of the launcher to get confused. In those cases, check if the
# exit code is an integer, and if it's not, handle it as a special error case.
if ! [[ $LAUNCHER_EXIT_CODE =~ ^[0-9]+$ ]]; then
  echo "${CMD[@]}" | head -n-1 1>&2
  exit 1
fi

if [ $LAUNCHER_EXIT_CODE != 0 ]; then
  exit $LAUNCHER_EXIT_CODE
fi

CMD=("${CMD[@]:0:$LAST}")
exec "${CMD[@]}"
```

* 检查环境变量，最终通过` "$RUNNER" -Xmx128m $SPARK_LAUNCHER_OPTS -cp "$LAUNCH_CLASSPATH" org.apache.spark.launcher.Main "$@"  printf "%d\0" $?`运行org.apache.spark.launcher.Main类
* 核心运行机制查看spark源码`org.apache.spark.launcher.Main`类

## 源码执行流程

* SparkSubmit.Main-->repl.Main-->SparkILoop.initializeSpark

# Spark基础设施

## Spark RPC框架

* spark各个组件间的消息互通、用户文件与Jar包的上传、节点间的Shuffle过程、Block数据的复制与备份等。
* Spark2.x.x基于NettyStreamManager实现Shuffle过程和Block数据的复制与备份。

![RPC](./img/RPC.jpg)

### Spark RPC类图

![rpc类图](./img/Spark NettyRPC类图.jpg)

### 相关参数

```scala
# rpc的io线程数根据核数决定
spark.rpc.io.threads默认为numUsableCores
# rpc网络连接超时时间
spark.network.timeout
# rpc并发连接数
spark.rpc.io.numConnectionsPerPeer
# rpc服务端线程个数
spark.rpc.io.serverThreads
# rpc客户端线程个数
spark.rpc.io.clientThreads
# rpc的SO_RVCBUF的大小，默认设置是 网络的延迟 * 网络带宽，比如延迟是1ms，带宽是10Gbps最终求出来大约是1.25MB
spark.rpc.io.receiveBuffer
spark.rpc.io.sendBuffer
# rpc连接线程数
spark.rpc.connect.threads
# dispatcher线程数，会有线程池支持numThreads的MessageLoop，以while true的形式
spark.rpc.netty.dispatcher.numThreads
```

### RPC组件

* TransportContext:传输上下文，包含用于创建传输服务端(TransportServer)和传输客户端工厂(TransportClientFactory)的上下文信息，并支持使用Transport-ChannelHandler设置Netty提供SocketChannel的Pipeline的实现。
* TransportConf:传输上下文的配置
* RpcHandler:对调用传输客户端(TransportClient)的sendRPC方法发送的消息进行处理的程序。
* MessageEncoder:在讲消息放入管道前，先对消息内容进行编码，防止管道另一端读取时丢包和解析错误。
* MessageDecoder:对从管道中读取的ByteBuffer进行解析，防止丢包和解析错误。
* TransportFrameDecoder:对从管道读取的ByteBuffer按照数据帧进行解析。
* RpcResponseCallback:RpcHandler对请求的消息处理完毕进行回调的接口。
* ClientPool：在两个对等节点间维护的关于TransportClient的池子。ClientPool是TransportClientFactory的内部组件。
* TransportClient:RPC框架的客户端，用于获取预先协商好的流中的连续块。TransportClient旨在允许有效传输大量数据，这些数据将被拆分成几百KB到几MB的块。当TransportClient处理从流中获取的块时，实际的设置是在传输层之外完成的。sendRPC方法能够在客户端和服务端的同一水平线的通信进行这些设置。
* TransportClientBootstrap：当服务端响应客户端连接时在客户端执行一次的引导程序。
* TransportResponseHandler：用于处理服务端的响应，并且对发出请求的客户端进行响应的处理程序。
* TransportChannelHandler：代理由TransportRequestHandler处理的请求和由Transport-ResponseHandler处理的响应，并加入传输层的处理。
* TransportServer:RPC框架的服务端，提供高效的、低级别的流服务。
* NettyStreamManager:管理SparkContext添加的file、jar或dir等。

### TransportConf

```java
  /**
     * 配置提供起
     */
    private final ConfigProvider conf;

    /**
     * 模块
     */
    private final String module;

    public TransportConf(String module, ConfigProvider conf) {
        this.module = module;
        this.conf = conf;
        // 格式为spark.module.suffix
        SPARK_NETWORK_IO_MODE_KEY = getConfKey("io.mode");
        SPARK_NETWORK_IO_PREFERDIRECTBUFS_KEY = getConfKey("io.preferDirectBufs");
        SPARK_NETWORK_IO_CONNECTIONTIMEOUT_KEY = getConfKey("io.connectionTimeout");
        SPARK_NETWORK_IO_BACKLOG_KEY = getConfKey("io.backLog");
        SPARK_NETWORK_IO_NUMCONNECTIONSPERPEER_KEY = getConfKey("io.numConnectionsPerPeer");
        SPARK_NETWORK_IO_SERVERTHREADS_KEY = getConfKey("io.serverThreads");
        SPARK_NETWORK_IO_CLIENTTHREADS_KEY = getConfKey("io.clientThreads");
        SPARK_NETWORK_IO_RECEIVEBUFFER_KEY = getConfKey("io.receiveBuffer");
        SPARK_NETWORK_IO_SENDBUFFER_KEY = getConfKey("io.sendBuffer");
        SPARK_NETWORK_SASL_TIMEOUT_KEY = getConfKey("sasl.timeout");
        SPARK_NETWORK_IO_MAXRETRIES_KEY = getConfKey("io.maxRetries");
        SPARK_NETWORK_IO_RETRYWAIT_KEY = getConfKey("io.retryWait");
        SPARK_NETWORK_IO_LAZYFD_KEY = getConfKey("io.lazyFD");
        SPARK_NETWORK_VERBOSE_METRICS = getConfKey("io.enableVerboseMetrics");
    }
```

### TransportClientFactory

```java
// 客户端连接池，存储的是传输客户端数组和不同的所对象，保证不同的客户端有不同的锁。
private static class ClientPool {
        TransportClient[] clients;
        Object[] locks;

        ClientPool(int size) {
            clients = new TransportClient[size];
            locks = new Object[size];
            for (int i = 0; i < size; i++) {
                locks[i] = new Object();
            }
        }
    }

    private static final Logger logger = LoggerFactory.getLogger(TransportClientFactory.class);

    private final TransportContext context;
    private final TransportConf conf;
    private final List<TransportClientBootstrap> clientBootstraps;
    // 连接池，clientPool存在这里
    private final ConcurrentHashMap<SocketAddress, ClientPool> connectionPool;
```

* 创建客户端时会先去获取对应的ClientPool，然后在根据index获取对应的传输层客户端锁和传输层客户端，校验是否可用如果一系列校验没问题就返回给NettyRpcEnv中。

#### 创建TransportClient

```java
 private TransportClient createClient(InetSocketAddress address)
            throws IOException, InterruptedException {
        logger.debug("Creating new connection to {}", address);

        // 创建传输层引导程序Bootstrap，netty
        Bootstrap bootstrap = new Bootstrap();
        // 设置工作组，socket channel，其他参数
        bootstrap.group(workerGroup)
                .channel(socketChannelClass)
                // Disable Nagle's Algorithm since we don't want packets to wait
                .option(ChannelOption.TCP_NODELAY, true)
                .option(ChannelOption.SO_KEEPALIVE, true)
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, conf.connectionTimeoutMs())
                .option(ChannelOption.ALLOCATOR, pooledAllocator);

        if (conf.receiveBuf() > 0) {
            bootstrap.option(ChannelOption.SO_RCVBUF, conf.receiveBuf());
        }

        if (conf.sendBuf() > 0) {
            bootstrap.option(ChannelOption.SO_SNDBUF, conf.sendBuf());
        }

        final AtomicReference<TransportClient> clientRef = new AtomicReference<>();
        final AtomicReference<Channel> channelRef = new AtomicReference<>();

        bootstrap.handler(new ChannelInitializer<SocketChannel>() {
            @Override
            public void initChannel(SocketChannel ch) {
                TransportChannelHandler clientHandler = context.initializePipeline(ch);
                clientRef.set(clientHandler.getClient());
                channelRef.set(ch);
            }
        });

        // Connect to the remote server 连接到远程服务器
        long preConnect = System.nanoTime();
        ChannelFuture cf = bootstrap.connect(address);
        // 超时判断
        if (!cf.await(conf.connectionTimeoutMs())) {
            throw new IOException(
                    String.format("Connecting to %s timed out (%s ms)", address, conf.connectionTimeoutMs()));
            // 连接异常判断
        } else if (cf.cause() != null) {
            throw new IOException(String.format("Failed to connect to %s", address), cf.cause());
        }

        // 获取传输层客户端
        TransportClient client = clientRef.get();
        Channel channel = channelRef.get();
        assert client != null : "Channel future completed successfully with null client";

        // Execute any client bootstraps synchronously before marking the Client as successful.
        long preBootstrap = System.nanoTime();
        logger.debug("Connection to {} successful, running bootstraps...", address);
        try {
            // 给传输层客户端设置客户端引导程序，权限、安全相关
            for (TransportClientBootstrap clientBootstrap : clientBootstraps) {
                clientBootstrap.doBootstrap(client, channel);
            }
        } catch (Exception e) { // catch non-RuntimeExceptions too as bootstrap may be written in Scala
            long bootstrapTimeMs = (System.nanoTime() - preBootstrap) / 1000000;
            logger.error("Exception while bootstrapping client after " + bootstrapTimeMs + " ms", e);
            client.close();
            throw Throwables.propagate(e);
        }
        long postBootstrap = System.nanoTime();

        logger.info("Successfully created connection to {} after {} ms ({} ms spent in bootstraps)",
                address, (postBootstrap - preConnect) / 1000000, (postBootstrap - preBootstrap) / 1000000);

        return client;
    }
```

* 构建根引导程序Bootstrap并且对其配置
* 为根引导程序设置管道初始化回调函数，此会调函数将调用TransportContext的initializePipeline方法初始化Channel的pipeline。
* 使用根引导程序连接远程服务器，当连接成功对管道初始化时会回调初始化回调函数，将TransportClient和Channel对象分别设置到原子引用clientRef与channelRef中。
* 给TransportClient设置客户端引导程序，即设置TransportClientFactory中的Transport-ClientBootstrap列表
* 返回TransportClient对象

#### TransportServer

```java
private void init(String hostToBind, int portToBind) {

    // 选择IO模型，默认为NIO
    IOMode ioMode = IOMode.valueOf(conf.ioMode());
    // 创建bossGroup
    EventLoopGroup bossGroup = NettyUtils.createEventLoop(ioMode, 1,
      conf.getModuleName() + "-boss");
    // 创建workerGroup
    EventLoopGroup workerGroup =  NettyUtils.createEventLoop(ioMode, conf.serverThreads(),
      conf.getModuleName() + "-server");

    // 穿线byte申请器
    PooledByteBufAllocator allocator = NettyUtils.createPooledByteBufAllocator(
      conf.preferDirectBufs(), true /* allowCache */, conf.serverThreads());

    // 创建netty serverbootstrap
    bootstrap = new ServerBootstrap()
      .group(bossGroup, workerGroup)
      .channel(NettyUtils.getServerChannelClass(ioMode))
      .option(ChannelOption.ALLOCATOR, allocator)
      .option(ChannelOption.SO_REUSEADDR, !SystemUtils.IS_OS_WINDOWS)
      .childOption(ChannelOption.ALLOCATOR, allocator);

    //创建netty内存指标
    this.metrics = new NettyMemoryMetrics(
      allocator, conf.getModuleName() + "-server", conf);

    // 设置netty所需网络参数
    if (conf.backLog() > 0) {
      bootstrap.option(ChannelOption.SO_BACKLOG, conf.backLog());
    }

    if (conf.receiveBuf() > 0) {
      bootstrap.childOption(ChannelOption.SO_RCVBUF, conf.receiveBuf());
    }

    if (conf.sendBuf() > 0) {
      bootstrap.childOption(ChannelOption.SO_SNDBUF, conf.sendBuf());
    }

    bootstrap.childHandler(new ChannelInitializer<SocketChannel>() {
      @Override
      protected void initChannel(SocketChannel ch) {
        RpcHandler rpcHandler = appRpcHandler;
        // 为SocketChannel、rpcHandler分配引导程序
        for (TransportServerBootstrap bootstrap : bootstraps) {
          rpcHandler = bootstrap.doBootstrap(ch, rpcHandler);
        }
        context.initializePipeline(ch, rpcHandler);
      }
    });

    InetSocketAddress address = hostToBind == null ?
        new InetSocketAddress(portToBind): new InetSocketAddress(hostToBind, portToBind);
    // 绑定客户端地址
    channelFuture = bootstrap.bind(address);
    channelFuture.syncUninterruptibly();

    port = ((InetSocketAddress) channelFuture.channel().localAddress()).getPort();
    logger.debug("Shuffle server started on port: {}", port);
  }
```

#### 管道初始化

* 在创建TransportClient和初始化TransportServer时都调用了initlizePipeline方法，此方法将会调用Netty的API对管道初始化。

```java
# 真正创建TransportClient的地方
TransportChannelHandler channelHandler = createChannelHandler(channel, channelRpcHandler);

# 设置channel管道的编解码器
  channel.pipeline()
        .addLast("encoder", ENCODER)
        .addLast(TransportFrameDecoder.HANDLER_NAME, NettyUtils.createFrameDecoder())
        .addLast("decoder", DECODER)
        .addLast("idleStateHandler", new IdleStateHandler(0, 0, conf.connectionTimeoutMs() / 1000))
        // NOTE: Chunks are currently guaranteed to be returned in the order of request, but this
        // would require more logic to guarantee if this were not part of the same event loop.
        .addLast("handler", channelHandler);
```

![管道处理请求和响应流程图](./img/管道处理请求和响应流程图.png)

### Dispatcher

```scala
/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.spark.rpc.netty

import java.util.concurrent._

import javax.annotation.concurrent.GuardedBy
import org.apache.spark.SparkException
import org.apache.spark.internal.Logging
import org.apache.spark.network.client.RpcResponseCallback
import org.apache.spark.rpc._
import org.apache.spark.util.ThreadUtils

import scala.collection.JavaConverters._
import scala.concurrent.Promise
import scala.util.control.NonFatal

/**
 * 相当于对生产者的包装，使用endpoint包装一个inbox用于发送相应的RPC消息，形成endpoint和inbox的绑定关系
 *
 * A message dispatcher, responsible for routing RPC messages to the appropriate endpoint(s).
 * 一个消息转发器，负责将RPC消息路由到适当的端点。
 *
 * @param numUsableCores Number of CPU cores allocated to the process, for sizing the thread pool.
 *                       If 0, will consider the available CPUs on the host.
 */
private[netty] class Dispatcher(nettyEnv: NettyRpcEnv, numUsableCores: Int) extends Logging {

  /**
   * 初始化inbox对象
   *
   * @param name     endpont名字
   * @param endpoint endpoint
   * @param ref      nettyEndpoint应用
   */
  private class EndpointData(
                              val name: String,
                              val endpoint: RpcEndpoint,
                              val ref: NettyRpcEndpointRef) {
    // 收件箱，接收数据的地方
    val inbox = new Inbox(ref, endpoint)
  }

  // 维护全部的endpoint
  private val endpoints: ConcurrentMap[String, EndpointData] = {
    new ConcurrentHashMap[String, EndpointData]
  }
  // 维护全部的endpoint引用
  private val endpointRefs: ConcurrentMap[RpcEndpoint, RpcEndpointRef] =
    new ConcurrentHashMap[RpcEndpoint, RpcEndpointRef]

  // Track the receivers whose inboxes may contain messages.
  private val receivers = new LinkedBlockingQueue[EndpointData]

  /**
   * True if the dispatcher has been stopped. Once stopped, all messages posted will be bounced
   * immediately.
   */
  @GuardedBy("this")
  private var stopped = false

  /**
   * 注册RpcEndpont
   *
   * @param name
   * @param endpoint
   * @return
   */
  def registerRpcEndpoint(name: String, endpoint: RpcEndpoint): NettyRpcEndpointRef = {
    // 创建RpcEndpoint地址
    val addr = RpcEndpointAddress(nettyEnv.address, name)
    // 创建一个服务端引用,根据地址创建一个endpointRef
    val endpointRef = new NettyRpcEndpointRef(nettyEnv.conf, addr, nettyEnv)
    synchronized {
      // 如果rpc已经被关闭直接抛出rpc关闭异常
      if (stopped) {
        throw new IllegalStateException("RpcEnv has been stopped")
      }
      // 如果本地缓存中已经存在一个相同名字的rpcEndpoint则抛出异常
      if (endpoints.putIfAbsent(name, new EndpointData(name, endpoint, endpointRef)) != null) {
        throw new IllegalArgumentException(s"There is already an RpcEndpoint called $name")
      }
      // 从缓存中拿到EndpointData数据(包含name,endpoint,endpointRef,inbox)
      val data = endpoints.get(name)
      // endpoint和ref放入endpointRefs
      endpointRefs.put(data.endpoint, data.ref)
      //将数据放入放入receivers中
      receivers.offer(data) // for the OnStart message
    }
    endpointRef
  }

  def getRpcEndpointRef(endpoint: RpcEndpoint): RpcEndpointRef = endpointRefs.get(endpoint)

  def removeRpcEndpointRef(endpoint: RpcEndpoint): Unit = endpointRefs.remove(endpoint)

  // Should be idempotent
  private def unregisterRpcEndpoint(name: String): Unit = {
    val data = endpoints.remove(name)
    if (data != null) {
      data.inbox.stop()
      // 数据放入receivers
      receivers.offer(data) // for the OnStop message
    }
    // Don't clean `endpointRefs` here because it's possible that some messages are being processed
    // now and they can use `getRpcEndpointRef`. So `endpointRefs` will be cleaned in Inbox via
    // `removeRpcEndpointRef`.
  }

  def stop(rpcEndpointRef: RpcEndpointRef): Unit = {
    synchronized {
      if (stopped) {
        // This endpoint will be stopped by Dispatcher.stop() method.
        return
      }
      unregisterRpcEndpoint(rpcEndpointRef.name)
    }
  }

  /**
   * Send a message to all registered [[RpcEndpoint]]s in this process.
   * 发送消息给全部已经注册的rpcEndpoint
   * This can be used to make network events known to all end points (e.g. "a new node connected").
   */
  def postToAll(message: InboxMessage): Unit = {
    // 拿到全部的endpoint
    val iter = endpoints.keySet().iterator()
    while (iter.hasNext) {
      val name = iter.next
      // 发送消息
      postMessage(name, message, (e) => {
        e match {
          case e: RpcEnvStoppedException => logDebug(s"Message $message dropped. ${e.getMessage}")
          case e: Throwable => logWarning(s"Message $message dropped. ${e.getMessage}")
        }
      }
      )
    }
  }

  /**
   * 发送远程消息
   */
  /** Posts a message sent by a remote endpoint. */
  def postRemoteMessage(message: RequestMessage, callback: RpcResponseCallback): Unit = {
    // 创建远程RPC回调上下文
    val rpcCallContext = {
      new RemoteNettyRpcCallContext(nettyEnv, callback, message.senderAddress)
    }
    // 创建RPC消息
    val rpcMessage = RpcMessage(message.senderAddress, message.content, rpcCallContext)
    // 发送消息
    postMessage(message.receiver.name, rpcMessage, (e) => callback.onFailure(e))
  }

  /** Posts a message sent by a local endpoint. */
  // 发送本地消息
  def postLocalMessage(message: RequestMessage, p: Promise[Any]): Unit = {
    val rpcCallContext =
      new LocalNettyRpcCallContext(message.senderAddress, p)
    val rpcMessage = RpcMessage(message.senderAddress, message.content, rpcCallContext)
    postMessage(message.receiver.name, rpcMessage, (e) => p.tryFailure(e))
  }

  /** Posts a one-way message. */
  def postOneWayMessage(message: RequestMessage): Unit = {
    postMessage(message.receiver.name, OneWayMessage(message.senderAddress, message.content),
      (e) => throw e)
  }

  /**
   * Posts a message to a specific endpoint.
   *
   * @param endpointName      name of the endpoint.
   * @param message           the message to post
   * @param callbackIfStopped callback function if the endpoint is stopped.
   */
  private def postMessage(
                           endpointName: String,
                           message: InboxMessage,
                           callbackIfStopped: (Exception) => Unit): Unit = {
    val error = synchronized {
      val data = endpoints.get(endpointName)
      if (stopped) {
        Some(new RpcEnvStoppedException())
      } else if (data == null) {
        Some(new SparkException(s"Could not find $endpointName."))
      } else {
        // 发送消息
        data.inbox.post(message)
        // 插入在recives
        receivers.offer(data)
        None
      }
    }
    // We don't need to call `onStop` in the `synchronized` block
    error.foreach(callbackIfStopped)
  }

  def stop(): Unit = {
    synchronized {
      if (stopped) {
        return
      }
      stopped = true
    }
    // Stop all endpoints. This will queue all endpoints for processing by the message loops.
    endpoints.keySet().asScala.foreach(unregisterRpcEndpoint)
    // Enqueue a message that tells the message loops to stop.
    // 发送一个毒药消息，作为stop标示
    receivers.offer(PoisonPill)
    threadpool.shutdown()
  }

  def awaitTermination(): Unit = {
    threadpool.awaitTermination(Long.MaxValue, TimeUnit.MILLISECONDS)
  }

  /**
   * Return if the endpoint exists
   */
  def verify(name: String): Boolean = {
    endpoints.containsKey(name)
  }

  /** Thread pool used for dispatching messages. */
  private val threadpool: ThreadPoolExecutor = {
    val availableCores =
      if (numUsableCores > 0) numUsableCores else Runtime.getRuntime.availableProcessors()
    val numThreads = nettyEnv.conf.getInt("spark.rpc.netty.dispatcher.numThreads",
      math.max(2, availableCores))
    val pool = ThreadUtils.newDaemonFixedThreadPool(numThreads, "dispatcher-event-loop")
    // 多线程执行，开启dispather线程
    for (i <- 0 until numThreads) {
      pool.execute(new MessageLoop)
    }
    pool
  }

  /** Message loop used for dispatching messages. */
  private class MessageLoop extends Runnable {
    override def run(): Unit = {
      try {
        while (true) {
          try {
            val data = receivers.take()
            // 如果消息为毒药消息，跳过并将该消息放入其他messageLoop中
            if (data == PoisonPill) {
              // Put PoisonPill back so that other MessageLoops can see it.
              receivers.offer(PoisonPill)
              return
            }
            // 处理存储的消息，传递Dispatcher主要是为了移除Endpoint的引用
            data.inbox.process(Dispatcher.this)
          } catch {
            case NonFatal(e) => logError(e.getMessage, e)
          }
        }
      } catch {
        case _: InterruptedException => // exit
        case t: Throwable =>
          try {
            // Re-submit a MessageLoop so that Dispatcher will still work if
            // UncaughtExceptionHandler decides to not kill JVM.
            threadpool.execute(new MessageLoop)
          } finally {
            throw t
          }
      }
    }
  }

  /** A poison endpoint that indicates MessageLoop should exit its message loop. */
  private val PoisonPill = new EndpointData(null, null, null)
}
```

## 事件总线

* Spark定义了一个特质ListenerBus，可以接受事件并且将事件提交到对应事件的监听器。

### ListenerBus的继承体系

![ListenerBus继承体系](./img/ListenerBus继承体系.jpg)

* SparkListenerBus:用于将SparkListenerEvent类型的事件投递到SparkListener-Interface类型的监听器。
  * AsyncEventQueue：采用异步线程将SparkListenerEvent类型的事件投递到SparkListener类型的监听器。
  * ReplayListenerBus：用于从序列化的事件数据中重播事件。
* StreamingQueryListenerBus：用于将StreamingQueryListener.Event类型的事件投递到StreamingQueryListener类型的监听器，此外还会将StreamingQueryListener. Event类型的事件交给SparkListenerBus。
* StreamingListenerBus：用于将StreamingListenerEvent类型的事件投递到Streaming Listener类型的监听器，此外还会将StreamingListenerEvent类型的事件交给Spark ListenerBus。
* ExternalCatalogWithListener:外部catalog监听器。

### SparkListenerBus

* 支持`SparkListenerEvent`的各个子类事件。

* 实现ListenerBus的onPostEvent方法，模式匹配了event做了对应的处理，主要包含了task、statge、job相关。

### AsyncEventQueue

* eventQueue:是SparkListenerEvent事件的阻塞队列，队列大小可以通过Spark属性spark.scheduler.listenerbus.eventqueue.size进行配置，默认为10000（Spark早期版本中属于静态属性，固定为10000）。
* started：标记LiveListenerBus的启动状态的AtomicBoolean类型的变量。
* stopped：标记LiveListenerBus的停止状态的AtomicBoolean类型的变量。
* droppedEventsCounter：使用AtomicLong类型对删除的事件进行计数，每当日志打印了droppedEventsCounter后，会将droppedEventsCounter重置为0。
* lastReportTimestamp：用于记录最后一次日志打印droppedEventsCounter的时间戳。
* logDroppedEvent:AtomicBoolean类型的变量，用于标记是否由于eventQueue已满，导致新的事件被删除。

```java
private class AsyncEventQueue(
    val name: String,
    conf: SparkConf,
    metrics: LiveListenerBusMetrics,
    bus: LiveListenerBus)
  extends SparkListenerBus
  with Logging {

  import AsyncEventQueue._

  // Cap the capacity of the queue so we get an explicit error (rather than an OOM exception) if
  // it's perpetually being added to more quickly than it's being drained.
  //
  private val eventQueue = new LinkedBlockingQueue[SparkListenerEvent](
    conf.get(LISTENER_BUS_EVENT_QUEUE_CAPACITY))

  // Keep the event count separately, so that waitUntilEmpty() can be implemented properly;
  // this allows that method to return only when the events in the queue have been fully
  // processed (instead of just dequeued).
  private val eventCount = new AtomicLong()

  /** A counter for dropped events. It will be reset every time we log it. */
  private val droppedEventsCounter = new AtomicLong(0L)

  /** When `droppedEventsCounter` was logged last time in milliseconds. */
  @volatile private var lastReportTimestamp = 0L

  private val logDroppedEvent = new AtomicBoolean(false)

  private var sc: SparkContext = null

  private val started = new AtomicBoolean(false)
  private val stopped = new AtomicBoolean(false)

  private val droppedEvents = metrics.metricRegistry.counter(s"queue.$name.numDroppedEvents")
  private val processingTime = metrics.metricRegistry.timer(s"queue.$name.listenerProcessingTime")

  // Remove the queue size gauge first, in case it was created by a previous incarnation of
  // this queue that was removed from the listener bus.
  metrics.metricRegistry.remove(s"queue.$name.size")
  metrics.metricRegistry.register(s"queue.$name.size", new Gauge[Int] {
    override def getValue: Int = eventQueue.size()
  })

    // 后台线程，转发器
  private val dispatchThread = new Thread(s"spark-listener-group-$name") {
    setDaemon(true)
    override def run(): Unit = Utils.tryOrStopSparkContext(sc) {
      // 发送消息
      dispatch()
    }
  }
 // 转发转系
  private def dispatch(): Unit = LiveListenerBus.withinListenerThread.withValue(true) {
    var next: SparkListenerEvent = eventQueue.take()
    // 不是毒药消息则一致调用postToAll
    while (next != POISON_PILL) {
      val ctx = processingTime.time()
      try {
        // 遍历消息调用doPostEvent
        super.postToAll(next)
      } finally {
        ctx.stop()
      }
      eventCount.decrementAndGet()
      next = eventQueue.take()
    }
    eventCount.decrementAndGet()
  }

  override protected def getTimer(listener: SparkListenerInterface): Option[Timer] = {
    metrics.getTimerForListenerClass(listener.getClass.asSubclass(classOf[SparkListenerInterface]))
  }

  /**
   * Start an asynchronous thread to dispatch events to the underlying listeners.
   *
   * @param sc Used to stop the SparkContext in case the async dispatcher fails.
   */
  private[scheduler] def start(sc: SparkContext): Unit = {
    if (started.compareAndSet(false, true)) {
      this.sc = sc
      // 开始dispatchThread线程，发送监听器事件
      dispatchThread.start()
    } else {
      throw new IllegalStateException(s"$name already started!")
    }
  }

  /**
   * Stop the listener bus. It will wait until the queued events have been processed, but new
   * events will be dropped.
   */
  private[scheduler] def stop(): Unit = {
    if (!started.get()) {
      throw new IllegalStateException(s"Attempted to stop $name that has not yet started!")
    }
    if (stopped.compareAndSet(false, true)) {
      eventCount.incrementAndGet()
      // 发送毒药消息
      eventQueue.put(POISON_PILL)
    }
    // this thread might be trying to stop itself as part of error handling -- we can't join
    // in that case.
    if (Thread.currentThread() != dispatchThread) {
      // 当先线程不是dispatchThread，就会尝试让dispatchThread die
      dispatchThread.join()
    }
  }

  def post(event: SparkListenerEvent): Unit = {
    if (stopped.get()) {
      return
    }

    eventCount.incrementAndGet()
    if (eventQueue.offer(event)) {
      return
    }

    eventCount.decrementAndGet()
    droppedEvents.inc()
    droppedEventsCounter.incrementAndGet()
    if (logDroppedEvent.compareAndSet(false, true)) {
      // Only log the following message once to avoid duplicated annoying logs.
      logError(s"Dropping event from queue $name. " +
        "This likely means one of the listeners is too slow and cannot keep up with " +
        "the rate at which tasks are being started by the scheduler.")
    }
    logTrace(s"Dropping event $event")

    val droppedCount = droppedEventsCounter.get
    if (droppedCount > 0) {
      // Don't log too frequently
      if (System.currentTimeMillis() - lastReportTimestamp >= 60 * 1000) {
        // There may be multiple threads trying to decrease droppedEventsCounter.
        // Use "compareAndSet" to make sure only one thread can win.
        // And if another thread is increasing droppedEventsCounter, "compareAndSet" will fail and
        // then that thread will update it.
        if (droppedEventsCounter.compareAndSet(droppedCount, 0)) {
          val prevLastReportTimestamp = lastReportTimestamp
          lastReportTimestamp = System.currentTimeMillis()
          val previous = new java.util.Date(prevLastReportTimestamp)
          logWarning(s"Dropped $droppedCount events from $name since $previous.")
        }
      }
    }
  }

  /**
   * For testing only. Wait until there are no more events in the queue.
   *
   * @return true if the queue is empty.
   */
  def waitUntilEmpty(deadline: Long): Boolean = {
    while (eventCount.get() != 0) {
      if (System.currentTimeMillis > deadline) {
        return false
      }
      Thread.sleep(10)
    }
    true
  }

  /**
   * LiveListenerBus的委托类，移除监听器
   * @param listener
   */
  override def removeListenerOnError(listener: SparkListenerInterface): Unit = {
    // the listener failed in an unrecoverably way, we want to remove it from the entire
    // LiveListenerBus (potentially stopping a queue if it is empty)
    bus.removeListener(listener)
  }

}

private object AsyncEventQueue {

  val POISON_PILL = new SparkListenerEvent() { }

}
```

