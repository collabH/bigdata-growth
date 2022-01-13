# 应用配置

* Alluxio shell通过`-Dkey=value`方式配置额外设置
* Spark作业通过`spark.driver.extraJavaOptions=-Dkey=value`方式配置相关配置

```shell
spark-submit \
--conf 'spark.driver.extraJavaOptions=-Dalluxio.user.file.writetype.default=CACHE_THROUGH' \
--conf 'spark.executor.extraJavaOptions=-Dalluxio.user.file.writetype.default=CACHE_THROUGH' \
```

* Hadoop Mr作业通过`-Dkey=value`方式

```shell
hadoop jar libexec/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.3.jar wordcount \
-Dalluxio.user.file.writetype.default=CACHE_THROUGH \
-libjars /<PATH_TO_ALLUXIO>/client/alluxio-2.8.0-SNAPSHOT-client.jar \
<INPUT FILES> <OUTPUT DIRECTORY>
```

# 配置Alluxio集群

* 使用site-Property文件,寻找`alluxio-site.properties`的优先级为`${HOME}/.alluxio/`, `/etc/alluxio/` and `${ALLUXIO_HOME}/conf`

```shell
cp conf/alluxio-site.properties.template conf/alluxio-site.properties
```

## 安全性配置

### 安全认证

* SIMPLE
  * 配置`alluxio.security.authentication.type=SIMPLE`，身份验证将被弃用，在客户端访问Alluxio服务时，客户端将按照以下次序获取用户信息汇报给Alluxio服务进行身份验证
    * 如果属性`alluxio.security.login.username`在客户端上被设置，其值将作为此客户端的登录用户。
    * 否则，将从操作系统获取登录用户。
  * 客户端检索用户信息后，将使用该用户信息进行连接该服务。在客户端创建目录/文件之后，将用户信息添加到元数据中并且可以在CLI和UI中检索。
* NOSASL
  * 当`alluxio.security.authentication.type`为`NOSASL`时，身份验证被禁用。Alluxio服务将忽略客户端的用户， 并不把任何用户信息与创建的文件或目录关联。
* CUSTOM
  * 当`alluxio.security.authentication.type`为`CUSTOM`时，身份验证被启用。Alluxio客户端检查`alluxio.security.authentication.custom.provider.class`类的名称用于检索用户。此类必须实现`alluxio.security.authentication.AuthenticationProvider`接口。

### 用户模拟

* Master配置
  * `alluxio.master.security.impersonation.alluxio_user.users=user1,user2`
    * Alluxio用户`alluxio_user`被允许模拟用户`user1`以及`user2`。
  * `alluxio.master.security.impersonation.client.users=*`
    - Alluxio用户`client`被允许模拟任意的用户。
  * `alluxio.master.security.impersonation.alluxio_user.groups=group1,group2`
    - Alluxio用户`alluxio_user`可以模拟用户`group1`以及`group2`中的任意用户。
  * `alluxio.master.security.impersonation.client.groups=*`
    - Alluxio用户`client`可以模拟任意的用户。
* 客户端设置
  * `alluxio.security.login.impersonation.username`
    - 不设置
      - 不启用Alluxio client用户模拟
    - `_NONE_`
      - 不启用Alluxio client用户模拟
    - `_HDFS_USER_`
      - Alluxio client会模拟HDFS client的用户（当使用Hadoop兼容的client来调用Alluxio时）