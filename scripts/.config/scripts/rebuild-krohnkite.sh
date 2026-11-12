#!/usr/bin/env bash
# Rebuilds kwin-scripts-krohnkite-git from the AUR with local patches applied
# on top, and installs it.
#
# Patches, from ~/dotfiles/patches/kwin-scripts-krohnkite-git/:
#
#   fix-timer-pool-after-reload.patch  (always applied)
#     After a script reload (krohnkite-reload.sh, the resume watchdog, or a
#     toggle in System Settings) every Krohnkite timer failed with
#     "Qt.createQmlObject(): Missing parent object" until KWin restarted. The
#     deferred re-commit in enforceSize() never ran, so a tiled window that was
#     pushed off its tile (e.g. Ghostty after a Flameshot overlay) stayed off it.
#     The patch parents timers to the live instance's root item.
#
#   defer-tiling-until-stable-geometry.patch  (only with --with-defer)
#     OPTIONAL / UNVERIFIED. Written for "kitty doesn't tile", which turned out
#     to be the script dying on a destroyed output; a reload fixed that WITHOUT
#     this patch. It is still a genuine upstream bug (esjeon/krohnkite#241), but
#     it has never been confirmed to fix anything on this machine. It was made
#     against 0.9.9.2 and does NOT apply to 0.9.11.0; re-diff before using it.
#
# Stock updates do not need this: the pacman hook
# pacman-hooks/krohnkite-timer-fix.hook applies the timer fix to whatever
# `yay -Syu` installs (krohnkite-timer-hotfix.sh). Use this script for a clean
# build from source, or to try --with-defer.
#
# Why a script and not edits in the cache: `yay -Syu` re-clones/pulls the
# upstream source and would wipe any changes made directly in the AUR cache
# dir, so the fixes are kept here as patches and reapplied by this script.
#
# Usage: rebuild-krohnkite.sh [--with-defer] [--build-only]
#   --build-only  build the package but do not install it (no sudo)

set -euo pipefail

PKG_DIR="$HOME/.cache/yay/kwin-scripts-krohnkite-git"
SRC_DIR="$PKG_DIR/src/codeberg.krohnkite"
PATCH_DIR="$HOME/dotfiles/patches/kwin-scripts-krohnkite-git"
PATCHES=("$PATCH_DIR/fix-timer-pool-after-reload.patch")
INSTALL=1

for arg in "$@"; do
  case "$arg" in
    --with-defer) PATCHES+=("$PATCH_DIR/defer-tiling-until-stable-geometry.patch") ;;
    --build-only) INSTALL=0 ;;
    *) echo "error: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$PKG_DIR" ]]; then
  echo "error: $PKG_DIR not found — run 'yay -S kwin-scripts-krohnkite-git' first" >&2
  exit 1
fi

echo "==> Fetching latest krohnkite source"
(cd "$PKG_DIR" && makepkg -o)

for PATCH in "${PATCHES[@]}"; do
  echo "==> Applying patch: $(basename "$PATCH")"
  if ! git -C "$SRC_DIR" apply --check "$PATCH" 2>/dev/null; then
    echo "error: patch no longer applies cleanly — upstream source has likely changed." >&2
    echo "       Re-diff the fix by hand against $SRC_DIR and update:" >&2
    echo "       $PATCH" >&2
    exit 1
  fi
  git -C "$SRC_DIR" apply "$PATCH"
done

echo "==> Building (patched)"
(cd "$PKG_DIR" && makepkg -ef --noconfirm)

PKG_FILE=$(cd "$PKG_DIR" && ls -t kwin-scripts-krohnkite-git-*-any.pkg.tar.zst | head -1)

echo "==> Built: $PKG_DIR/$PKG_FILE"
if [[ $INSTALL -eq 0 ]]; then
  echo "==> Not installing (--build-only). To install:"
  echo "    sudo pacman -U $PKG_DIR/$PKG_FILE"
  exit 0
fi
echo "==> Installing (will prompt for sudo password)"
sudo pacman -U --noconfirm "$PKG_DIR/$PKG_FILE"

echo "==> Done. Log out and back in to load it. A script reload is not enough"
echo "    the first time: the running copy still has the broken timer pool."
