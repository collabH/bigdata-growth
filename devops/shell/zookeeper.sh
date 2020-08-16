#!/usr/bin/env bash

type=$1

case ${type} in
    'start')
        zkServer.sh --config $ZOOKEEPER_HOME/../zkCluster/zoo1 start
        zkServer.sh --config $ZOOKEEPER_HOME/../zkCluster/zoo2 start
        zkServer.sh --config $ZOOKEEPER_HOME/../zkCluster/zoo3 start
    ;;
    'stop')
        zkServer.sh --config $ZOOKEEPER_HOME/../zkCluster/zoo1 stop
        zkServer.sh --config $ZOOKEEPER_HOME/../zkCluster/zoo2 stop
        zkServer.sh --config $ZOOKEEPER_HOME/../zkCluster/zoo3 stop
    ;;
    'status')
        zkServer.sh --config $ZOOKEEPER_HOME/../zkCluster/zoo1 status
        zkServer.sh --config $ZOOKEEPER_HOME/../zkCluster/zoo2 status
        zkServer.sh --config $ZOOKEEPER_HOME/../zkCluster/zoo3 status
    ;;
esac