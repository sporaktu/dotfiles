#!/usr/bin/env bash

# Check if Microsoft Teams is running (new Teams' process is MSTeams)
if ! pgrep -x "MSTeams|Microsoft Teams" > /dev/null; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

# Get unread notifications count from Teams
# This uses AppleScript to check the Teams dock icon badge
UNREAD_COUNT=$(osascript << 'EOF'
try
    tell application "System Events"
        tell application process "Dock"
            try
                set teamsTile to (first UI element of list 1 whose name contains "Microsoft Teams")
                set badgeText to value of attribute "AXStatusLabel" of teamsTile
                if badgeText is not missing value and badgeText is not "" then
                    return badgeText as string
                else
                    return "0"
                end if
            on error
                return "0"
            end try
        end tell
    end tell
on error
    return "0"
end try
EOF
)

# Clean up the count (remove any non-numeric characters)
CLEAN_COUNT=$(echo "$UNREAD_COUNT" | grep -o '[0-9]\+' | head -1)
if [[ -z "$CLEAN_COUNT" ]]; then
    CLEAN_COUNT="0"
fi

# Update the widget
if [[ "$CLEAN_COUNT" -gt 0 ]]; then
    sketchybar --set "$NAME" label="$CLEAN_COUNT" drawing=on
else
    sketchybar --set "$NAME" drawing=off
fi