#!/usr/bin/env bash

# Check if Microsoft Outlook is running
if ! pgrep -x "Microsoft Outlook" > /dev/null; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

# Get today's date in the format Outlook expects
TODAY=$(date +"%Y-%m-%d")

# Try a simpler approach to get next meeting
MEETING_INFO=$(osascript << 'EOF'
try
    tell application "Microsoft Outlook"
        -- Get current time
        set currentTime to current date
        set todayStart to current date
        set time of todayStart to 0
        set todayEnd to todayStart + (24 * 60 * 60)
        
        -- Try to get events from default calendar
        try
            set todayEvents to (every calendar event whose start time ≥ currentTime and start time < todayEnd)
            
            if (count of todayEvents) > 0 then
                -- Get the first upcoming event
                set nextEvent to item 1 of todayEvents
                set eventTime to start time of nextEvent
                set eventTitle to subject of nextEvent
                
                -- Format time
                set timeStr to time string of eventTime
                set timeStr to (characters 1 through -4 of timeStr) as string
                
                return timeStr & "|" & eventTitle
            end if
        on error
            -- If that fails, try a different approach
            set allEvents to (every calendar event)
            repeat with evt in allEvents
                if start time of evt > currentTime and start time of evt < todayEnd then
                    set eventTime to start time of evt
                    set eventTitle to subject of evt
                    set timeStr to time string of eventTime
                    set timeStr to (characters 1 through -4 of timeStr) as string
                    return timeStr & "|" & eventTitle
                end if
            end repeat
        end try
    end tell
    return ""
on error theError
    return "Error: " & theError
end try
EOF
)

# Debug: log what we got
echo "Meeting info: '$MEETING_INFO'" >> /tmp/meeting_debug.log
echo "Today: $(date)" >> /tmp/meeting_debug.log

# Temporary manual override for testing - replace with your actual meeting info
# Format: "TIME|MEETING_TITLE" (remove this section once AppleScript works)
# MEETING_INFO="4:00 PM|Team Standup"

# Parse the meeting info
if [[ -n "$MEETING_INFO" && "$MEETING_INFO" != "" && "$MEETING_INFO" != "Error:"* ]]; then
    TIME_PART=$(echo "$MEETING_INFO" | cut -d'|' -f1)
    TITLE_PART=$(echo "$MEETING_INFO" | cut -d'|' -f2-)
    
    # Truncate title if too long
    if [[ ${#TITLE_PART} -gt 25 ]]; then
        TITLE_PART="${TITLE_PART:0:22}..."
    fi
    
    # Update widget with meeting info
    sketchybar --set "$NAME" label="$TIME_PART $TITLE_PART" drawing=on
    echo "Widget updated with: $TIME_PART $TITLE_PART" >> /tmp/meeting_debug.log
else
    # No upcoming meetings today
    sketchybar --set "$NAME" drawing=off
    echo "No meeting found - widget hidden" >> /tmp/meeting_debug.log
fi