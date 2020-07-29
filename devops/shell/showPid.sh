#!/usr/bin/env bash
jps | grep '*'| awk -F" " '{print $1}'