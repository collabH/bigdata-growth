#!/usr/bin/env bash

topic=$1
brokerList=$2

maxOffset=`kafka-run-class.sh kafka.tools.GetOffsetShell --topic ${topic} --time -1 --broker-list ${brokerList} |awk -F':' '{print $3}'| awk ' { SUM += $1 } END { print SUM }'`
minOffset=`kafka-run-class.sh kafka.tools.GetOffsetShell --topic ${topic} --time -2 --broker-list ${brokerList} |awk -F':' '{print $3}'| awk ' { SUM += $1 } END { print SUM }'`

echo topic:${topic}---消费消息个数: $(($maxOffset-$minOffset))