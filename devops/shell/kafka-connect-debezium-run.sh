#!/bin/bash

namespace=$2

if(($#!=2))
then
    echo 请输入start/stop mysql/pg/mongo
    exit;
fi

case $1 in
"start"){
    nohup /lib/kafka-current/bin/connect-distributed.sh /home/hadoop/debezium/${namespace}-connect-distributed.properties 1 > /dev/null 2 > connect_error.log &
};;
"stop"){
    jps | grep ConnectDistributed | awk '{print $1}'|xargs kill
};;
esac