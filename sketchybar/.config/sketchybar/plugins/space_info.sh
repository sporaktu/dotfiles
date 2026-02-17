#!/usr/bin/env bash

source "$HOME/.config/sketchybar/variables.sh"

# Get the display number from the widget name (e.g., "space_info_1" -> display 1)
DISPLAY_ID="${NAME##*_}"

# Get the focused/visible workspace for this monitor
FOCUSED_WORKSPACE=$(aerospace list-workspaces --monitor "$DISPLAY_ID" --visible 2>/dev/null | head -1)

# Get all workspaces assigned to this monitor
ALL_WORKSPACES=$(aerospace list-workspaces --monitor "$DISPLAY_ID" 2>/dev/null)

if [[ -z "$ALL_WORKSPACES" ]]; then
    sketchybar --set "$NAME" label="—"
    exit 0
fi

# Build the label showing all workspaces with active one highlighted
# Format: "1  2  [3]  4" where [3] is the active workspace
LABEL=""
while IFS= read -r ws; do
    if [[ -n "$ws" ]]; then
        if [[ "$ws" == "$FOCUSED_WORKSPACE" ]]; then
            # Active workspace - highlighted with brackets
            LABEL+="[$ws] "
        else
            # Inactive workspace
            LABEL+="$ws  "
        fi
    fi
done <<< "$ALL_WORKSPACES"

# Trim trailing whitespace
LABEL="${LABEL% }"

sketchybar --set "$NAME" label="$LABEL"
