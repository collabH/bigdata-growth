#!/usr/bin/env bash

table_name=$1
schema_name=$2
db_name=$3

hive -e "drop table ${db_name}.${table_name}"
hdfs dfs -rm -r /user/hive/warehouse/${schema_name}/${table_name}