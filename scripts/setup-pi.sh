#!/usr/bin/env bash
# Link this repo's Pi config into ~/.pi and enable the dotfiles-sync extension.
# Safe to re-run. Existing machines: `git -C ~/dotfiles pull && ~/dotfiles/scripts/setup-pi.sh`
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for tool in git stow jq; do
  command -v "$tool" >/dev/null || {
    echo "setup-pi: $tool is required (brew/apt install $tool)" >&2
    exit 1
  }
done

# Create ~/.pi/agent first so stow links files inside it, never the whole dir (it holds auth and sessions).
mkdir -p "$HOME/.pi/agent"

# Files Pi created before this machine used the repo would block stow; keep them as *.pre-dotfiles.
for rel in .pi/acp.json .pi/agent/settings.json .pi/agent/vision.json; do
  target="$HOME/$rel"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mv "$target" "$target.pre-dotfiles"
    echo "setup-pi: moved existing ~/$rel to ~/$rel.pre-dotfiles (repo version now in use)"
  fi
done

stow --dir="$DOTFILES_DIR" --target="$HOME" --restow pi

# Commit Pi settings without per-machine version fields (see .gitattributes).
git -C "$DOTFILES_DIR" config filter.pi-settings.clean "jq --indent 2 'del(.lastChangelogVersion, .extensionChangelogVersions)'"
git -C "$DOTFILES_DIR" config filter.pi-settings.smudge cat

echo "setup-pi: done. Restart Pi to load dotfiles-sync (it pulls on start, commits and pushes pi/ on quit)."
