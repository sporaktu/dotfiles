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
  brew install git fish starship tuios neovim stow ripgrep jq fzf yazi lazydocker
  brew install asmvik/formulae/yabai asmvik/formulae/skhd FelixKratz/formulae/sketchybar
  brew install --cask kitty ghostty
  brew install --cask font-meslo-lg-nerd-font font-caskaydia-cove-nerd-font
}

# tuios has no apt package. Pin a release and verify it before it reaches sudo;
# when bumping the version, take the new hashes from the release's checksums.txt.
install_tuios_linux() {
  local version=0.12.1 arch sha256 tmp
  case "$(uname -m)" in
    x86_64)
      arch=x86_64
      sha256=4f68bac6e05d826b8c59b671b565c61b859dacedcb5d889160ba6d8624589b50
      ;;
    aarch64 | arm64)
      arch=arm64
      sha256=4f1b39c2ec58c057f7bc6298d558f690336031fc564d80ee38d950f1ecbd2753
      ;;
    *)
      echo "No pinned tuios build for $(uname -m)" >&2
      return 1
      ;;
  esac
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/tuios.tar.gz" \
    "https://github.com/Gaurav-Gosain/tuios/releases/download/v$version/tuios_${version}_Linux_$arch.tar.gz"
  echo "$sha256  $tmp/tuios.tar.gz" | sha256sum --check --quiet
  tar -xzf "$tmp/tuios.tar.gz" -C "$tmp"
  sudo install -m 755 "$tmp/tuios" /usr/local/bin/tuios
  rm -rf "$tmp"
}

install_linux() {
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y git curl fish starship neovim stow ripgrep jq kitty unzip fontconfig
  install_tuios_linux
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
stow --dir="$DOTFILES_DIR" --target="$HOME" fish kitty nvim tuios ghostty superfile
if [[ "$OS" == mac ]]; then
  stow --dir="$DOTFILES_DIR" --target="$HOME" sketchybar yabai skhd
fi

# Stow configs that use ~/  (APP/.APP/ structure)
stow --dir="$DOTFILES_DIR" --target="$HOME" claude

echo "Installation complete. Log out and back in for shell changes to take effect."
