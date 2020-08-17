#!/usr/bin/env bash


shell=$1


for server in flink-cluster-01 flink-cluster-02 flink-cluster-03 flink-cluster-04 flink-cluster-05; do
    echo '----------'${server}'---------'
    ssh ${server} ${shell}
done