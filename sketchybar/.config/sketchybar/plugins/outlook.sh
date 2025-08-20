#!/usr/bin/env bash

# Check if Microsoft Outlook is running
if ! pgrep -x "Microsoft Outlook" > /dev/null; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

# Try multiple methods to get unread count
UNREAD_COUNT="0"

# Method 1: Try AppleScript with different syntax
UNREAD_COUNT=$(osascript << 'EOF' 2>/dev/null || echo "0"
try
    tell application "Microsoft Outlook"
        set unreadCount to 0
        try
            # Try getting from default inbox
            set unreadCount to unread count of inbox
        on error
            try
                # Try getting from first account's inbox
                set firstAccount to item 1 of (get every account)
                set unreadCount to unread count of inbox of firstAccount
            end try
        end try
        return unreadCount as string
    end tell
on error
    return "0"
end try
EOF
)

# Method 2: Try to get from dock badge if AppleScript fails
if [[ "$UNREAD_COUNT" == "0" ]]; then
    DOCK_COUNT=$(osascript << 'EOF' 2>/dev/null || echo "0"
try
    tell application "System Events"
        tell application process "Dock"
            try
                set outlookTile to (first UI element of list 1 whose name contains "Microsoft Outlook")
                set badgeText to value of attribute "AXStatusLabel" of outlookTile
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
    
    if [[ "$DOCK_COUNT" != "0" ]]; then
        UNREAD_COUNT="$DOCK_COUNT"
    fi
fi

# Clean up the count
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