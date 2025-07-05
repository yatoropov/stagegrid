#!/bin/bash

SCRIPT_DIR="/home/toropov/stagegrid/shs"

for script in "$SCRIPT_DIR"/*.sh; do
    if [[ -f "$script" ]]; then
        counter=$((counter + 1))
        bash "$script" &
    fi
done
