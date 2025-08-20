#!/usr/bin/env bash

# Get actual total physical RAM from hardware
TOTAL_BYTES=$(sysctl -n hw.memsize)

# Read page counts for used memory calculation
P_ACTIVE=$(vm_stat | awk '/Pages active:/       {print $3}' | tr -d '.')
P_INACTIVE=$(vm_stat | awk '/Pages inactive:/   {print $3}' | tr -d '.')
P_SPEC=$(vm_stat | awk '/Pages speculative:/   {print $3}' | tr -d '.')
P_WIRED=$(vm_stat | awk '/Pages wired down:/    {print $4}' | tr -d '.')

# Get page size in bytes
PAGE_SIZE=$(sysctl -n vm.pagesize)

# Calculate used bytes (active + inactive + speculative + wired)
USED_BYTES=$(( (P_ACTIVE + P_INACTIVE + P_SPEC + P_WIRED) * PAGE_SIZE ))

# Convert to GB with 1 decimal place
TOTAL_GB=$(echo "scale=1; $TOTAL_BYTES / 1024 / 1024 / 1024" | bc)
USED_GB=$(echo "scale=1; $USED_BYTES / 1024 / 1024 / 1024" | bc)

# Output for SketchyBar
sketchybar --set "$NAME" icon="󰍛" label="${USED_GB}GB/${TOTAL_GB}GB"
