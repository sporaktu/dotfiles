#!/usr/bin/env bash

# Debug script to see what yabai reports about displays
echo "=== YABAI DISPLAY DEBUG ==="
echo "All displays:"
yabai -m query --displays | jq '.[] | {index, frame: .frame, "has-focus": ."has-focus", spaces}'

echo ""
echo "Display widths:"
yabai -m query --displays | jq -r '.[] | "Display \(.index): \(.frame.w)px wide"'

echo ""
echo "Current spaces and their padding:"
yabai -m query --spaces | jq -r '.[] | "Space \(.index) (display \(.display)): top_padding=\(."top-padding")"'
