#!/usr/bin/env bash

source ./library.sh

nucleus=Bi214

num=(     2     2     2     3     3     3 )
pos=( 813.9 840.5 857.0 812.8 829.2 857.0 )

for i in "${!num[@]}"; do
    for cov in {0.30,}; do
        for abs in {85,}; do
            process_simulation $nucleus ${num[i]} ${pos[i]} $abs $cov 1000000 150 0
        done
    done
done
