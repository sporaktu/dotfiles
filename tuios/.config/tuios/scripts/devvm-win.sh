#!/usr/bin/env bash
# Open a tuios window that lands in a shell on the dev VM, handling everything it can on the way:
#   1. Azure CLI sign-in (browser login only if the token is gone/expired)
#   2. Starts the VM if the nightly auto-shutdown deallocated it
#   3. Check Point VPN: opens the login if it isn't connected, then waits for you to finish it
#   4. Waits for sshd, then ssh's in (the Entra SSH cert is refreshed by devvm-access.sh via ~/.ssh/config)
#
# Usage: devvm-win [-t] [-n NAME]
#   -t       attach the persistent tmux session "main" instead of a fresh shell (ssh devvm-tmux)
#   -n NAME  tuios window name (default: devvm)
# Outside tuios (or with --here) it runs in the current terminal instead of opening a window.
set -euo pipefail

# Site settings (subscription, RG, VM name, VPN site) live outside this public repo.
DEVVM_ENV="${DEVVM_ENV:-$HOME/cloud-workspace/devvm/devvm.env}"
[[ -r $DEVVM_ENV ]] || { echo "devvm-win: $DEVVM_ENV not found (set DEVVM_ENV)" >&2; exit 1; }
# shellcheck source=/dev/null
source "$DEVVM_ENV"

SELF="$(realpath "${BASH_SOURCE[0]}")"
SSH_HOST_ALIAS="devvm"
# HostName from the managed block in ~/.ssh/config (ssh -G would fire its Match exec)
VM_IP="$(awk '/^Host devvm devvm-tmux/{f=1} f && $1 == "HostName" {print $2; exit}' "$HOME/.ssh/config")"
TRAC="/Library/Application Support/Checkpoint/Endpoint Connect/trac"
VPN_SITE="${DEVVM_VPN_SITE:?set DEVVM_VPN_SITE in $DEVVM_ENV}"
VPN_APP="${DEVVM_VPN_APP:-Endpoint Security VPN}"

say() { printf '\033[1;36m[devvm]\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31m[devvm]\033[0m %s\n' "$*" >&2
  read -r -p "Press Enter to close. " _ || true
  exit 1
}
port_open() { nc -z -G 3 "$VM_IP" 22 >/dev/null 2>&1; }
az_() { az "$@" --subscription "$DEVVM_SUBSCRIPTION"; }

# ---- launcher: re-run this script inside a new tuios window ----
name="devvm"
mode="launch"
args=()
while (($#)); do
  case $1 in
    -t) SSH_HOST_ALIAS="devvm-tmux"; args+=(-t) ;;
    -n) name="$2"; shift ;;
    --here) mode="here" ;;
    --inner) mode="here" ;;
    -h | --help) sed -n '2,11p' "$SELF"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ $mode == launch ]] && command -v tuios >/dev/null && tuios list-windows >/dev/null 2>&1; then
  exec tuios new-window "$name" -- "$SELF" --inner ${args[@]+"${args[@]}"}
fi
[[ -n $VM_IP ]] || die "no HostName for devvm in ~/.ssh/config; run mac-setup.sh"

# ---- inner: runs in the window ----

# 1. Azure sign-in (needed for VM start and the SSH cert)
if ! az account get-access-token --subscription "$DEVVM_SUBSCRIPTION" >/dev/null 2>&1; then
  say "Azure CLI token missing or expired; opening browser sign-in"
  az login --only-show-errors >/dev/null || die "az login failed"
fi

# 2. Start the VM if it's not running (auto-shutdown deallocates it nightly)
power=$(az_ vm get-instance-view -g "$DEVVM_RG" -n "$DEVVM_VM" \
  --query "instanceView.statuses[?starts_with(code,'PowerState/')].code | [0]" -o tsv 2>/dev/null) ||
  die "couldn't read VM state for $DEVVM_VM"
if [[ $power != PowerState/running ]]; then
  say "VM is ${power#PowerState/}; starting it (about 1-2 min, runs while the VPN connects)"
  az_ vm start -g "$DEVVM_RG" -n "$DEVVM_VM" --no-wait || die "az vm start failed"
fi

# 3. VPN (the VM has only a private IP; the NSG allows SSH from the VPN pool only)
vpn_connected() { "$TRAC" info -s "$VPN_SITE" 2>/dev/null | grep -qi 'status: *connected'; }
if ! vpn_connected; then
  say "Check Point VPN not connected; opening the login for $VPN_SITE"
  open -ga "$VPN_APP" || true
  sleep 2
  say "Finish the VPN sign-in (password/MFA) in the Check Point window. Waiting..."
  # connectgui blocks until the GUI login finishes, so poll the status alongside it
  "$TRAC" connectgui -s "$VPN_SITE" >/dev/null 2>&1 &
  for _ in $(seq 1 120); do vpn_connected && break; sleep 5; done
  vpn_connected || die "VPN still not connected after 10 min; connect it and rerun"
  say "VPN connected"
fi

# 4. Wait for the VM to be up and sshd listening
if ! port_open; then
  say "Waiting for $VM_IP:22 ..."
  for _ in $(seq 1 60); do port_open && break; sleep 5; done
  port_open || die "$VM_IP:22 unreachable after 5 min (VM state: $(az_ vm get-instance-view -g "$DEVVM_RG" -n "$DEVVM_VM" \
    --query "instanceView.statuses[?starts_with(code,'PowerState/')].code | [0]" -o tsv 2>/dev/null))"
fi

say "Connecting ($SSH_HOST_ALIAS)"
exec ssh "$SSH_HOST_ALIAS"
