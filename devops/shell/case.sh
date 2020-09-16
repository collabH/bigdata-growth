#!/bin/bash
case $1 in
1)
  echo "hsm"
  ;;
2)
  echo "zzl"
  ;;
*)
  echo "zzz"
  ;;
esac
a=false
if [ ${a} == "true" ]; then
  echo "xx"
else
  echo "xxx"
fi
