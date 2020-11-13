#!/usr/bin/env bash


shell=$1


for server in cdh04 cdh05 cdh06 cdh01 cdh02 cdh03; do
    echo '----------'${server}'---------'
    ssh ${server} ${shell}
done