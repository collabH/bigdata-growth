# Flink On K8s

## 基础环境

### 准备K8s环境

* 安装docker Mac os客户端
* 启动k8s集群
* 创建namespace、serviceaccount等

```shell
  1, 创建一个namespace
      kubectl create namespace flink-session-cluster-test-1213
  2, 新建一个serviceaccount, 用来提交flink的任务
     kubectl create serviceaccount flink -n flink-session-cluster-test-1213
  3, 做好绑定
     kubectl create clusterrolebinding flink-role-binding-flink-session-cluster-test-1213_flink \
     --clusterrole=edit   --serviceaccount=flink-session-cluster-test-1213:flink   
```

### 准备Flink基础

* 下载flink安装包[Flink安装包](https://archive.apache.org/dist/flink/flink-1.12.0/flink-1.12.0-bin-scala_2.11.tgz)
* 配置Flink环境变量包含Home目录与bin目录

## 自定义DockerFile方式

### Application Mode

* 这里介绍application mode方式部署任务，其他模式可以参考官网整体的区别只是flink启动命令的区别

#### 编辑Dockerfile

```dockerfile
FROM flink:1.13.0-scala_2.11-java8
RUN rm -rf $FLINK_HOME/job/job-streaming&&mkdir -p $FLINK_HOME/job&&mkdir -p $FLINK_HOME/kafka-ssl
COPY ./job-streaming.zip $FLINK_HOME/job/job-streaming.zip
COPY ./kafka-key-bj/* $FLINK_HOME/kafka-ssl/
COPY ./hadoop-conf/conf/* $FLINK_HOME/conf/
RUN cd $FLINK_HOME/job&&unzip $FLINK_HOME/job/job-streaming.zip&&cd job-streaming/jar&&ls&&pwd
RUN cp $FLINK_HOME/job/job-streaming/lib/* $FLINK_HOME/lib
```

#### 前置环境配置

* 加载hadoop配置文件

```shell
export HADOOP_CONF_DIR=/opt/hadoop-conf/conf
```

* 编写job启动命令

```shell
/opt/flink-1.14.0/bin/flink run-application \
  --target kubernetes-application \
  -Dresourcemanager.taskmanager-timeout=60000 \
  -Dkubernetes.namespace=flink-test \
  -Dkubernetes.service-account=flink \
  -Dkubernetes.taskmanager.service-account=flink \
  -Dkubernetes.cluster-id=flink-app \
  -Dkubernetes.container.image=registryjob-test:1.3 \
  -Djobmanager.memory.process.size=1024m \
  -Dtaskmanager.memory.process.size=2048m \
  -Dclassloader.resolve-order=parent-first \
  -Dkubernetes.taskmanager.cpu=1 \
  -Dtaskmanager.numberOfTaskSlots=4 \
  -Dkubernetes.container.image.pull-secrets=docker-registry \
  -Dkubernetes.rest-service.exposed.type=NodePort  \
  # 指定特定的kube配置
  -Dkubernetes.config.file=/home/hdfs/kubeconf/kube.conf \
  # 用于指定内部状态存储hdfs是用的hadoop用户，否则可能会存在无权访问hdfs等问题
  -Denv.java.opts="-DHADOOP_USER_NAME=hdfs" \
  -c com.job.streaming.job.Job \
  local:///opt/flink/job/job-streaming/jar/job-streaming.jar
```

* 相关命令

```shell
# 构建镜像
docker build  -t job-test:1.2 .
docker tag 715c750b6d5a registry/job-test:1.2
docker push registry/job-test:1.2
# 管理pod
kubectl delete deploy -n flink-test flink-app
kubectl get po -n flink-test
kubectl logs -n flink-test
kubectl edit deploy -n flink-test flink-app
kubectl exec -it flink-app-5cd656df8-lcvp7 bash -n flink-test
```

## Pod template方式

* 自定义DockerFile方式存在一个问题就是指定一些公共的host配置或者相关任务jar包的管理会相对复杂，并且每次需要手动基于一堆命令构建镜像，为了解决这种复杂的流程flink也提供一种基于`pod-template`模板创建pod的方式。

### Application Mode

* 这里介绍application mode方式部署任务，其他模式可以参考官网整体的区别只是flink启动命令的区别

#### 编写pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: flink-job-template
spec:
  initContainers:
    - name: artifacts-fetcher
      image: flink:1.14.0-scala_2.11-java8
      # 添加自定义运行的jar包以及各种配置文件
      command: ["/bin/sh","-c"]
      # 这里写核心任务jar包处理逻辑，可以将配置、任务jar、任务依赖的lib都放入flinkHome下
      args: [ "$jarUrl;"]
      volumeMounts:
        - mountPath: /opt/flink/job
          name: flink-usr-home
        - mountPath: /opt/flink/lib/extr-lib
          name: flink-usr-extr-lib
        - mountPath: /home/flink/kafka-key-bj
          name: kafka-key-bj
        - mountPath: /home/flink/kafka-key-sz
          name: kafka-key-sz
      env:
        - name: TZ
          value: Asia/Shanghai
  containers:
    - name: flink-main-container
    # 设置容器时区
      env:
        - name: TZ
          value: Asia/Shanghai
      resources:
        requests:
          ephemeral-storage: 2048Mi
        limits:
          ephemeral-storage: 2048Mi
      volumeMounts:
        - mountPath: /opt/flink/job
          name: flink-usr-home
        - mountPath: /opt/flink/lib/extr-lib
          name: flink-usr-extr-lib
        - mountPath: /home/flink/kafka-key-bj
          name: kafka-key-bj
        - mountPath: /home/flink/kafka-key-sz
          name: kafka-key-sz
  volumes:
    - name: flink-usr-home
      emptyDir: {}
    - name: flink-usr-extr-lib
      emptyDir: {}
    - name: kafka-key-bj
      emptyDir: {}
    - name: kafka-key-sz
      emptyDir: {}
# 配置host映射
  hostAliases:
  - ip: "xxx"
    hostnames:
    - "client-f40c134"
```

#### 基于pod-template运行任务

```shell
# 加载hadoop配置
export HADOOP_CONF_DIR=/opt/hadoop-conf/conf
# 启动任务
/home/hdfs/flink-1.14.0/bin/flink run-application \
-t kubernetes-application \
-p 3 \
-Dresourcemanager.taskmanager-timeout=60000 \
-Dkubernetes.namespace=flink \
-Dkubernetes.service-account=flink \
-Dkubernetes.taskmanager.service-account=flink \
-Dkubernetes.cluster-id=entrance-job-test \
-Dkubernetes.container.image.pull-secrets=registry \
-Dkubernetes.rest-service.exposed.type=NodePort  \
-Dkubernetes.config.file=/home/hdfs/kubeconf/kube.conf \
-Denv.java.opts="-DHADOOP_USER_NAME=hdfs" \
# 指定对应的pod-template配置文件
-Dkubernetes.pod-template-file=/home/hdfs/flink-pod.yaml \
-Dkubernetes.taskmanager.cpu=1 \
-Djobmanager.memory.process.size=1024m \
-Dtaskmanager.memory.process.size=2048m \
-Dtaskmanager.numberOfTaskSlots=3 \
-Dclassloader.resolve-order=parent-first \
-c xxx.Job \
local:///opt/flink/job/job-streaming/jar/job-streaming.jar
```

## 部署平台设计

* 方式1：可以通过基于底层`flink`命令去编写对应的shell脚本，包括启动任务、根据savepoint停止任务、根据checkpoint/savepoint启动任务等功能，这种方式shell脚本会相对难管理并且没办法实时感知到任务的状态，任务的监控也需要依赖特定组件去做。
* 方式2：基于Flink On K8s模板提供的`KubernetesClusterDescriptor`对象可以构建一个管理任务的部署平台，可以抽象出k8s集群资源、任务资源、监控告警管理模块等等，最终构建出一套全链路的任务部署管理平台。

### shell脚本管理

#### 底层任务运行命令

* 将特定的任务根据checkpoint启动的命令放到一个统一的shell中，根据不同环境可以拆分出来多套执行命令。

```shell
#!/usr/bin/env bash

appName=$1
ckPath=$2

homePath=$( cd "$(dirname "$0")/..";pwd )
shipFiles="$homePath"
runJar="local:///streaming.jar"

case $appName in
test)
echo "
    /home/hdfs/flink-1.14.0/bin/flink run-application \
    -t kubernetes-application \
    -s $ckPath \
    -p 3 \
    -Dresourcemanager.taskmanager-timeout=60000 \
    -Dkubernetes.namespace=flink \
    -Dkubernetes.service-account=flink \
    -Dkubernetes.taskmanager.service-account=flink \
    -Dkubernetes.cluster-id=test-job \
    -Dkubernetes.container.image.pull-secrets=registry \
    -Dkubernetes.rest-service.exposed.type=NodePort  \
    -Dkubernetes.config.file=/home/hdfs/kubeconf/kube.conf \
    -Denv.java.opts="-DHADOOP_USER_NAME=hdfs" \
    -Dkubernetes.pod-template-file=/home/hdfs/flink-pod.yaml \
    -Dkubernetes.taskmanager.cpu=1 \
    -Djobmanager.memory.process.size=1024m \
    -Dtaskmanager.memory.process.size=2048m \
    -Dtaskmanager.numberOfTaskSlots=3 \
    -Dclassloader.resolve-order=parent-first \
    -c com.test.Job \
     $runJar
"
  ;;
   echo "未找到匹配的job：appName = $1"
   exit 1
esac
```

#### 部署脚本

```shell
#!/usr/bin/env bash

# 基础环境变量
flinkRunScriptPath="/home/hdfs/flink-1.13.0/bin/flink"
flinkJobManagerHostToolPath="/home/hdfs/bin/flink-jm"
kubeCceConfigPath="/home/hdfs/kubeconf/kube.conf"
binHome=$(pwd)
log_file="$binHome/log.log"

export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop/

declare -A aliasNames
aliasNames["test"]=test-job-

# 获取jm真实host，flink 1.13.0需要中转查找jobmanager的真实web url
function getJobManagerHost(){
    jmHost=$($flinkJobManagerHostToolPath -config $kubeCceConfigPath -clusterId $1 -namespace aff-flink)
    echo $jmHost
}

# 获取jobid
function getJobInfo() {
  jmHost=$1
  # 包装flink list，用于屏蔽其标准输出
  flink_list_result=$($flinkRunScriptPath list -r -m ${jmHost} \
  -Dkubernetes.config.file=$kubeCceConfigPath \
  -Dkubernetes.namespace=flink)

  # 执行成功，则解析结果(n：读取匹配的下一行，p：打印行)
  flink_list_result=$(echo "$flink_list_result" | sed -n '/------------------ Running\/Restarting Jobs -------------------/{n;p}')

  # 从结果中获取 job_id 和 job_name
  job_id=$(echo "$flink_list_result" | awk -F ' ' '{print $4}')

  # 如果检索失败，则终止脚本

  echo $job_id
}

# 停止任务并且返回savepoint
function stopAppWithSp() {
    clusterId=${aliasNames[$1]}$executeEnv
     if [[ -z $clusterId ]]; then
      echo -e "[ERROR] Flink任务clusterId不能为空!\n" > $log_file
      exit 1
     fi
     # 获取真实的jm host
     jmHost=$(getJobManagerHost $clusterId)
     if [[ -z $jmHost ]]; then
         echo  -e "[ERROR] Flink clusterId:$clusterId不存在对应的JobManager Web Url,请检查任务状态!\n" > $log_file
         exit 1
     fi
    jobId=$(getJobInfo $jmHost)
    echo -e "[INFO] clusterId:$clusterId的JobManager Host为:$jmHost jobId:$jobId \n" > $log_file
    savepointPath=hdfs://bmr-cluster/flink/savepoints/$clusterId

  # 执行保存点命令
  flink_stop_result=$($flinkRunScriptPath stop -p $savepointPath -m $jmHost \
                                        -Dkubernetes.cluster-id=$clusterId \
                                        -Dkubernetes.namespace=flink \
                                        -Dkubernetes.service-account=flink \
                                        -Dkubernetes.config.file=$kubeCceConfigPath \
                                        -Dkubernetes.taskmanager.service-account=flink  $jobId)

  # 获取保存点路径
  savepointPath=$(echo -e "$flink_stop_result" | sed -n '/^Savepoint completed. Path: /p' | awk -F ' ' '{print $4}')

  echo "$savepointPath"
}

# 格式脚本如果没有checkpointPath则将-s命令移除
function rewriteRunScript() {
  run_script=$1

  # 没有ckPath，则删除启动命令的-s参数
  run_script=$([[ ! $run_script =~ -s[[:space:]]+- ]] && echo $run_script || echo $run_script | sed -n 's/-s\s\+-/-/gp')
  # 去除多余空格
  run_script=$(echo -e "$run_script" | sed -n 's/\s\+/ /gp')

  echo "$run_script"
}

# 核心运行主类
function main(){
    executeEnv=$1
    operationType=$2
    jobName=$3
    ckPath=$4
    if [[ -z ${aliasNames[$jobName]} ]]; then
    echo "参数3 jobName异常，请输入对应job缩写!"
    exit 1
    fi
   allJobName=${aliasNames[$jobName]}-$executeEnv
    # 获取执行环境
    # 3种上线流程
    case $operationType in
    start )
       echo "jobName:$allJobName ckPath:$ckPath"
       runScript=$($binHome/get_script_${executeEnv}_k8s.sh $jobName $ckPath)
       runScript=$(rewriteRunScript "$runScript")
       echo "start runScript $runScript"
       $runScript
             ;;
    restart )
       savepointPath=$(stopAppWithSp $jobName)
       echo "executeEnv:$executeEnv jobName:$allJobName savepointPath:$savepointPath"
       runScript=$($binHome/get_script_${executeEnv}_k8s.sh $jobName $savepointPath)
       runScript=$(rewriteRunScript "$runScript")
       echo "restart runScript $runScript"
       $runScript
             ;;
    stop )
      savepointPath=$(stopAppWithSp $jobName)
      echo "executeEnv:$executeEnv jobName:$allJobName savepointPath:$savepointPath"
             ;;
     script    )
     echo "$($binHome/get_script_${executeEnv}_k8s.sh $jobName $ckPath)"
     ;;
    esac

}

main $*
```

### 启动任务

```shell
# 不基于ckpath或spPath启动测试环境test任务
sh deployer.sh test start test
# 基于ckpath或者spPath启动
sh deployer.sh test start test hdfs://xxx/ck01
# 重启任务
sh deployer.sh test restart test
# 停止任务
sh deployer.sh test stop test
```

## 存在的问题

### 版本问题

1. Flink1.12.x版本根据配置`-Dkubernetes.service-account`指定的运行jobManager和taskManager的角色不生效，默认使用default用户因此需要调整defualt用户对pod的`create\list\delete`等权限。
2. Flink1.13.x版本因flink on k8s源码获取对应jobManager Web Url的代码是从其kube.conf配置下获取的master地址，因此通过api server的方式的k8s集群会导致jobmanager地址无法访问，需要根据shell脚本去获取pod真实的地址，在取消任务或者查看任务jobId需要通过flink命令`-m jobManagerUrl`方式去获取和取消任务。

### 状态迁移问题

1. 注意历史flink任务的状态迁移问题，等没流量后在将对应的状态数据迁移至新的状态存储中，然后在根据savepoint方式恢复任务。
