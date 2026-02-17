#!/usr/bin/env bash

ACTIVE_COLOR="$RED"
INACTIVE_COLOR="$COMMENT"

sketchybar --add item spacer.1 left \
	--set spacer.1 background.drawing=off \
	label.drawing=off \
	icon.drawing=off \
	width=10

# Create spaces for each Mission Control space (up to 10 per display)
SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")

for i in "${!SPACE_ICONS[@]}"; do
    sid=$((i + 1))

    sketchybar --add space space.$sid left \
        --set space.$sid \
        space="$sid" \
        icon="${SPACE_ICONS[i]}" \
        icon.font="$FONT:Bold:12.0" \
        icon.color="$INACTIVE_COLOR" \
        icon.highlight_color="$ACTIVE_COLOR" \
        icon.padding_left=8 \
        icon.padding_right=8 \
        label.drawing=off \
        background.color="$BAR_COLOR" \
        background.height=26 \
        background.corner_radius=8 \
        background.border_width=0 \
        background.drawing=off \
        click_script="yabai -m space --focus $sid" \
        script="$PLUGIN_DIR/space.sh"
done

sketchybar --add item separator left \
	--set separator icon= \
	icon.font="$FONT:Regular:16.0" \
	background.padding_left=10 \
	background.padding_right=5 \
	label.drawing=off \
	icon.color="$YELLOW"
