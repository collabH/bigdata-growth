
table_name=$1

hdfs dfs -rm -r /user/hive/warehouse/for_source/${table_name}

hive -e "drop table for_source.${table_name}"