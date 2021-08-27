#!/usr/bin/env bash


shell=$1
servers=$2


for server in $servers; do
    echo '----------'${server}'---------'
    ssh ${server} ${shell}
done