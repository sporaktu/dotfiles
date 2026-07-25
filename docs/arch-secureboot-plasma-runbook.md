# Arch: systemd-boot + signed UKIs + Secure Boot + Plasma — Real-Hardware Runbook

**Read this on the physical machine.** It is the step-by-step for switching the
boot chain from GRUB to **systemd-boot + signed Unified Kernel Images (UKIs)**,
turning on **Secure Boot** (so you can dual-boot Windows without disabling SB in
BIOS), and installing **KDE Plasma 6**. Everything below was rehearsed in a
throwaway QEMU snapshot VM booting this exact NVMe; the one thing the VM **could
not** test is Secure Boot enforcement (its firmware has no SB), so that half —
`phase2` — is the only genuinely-first-time step. Take it slow, one phase per
reboot.

Machine facts baked into the scripts (verified 2026-07):
- ESP: `/boot` (`nvme0n1p1`, vfat) · root: btrfs `UUID=9e46b78d-74c4-4eeb-a616-416e44ba3b88`, subvol `@`
- Kernels: `linux`, `linux-zen` (boots zen) · initramfs: mkinitcpio · microcode: `amd-ucode`
- GPU: NVIDIA `nvidia-open-dkms`. Arch does **not** force kernel-module signatures
  under Secure Boot, so the DKMS module still loads unsigned — **only the
  bootloader + UKIs need signing.**
- Windows lives on a **separate disk**; the firmware boot menu picks the OS.

Two scripts do the work (both in `scripts/.config/scripts/`, stow-deployed to
`~/.config/scripts/`):
- `bootloader-migrate.sh` — phased GRUB → systemd-boot + UKI + Secure Boot
- `plasma-install.sh` — Plasma 6 + Krohnkite

---

## 0. Before you touch anything — safety net

1. **Confirm you can get into firmware setup** (the BIOS/UEFI key for this board)
   and that you know how to pick a boot device from the firmware boot menu. This
   is your escape hatch if a phase fails.
2. **Know that GRUB stays installed and bootable until `phase3`.** Every phase up
   to that point is reversible by just selecting the old GRUB entry in the
   firmware boot menu.
3. Make sure the system is **fully up to date and reboots cleanly on its current
   GRUB setup first** — don't stack a migration on top of a half-applied upgrade.
   ```
   sudo pacman -Syu   # then reboot once, confirm normal boot, before starting
   ```
4. Optional but cheap: back up the ESP so you can hand-restore GRUB if needed.
   ```
   sudo cp -a /boot /boot.bak-$(date +%F)
   ```

---

## 1. PHASE 1 — install systemd-boot + build signed-later UKIs (GRUB kept)

```
sudo ~/.config/scripts/bootloader-migrate.sh phase1
```
What it does: installs systemd-boot to the ESP (adds an NVRAM entry "Linux Boot
Manager"), writes the kernel cmdline to `/etc/kernel/cmdline`, points the
mkinitcpio presets at UKIs in `/boot/EFI/Linux/`, runs `mkinitcpio -P` to build
them, and writes `/boot/loader/loader.conf` (default = zen, 4 s timeout). **GRUB
is untouched.**

Then **reboot**. In the firmware boot menu pick **"Linux Boot Manager"**, then
choose `arch-linux-zen`. Confirm you reach a normal desktop.

Verify after boot:
```
bootctl status | head            # Current Boot Loader: systemd-boot
cat /proc/cmdline                # the UKI cmdline (root=UUID=9e46… subvol=@ …)
                                 # NOT BOOT_IMAGE=/vmlinuz-linux-zen  (that's GRUB)
```
If `/proc/cmdline` shows the UKI line, the systemd-boot → UKI → kernel chain
works. **Do not proceed to phase2 until this is true.** If anything's wrong,
reboot and pick GRUB in the firmware menu — you're exactly where you started.

---

## 2. PHASE 2 — Secure Boot: your own keys, keep Microsoft's, sign the chain

This is the only step the VM couldn't rehearse. It needs the firmware in
**Setup Mode** (Secure Boot keys cleared) — that's how `sbctl` is allowed to
enroll its own keys.

1. **Reboot into firmware setup.** Find the Secure Boot section and:
   - **Clear / Erase / Delete all Secure Boot keys** (wording varies:
     "Erase all Secure Boot Settings", "Clear Secure Boot Keys", "Restore
     Factory Keys" is the *wrong* one — you want them **cleared**, i.e. Setup Mode).
   - Leave **Secure Boot = Enabled** (it's inert while in Setup Mode).
   - Save & exit, boot Arch (via Linux Boot Manager).
2. Run phase2:
   ```
   sudo ~/.config/scripts/bootloader-migrate.sh phase2
   ```
   It **guards on Setup Mode** — if the firmware isn't actually in Setup Mode it
   stops and tells you, changing nothing. Otherwise it: installs `sbctl`,
   `sbctl create-keys`, `sbctl enroll-keys --microsoft` (**the `--microsoft` is
   mandatory** — it keeps Microsoft's keys so Windows still boots *and* so the
   NVIDIA GPU's Microsoft-signed UEFI option ROM stays trusted), then signs the
   systemd-boot binaries and both UKIs and runs `sbctl verify`.
   > `sbctl verify` will still list GRUB's `grubx64.efi` and the bare
   > `vmlinuz-linux*` as "not signed" — **that's expected and fine.** Under Secure
   > Boot the signed UKIs boot (they embed their own kernel), so the standalone
   > vmlinuz and GRUB aren't in the trusted path. Only the 4 signed files
   > (systemd-boot ×2 + both UKIs) matter.
3. **Reboot into firmware setup**, confirm **Secure Boot = Enabled** (now in User
   Mode since keys are enrolled), save, boot Arch.

Verify:
```
sbctl status      # Secure Boot: Enabled  ·  Setup Mode: Disabled
bootctl status    # Secure Boot: enabled
```
**Then confirm Windows still boots** from the firmware boot menu. The sbctl
pacman hook now auto-re-signs the UKIs + systemd-boot on every kernel/systemd
update, so this stays working across upgrades.

If Arch won't boot after enabling SB: reboot into firmware, **turn Secure Boot
off**, boot Arch, and re-check `sbctl verify` / re-run the signing. You are never
stuck — GRUB is still there too.

---

## 3. PHASE 3 — remove GRUB (only after phase2 + Windows both confirmed)

Optional cleanup. **Only do this once systemd-boot + Secure Boot + Windows are
all confirmed working.**
```
sudo ~/.config/scripts/bootloader-migrate.sh phase3
```
Removes the GRUB package, its ESP files, and its NVRAM entry. systemd-boot
becomes the only bootloader.

Check state anytime:
```
sudo ~/.config/scripts/bootloader-migrate.sh status
```

---

## 4. KDE Plasma 6 (independent of the bootloader work — do it whenever)

```
~/.config/scripts/plasma-install.sh      # run as your normal user, NOT root
```
Refreshes the keyring first, does a full `pacman -Syu`, installs
`plasma-desktop` + companions (plasma-pa/nm, powerdevil, bluedevil, kscreen,
kde-gtk-config, xdg-desktop-portal-kde, kwallet-pam), installs **Krohnkite**
(KWin tiling) with a source-build fallback if the AUR package fails, and enables
it in `kwinrc`.

Then **reboot** (loads new kernel + rebuilt NVIDIA module). At SDDM, session
picker → **"Plasma (Wayland)"**. Your Hyprland session stays selectable.

> On real hardware the GPU renders Plasma natively — **do not** use the VM
> software-render shim. If `~/.config/plasma-workspace/env/10-vm-software-rendering.sh`
> somehow exists on the real box, delete it (it would force llvmpipe and cripple
> the GPU).

---

## Quick reference — order of operations

| Step | Command | Reboot into | Confirm |
|---|---|---|---|
| 0 | `sudo pacman -Syu` + backup ESP | normal | clean boot on GRUB |
| 1 | `bootloader-migrate.sh phase1` | Linux Boot Manager | `/proc/cmdline` = UKI line |
| 2a | (firmware) clear SB keys → Setup Mode | Arch | — |
| 2b | `bootloader-migrate.sh phase2` | firmware → SB Enabled | `sbctl status` Enabled + Windows boots |
| 3 | `bootloader-migrate.sh phase3` | — | GRUB gone, still boots |
| 4 | `plasma-install.sh` | Plasma (Wayland) at SDDM | desktop loads |

Golden rule: **GRUB is your fallback through phase2.** Never run `phase3` until
Secure Boot *and* Windows are both confirmed. Nothing here is irreversible before
that point.
