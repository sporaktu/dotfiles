#!/usr/bin/env bash
#
# Migrate GRUB -> systemd-boot + signed Unified Kernel Images (UKIs), then enable
# Secure Boot via sbctl. REAL HARDWARE ONLY (the QEMU snapshot VM has no Secure
# Boot firmware and throwaway NVRAM, so the firmware-boot half can't be tested there).
#
# Grounded in this machine's verified config (read 2026-07-24):
#   ESP        : /boot  (nvme0n1p1, vfat)
#   root       : btrfs UUID 9e46b78d-74c4-4eeb-a616-416e44ba3b88, subvol=@
#   kernels    : linux, linux-zen        initramfs: mkinitcpio 41
#   microcode  : amd-ucode (auto-bundled via the `microcode` hook)
#   GPU        : nvidia-open-dkms  (Arch doesn't force module sigs under SB, so the
#                module still loads unsigned — only bootloader+UKIs get signed)
#
# RUN PHASE BY PHASE, rebooting between phases. GRUB stays as a fallback until
# Phase 3, so a failed phase never leaves you unbootable.
#
#   sudo bootloader-migrate.sh phase1   # install systemd-boot + build UKIs (GRUB kept)
#   <reboot, pick "Linux Boot Manager", confirm Arch boots>
#   sudo bootloader-migrate.sh phase2   # sbctl keys + sign  (firmware in SETUP MODE)
#   <reboot into BIOS, set Secure Boot = Enabled, confirm Arch + Windows boot>
#   sudo bootloader-migrate.sh phase3   # remove GRUB (only after the above works)
#   sudo bootloader-migrate.sh status   # show current state anytime
#
set -euo pipefail

ESP=/boot
ROOT_UUID=9e46b78d-74c4-4eeb-a616-416e44ba3b88
# Kernel cmdline for the UKI. NOTE: intentionally omits `systemd.mask=mnt-games.mount`
# (that was a VM-only hack; on real hardware the games drive is attached).
CMDLINE="root=UUID=${ROOT_UUID} rw rootflags=subvol=@ rootfstype=btrfs zswap.enabled=0 loglevel=3 quiet nvidia-drm.modeset=1"
KERNELS=(linux linux-zen)

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "run with sudo (needs root for ESP/NVRAM): sudo $0 $*"
[[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode"
findmnt -no FSTYPE "$ESP" | grep -q vfat || die "$ESP is not a mounted vfat ESP"

# ── PHASE 1 ── systemd-boot + UKIs, installed alongside GRUB ──────────────────
phase1(){
  echo ">>> [1/4] install systemd-boot to $ESP (adds NVRAM entry 'Linux Boot Manager')"
  # This also writes $ESP/EFI/BOOT/BOOTX64.EFI (removable fallback), replacing
  # GRUB's fallback — but GRUB keeps its own NVRAM entry, so it still boots.
  bootctl --esp-path="$ESP" install

  echo ">>> [2/4] write UKI cmdline -> /etc/kernel/cmdline"
  install -Dm644 /dev/stdin /etc/kernel/cmdline <<<"$CMDLINE"

  echo ">>> [3/4] point mkinitcpio presets at UKIs (keeping standalone .img as fallback)"
  mkdir -p "$ESP/EFI/Linux"
  for k in "${KERNELS[@]}"; do
    p="/etc/mkinitcpio.d/$k.preset"
    [[ -f $p ]] || die "missing preset $p"
    cp -n "$p" "$p.pre-uki.bak"
    grep -q '^default_uki=' "$p" || \
      echo "default_uki=\"$ESP/EFI/Linux/arch-$k.efi\"" >> "$p"
  done

  echo ">>> [4/4] build UKIs (bundles kernel+initramfs+cmdline+amd-ucode, all signed later)"
  mkinitcpio -P

  install -Dm644 /dev/stdin "$ESP/loader/loader.conf" <<'EOF'
default  arch-linux-zen.efi
timeout  4
console-mode keep
EOF

  echo; bootctl --esp-path="$ESP" list || true
  cat <<'MSG'

>>> PHASE 1 COMPLETE. GRUB is untouched as a fallback.
    Reboot. In the UEFI boot menu choose "Linux Boot Manager" (systemd-boot),
    then pick arch-linux-zen. Confirm you reach a normal desktop.
    When it works:  sudo bootloader-migrate.sh phase2
MSG
}

# ── PHASE 2 ── Secure Boot: own keys + sign (firmware must be in SETUP MODE) ───
phase2(){
  pacman -S --needed --noconfirm sbctl
  echo ">>> sbctl status:"; sbctl status || true
  sbctl status 2>/dev/null | grep -qi 'Setup Mode.*Enabled' || die \
    "Firmware is NOT in Setup Mode. Reboot into BIOS, clear/erase the Secure Boot
     keys (a.k.a. enter Setup Mode), leave Secure Boot enabled, boot Arch, re-run phase2."

  sbctl create-keys
  # --microsoft keeps Microsoft's keys: REQUIRED so Windows still boots AND so the
  # NVIDIA GPU's Microsoft-signed UEFI option ROM is still trusted. Do not drop it.
  sbctl enroll-keys --microsoft

  echo ">>> signing the boot chain (-s registers each file for auto re-signing on updates)"
  sbctl sign -s "$ESP/EFI/systemd/systemd-bootx64.efi"
  sbctl sign -s "$ESP/EFI/BOOT/BOOTX64.EFI"
  for k in "${KERNELS[@]}"; do sbctl sign -s "$ESP/EFI/Linux/arch-$k.efi"; done
  echo; sbctl verify
  cat <<'NOTE'

  NOTE: sbctl verify will still list some files as "not signed" — this is FINE:
    * EFI/GRUB/grubx64.efi, grub/*  -> GRUB, the unsigned fallback (removed in phase3)
    * vmlinuz-linux, vmlinuz-linux-zen -> bare kernels; under Secure Boot the signed
      UKIs boot (they embed their own kernel copy), so the standalone vmlinuz are not
      in the boot path and don't need signing.
  Only the 4 signed above (systemd-boot x2 + both UKIs) are the trusted chain.
NOTE

  cat <<'MSG'

>>> PHASE 2 COMPLETE. sbctl's pacman hook now re-signs the UKIs + systemd-boot
    automatically on every kernel/systemd update.
    Reboot into BIOS, set Secure Boot = Enabled (User Mode), save, boot Arch.
    Verify:  sbctl status   -> "Secure Boot: Enabled"
    Confirm Windows still boots too. Then, optionally: sudo bootloader-migrate.sh phase3
MSG
}

# ── PHASE 3 ── remove GRUB (only after systemd-boot + Secure Boot confirmed) ───
phase3(){
  pacman -S --needed --noconfirm efibootmgr
  pacman -Rns --noconfirm grub || true
  rm -rf "$ESP/EFI/GRUB" "$ESP/grub"
  # drop the stale GRUB NVRAM entry, if any
  efibootmgr 2>/dev/null | grep -i 'GRUB' | sed -E 's/^Boot([0-9A-Fa-f]{4}).*/\1/' \
    | while read -r n; do efibootmgr -b "$n" -B >/dev/null 2>&1 || true; done
  echo ">>> GRUB removed. systemd-boot is now your only bootloader."
}

status(){
  echo "== bootctl =="; bootctl --esp-path="$ESP" status 2>&1 | grep -iE 'Secure Boot|Current Boot|systemd-boot|Product' || true
  echo; echo "== boot entries =="; bootctl --esp-path="$ESP" list 2>&1 || true
  echo; echo "== sbctl =="; command -v sbctl >/dev/null && sbctl status 2>&1 || echo "(sbctl not installed yet)"
}

case "${1:-}" in
  phase1) phase1 ;;
  phase2) phase2 ;;
  phase3) phase3 ;;
  status) status ;;
  *) echo "usage: sudo $0 {phase1|phase2|phase3|status}"; exit 2 ;;
esac
