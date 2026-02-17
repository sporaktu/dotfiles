#!/usr/bin/env bash

# Switch to workspace on the monitor where the mouse cursor is located
WORKSPACE="$1"

# Get which screen the mouse is on (1-indexed)
SCREEN_NUM=$(osascript -e '
use framework "Foundation"
use framework "AppKit"

set mouseLocation to current application'\''s NSEvent'\''s mouseLocation()
set screens to current application'\''s NSScreen'\''s screens()

set screenIndex to 1
repeat with aScreen in screens
    set screenFrame to aScreen'\''s frame()
    set originX to (current application'\''s NSMinX(screenFrame)) as integer
    set screenWidth to (current application'\''s NSWidth(screenFrame)) as integer
    set mouseX to (mouseLocation'\''s x) as integer

    if mouseX >= originX and mouseX < (originX + screenWidth) then
        return screenIndex
    end if
    set screenIndex to screenIndex + 1
end repeat
return 1
' 2>/dev/null)

# Focus the monitor under the mouse, then switch workspace there
aerospace focus-monitor "$SCREEN_NUM" 2>/dev/null
aerospace workspace "$WORKSPACE"
