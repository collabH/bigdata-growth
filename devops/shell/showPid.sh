#!/usr/bin/env bash
# shellcheck disable=SC2063
jps | grep '*'| awk -F" " '{print $1}'