# MySQL to HDFS

## 命令格式

```shell
sqoop import --connect <jdbc-uri> \
--username <username> \
--password <password> \
# 是否累加导入数据
--append \
# 导入parquet文件格式
--as-parquetfile \
# 导入那些列
--columns <col,col,col...> \
--compression-codec <codec> \
# 导入前是否删除目录
--delete-target-dir \
# 拉取数据条数
--fetch-size <n> \
# 读那张表
--table <table-name> \
#  导入的目录
--target-dir <dir> \
# mapper个数
-m,--num-mappers <n> \
# where条件
 --where <where clause> \
 # 字段切割符
 --fields-terminated-by \
```

## 定时导入脚本

```shell
#!/bin/bash

db_date=$2
echo $db_date
db_name=gmall

import_data() {
/opt/module/sqoop/bin/sqoop import \
--connect jdbc:mysql://hadoop:3306/$db_name \
--username root \
--password root \
--target-dir /origin_data/$db_name/db/$1/$db_date \
--delete-target-dir \
--num-mappers 1 \
--fields-terminated-by "\t" \
--query "$2"' and $CONDITIONS;'
}

// 全量数据
import_sku_info(){
  import_data "sku_info" "select 
id, spu_id, price, sku_name, sku_desc, weight, tm_id,
category3_id, create_time
  from sku_info where 1=1"
}
// 全量数据
import_user_info(){
  import_data "user_info" "select 
id, name, birthday, gender, email, user_level, 
create_time 
from user_info where 1=1"
}
// 全量数据
import_base_category1(){
  import_data "base_category1" "select 
id, name from base_category1 where 1=1"
}
// 全量数据
import_base_category2(){
  import_data "base_category2" "select 
id, name, category1_id from base_category2 where 1=1"
}
// 全量数据
import_base_category3(){
  import_data "base_category3" "select id, name, category2_id from base_category3 where 1=1"
}

// 新增数据
import_order_detail(){
  import_data   "order_detail"   "select 
    od.id, 
    order_id, 
    user_id, 
    sku_id, 
    sku_name, 
    order_price, 
    sku_num, 
    o.create_time  
  from order_info o, order_detail od
  where o.id=od.order_id
  and DATE_FORMAT(create_time,'%Y-%m-%d')='$db_date'"
}
// 新增数据
import_payment_info(){
  import_data "payment_info"   "select 
    id,  
    out_trade_no, 
    order_id, 
    user_id, 
    alipay_trade_no, 
    total_amount,  
    subject, 
    payment_type, 
    payment_time 
  from payment_info 
  where DATE_FORMAT(payment_time,'%Y-%m-%d')='$db_date'"
}

# 新增和变化的数据
import_order_info(){
  import_data   "order_info"   "select 
    id, 
    total_amount, 
    order_status, 
    user_id, 
    payment_way, 
    out_trade_no, 
    create_time, 
    operate_time  
  from order_info 
  where (DATE_FORMAT(create_time,'%Y-%m-%d')='$db_date' or DATE_FORMAT(operate_time,'%Y-%m-%d')='$db_date')"
}

case $1 in
  "base_category1")
     import_base_category1
;;
  "base_category2")
     import_base_category2
;;
  "base_category3")
     import_base_category3
;;
  "order_info")
     import_order_info
;;
  "order_detail")
     import_order_detail
;;
  "sku_info")
     import_sku_info
;;
  "user_info")
     import_user_info
;;
  "payment_info")
     import_payment_info
;;
   "all")
   import_base_category1
   import_base_category2
   import_base_category3
   import_order_info
   import_order_detail
   import_sku_info
   import_user_info
   import_payment_info
;;
esac
```

