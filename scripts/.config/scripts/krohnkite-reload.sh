#!/usr/bin/env bash
# Reload the Krohnkite KWin script.
#
# Why this exists: Krohnkite can latch onto a destroyed output (KWin's synthetic
# "Placeholder-N") when monitors disappear -- suspend/resume, DPMS, GPU hotplug.
# When that happens the script stays nominally loaded (isScriptLoaded reports
# true) but its engine is dead: nothing tiles and every Meta+<key> shortcut is a
# silent no-op. Observed 2026-08-09: it went mute after a Placeholder-1 output
# and stayed dead for 5 days across a resume, with KWin never restarting.
#
# The fix is a script reload, equivalent to toggling it off/on in
# System Settings -> Window Management -> KWin Scripts.
#
# NOTE: loading via Scripting.loadScript("...code/script.js") does NOT work --
# the package is a `declarativescript` whose entry point is ui/main.qml, so that
# path silently registers the wrong thing and never runs init. Toggling the
# config + reconfigure is the only reliable route.
#
# Usage: krohnkite-reload.sh [-q]

set -euo pipefail

QUIET=0
[[ "${1:-}" == "-q" ]] && QUIET=1
log() { [[ $QUIET -eq 1 ]] || echo "$@"; }

KWIN_DEST=(--session --dest org.kde.KWin)

is_loaded() {
  gdbus call "${KWIN_DEST[@]}" --object-path /Scripting \
    --method org.kde.kwin.Scripting.isScriptLoaded krohnkite 2>/dev/null \
    | grep -q true && echo true || echo false
}

reconfigure() {
  gdbus call "${KWIN_DEST[@]}" --object-path /KWin \
    --method org.kde.KWin.reconfigure >/dev/null 2>&1 || true
}

if ! gdbus call "${KWIN_DEST[@]}" --object-path /KWin \
      --method org.kde.KWin.reconfigure >/dev/null 2>&1; then
  echo "error: cannot reach org.kde.KWin on the session bus (is KWin running?)" >&2
  exit 1
fi

# Ground truth for "did it really restart" is the unconditional startup banner
# that ui/main.qml logs. isScriptLoaded() is NOT sufficient: it can keep
# reporting true across a too-fast disable/enable cycle where the script was
# never actually torn down, so a naive check yields a false success.
BANNER="KROHNKITE: starting the script"
SINCE=$(date '+%Y-%m-%d %H:%M:%S')
banners_since() {
  journalctl -b --no-pager --since "$SINCE" 2>/dev/null | grep -c "$BANNER" || true
}

log "==> disabling krohnkite"
kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled false

# Wait for the teardown to actually land before re-enabling. Skipping this is
# what makes the reload silently no-op.
for _ in $(seq 1 30); do
  reconfigure
  [[ "$(is_loaded)" == "false" ]] && break
  sleep 0.2
done

if [[ "$(is_loaded)" != "false" ]]; then
  echo "error: krohnkite would not unload; aborting without re-enabling" >&2
  kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled true
  reconfigure
  exit 1
fi
log "==> unloaded"

log "==> re-enabling krohnkite"
kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled true
for _ in $(seq 1 30); do
  reconfigure
  [[ "$(banners_since)" -gt 0 ]] && break
  sleep 0.2
done

if [[ "$(banners_since)" -gt 0 ]] && [[ "$(is_loaded)" == "true" ]]; then
  log "==> krohnkite reloaded and running (init confirmed in journal)"
  exit 0
fi

echo "error: krohnkite did not re-initialize (no startup banner in journal)" >&2
echo "       try System Settings -> Window Management -> KWin Scripts" >&2
exit 1
