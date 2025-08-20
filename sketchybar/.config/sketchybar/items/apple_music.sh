#!/usr/bin/env bash

COLOR="$RED"

sketchybar --add item apple_music left \
	--set apple_music \
	scroll_texts=on \
	icon=󰎆 \
	icon.color="$COLOR" \
	icon.padding_left=10 \
	background.color="$BAR_COLOR" \
	background.height=26 \
	background.corner_radius="$CORNER_RADIUS" \
	background.border_width="$BORDER_WIDTH" \
	background.border_color="$COLOR" \
	background.padding_right=-5 \
	background.drawing=on \
	label.padding_right=10 \
	label.max_chars=23 \
	update_freq=2 \
	updates=on \
	script="$PLUGIN_DIR/apple_music.sh" \
	click_script="open -a 'Music'"