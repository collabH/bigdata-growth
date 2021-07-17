#!/bin/bash
#
# hdfs环境启动脚本
# Copyright 2021 huangshimin
cmd=$1

if [ $cmd == "start" ]
then
   start-all.sh
   hive --service hiveserver2 &
   hive --service metastore &
else
 stop-all.sh
fi