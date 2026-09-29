#!/usr/bin/env bash

source "$HOME/.config/sketchybar/variables.sh"

# For yabai, SELECTED is provided by sketchybar's space event
if [ "$SELECTED" = "true" ]; then
    sketchybar --set "$NAME" \
        icon.highlight=on \
        background.drawing=on \
        background.border_width=2 \
        background.border_color="$RED"
else
    sketchybar --set "$NAME" \
        icon.highlight=off \
        background.drawing=off \
        background.border_width=0
fi
