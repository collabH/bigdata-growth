#!/usr/bin/env bash

# mysql table params
connect_url=
username=
password=
mysql_table=

# hive table params
hive_table=
hive_partition_key=
hive_partition_value=
map_task_nums=
compression_codec=
split_key=
db_name=for_ods
external_prefix=
where_condition=

sqoop import --connect ${connect_url} --username ${username} --password ${password} \
  --table ${mysql_table} \
  --mapreduce-job-name ${hive_table} \
  --delete-target-dir \
  --hive-partition-key ${hive_partition_key} \
  --hive-table ${hive_table} \
  --hive-partition-value ${hive_partition_value} \
  -m ${map_task_nums} \
  --fields-terminated-by "\t" \
  --compression-codec ${compression_codec} \
  --split-by ${split_key} \
  -z \
  --hive-drop-import-delims \
  --create-hive-table \
  --external-table-dir ${external_prefix}/${db_name}.db/${hive_table} \
  --hive-import \
  --hive-overwrite \
  --hive-database ${db_name} \
  --null-string '\\N' \
  --null-non-string '\0' \
  --where ${where_condition}
