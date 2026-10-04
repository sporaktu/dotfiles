#!/usr/bin/env bash
# Brightness control per display
# Usage: brightness.sh <monitor> [up|down|get]

MONITOR=$1
ACTION=${2:-get}
STEP=10

export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr/ | head -1)
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1

case "$MONITOR" in
    HDMI-A-2)
        # LG OLED — use Hyprland sdrbrightness (0.5 - 2.0)
        CURRENT=$(hyprctl monitors -j | jq '.[] | select(.name=="HDMI-A-2") | .sdrBrightness')
        case "$ACTION" in
            up)   NEW=$(echo "$CURRENT + 0.1" | bc); [ "$(echo "$NEW > 2.0" | bc)" -eq 1 ] && NEW=2.0 ;;
            down) NEW=$(echo "$CURRENT - 0.1" | bc); [ "$(echo "$NEW < 0.5" | bc)" -eq 1 ] && NEW=0.5 ;;
            *)    printf '{"text": "%.0f%%", "tooltip": "OLED: %.1f", "class": "oled"}' "$(echo "$CURRENT * 100 / 2" | bc)" "$CURRENT"; exit 0 ;;
        esac
        hyprctl keyword monitor "HDMI-A-2, 3840x2160@144, 2560x0, 1, bitdepth, 10, cm, hdr, sdrbrightness, $NEW" >/dev/null
        printf '{"text": "%.0f%%", "tooltip": "OLED: %.1f", "class": "oled"}' "$(echo "$NEW * 100 / 2" | bc)" "$NEW"
        ;;
    DP-5)
        # Acer XB271HU — DDC bus 14
        case "$ACTION" in
            up)   ddcutil --bus 14 setvcp 10 + $STEP 2>/dev/null ;;
            down) ddcutil --bus 14 setvcp 10 - $STEP 2>/dev/null ;;
        esac
        VAL=$(ddcutil --bus 14 getvcp 10 2>/dev/null | grep -oP 'current value =\s+\K\d+')
        printf '{"text": "%s%%", "tooltip": "Acer: %s%%", "class": "dp5"}' "$VAL" "$VAL"
        ;;
    DP-6)
        # Philips 278E1 — DDC bus 15
        case "$ACTION" in
            up)   ddcutil --bus 15 setvcp 10 + $STEP 2>/dev/null ;;
            down) ddcutil --bus 15 setvcp 10 - $STEP 2>/dev/null ;;
        esac
        VAL=$(ddcutil --bus 15 getvcp 10 2>/dev/null | grep -oP 'current value =\s+\K\d+')
        printf '{"text": "%s%%", "tooltip": "Philips: %s%%", "class": "dp6"}' "$VAL" "$VAL"
        ;;
esac
