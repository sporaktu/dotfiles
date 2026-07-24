#!/usr/bin/env bash
#
# Plasma 6 + Krohnkite install — REAL HARDWARE (not the snapshot VM).
# Validated as a rehearsal on 2026-07-24. Run this on a normal boot of the
# physical machine, NOT inside the QEMU snapshot=on VM (writes there vanish).
#
# Differences from the VM rehearsal, on purpose:
#   * plain `pacman -Syu` — NO --ignore. On real HW you reboot into the new
#     kernel, so nothing is held back. (The VM held the kernel only because it
#     can't reboot.)
#   * NO software-rendering shim. Your NVIDIA GPU renders Plasma natively;
#     forcing llvmpipe would cripple it. If ~/.config/plasma-workspace/env/
#     10-vm-software-rendering.sh somehow exists on real HW, delete it.
#   * Super/Meta key works here, so Krohnkite's default Meta+* tiling binds are
#     usable directly — no D-Bus shortcut workaround needed.
#
set -euo pipefail

# ── 0. Safety rails ─────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user (it calls sudo where needed), not as root." >&2
  exit 1
fi
echo ">>> Sanity: this should be the REAL machine. Ctrl-C now if you're in the VM."
sleep 4

# ── 1. Refresh keyring FIRST ────────────────────────────────────────────────
# A stale archlinux-keyring can't verify recently-signed packages and aborts
# the upgrade early (this is exactly what bit the rehearsal). Do it alone first.
sudo pacman -Sy --needed --noconfirm archlinux-keyring

# ── 2. Complete a full system upgrade ───────────────────────────────────────
# Installing Plasma on top of a half-upgraded system is what produced the
# Qt 6.10-vs-6.11 symbol breakage in the rehearsal. Get fully current first.
sudo pacman -Syu

# ── 3. Install Plasma ───────────────────────────────────────────────────────
# plasma-desktop is the core (plasmashell, kwin, krunner, systemsettings).
# The rest are the companions that make it a genuinely usable desktop.
# You already have: sddm, kitty, dolphin, pipewire, papirus icons.
sudo pacman -S --needed \
    plasma-desktop \
    plasma-pa \
    plasma-nm \
    powerdevil \
    bluedevil \
    kscreen \
    kde-gtk-config \
    xdg-desktop-portal-kde \
    kwallet-pam
# For the FULL official spread instead (Discover, PIM, wallpapers, etc.),
# swap the block above for:  sudo pacman -S --needed plasma-meta

# ── 4. Krohnkite (KWin tiling script) ───────────────────────────────────────
# The AUR packages track the Plasma-6 fork at codeberg.org/anametologin/krohnkite.
# Two known breakages as of the rehearsal:
#   * kwin-scripts-krohnkite      → stale tarball sha256 (Codeberg re-rolls archives)
#   * kwin-scripts-krohnkite-git  → TypeScript build fails: `outFile` deprecation
#                                    (TS5101) + missing `rootDir` (TS5011)
# Try the AUR (-git) first — upstream may have fixed it by now. If the build
# fails, fall back to a patched build from source that installs the .kwinscript.
if ! yay -S --needed --noconfirm kwin-scripts-krohnkite-git; then
  echo ">>> AUR build failed; patching tsconfig and building from source."
  tmp="$(mktemp -d)"
  git clone --depth=1 https://codeberg.org/anametologin/krohnkite.git "$tmp/krohnkite"
  cd "$tmp/krohnkite"
  # Silence the deprecation-as-error and set the required rootDir.
  sed -i 's/"outFile": *"krohnkite.js",/"outFile": "krohnkite.js", "rootDir": ".", "ignoreDeprecations": "6.0",/' tsconfig.json
  # Build the .kwinscript (repo Makefile handles npm deps + kpackagetool pack).
  if command -v make >/dev/null && grep -q kwinscript Makefile 2>/dev/null; then
    make
    kpackagetool6 --type KWin/Script --install krohnkite.kwinscript \
      || kpackagetool6 --type KWin/Script --upgrade krohnkite.kwinscript
  else
    # Minimal manual build if the Makefile target isn't present.
    npm install
    npx tsc
    kpackagetool6 --type KWin/Script --install . \
      || kpackagetool6 --type KWin/Script --upgrade .
  fi
  cd - >/dev/null
  rm -rf "$tmp"
fi

# ── 5. Enable Krohnkite in KWin ─────────────────────────────────────────────
# Runs as your user (writes ~/.config/kwinrc). Takes effect at next login;
# if you're already in a KWin session, the reconfigure call applies it live.
kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled true
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true

cat <<'DONE'

============================================================
Done. Next:
  1. Reboot (loads the new kernel + rebuilt NVIDIA module).
  2. At SDDM, pick the session picker → "Plasma (Wayland)".
  3. Log in. Krohnkite tiles automatically; default binds are Meta+* .
     Configure them in: System Settings → Window Management → KWin Scripts,
     and System Settings → Shortcuts (search "Krohnkite").

Your Hyprland session is untouched and still selectable at SDDM.
============================================================
DONE
