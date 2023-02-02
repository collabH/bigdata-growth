# 环境准备

* Kubernetes server 1.14.0+
* kubectl 1.14.0+
* Helm 3.0+

# 操作步骤

## 准备K8s环境

* mac机器可以使用Docker客户端快速构建Docker+K8s运行环境

## 安装Pulsar

* 添加helm charts repo

```shell
helm repo add apache https://pulsar.apache.org/charts
helm repo update
```

* clone pulsar helm chart

```shell
git clone https://github.com/apache/pulsar-helm-chart
cd pulsar-helm-chart
```

* 通过prepare_helm_release创建pulsar必须秘钥

```shell
./scripts/pulsar/prepare_helm_release.sh \
    -n pulsar \
    -k pulsar-mini \
    -c
```

* 通过helm安装pulsar

```shell
helm install \
    --values examples/values-minikube.yaml \
    --namespace pulsar \
    pulsar-mini apache/pulsar
```

* 校验是否安装成功

```shell
-- 校验pods是否正常
kubectl get pods -n pulsar
-- output如下
pulsar-mini-bookie-0                                   0/1     Init:0/1            0          113s
pulsar-mini-bookie-init-8vbqg                          0/1     Init:0/1            0          114s
pulsar-mini-broker-0                                   0/1     Init:0/2            0          113s
pulsar-mini-grafana-648ccb799b-96mpz                   0/3     ContainerCreating   0          114s
pulsar-mini-kube-prometheu-operator-7b65fbd76c-9fhd4   0/1     ContainerCreating   0          114s
pulsar-mini-kube-state-metrics-64c7dc48f5-7xd85        0/1     ContainerCreating   0          114s
pulsar-mini-prometheus-node-exporter-hnpvr             0/1     ContainerCreating   0          114s
pulsar-mini-proxy-0                                    0/1     Init:0/2            0          113s
pulsar-mini-pulsar-init-f9f4b                          0/1     Init:0/2            0          114s
pulsar-mini-pulsar-manager-59f7496fcd-2m652            0/1     ContainerCreating   0          114s
pulsar-mini-toolset-0                                  0/1     ContainerCreating   0          113s
pulsar-mini-zookeeper-0                                0/1     Pending             0          113s

-- 校验service是否正常
kubectl get services -n pulsar
-- output如下
pulsar-mini-bookie                      ClusterIP      None             <none>        3181/TCP,8000/TCP                     2m41s
pulsar-mini-broker                      ClusterIP      None             <none>        8080/TCP,6650/TCP                     2m41s
pulsar-mini-grafana                     ClusterIP      10.99.72.200     <none>        80/TCP                                2m41s
pulsar-mini-kube-prometheu-operator     ClusterIP      10.102.5.74      <none>        443/TCP                               2m41s
pulsar-mini-kube-prometheu-prometheus   ClusterIP      10.109.99.226    <none>        9090/TCP                              2m41s
pulsar-mini-kube-state-metrics          ClusterIP      10.110.148.83    <none>        8080/TCP                              2m41s
pulsar-mini-prometheus-node-exporter    ClusterIP      10.101.234.224   <none>        9100/TCP                              2m41s
pulsar-mini-proxy                       LoadBalancer   10.99.195.218    localhost     80:32036/TCP,6650:31319/TCP           2m41s
pulsar-mini-pulsar-manager              LoadBalancer   10.109.129.44    localhost     9527:31041/TCP                        2m41s
pulsar-mini-toolset                     ClusterIP      None             <none>        <none>                                2m41s
pulsar-mini-zookeeper                   ClusterIP      None             <none>        8000/TCP,2888/TCP,3888/TCP,2181/TCP   2m41s
```

## 使用pulsar-admin创建pulsar tenants/namespaces/topics

```shell
kubectl exec -it -n pulsar pulsar-mini-toolset-0 -- /bin/bash
## 创建tenant
bin/pulsar-admin tenants create apache
bin/pulsar-admin tenants list
## 创建namespace
bin/pulsar-admin namespaces create apache/pulsar
bin/pulsar-admin namespaces list apache
## 创建topic
bin/pulsar-admin topics create-partitioned-topic apache/pulsar/test-topic -p 4
```

