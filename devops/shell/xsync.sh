#!/usr/bin/env bash

targetPath=$2

# 多服务器配置同步脚本
#1 获取输入参数个数，如果没有参数，直接退出
#paramCount=$#
#if (($paramCount == 0)); then
#    echo no args;
#    exit
#fi

#2 获取文件名称
p1=$1
fileName=`basename ${p1}`
echo fileName=${fileName}

#3 获取上级目录到绝对路径,-P进入真是的Bash路径
pdir=`cd -P $(dirname ${p1});
pwd`
echo pdir=${pdir}

#4获取当前用户名
user=`whoami`

#5 循环

for server in flink-cluster-01 flink-cluster-02 flink-cluster-03 flink-cluster-04 flink-cluster-05; do
    echo '----------'${server}'---------'
    scp ${pdir}/${fileName} ${user}@${server}:${targetPath}
done