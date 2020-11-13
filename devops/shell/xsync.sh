#!/usr/bin/env bash

targetPath=$2
targetServer=$3

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

for server in ${targetServer}; do
    echo '----------'${server}'---------'
    scp ${pdir}/${fileName} ${user}@${server}:${targetPath}
done