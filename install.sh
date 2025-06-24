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

install_mac() {
  xcode-select --install 2>/dev/null || true
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.profile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  brew install git fish starship tmux neovim stow ripgrep
  brew install --cask kitty ghostty
  brew install --cask font-meslo-lg-nerd-font font-caskaydia-cove-nerd-font
}

install_linux() {
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y git curl fish starship tmux neovim stow ripgrep kitty unzip fontconfig
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

stow --target="$HOME/.config" fish kitty nvim tmux || true

echo "Installation complete. Log out and back in for shell changes to take effect."
