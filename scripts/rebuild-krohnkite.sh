#!/usr/bin/env bash
# Rebuilds kwin-scripts-krohnkite-git from the AUR with a local patch applied
# on top, and installs it.
#
# Why this exists: Krohnkite has a race where fast-starting clients (notably
# kitty) can get added before KWin reports their final geometry, so the
# initial tile placement misfires and the window is left floating/untiled.
# Upstream (esjeon/krohnkite#241) has an unmerged fix for this; it isn't in
# the anametologin/Krohnkite fork this AUR package builds from. The patch
# here backports the same "defer tiling until first stable geometry event"
# approach onto that fork.
#
# `yay -Syu` re-clones/pulls the upstream source on every run and would wipe
# any changes made directly in the AUR cache dir, so the fix is kept here as
# a patch and reapplied by this script instead of edited in place.
#
# Usage: ~/dotfiles/scripts/rebuild-krohnkite.sh

set -euo pipefail

PKG_DIR="$HOME/.cache/yay/kwin-scripts-krohnkite-git"
SRC_DIR="$PKG_DIR/src/codeberg.krohnkite"
PATCH="$HOME/dotfiles/patches/kwin-scripts-krohnkite-git/defer-tiling-until-stable-geometry.patch"

if [[ ! -d "$PKG_DIR" ]]; then
  echo "error: $PKG_DIR not found — run 'yay -S kwin-scripts-krohnkite-git' first" >&2
  exit 1
fi

echo "==> Fetching latest krohnkite source"
(cd "$PKG_DIR" && makepkg -o)

echo "==> Applying patch: $(basename "$PATCH")"
if ! git -C "$SRC_DIR" apply --check "$PATCH" 2>/dev/null; then
  echo "error: patch no longer applies cleanly — upstream source has likely changed." >&2
  echo "       Re-diff the fix by hand against $SRC_DIR and update:" >&2
  echo "       $PATCH" >&2
  exit 1
fi
git -C "$SRC_DIR" apply "$PATCH"

echo "==> Building (patched)"
(cd "$PKG_DIR" && makepkg -ef --noconfirm)

PKG_FILE=$(cd "$PKG_DIR" && ls -t kwin-scripts-krohnkite-git-*-any.pkg.tar.zst | head -1)

echo "==> Built: $PKG_DIR/$PKG_FILE"
echo "==> Installing (will prompt for sudo password)"
sudo pacman -U --noconfirm "$PKG_DIR/$PKG_FILE"

echo "==> Done. Restart the Krohnkite KWin script to load it:"
echo "    System Settings -> Window Management -> KWin Scripts -> toggle Krohnkite off/on"
