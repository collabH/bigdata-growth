#!/usr/bin/env bash

jar_name=$1

nohup java -jar ${jar_name} > log.file 2>&1 &