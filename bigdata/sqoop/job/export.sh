#!/usr/bin/env bash

db_name=$1
parallelism=$2
# 根据某个字段识别record是否被修改
update_key=$3
table_name=$4
# 更新模式 allowinsert:运行新增，updateonly只更新
update_mode=allowinsert

sqoop export --connect jdbc:mysql://hadoop:3306/ds1 \
--username root --password root \
--num-mappers ${parallelism}  \
--update-key ${update_key} --update-mode ${update_mode}  \
--input-null-string '\\N' --input-null-non-string '\\N'  \
--input-fields-terminated-by '\t'  \
--table ${table_name} \
--export-dir hdfs://hadoop:8020/user/hive/warehouse/${db_name}/${table_name}