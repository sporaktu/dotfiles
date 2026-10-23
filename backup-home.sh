#!/usr/bin/env bash
#
# backup_home.sh — create a timestamped tar.gz of /home and store it on your flash drive.
# Usage: ./backup_home.sh [TARGET_DIR]
# If no TARGET_DIR is given, defaults to /mnt/usb.

set -euo pipefail
IFS=$'\n\t'

# ——— Configuration ———
SOURCE_DIR="/home"
TARGET_DIR="${1:-/mnt/usb}"       # mount point of your flash drive
EXCLUDES=(                         # directories to skip (optional)
  --exclude="$SOURCE_DIR/*/.cache"
  --exclude="$SOURCE_DIR/*/Downloads"
)

# ——— Sanity checks ———
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  Warning: you’re not root; you may miss files owned by other users."
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "❌ Source directory $SOURCE_DIR does not exist." >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "❌ Target directory $TARGET_DIR not found or not a directory." >&2
  exit 1
fi


# ——— Prepare filename ———
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"

# use hostname if available, otherwise uname -n
if command -v hostname &>/dev/null; then
  HOSTNAME="$(hostname -s)"
else
  HOSTNAME="$(uname -n)"
fi

FILENAME="home_backup_${HOSTNAME}_${TIMESTAMP}.tar.gz"
DESTPATH="$TARGET_DIR/$FILENAME"
# ——— Run backup ———
echo "🗂️  Backing up $SOURCE_DIR → $DESTPATH"
tar czpf "$DESTPATH" "${EXCLUDES[@]}" "$SOURCE_DIR"

# ——— Verify and finish ———
if [[ -f "$DESTPATH" ]]; then
  echo "✅ Backup successful: $DESTPATH"
  echo "ℹ️  Size: $(du -h "$DESTPATH" | cut -f1)"
else
  echo "❌ Backup failed: $DESTPATH not created." >&2
  exit 1
fi
