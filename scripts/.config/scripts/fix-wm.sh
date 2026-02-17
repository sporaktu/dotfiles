#!/usr/bin/env bash

# Fix window manager and desktop environment

echo "Restarting yabai..."
yabai --restart-service

echo "Restarting Finder..."
killall Finder

echo "Restarting Dock..."
killall Dock

echo "Reloading sketchybar..."
sketchybar --reload

echo "Done! Window manager fixed."
