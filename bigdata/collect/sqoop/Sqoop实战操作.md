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

# HDFS to MYSQL

## 命令格式

```shell
sqoop export  --connect <jdbc-uri> \
--username <username> \
--password <password> \
-m,--num-mappers <n> \
--table <table-name> \
--update-mode <mode> \
--export-dir \
--input-fields-terminated-by\
--input-null-string '\\N' \
--input-null-non-string '\\N'
```

* --update-mode：\
  * updateonly  只更新，无法插入新数据
  * allowinsert  允许新增 
* --update-key：允许更新的情况下，指定哪些字段匹配视为同一条数据，进行更新而不增加。多个字段用逗号分隔。
*  --input-null-string和--input-null-non-string：分别表示，将字符串列和非字符串列的空串和“null”转换成'\\N'。

```
Hive中的Null在底层是以“\N”来存储，而MySQL中的Null在底层就是Null，为了保证数据两端的一致性。在导出数据时采用--input-null-string和--input-null-non-string两个参数。导入数据时采用--null-string和--null-non-string。
```

[Sqoop export文档](https://sqoop.apache.org/docs/1.4.7/SqoopUserGuide.html#_literal_sqoop_export_literal)

```shell
#!/bin/bash

db_name=gmall

export_data() {
/opt/module/sqoop/bin/sqoop export \
--connect "jdbc:mysql://hadoop102:3306/${db_name}?useUnicode=true&characterEncoding=utf-8"  \
--username root \
--password 000000 \
--table $1 \
--num-mappers 1 \
--export-dir /user/hive/warehouse/bussines_ads.db/$1 \
--input-fields-terminated-by "\t" \
--update-mode allowinsert \
--update-key "tm_id,category1_id,stat_mn,stat_date" \
--input-null-string '\\N'    \
--input-null-non-string '\\N'
}

case $1 in
  "ads_uv_count")
     export_data "ads_uv_count"
;;
esac
```

# Sqoop踩坑

## Sqoop导入导出Null存储一致性问题

* Hive中的Null在底层是以`“\N”来存储`，而`MySQL中的Null在底层就是Null，为了保证数据两端的一致性。`在导出数据时采用`--input-null-string和--input-null-non-string两个参数。导入数据时采用--null-string和--null-non-string。`

## Sqoop数据导出一致性问题

* 如Sqoop在导出到Mysql时，使用4个Map任务，过程中有2个任务失败，那此时MySQL中存储了另外两个Map任务导入的数据，如果此时重跑会有数据不一致问题
  * 使用--staging-table先导出到一个临时表，全部成功后才会放入最终的表
  * 使用--clear-staging-table会先情况staging的临时表，再写入临时表。

## java.security.AccessControlException: access denied ("javax.management.MBeanTrustPermission" "register")

```text
 ERROR Could not register mbeans java.security.AccessControlException: access denied ("javax.management.MBeanTrustPermission" "register")
```

* 修改$JAVA_HOME/jre/lib/security/java.policy
```json
# 添加
grant {
	permission javax.management.MBeanTrustPermission "register";
}
```
