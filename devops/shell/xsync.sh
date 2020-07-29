#!/usr/bin/env bash

cluster01=10.16.18.131
cluster02=10.16.18.133
cluster03=10.16.18.134
cluster04=10.16.18.135

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

scp ${pdir}/${fileName} ${user}@${cluster01}:${targetPath}
scp ${pdir}/${fileName} ${user}@${cluster02}:${targetPath}
scp ${pdir}/${fileName} ${user}@${cluster03}:${targetPath}
scp ${pdir}/${fileName} ${user}@${cluster04}:${targetPath}