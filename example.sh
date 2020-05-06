#!/usr/bin/env bash

source ./library.sh

nucleus=Bi214

num=(    2    2    2    3    3    3 )
pos=( 8139 8405 8570 8128 8292 8570 )

for i in "${!num[@]}"; do
    for cov in {0.30,}; do
        for abs in {85,}; do
            process_simulation $nucleus ${num[i]} ${pos[i]} $abs $cov 1000000 150
        done
    done
done
