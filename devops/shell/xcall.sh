#!/usr/bin/env bash


shell=$1


ssh flink-cluster-02 ${shell}
ssh flink-cluster-03 ${shell}
ssh flink-cluster-04 ${shell}
ssh flink-cluster-05 ${shell}