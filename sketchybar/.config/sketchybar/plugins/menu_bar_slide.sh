#!/usr/bin/env bash

# Background daemon that detects cursor near top of screen
# and slides sketchybar down to make room for the auto-hidden menu bar.

MENU_BAR_HEIGHT=24
RESTING_OFFSET=5
SLIDE_OFFSET=$((MENU_BAR_HEIGHT + RESTING_OFFSET + 6))
TRIGGER_ZONE=10  # pixels from top to trigger slide
STATE="up"

while true; do
  # Get cursor position using coreutils - macOS coordinates (0,0 is bottom-left)
  MOUSE_INFO=$(/usr/bin/osascript -l JavaScript -e "
    ObjC.import('CoreGraphics');
    var e = $.CGEventCreate(null);
    var p = $.CGEventGetLocation(e);
    JSON.stringify({x: p.x, y: p.y});
  " 2>/dev/null)

  # CGEvent coordinates are from top-left, so y near 0 = top of screen
  CURSOR_Y=$(echo "$MOUSE_INFO" | /usr/bin/python3 -c "import sys,json; print(int(json.load(sys.stdin)['y']))" 2>/dev/null)

  if [ -n "$CURSOR_Y" ]; then
    if [ "$CURSOR_Y" -le "$TRIGGER_ZONE" ] && [ "$STATE" = "up" ]; then
      sketchybar --animate sin 10 --bar y_offset="$SLIDE_OFFSET"
      STATE="down"
    elif [ "$CURSOR_Y" -gt 50 ] && [ "$STATE" = "down" ]; then
      sketchybar --animate sin 10 --bar y_offset="$RESTING_OFFSET"
      STATE="up"
    fi
  fi

  sleep 0.01
done
