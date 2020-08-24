#!/usr/bin/env bash

connect_url=$1
username=$2
password=$3
hive_table=$4
parallelism=$5
db_name=$6
ds=$7

sqoop import --connect ${connect_url} \
--username ${username} \
--password ${password} \
--table users_d \
--delete-target-dir \
--create-hive-table \
--hive-partition-key ds \
--hive-table ${hive_table} \
--hive-partition-value ${ds} \
--m ${parallelism} \
--fields-terminated-by "\t" \
--hive-import \
--hive-database ${db_name} \
--hive-home /user/hive/warehouse/ \
--map-column-hive id=string \
--hive-drop-import-delims