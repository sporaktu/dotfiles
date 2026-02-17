#!/bin/bash

source "$HOME/.config/sketchybar/variables.sh"

# Apps to exclude from the dock (system apps, menu bar apps, etc.)
EXCLUDED_APPS="Finder|Notification Center|Control Center|Spotlight|loginwindow|AnyBar|bartender|System Preferences|System Settings|Keychain Access|universalAccessAuthWarn"

# Get currently running GUI applications
RUNNING_APPS=$(osascript -e '
tell application "System Events"
    set appList to name of every process whose background only is false
    set output to ""
    repeat with appName in appList
        set output to output & appName & linefeed
    end repeat
    return output
end tell
' 2>/dev/null | grep -vE "^$|$EXCLUDED_APPS" | sort -u)

# Get the currently focused app
FOCUSED_APP=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)

# Get existing app items from sketchybar
EXISTING_ITEMS=$(sketchybar --query bar | grep -o '"app\.dock\.[^"]*"' | tr -d '"' | sort -u)

# Use a temp file to track seen items
SEEN_FILE=$(mktemp)
trap "rm -f $SEEN_FILE" EXIT

# Create/update items for each running app
while IFS= read -r app; do
    [ -z "$app" ] && continue

    # Create a safe item name (replace spaces and special chars)
    ITEM_NAME="app.dock.$(echo "$app" | tr ' ' '_' | tr -cd '[:alnum:]_')"
    echo "$ITEM_NAME" >> "$SEEN_FILE"

    # Check if this app is focused
    if [ "$app" = "$FOCUSED_APP" ]; then
        BORDER_WIDTH=2
        BG_DRAWING="on"
    else
        BORDER_WIDTH=0
        BG_DRAWING="off"
    fi

    # Check if item already exists
    if echo "$EXISTING_ITEMS" | grep -q "^${ITEM_NAME}$"; then
        # Update existing item
        sketchybar --set "$ITEM_NAME" \
            background.border_width="$BORDER_WIDTH" \
            background.drawing="$BG_DRAWING"
    else
        # Create new item with app icon
        sketchybar --add item "$ITEM_NAME" left \
            --set "$ITEM_NAME" \
            icon.drawing=off \
            label.drawing=off \
            background.image="app.$app" \
            background.image.scale=0.7 \
            background.image.padding_left=3 \
            background.image.padding_right=3 \
            background.color="$BAR_COLOR" \
            background.height=26 \
            background.corner_radius=8 \
            background.border_color="$BLUE" \
            background.border_width="$BORDER_WIDTH" \
            background.drawing="$BG_DRAWING" \
            background.padding_left=1 \
            background.padding_right=1 \
            click_script="open -a '$app'" \
            --move "$ITEM_NAME" after apps_spacer
    fi
done <<< "$RUNNING_APPS"

# Remove items for apps that are no longer running
for item in $EXISTING_ITEMS; do
    if ! grep -q "^${item}$" "$SEEN_FILE" 2>/dev/null; then
        sketchybar --remove "$item" 2>/dev/null
    fi
done
