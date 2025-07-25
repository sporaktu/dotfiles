#!/usr/bin/env bash

compute PCT
COLOR="$CYAN"

sketchybar --add item ram right \
    --set ram \
        update_freq=5 \
        icon="" \
        icon.color="$COLOR" \
        icon.padding_left=10 \
        label="${PCT}%" \
        label.color="$COLOR" \
        label.padding_right=10 \
        background.height=26 \
        background.corner_radius="$CORNER_RADIUS" \
        background.padding_right=5 \
        background.border_width="$BORDER_WIDTH" \
        background.border_color="$COLOR" \
        background.color="$BAR_COLOR" \
        background.drawing=on \
        script="$PLUGIN_DIR/ram.sh" \
    --subscribe ram system_woke  # optional, to force-update on wake
