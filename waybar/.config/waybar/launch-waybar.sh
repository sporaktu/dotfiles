#!/bin/bash

CONFIG_FILES="$HOME/dotfiles/waybar/.config/waybar $HOME/dotfiles/waybar/.config/waybar/style.css"

trap "killall waybar" EXIT

while true; do
    waybar &
    inotifywait -e create,modify $CONFIG_FILES
    killall waybar
done
