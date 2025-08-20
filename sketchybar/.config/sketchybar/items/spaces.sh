#!/usr/bin/env bash

COLOR="$RED"

sketchybar --add item spacer.1 left \
	--set spacer.1 background.drawing=off \
	label.drawing=off \
	icon.drawing=off \
	width=10

# Create space info widget for display 1
sketchybar --add item space_info_1 left \
	--set space_info_1 \
	associated_display=1 \
	icon="󰍹" \
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
	update_freq=1 \
	script="$PLUGIN_DIR/space_info.sh" \
	--subscribe space_info_1 space_change

# Create space info widget for display 2  
sketchybar --add item space_info_2 left \
	--set space_info_2 \
	associated_display=2 \
	icon="󰍹" \
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
	update_freq=1 \
	script="$PLUGIN_DIR/space_info.sh" \
	--subscribe space_info_2 space_change

# Create space info widget for display 3
sketchybar --add item space_info_3 left \
	--set space_info_3 \
	associated_display=3 \
	icon="󰍹" \
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
	update_freq=1 \
	script="$PLUGIN_DIR/space_info.sh" \
	--subscribe space_info_3 space_change

sketchybar --add item separator left \
	--set separator icon= \
	icon.font="$FONT:Regular:16.0" \
	background.padding_left=10 \
	background.padding_right=5 \
	label.drawing=off \
	icon.color="$YELLOW"