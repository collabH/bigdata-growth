#!/usr/bin/env bash

# 接收参数
type=$1
agent=$2
job=$3
case $type in
    'start')
        flume-ng agent -n ${agent} -c ${FLUME_HOME}/conf -f ${job}
    ;;
    'stop')
        jps | grep 'Application' | awk -F" " '{print $1}'| xargs kill
esac
