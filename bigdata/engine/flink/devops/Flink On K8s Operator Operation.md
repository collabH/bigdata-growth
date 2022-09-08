# Helm

## Helm installation

```shell
# 安装operator helm chart
helm install flink-kubernetes-operator helm/flink-kubernetes-operator
# 安装到指定k8s namespace，没有则新建
helm install flink-kubernetes-operator helm/flink-kubernetes-operator --namespace flink --create-namespace
```

## 重写配置进行helm install

```shell
helm install --set image.repository=apache/flink-kubernetes-operator --set image.tag=1.1.0 flink-kubernetes-operator helm/flink-kubernetes-operator
```

## Operator webhooks

* 为了在operator中使用webhooks，需要在k8s上安装cert-manager。

```shell
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml
```

## Watching only specific namespaces

* Operator支持监视FlinkDeployment资源的特定namespace列表。可以通过设置--set watchNamespaces={flink-test}参数启用它。当启用此功能时，基于角色的访问控制只针对operator和作业管理器的这些namespace创建，否则默认为集群作用域。
* 为k8s集群打标签

```shell
kubectl label namespace <target namespace name> kubernetes.io/metadata.name=<target namespace name>
```

* 根据自定义namespaceSelector，监听对应的namespace,key-value表示{定制的命名空间键:<目标命名空间名称>}

```yaml
namespaceSelector:
  matchExpressions:
    - key: customized_namespace_key
    operator: In
    values: [{{- range .Values.watchNamespaces }}{{ . | quote }},{{- end}}]
```

## 通过kustomize自定义K8s集群配置

* 使用`kustomize`定义a [fluent-bit](https://docs.fluentbit.io/manual) sidecar容器配置，使用value.yaml覆盖helm chart默认日志配置

```yaml
# value.yaml
defaultConfiguration:
  ...
  log4j-operator.properties: |+
    rootLogger.appenderRef.file.ref = LogFile
    appender.file.name = LogFile
    appender.file.type = File
    appender.file.append = false
    appender.file.fileName = ${sys:log.file}
    appender.file.layout.type = PatternLayout
    appender.file.layout.pattern = %d{yyyy-MM-dd HH:mm:ss,SSS} %-5p %-60c %x - %m%n    

jvmArgs:
  webhook: "-Dlog.file=/opt/flink/log/webhook.log -Xms256m -Xmx256m"
  operator: "-Dlog.file=/opt/flink/log/operator.log -Xms2048m -Xmx2048m"
```

* 以上配置不能够定义fluent-bit sidecar，需要通过`kustomize`来自定义sidecar配置

```yaml
# kustomize.yaml
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

apiVersion: apps/v1
kind: Deployment
metadata:
  name: not-important
spec:
  template:
    spec:
      containers:
        - name: flink-kubernetes-operator
          volumeMounts:
            - name: flink-log
              mountPath: /opt/flink/log
          resources:
            requests:
              memory: "2.5Gi"
              cpu: "1000m"
            limits:
              memory: "2.5Gi"
              cpu: "2000m"
        - name: flink-webhook
          volumeMounts:
            - name: flink-log
              mountPath: /opt/flink/log
          resources:
            requests:
              memory: "0.5Gi"
              cpu: "200m"
            limits:
              memory: "0.5Gi"
              cpu: "500m"
        - name: fluentbit
          image: fluent/fluent-bit:1.8.12
          command: [ 'sh','-c','/fluent-bit/bin/fluent-bit -i tail -p path=/opt/flink/log/*.log -p multiline.parser=java -o stdout' ]
          volumeMounts:
            - name: flink-log
              mountPath: /opt/flink/log
      volumes:
        - name: flink-log
          emptyDir: { }
```

* 安装自定义配置k8s operator

```shell
helm install flink-kubernetes-operator helm/flink-kubernetes-operator -f examples/kustomize/values.yaml --post-renderer examples/kustomize/render
```

* 具体kustomize使用方式可以查看https://github.com/kubernetes-sigs/kustomize

# Configuration

## 指定Operator Configuration

* Operator允许用户指定由Flink Operator本身和Flink部署共享的默认配置。这个配置文件可以挂在到外部的ConfigMaps中，使用value.yaml配置自定义的配置通过`helm install flink-kubernetes-operator helm/flink-kubernetes-operator -f value.yaml`进行生效

```yaml
defaultConfiguration:
  create: true
  # flase表示会替换底层配置文件，true为append
  append: true
  flink-conf.yaml: |+
    # Flink Config Overrides
    kubernetes.operator.metrics.reporter.slf4j.factory.class: org.apache.flink.metrics.slf4j.Slf4jReporterFactory
    kubernetes.operator.metrics.reporter.slf4j.interval: 5 MINUTE

    kubernetes.operator.reconcile.interval: 15 s
    kubernetes.operator.observer.progress-check.interval: 5 s
```

## Dynamic Operator Configuration

* k8s operator支持通过operator ConfigMaps动态改变配置。动态operator配置默认是开启的，可以通过`kubernetes.operator.dynamic.config.enabled`设置为false关闭。时间线定期会校验动态配置是否改变，通过`kubernetes.operator.dynamic.config.check.interval`设置check间隔，默认为5分钟。
* 通过`kubectl edit cm`或者`kubectl patch`修改configmap配置。