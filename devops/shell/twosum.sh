#!/usr/bin/env bash

function sum() {
    s=0;
    s=$[$1 + $2];
    echo ${s}
}

# 输出参数
read -p "input your paramter1:" P1
read -p "input your paramter2:" P2
sum ${P1} ${P2}