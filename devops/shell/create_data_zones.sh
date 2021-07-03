#!/usr/bin/env bash
# 创建目录，并且设置权限为bdp-dwh用户 bdp组，赋予/data/tmp赋予全部写权限
su -l hdfs
dirs=(/data/src /data/dwh /data/dmt /data/app /data/tmp)

for dir in ${dirs[@]}
do 
	hdfs dfs -test -d $dir && hdfs dfs -rm -r -f $dir
	hdfs dfs -mkdir -p $dir
	hdfs dfs -chown -R bdp-dwh:bdp $dir
done 
hdfs dfs -chmod a+w /data/tmp
exit
