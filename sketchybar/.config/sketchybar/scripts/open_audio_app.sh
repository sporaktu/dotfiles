#!/usr/bin/env bash

# Try to find which app is currently playing audio
PLAYING_APP=$(osascript << 'EOF'
try
    -- Check Apple Music first
    tell application "Music"
        if player state is playing then
            return "Music"
        end if
    end tell
on error
end try

try
    -- Check Spotify
    if application "Spotify" is running then
        tell application "Spotify"
            if player state is playing then
                return "Spotify"
            end if
        end tell
    end if
on error
end try

try
    -- Check for other common audio apps that might be playing
    set audioApps to {"VLC", "QuickTime Player", "IINA", "Plex", "Netflix", "YouTube", "Safari", "Google Chrome", "Firefox"}
    
    repeat with appName in audioApps
        try
            if application appName is running then
                -- For browsers, we can't easily detect if they're playing audio
                -- but we can return them as a fallback
                if appName is in {"Safari", "Google Chrome", "Firefox"} then
                    set browserApp to appName
                else
                    return appName
                end if
            end if
        on error
        end try
    end repeat
    
    -- If no specific audio app found but browser is running, return browser
    if browserApp is not missing value then
        return browserApp
    end if
on error
end try

-- Fallback: return empty if no audio app detected
return ""
EOF
)

# Open the detected app or fallback to Control Center
if [[ -n "$PLAYING_APP" && "$PLAYING_APP" != "" ]]; then
    open -a "$PLAYING_APP"
else
    # Fallback to Control Center if no audio app detected
    open -b com.apple.controlcenter
fi