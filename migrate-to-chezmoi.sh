
#!/usr/bin/env bash

# Update this if your dotfiles are somewhere else
DOTFILES_DIR=~/dotfiles

# Fail fast
set -euo pipefail

# Check if chezmoi is installed
if ! command -v chezmoi &> /dev/null; then
  echo "chezmoi not found. Install it first." >&2
  exit 1
fi

echo "Starting dotfile migration from $DOTFILES_DIR..."

# Traverse all files under dotfiles dir
find "$DOTFILES_DIR" -type f | while read -r src_file; do
  # Get relative path from dotfiles dir
  rel_path="${src_file#$DOTFILES_DIR/}"

  # Assume it maps to $HOME, e.g. fish/config.fish → ~/.config/fish/config.fish
  case "$rel_path" in
    # If it's under fish/, ghostty/, etc
    fish/*)
      target="$HOME/.config/$rel_path"
      ;;
    ghostty/.config/*)
      target="$HOME/${rel_path#ghostty/}"
      ;;
    hyprland/*|hyprpaper/*|kitty/*|superfile/*|tmux/*|waybar/*|wofi/*|wpaperd/*)
      target="$HOME/.config/$rel_path"
      ;;
    *.sh)
      target="$HOME/${rel_path}"  # script file in home
      ;;
    *)
      echo "Skipping unknown mapping: $rel_path"
      continue
      ;;
  esac

  if [ -f "$target" ]; then
    echo "Adding $target to chezmoi..."
    chezmoi add "$target"
  else
    echo "Target file not found: $target (from $rel_path)" >&2
  fi
done

echo "Done. You can now run 'chezmoi apply' to deploy them."
