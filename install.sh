#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [mac|linux]" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
fi

OS="$1"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_mac() {
  xcode-select --install 2>/dev/null || true
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # shellcheck disable=SC2016 # written literally; ~/.profile expands it
  grep -qF 'brew shellenv' "$HOME/.profile" 2>/dev/null ||
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.profile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  brew install git fish starship tmux neovim stow ripgrep jq fzf sesh yazi lazydocker
  brew install asmvik/formulae/yabai asmvik/formulae/skhd FelixKratz/formulae/sketchybar
  brew install --cask kitty ghostty
  brew install --cask font-meslo-lg-nerd-font font-caskaydia-cove-nerd-font
}

install_linux() {
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y git curl fish starship tmux neovim stow ripgrep jq kitty unzip fontconfig
  mkdir -p "$HOME/.local/share/fonts"
  cd "$HOME/.local/share/fonts"
  curl -L -o Meslo.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip
  curl -L -o CaskaydiaCove.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CaskaydiaCove.zip
  unzip Meslo.zip && unzip CaskaydiaCove.zip
  fc-cache -fv
}

case "$OS" in
  mac)
    install_mac
    ;;
  linux)
    install_linux
    ;;
  *)
    usage
    ;;
esac

# Stow configs that use ~/.config (APP/.config/APP/ structure)
stow --dir="$DOTFILES_DIR" --target="$HOME" fish kitty nvim tmux ghostty superfile
if [[ "$OS" == mac ]]; then
  stow --dir="$DOTFILES_DIR" --target="$HOME" sketchybar yabai skhd
fi

# Stow configs that use ~/  (APP/.APP/ structure)
stow --dir="$DOTFILES_DIR" --target="$HOME" claude

echo "Installation complete. Log out and back in for shell changes to take effect."
