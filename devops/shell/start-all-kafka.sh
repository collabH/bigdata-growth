#!/usr/bin/env bash

# 启动zk集群
zkServer.sh --config ${ZOOKEEPER_HOME}/../zkCluster/zoo1 start
zkServer.sh --config ${ZOOKEEPER_HOME}/../zkCluster/zoo2 start
zkServer.sh --config ${ZOOKEEPER_HOME}/../zkCluster/zoo3 start

# 启动kafka集群
kafka-server-start.sh -daemon $KAFKA_HOME/config/server.properties &
kafka-server-start1.sh -daemon ${KAFKA_HOME}/config/server1.properties &
kafka-server-start2.sh -daemon ${KAFKA_HOME}/config/server2.properties &
