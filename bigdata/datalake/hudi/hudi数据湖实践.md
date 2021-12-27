# hudi解决的问题

## schema增量字段位置乱序对齐方案

* 基于hudi携带的schema evolution可以解决历史数据base schema从(id、age、name)变更为(id,sex,age,name)这种乱序schema的情况。

![](./img/schema演进.jpg)

## 一条数据进入Hudi的流程

![](./img/数据流.jpg)

![](./img/数据流2.jpg)

## 流量毛刺问题

### 集中毛刺更新

#### 离线架构存在的问题

1. 数据峰值任务处理周期长、引起时效性报警。
2. 数据量持续变大引起GC严重，任务OOM问题。
3. 峰值持续时间长、造成数据积压，失败的任务重启失败。

#### Hudi解决方式

![](./img/流量毛刺.jpg)
