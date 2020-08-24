#!/usr/bin/env bash

connect_url="jdbc:mysql://localhost:3306/test"
username=datapipeline
password=${password}
hive_table=ods_ninth_studio_wechat_chat_records
db_name=for_ods
type="wechat_chat_records"


# 统一数据导入hive脚本
import_data() {
    sqoop import --connect ${connect_url} --username ${username} --password ${password}  \
 --table $1  \
 --mapreduce-job-name ${hive_table}  \
 --delete-target-dir  \
 --create-hive-table  \
 --hive-partition-key source_table  \
 --hive-table ${hive_table}  \
 --hive-partition-value $2  \
 -m $3  \
 --fields-terminated-by "\t"  \
 -z  \
 --compression-codec snappy  \
 --external-table-dir "hdfs:///user/hive/warehouse/${db_name}/${hive_table}"  \
 --hive-import  \
 --hive-overwrite  \
 --hive-database ${db_name}  \
 --hive-home /user/hive/warehouse/  \
 --hive-overwrite  \
 --hive-drop-import-delims  \
 --null-string '\\N'  \
 --null-non-string '\0'  \
 --where $4
}

import_wechat_chat_records() {
    import_data "wechat_chat_records" "wechat_chat_records" 8 "1=1"
    # "(DATE_FORMAT(created_at,'%Y%m%d')='${ds}' or DATE_FORMAT(updated_at,'%Y%m%d')='${ds}')"
}

import_wechat_chat_records_202006() {
    import_data "wechat_chat_records_202006" "wechat_chat_records_202006" 8 "1=1"
}


import_wechat_chat_records01() {
    import_data "wechat_chat_records01" "wechat_chat_records01" 8 "1=1"
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