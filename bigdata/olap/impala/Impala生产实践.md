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





