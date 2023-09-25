# OverView

* Flink On K8s Operator是Flink 1.15大版本推出的Flink On K8s方案，之前Flink社区提供的Flink Native K8s方式相对来说使用繁琐并且没有统一的容器管理方案，整体任务管理起来比较复杂。因此社区基于flink-kubernetes底层sdk开发基于operator的flink k8s方案，其提供更加成熟的容器管理方案。

## 核心特点

* **全自动作业生命周期管理**
  * 运行、挂起和删除应用
  * 有状态和无状态的应用程序升级
  * 触发和管理savepoints
  * 处理错误，回滚异常的升级
* **支持多版本flink:v1.13，v1.14，v1.15，v1.16，v1.17**
* **多种部署模式支持**
  * Application Cluster
  * Session Cluster
  * Session Job
* [**支持高可用**](https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/ha/kubernetes_ha/)
* **可扩展的架构**
  * [自定义校验器](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.6/docs/operations/plugins/#custom-flink-resource-validators)
  * [自定义资源监听器](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.6/docs/operations/plugins/#custom-flink-resource-listeners)
* **更先进的配置管理**
  * 默认配置动态更新
  * 预配置job
  * 环境变量
* **支持pod template增强pod**
  * native kubernetes pod定义
  * 分层 (Base/JobManager/TaskManager overrides)
* [**作业自动资源分配**](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.6/docs/custom-resource/autoscaler/)
  * 收集滞后和利用率指标
  * 将作业vertices缩放到理想的并行度
  * 随着负载的变化而上下缩放


## Operations

* **Operator Mertrics**
  * 采用flink指标系统
  * 插件化指标上报器
  * 详细资源和Kubernetes API访问指标
* 完全自定义log
  * 默认log配置
  * job预配置log
  * 基于Sidecar的日志转发器
* Flink web ui和rest入口访问
  * 支持flink native k8s的全部expose type
  * Dynamic [Ingress templates](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/docs/operations/ingress/)
* Helm based installation
  - Automated [RBAC configuration](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/docs/operations/rbac/)
  - Advanced customization techniques
* 最新的公共存储库
  - GitHub Container Registry [ghcr.io/apache/flink-kubernetes-operator](http://ghcr.io/apache/flink-kubernetes-operator)
  - DockerHub https://hub.docker.com/r/apache/flink-kubernetes-operator

# Quick Start

## 前置条件

* 准备以下基础环境
* [docker](https://docs.docker.com/)
* [kubernetes](https://kubernetes.io/)
* [helm](https://helm.sh/docs/intro/quickstart/)

```shell
# 启动minikube
minikube start --kubernetes-version=v1.24.3
# 安装helm
brew install helm
# 安装k9s,推荐使用k9s来管理k8s pod
brew install k9s
```

* k9s文档:https://k9scli.io/

## 部署operator

```shell
# 在Kubernetes集群中安装证书管理器来添加webhook组件(每个Kubernetes集群只需要添加一次):
kubectl create -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml
# 添加flink k8s operator helm chart，这里选择1.0.1版本的operator
helm repo add flink-operator-repo160 https://downloads.apache.org/flink/flink-kubernetes-operator-1.6.0/
helm install flink-kubernetes-operator flink-operator-repo160/flink-kubernetes-operator
```

* **kubectl get pods**查看flink-kubernetes-operator是否启动成功
* **helm list**查看对应chart是否安装成功

## 提交flink任务

* 根据官方提供的yaml配置提交一个flink job

```shell
# 创建测试flink任务
kubectl create -f https://raw.githubusercontent.com/apache/flink-kubernetes-operator/release-1.6/examples/basic.yaml
# 查看容器日志
kubectl logs -f deploy/basic-example
# 暴露对应任务web port
kubectl port-forward svc/basic-example-rest 8081
# 删除作业
kubectl delete flinkdeployment/basic-example
```

* 通过localhost:8081就可以访问flink web dashboard，basic文件含义

```yaml
################################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
################################################################################
apiVersion: flink.apache.org/v1beta1
# 部署类型
kind: FlinkDeployment
metadata:
  name: basic-example
spec:
  image: flink:1.15
  flinkVersion: v1_15
  flinkConfiguration:
  # flink配置
    taskmanager.numberOfTaskSlots: "2"
  # flink service用户
  serviceAccount: flink
  # jm资源配置
  jobManager:
    resource:
      memory: "2048m"
      cpu: 1
  taskManager:
    resource:
      memory: "2048m"
      cpu: 1
  job:
  # jar包地址
    jarURI: local:///opt/flink/examples/streaming/StateMachineExample.jar
    # 并行度
    parallelism: 2
    upgradeMode: stateless
```

# Architecture

* Flink Kubernetes Operator (Operator)作为一个**控制平台**，管理Apache Flink应用的整个**部署生命周期**。**Operator**可以通过**Helm**安装在**Kubernetes**集群上。在大多数生产环境中，它通常部署在指定的**namespace**中，并在一个或多个托管**namespace**中控制Flink的部署。

![](../img/flinkk8sopeartor架构.jpg)

## 控制流程

![](../img/operator控制流程.jpg)

* 用户可以使用Kubernetes命令行工具kubectl与operator进行交互。operator持续跟踪**FlinkDeployment**/**FlinkSessionJob**自定义资源相关的集群事件。当operator收到新的资源更新时，它将采取行动将Kubernetes集群调整到所需的状态，作为和解循环的一部分。初始循环由以下高级步骤组成:
  * 用户通过`kubectl`提交一个`FlinkDeployment/FlinkSessionJob`的自定义资源。
  * Operator观察flink资源(如果先前部署)的当前状态
  * Operator校验提交资源的改变
  * Operator协调任何需要的更改并执行升级
* 自定义资源能够在任何时间应用于集群中。Operator不断地根据期望状态进行调整，直到当前状态变为期望状态。在Operator中，所有生命周期管理操作都使用这个非常简单的原则来实现。

## Flink资源生命周期

* Operator管理者flink资源的生命周期，Flink资源的生命周期各个阶段如下图：

![](../img/k8soperator资源生命周期.jpg)

- CREATED : The resource was created in Kubernetes but not yet handled by the operator
- SUSPENDED : The (job) resource has been suspended
- UPGRADING : The resource is suspended before upgrading to a new spec
- DEPLOYED : The resource is deployed/submitted to Kubernetes, but it’s not yet considered to be stable and might be rolled back in the future
- STABLE : The resource deployment is considered to be stable and won’t be rolled back
- ROLLING_BACK : The resource is being rolled back to the last stable spec
- ROLLED_BACK : The resource is deployed with the last stable spec
- FAILED : The job terminally failed

# Custom Resource

* Flink Kubernetes操作员面向用户的核心API是FlinkDeployment和FlinkSessionJob自定义资源(CR)。自定义资源是k8s api的扩展和定义一个新的对象类型。FlinkDeployment CR(自定义资源)定义一个Flink Application和Session集群deployments。FlinkSessionJob的CR定义一个session任务在Session集群并且每个session集群可以运行多个FlinkSessionJob。
* 一但Flink K8s Operator被安装和运行在k8s环境，它将会持续的监听FlinkDeployment和FlinkSessionJob对象，以检测新的CR和对现有CR的更改。
* 俩种CR类型，FlinkDeployment和FlinkSessionJob
  * Flink应用的管理通过FlinkDeployment
  * 由FlinkDeployment管理的空Flink Session+由FlinkSessionJobs管理的多个作业。对会话任务的操作是相互独立的。

## FlinkDeployment

```yaml
apiVersion: flink.apache.org/v1beta1
# 部署类型
kind: FlinkDeployment
metadata:
  namespace: namespace-of-my-deployment
  name: my-deployment
spec:
  // Deployment specs of your Flink Session/Application
```

* 查看FlinkDeployment具体yaml配置

```shell
kubectl get flinkdeployment basic-example -o yaml
```

### FlinkDeployment spec描述

* image:Docker用于运行Flink作业和任务管理器进程
* flinkVersion:flink镜像的版本(v1_13,v1_14,v1_15)
* serviceAccount:flink pod使用的k8s账户
* taskManager，jobManager:job和task管理pod资源的描述(cpu、memory等)
* flinkConfiguration:flink配置的字典，例如ck和ha配置
* job:任务相关描述

### Application Deployments

* jarURI:任务jar包路径
* parallelism: 任务并行度
* upgradeMode: 作业的更新模式(stateless/savepoint/last-state)
* state:任务的描述状态(运行/挂起)

**创建一个新的namespace和serviceaccount**

```shell
# 创建namespace
kubectl create namespace flink-operator
# 创建serviceaccount
kubectl create serviceaccount flink -n flink-operator
# 赋予权限
kubectl create clusterrolebinding flink-role-binding-flink-operator_flink \
     --clusterrole=edit   --serviceaccount=flink-operator:flink
clusterrolebinding.rbac.authorization.k8s.io/flink-role-binding-flink-operator_flink created
```

**FlinkDeployment模式flink job yaml**

```yaml
apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata:
  namespace: flink-operator
  name: flink-deployment-test
spec:
  image: flink:1.15
  flinkVersion: v1_15
  flinkConfiguration:
    taskmanager.numberOfTaskSlots: "2"
  serviceAccount: flink
  jobManager:
    resource:
      memory: "2048m"
      cpu: 1
  taskManager:
    resource:
      memory: "2048m"
      cpu: 1
  job:
    jarURI: local:///opt/flink/examples/streaming/StateMachineExample.jar
    parallelism: 2
    upgradeMode: stateless
    state: running
```

**启动对应flink任务**

```shell
kubectl apply -f your-deployment.yaml
# 转发端口
kubectl port-forward svc/flink-deployment-test-rest 8081 -n flink-operator

## 如果遇到以下错误标识端口占用
Unable to listen on port 8081: Listeners failed to create with the following errors: [unable to create listener: Error listen tcp4 127.0.0.1:8081: bind: address already in use unable to create listener: Error listen tcp6 [::1]:8081: bind: address already in use]
error: unable to listen on any of the requested ports: [{8081 8081}]
## 通过lsof kill对应应用
lsof -i :8080
kill -9 pid
```

* port-forward作用:https://kubernetes.io/zh-cn/docs/tasks/access-application-cluster/port-forward-access-application-cluster/

## FlinkSessionJob

* 整体的yaml文件的结构类似于FlinkDeployment

```yaml
apiVersion: flink.apache.org/v1beta1
kind: FlinkSessionJob
metadata:
  name: basic-session-job-example
spec:
  deploymentName: basic-session-cluster
  job:
    jarURI: https://repo1.maven.org/maven2/org/apache/flink/flink-examples-streaming_2.12/1.15.1/flink-examples-streaming_2.12-1.15.1-TopSpeedWindowing.jar
    parallelism: 4
    upgradeMode: stateless
```

### FlinkSessionJob spec描述

* flink session的jar可以来着远程的资源，可以从不同的系统获取任务jar，例如支持从hadoop文件系统拉取jar需要改造原始flink operator打包新的镜像，如下：

```dockerfile
FROM apache/flink-kubernetes-operator
ENV FLINK_PLUGINS_DIR=/opt/flink/plugins
COPY flink-hadoop-fs-1.15-SNAPSHOT.jar $FLINK_PLUGINS_DIR/hadoop-fs/
```

### 限制

* FlinkSessionJob目前还不支持`LastState`的升级模式

### FlinkSessionJob Quick Start

#### 启动一个Session Cluster

* 基础yaml文件配置

```yaml
################################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata:
  name: basic-session-deployment-only-example
spec:
  image: flink:1.15
  flinkVersion: v1_15
  flinkConfiguration:
    taskmanager.numberOfTaskSlots: "2"
  serviceAccount: flink
  jobManager:
    resource:
      memory: "2048m"
      cpu: 1
  taskManager:
    resource:
      memory: "2048m"
      cpu: 1
```

* 部署deployment任务

```shell
kubectl apply -f basic-session-deployment-only-example.yaml
```

#### 添加任务至basic-session-deployment-only-example

* 基础yaml文件配置

```yaml
################################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
################################################################################
apiVersion: flink.apache.org/v1beta1
kind: FlinkSessionJob
metadata:
  name: basic-session-job-only-example
spec:
# 部署的deployment名称
  deploymentName: basic-session-deployment-only-example
  job:
    jarURI: https://repo1.maven.org/maven2/org/apache/flink/flink-examples-streaming_2.12/1.15.0/flink-examples-streaming_2.12-1.15.0-TopSpeedWindowing.jar
    parallelism: 4
    upgradeMode: stateless
```

* 添加任务运行

```shell
kubectl apply -f basic-session-job-only-example.yaml
```

## 任务管理

### Flink生命周期管理

* flink operator的核心特性是如何去管理一个Flink应用程序的完整生命周期。
  * 运行、挂起和删除应用
  * 有状态和无状态的应用更新方式
  * 触发和管理savepoint
  * 处理错误，回滚损坏的升级
* 以上特点都可以通过JobSpec来控制

### 启动、挂起和删除应用

* 取消/删除应用

```shell
kubectl delete flinkdeployment/flinksessionjob my-deployment
```

### 有状态和无状态应用升级

* operator可以停止当前正在运行的作业(除非已经挂起或者redeploy)，并使用上次运行有状态应用程序时保留的最新spec和状态重新部署它。
* 通过JobSpec的`upgradeMode`进行设置，支持以下值
  * **stateless:** 可以通过空状态来升级无状态应用
  * **savepoint:** 使用savepoint来升级。
  * **last-state: **在任何应用程序状态下(即使作业失败)进行快速升级，都不需要健康的作业，因为它总是使用最后检查点信息。当HA元数据丢失时，可能需要手动恢复。

|                        | Stateless               | Last State                                 | Savepoint                              |
| ---------------------- | ----------------------- | ------------------------------------------ | -------------------------------------- |
| Config Requirement     | None                    | Checkpointing & Kubernetes HA Enabled      | Checkpoint/Savepoint directory defined |
| Job Status Requirement | None                    | HA metadata available                      | Job Running*                           |
| Suspend Mechanism      | Cancel / Delete         | Delete Flink deployment (keep HA metadata) | Cancel with savepoint                  |
| Restore Mechanism      | Deploy from empty state | Recover last state using HA metadata       | Restore From savepoint                 |
| Production Use         | Not recommended         | Recommended                                | Recommended                            |

#### last-state yaml配置

```yaml
apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata:
  name: basic-checkpoint-ha-example
spec:
  image: flink:1.15
  flinkVersion: v1_15
  flinkConfiguration:
    taskmanager.numberOfTaskSlots: "2"
    state.savepoints.dir: file:///flink-data/savepoints
    state.checkpoints.dir: file:///flink-data/checkpoints
    high-availability: org.apache.flink.kubernetes.highavailability.KubernetesHaServicesFactory
    high-availability.storageDir: file:///flink-data/ha
  serviceAccount: flink
  jobManager:
    resource:
      memory: "2048m"
      cpu: 1
  taskManager:
    resource:
      memory: "2048m"
      cpu: 1
  podTemplate:
    spec:
      containers:
        - name: flink-main-container
          volumeMounts:
            - mountPath: /flink-data
              name: flink-volume
      volumes:
        - name: flink-volume
          hostPath:
            # directory location on host
            path: /tmp/flink
            # this field is optional
            type: Directory
  job:
    jarURI: local:///opt/flink/examples/streaming/StateMachineExample.jar
    parallelism: 2
    upgradeMode: last-state
    state: running
```

#### 应用重启没有spec变化

* 在某些情况下，用户只是希望重启Flink部署来处理一些临时问题。可以通过restartNonce来配置重启次数

```yaml
 spec:
    ...
    restartNonce: 123
```

### savepoint管理

#### 手动savepoint触发

* 通过`savepointTriggerNonce`来手动控制savepoint触发，改变`savepointTriggerNonce`的值将会触发一个新的savepoint

```yaml
job:
    ...
    savepointTriggerNonce: 123
```

#### 定期savepoint触发

```yaml
flinkConfiguration:
    ...
    kubernetes.operator.periodic.savepoint.interval: 6h
```

* 不能保证定期保存点的及时执行，因为不健康的作业状态或其他干扰用户操作可能会延迟它们的执行。

#### savepoint history

* operator可以动态跟踪由升级或手动保存点操作触发的保存点历史。

```yaml
flinkConfiguration:
    ...
		kubernetes.operator.savepoint.history.max.age: 24 h
		kubernetes.operator.savepoint.history.max.count: 5
```

### Recovery of missing job deployments

* 当启用Kubernetes HA时，操作员可以在用户或某些外部进程意外删除Flink集群部署的情况下恢复它。可以通过设置`kubernetes.operator.jm-deployment-recovery.enabled`在配置中关闭部署恢复。启用为false，但是建议保持该设置为默认的true值。

## Pod Template

* operator的CRD提供`flinkConfiguration`和`podTemplate`配置，pod template允许自定义Flink作业和任务管理器pod，例如指定卷安装，临时存储，sidecar容器等。
* operator会合并job manager和task manger的通用和特定模板，以下为pod template demo

```yaml
apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata:
  namespace: default
  name: pod-template-example
spec:
  image: flink:1.15
  flinkVersion: v1_15
  flinkConfiguration:
    taskmanager.numberOfTaskSlots: "2"
  podTemplate:
    apiVersion: v1
    kind: Pod
    metadata:
      name: pod-template
    spec:
      serviceAccount: flink
      containers:
        # Do not change the main container name
        - name: flink-main-container
          volumeMounts:
            - mountPath: /opt/flink/log
              name: flink-logs
        # Sample sidecar container
        - name: fluentbit
          image: fluent/fluent-bit:1.8.12-debug
          command: [ 'sh','-c','/fluent-bit/bin/fluent-bit -i tail -p path=/flink-logs/*.log -p multiline.parser=java -o stdout' ]
          volumeMounts:
            - mountPath: /flink-logs
              name: flink-logs
      volumes:
        - name: flink-logs
          emptyDir: { }
  jobManager:
    resource:
      memory: "2048m"
      cpu: 1
  taskManager:
    resource:
      memory: "2048m"
      cpu: 1
    podTemplate:
      apiVersion: v1
      kind: Pod
      metadata:
        name: task-manager-pod-template
      spec:
        initContainers:
          # Sample sidecar container
          - name: busybox
            image: busybox:latest
            command: [ 'sh','-c','echo hello from task manager' ]
  job:
    jarURI: local:///opt/flink/examples/streaming/StateMachineExample.jar
    parallelism: 2
```

