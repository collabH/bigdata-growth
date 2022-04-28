# 基础使用命令

```shell

# 登录
oc log 不同环境url
# 创建新项目
oc new-project ProjectName
# 查看当前项目下pod
oc get pod
# 查看project
oc get project
# 进入project
oc project projectName
#将一个服务映射出域名
oc expose svc svcname –hostname=xxx,将一个服务器映射成域名，支持http/https协议，svcname可以不写默认与dcname相同 
# 查看pod日志
oc logs -f podname 
# 查看pod详细状态信息
oc describe pod podname 
# 删除，获取，编辑
oc get/delete/edit pod/bc/dc/svc/route 
# 查看域名映射
oc get route 
# 进入openshift中运行的pod
oc rsh podname bash 
# 获取token
oc whoami -t
# build一份代码镜像
oc new-build gitlab clone地址
# 查看project的pod、
oc get pod -n <project>
# 查看 pod 对象配置细节(也可以是其他对象)
oc get pod <name> -n <ns> -o json|yaml
```

# Whoami

* oc whoami 命令众所周知，特别是加上flag -t用于获取当前用户/会话的持有者令牌。但是当你有一个令牌并且你不知道谁是所有者时会发生什么？ 您可以做的一件事是使用令牌登录OpenShift，然后执行oc whoami...等待一秒钟。oc whoami会给你这个信息！只需在命令行中传递令牌作为第3个参数，不需要任何标志。

  ```shell
  token=$(oc  whoami -t)
  oc whoami $token
  ```

# oc debug

> 你可以运行一个pod并获得一个shell，有时获取正在运行的pod配置的副本并使用shell对其进行故障排除很有用。

``` shell
oc debug podname
# set root权限
oc debug --as-root=true podname
```

