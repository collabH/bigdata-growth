#!/usr/bin/env bash

for (( i = 0; i < 10; ++ i )); do
    echo "hsm"+${i}
done

# for in
for i in $*; do
  echo "hsm $i"
done
