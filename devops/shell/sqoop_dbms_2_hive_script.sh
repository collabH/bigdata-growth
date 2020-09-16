#!/usr/bin/env bash

# common params
table=

# mysql table params
connect_url=
username=datapipeline
password=${password}

# hive table params
hive_partition_key=ds
hive_partition_value=${ds}
map_task_nums=1
compression_codec="org.apache.hadoop.io.compress.SnappyCodec"
split_key=id
db_name=for_sqoop
external_prefix=jfs://prod-block/user/hive/warehouse
# 是否增量同步标示
is_incr=true

import_data() {
  sqoop import --connect ${connect_url} --username ${username} --password ${password} \
    --table ${table} \
    --mapreduce-job-name ${table} \
    --delete-target-dir \
    --hive-partition-key ${hive_partition_key} \
    --hive-table ${table} \
    --hive-partition-value ${hive_partition_value} \
    -m ${map_task_nums} \
    --fields-terminated-by "\t" \
    --compression-codec ${compression_codec} \
    --split-by ${split_key} \
    -z \
    --hive-drop-import-delims \
    --external-table-dir ${external_prefix}/${db_name}.db/${table} \
    --hive-import \
    --hive-overwrite \
    --hive-database ${db_name} \
    --null-string '\\N' \
    --null-non-string '\0' \
    --where $1
}

# 增量/全量同步
if [ $is_incr ]; then
  import_data "(DATE_FORMAT(created_at,'%Y%m%d')='${ds}' or DATE_FORMAT(updated_at,'%Y%m%d')='${ds}')"
else
  import_data "1=1"
fi
