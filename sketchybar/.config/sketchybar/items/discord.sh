#!/usr/bin/env bash

COLOR="$MAGENTA"

sketchybar --add item discord right \
	--set discord \
	icon="󰙯" \
	icon.color="$COLOR" \
	icon.padding_left=10 \
	icon.padding_right=5 \
	label.color="$COLOR" \
	label.padding_right=10 \
	background.color="$BAR_COLOR" \
	background.height=26 \
	background.corner_radius="$CORNER_RADIUS" \
	background.border_width="$BORDER_WIDTH" \
	background.border_color="$COLOR" \
	background.drawing=on \
	update_freq=10 \
	script="$PLUGIN_DIR/discord.sh" \
	click_script="open -a 'Discord'"