#!/usr/bin/env bash

COLOR="$PURPLE"

sketchybar --add item next_meeting left \
	--set next_meeting \
	icon="󰃰" \
	icon.color="$COLOR" \
	icon.padding_left=10 \
	icon.padding_right=5 \
	label.color="$COLOR" \
	label.padding_right=10 \
	label.max_chars=35 \
	scroll_texts=on \
	background.color="$BAR_COLOR" \
	background.height=26 \
	background.corner_radius="$CORNER_RADIUS" \
	background.border_width="$BORDER_WIDTH" \
	background.border_color="$COLOR" \
	background.drawing=on \
	update_freq=60 \
	script="$PLUGIN_DIR/next_meeting.sh" \
	click_script="open -a 'Microsoft Outlook'"