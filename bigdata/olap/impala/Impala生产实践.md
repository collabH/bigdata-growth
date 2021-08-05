# Impala Script

## 使用可变变量

* sql脚本

```sql
-- 查看成员合并后各个表结果数据
-- 查看 c
select *
from user
where aff_id in (${var:from_aff_id}, ${var:to_aff_id});

-- 查看 b
select *
from account
where account_id in (${var:from_account_id}, ${var:to_account_id});

-- 查看 event
select *
from event
where aff_id = ${var:from_aff_id};
select *
from event
where aff_id = ${var:to_aff_id};

-- 查看 bc关系
select * from user_account_rela where aff_id in (${var:from_aff_id}, ${var:to_aff_id});
select * from user_account_rela where account_id in (${var:from_account_id}, ${var:to_account_id});
```

* shell脚本

```shell
#!/usr/bin/env bash

# 执行成员融合数据校验sql

from_aff_id=$1
to_aff_id=$2
from_account_id=$3
to_account_id=$4

impala-shell --print_header --var from_aff_id=${from_aff_id} --var to_aff_id=${to_aff_id} --var from_account_id=${from_account_id} \
--var to_account_id=${to_account_id} -f merge_result.sql
```

## 配置HDFS跨集群

* 保证每个集群的nameservice ID唯一；并且需要在"hdfs-site.xml"的HDFS客户端中增加集群的nameserviceID到dfs.nameservices属性中
```xml
<propert>
    <name>dfs.nameservices</name>
    <value>nameservice1,nameservice2,nameservice3</value>
</propert>
```
* 同时复制哪些引用nameserviceID的其他属性到hdfs-site.xml中，如:
    * dfs.ha.namenodes.<nameserviceID>
    * dfs.client.failover.proxy.provider.<nameserviceID>: `org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider`
    * dfs.namenode.http-address.<nameserviceID>.<namenode1>
    * dfs.namenode.http-address.<nameserviceID>.<namenode2>
    * dfs.namenode.https-address.<nameserviceID>.<namenode1>
    * dfs.namenode.https-address.<nameserviceID>.<namenode2>
    * dfs.namenode.rpc-address..<nameserviceID>.<namenode1>
    * dfs.namenode.rpc-address..<nameserviceID>.<namenode2>
