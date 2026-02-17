#!/usr/bin/env bash

COLOR="$BLUE"

# Add event for app changes
sketchybar --add event app_changed

# Spacer before apps
sketchybar --add item apps_spacer left \
    --set apps_spacer \
    width=5 \
    background.drawing=off \
    icon.drawing=off \
    label.drawing=off

# The plugin will dynamically add app items
# Run the plugin initially and subscribe to events
sketchybar --add item open_apps_trigger left \
    --set open_apps_trigger \
    drawing=off \
    update_freq=3 \
    script="$PLUGIN_DIR/open_apps.sh" \
    --subscribe open_apps_trigger front_app_switched space_change
