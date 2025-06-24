#!/usr/bin/env bash

LABEL=$(date '+%l:%M:%S %p' | sed 's/^ *//')
sketchybar --set "$NAME" label="$LABEL"
