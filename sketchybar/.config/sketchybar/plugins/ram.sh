#!/usr/bin/env bash

# Mirrors Activity Monitor's "Memory Used":
#   Used   = App Memory (anonymous - purgeable) + Wired + Compressed
#   Cached = File-backed + Purgeable (reclaimable on demand)

TOTAL_BYTES=$(sysctl -n hw.memsize)
PAGE_SIZE=$(sysctl -n vm.pagesize)

VM=$(vm_stat)
field() { echo "$VM" | awk -v pat="$1" '$0 ~ pat {for (i=1;i<=NF;i++) if ($i ~ /[0-9]+\.?$/) { gsub(/\./,"",$i); print $i; exit }}'; }

P_WIRED=$(field 'Pages wired down:')
P_ANON=$(field 'Anonymous pages:')
P_PURGE=$(field 'Pages purgeable:')
P_COMP=$(field 'Pages occupied by compressor:')
P_FILE=$(field 'File-backed pages:')

APP_BYTES=$(( (P_ANON - P_PURGE) * PAGE_SIZE ))
USED_BYTES=$(( APP_BYTES + (P_WIRED + P_COMP) * PAGE_SIZE ))
CACHED_BYTES=$(( (P_FILE + P_PURGE) * PAGE_SIZE ))

to_gb() { echo "scale=1; $1 / 1024 / 1024 / 1024" | bc; }

USED_GB=$(to_gb $USED_BYTES)
CACHED_GB=$(to_gb $CACHED_BYTES)
TOTAL_GB=$(to_gb $TOTAL_BYTES)

case "$SENDER" in
    mouse.entered)
        LABEL="${USED_GB} + ${CACHED_GB} cached / ${TOTAL_GB}GB"
        ;;
    *)
        LABEL="${USED_GB}GB/${TOTAL_GB}GB"
        ;;
esac

sketchybar --set "$NAME" icon="󰍛" label="$LABEL"
