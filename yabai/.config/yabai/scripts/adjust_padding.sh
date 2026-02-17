#!/usr/bin/env bash

# Script to adjust top padding based on display type
# Called when displays change or spaces are created

# Define padding values
BUILTIN_TOP_PADDING=10        # Minimal padding for built-in display (notch provides space)
EXTERNAL_TOP_PADDING=48       # Sketchybar height (30) + y_offset (5) + margin (5) + 8px
MAIN_EXTERNAL_TOP_PADDING=0   # Small breathing room; external_bar "main:50:0" already reserves sketchybar space

echo "Adjusting display padding..."

# Get all displays
displays=$(yabai -m query --displays)

# Get the main (primary) display index - the main display always has its origin at (0,0)
# external_bar "main:50:0" reserves sketchybar space on this display
main_display_id=$(echo "$displays" | jq -r 'map(select(.frame.x == 0 and .frame.y == 0)) | .[0].index')
echo "Detected main display: $main_display_id"

# Find the built-in display by looking for the smallest display
# Built-in MacBook displays are typically smaller than external monitors
# Also check for displays with negative coordinates (often positioned left of main)
smallest_width=$(echo "$displays" | jq -r 'min_by(.frame.w) | .frame.w')
builtin_display_id=$(echo "$displays" | jq -r "map(select(.frame.w == $smallest_width)) | .[0].index")

# Double-check: if we have a display with negative x coordinate and small width, prefer that
negative_x_display=$(echo "$displays" | jq -r 'map(select(.frame.x < 0 and .frame.w < 2000)) | .[0].index // empty')
if [[ -n "$negative_x_display" && "$negative_x_display" != "null" ]]; then
    builtin_display_id="$negative_x_display"
    echo "Found likely built-in display with negative x coordinate: $builtin_display_id"
fi

echo "Detected built-in display: $builtin_display_id (width: ${smallest_width}px)"

# Loop through each display
echo "$displays" | jq -c '.[]' | while read -r display; do
    display_id=$(echo "$display" | jq -r '.index')
    display_width=$(echo "$display" | jq -r '.frame.w')
    spaces=$(echo "$display" | jq -r '.spaces[]')

    # Determine padding based on display role
    if [[ "$display_id" == "$builtin_display_id" ]]; then
        # Built-in MacBook display - use minimal padding due to notch
        padding=$BUILTIN_TOP_PADDING
        echo "Setting built-in display $display_id (${display_width}px) to top padding: $padding"
    elif [[ "$display_id" == "$main_display_id" ]]; then
        # Main/primary external display - external_bar "main:50:0" already reserves sketchybar space
        padding=$MAIN_EXTERNAL_TOP_PADDING
        echo "Setting main external display $display_id (${display_width}px) to top padding: $padding"
    else
        # Other external display - use larger padding for sketchybar
        padding=$EXTERNAL_TOP_PADDING
        echo "Setting external display $display_id (${display_width}px) to top padding: $padding"
    fi
    
    # Apply padding to all spaces on this display
    for space in $spaces; do
        echo "  Applying padding $padding to space $space"
        yabai -m config --space "$space" top_padding "$padding"
    done
done

echo "Padding adjustment complete."
