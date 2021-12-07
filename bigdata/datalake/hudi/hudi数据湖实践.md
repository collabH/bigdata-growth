# hudi解决的问题

## schema增量字段位置乱序对齐方案

* 基于hudi携带的schema evolution可以解决历史数据base schema从(id、age、name)变更为(id,sex,age,name)这种乱序schema的情况。

![](./img/schema演进.jpg)

