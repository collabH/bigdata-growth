#!/usr/bin/env bash

connect_url="jdbc:mysql://pc-bp185ot31zten9a24.mysql.polardb.rds.aliyuncs.com:3306/ninth_studio"
username=datapipeline
password=${password}
hive_table=ods_ninth_studio_wechat_chat_records
db_name=for_ods
type="wechat_chat_records_202006"


# 统一数据导入hive脚本
import_data() {
    sqoop import --connect ${connect_url} --username ${username} --password ${password}  \
 --mapreduce-job-name ${hive_table}  \
 --delete-target-dir  \
 --hive-partition-key source_table  \
 --hive-table ${hive_table}  \
 --hive-partition-value $1  \
 -m $2  \
 --fields-terminated-by "\t" \
 -z  \
 --split-by split_key \
 --compression-codec snappy  \
 --hive-import  \
 --hive-overwrite  \
 --hive-database ${db_name}  \
 --hive-home /user/hive/warehouse/  \
 --hive-overwrite  \
 --hive-drop-import-delims  \
 --null-string '\\N'  \
 --null-non-string '\0'  \
 --query "$3"' and $CONDITIONS;'
}

import_wechat_chat_records() {
    import_data "wechat_chat_records" 8 "select id, assistant_wxid, `from`, `to`, msg_type, msg, status, task_id, created_at, updated_at, msg_id, send_status,
       Round(Rand()*15+1,0) as split_key
    from ninth_studio.wechat_chat_records where 1=1"
}

import_wechat_chat_records_202006() {
    import_data "wechat_chat_records_202006" "wechat_chat_records_202006" 16 "1=1"
}


import_wechat_chat_records01() {
    import_data "wechat_chat_records01" "wechat_chat_records01" 16 "1=1"
}

# 执行逻辑
case ${type} in
    "wechat_chat_records")
        import_wechat_chat_records
    ;;
    "wechat_chat_records_202006")
        import_wechat_chat_records_202006
    ;;
    "wechat_chat_records01")
        import_wechat_chat_records01
    ;;
    "all")
        import_wechat_chat_records
        import_wechat_chat_records_202006
        import_wechat_chat_records01
    ;;
esac