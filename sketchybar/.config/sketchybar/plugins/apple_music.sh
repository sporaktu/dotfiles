#!/usr/bin/env bash

# Check if Music is running (telling Music anything launches it)
if ! pgrep -x "Music" > /dev/null; then
	sketchybar --set "$NAME" drawing=off
	exit 0
fi

# Direct AppleScript query for Apple Music
if osascript -e 'tell application "Music" to get player state' 2>/dev/null | grep -q "playing"; then
	TRACK=$(osascript -e 'tell application "Music" to get name of current track' 2>/dev/null)
	ARTIST=$(osascript -e 'tell application "Music" to get artist of current track' 2>/dev/null)
	
	if [[ -n "$TRACK" && -n "$ARTIST" ]]; then
		MEDIA="$TRACK - $ARTIST"
		sketchybar --set "$NAME" label="$MEDIA" drawing=on
	else
		sketchybar --set "$NAME" drawing=off
	fi
else
	sketchybar --set "$NAME" drawing=off
fi