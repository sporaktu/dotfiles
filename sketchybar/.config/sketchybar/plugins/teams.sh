#!/usr/bin/env bash

# Check if Microsoft Teams is running
if ! pgrep -x "Microsoft Teams" > /dev/null; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

# Get unread notifications count from Teams
# This uses AppleScript to check the Teams dock icon badge
UNREAD_COUNT=$(osascript << 'EOF'
try
    tell application "System Events"
        tell process "Microsoft Teams"
            try
                set badge_value to value of attribute "AXStatusLabel" of UI element 1 of list 1 of application process "Dock"
                if badge_value is not missing value and badge_value is not "" then
                    return badge_value as string
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