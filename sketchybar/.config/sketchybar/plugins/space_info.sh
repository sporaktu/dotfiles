#!/usr/bin/env bash

source "$HOME/.config/sketchybar/variables.sh"

# Get the display number from the widget name (e.g., "space_info_1" -> display 1)
DISPLAY_ID="${NAME##*_}"

# Get all spaces for this display with their indices
SPACES_DATA=$(yabai -m query --spaces --display "$DISPLAY_ID" | jq -r '.[] | .index')

if [[ -z "$SPACES_DATA" ]]; then
    sketchybar --set "$NAME" label="1/1"
    exit 0
fi

# Convert to array and get total count
SPACES_ARRAY=($SPACES_DATA)
TOTAL_SPACES=${#SPACES_ARRAY[@]}

# Get the currently focused space globally
CURRENT_FOCUSED_SPACE=$(yabai -m query --spaces | jq -r '.[] | select(."has-focus" == true) | .index')

# Find the position of the current focused space within this display's spaces
CURRENT_POSITION=0
for i in "${!SPACES_ARRAY[@]}"; do
    if [[ "${SPACES_ARRAY[$i]}" == "$CURRENT_FOCUSED_SPACE" ]]; then
        CURRENT_POSITION=$((i + 1))  # 1-based indexing
        break
    fi
done

# If current focused space is not on this display, show first space
if [[ "$CURRENT_POSITION" == "0" ]]; then
    CURRENT_POSITION="1"
fi

# Update the widget
sketchybar --set "$NAME" label="$CURRENT_POSITION/$TOTAL_SPACES"