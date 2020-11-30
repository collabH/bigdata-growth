#!/usr/bin/env bash
jps |grep $1| awk -F" " '{print $1}'|xargs kill -9