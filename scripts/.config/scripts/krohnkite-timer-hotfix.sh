#!/usr/bin/env bash
# Applies the Krohnkite timer fix to the installed script, in place.
#
# Run by the pacman hook pacman-hooks/krohnkite-timer-fix.hook after every
# install or upgrade of kwin-scripts-krohnkite-git, so stock `yay -Syu` updates
# stay fixed without a rebuild.
#
# The bug: script.js state can outlive a Krohnkite reload (krohnkite-reload.sh,
# the resume watchdog, a toggle in System Settings). Its `scriptRoot` global
# then names the destroyed root of the previous instance, every new timer fails
# with "Qt.createQmlObject(): Missing parent object", and deferred work such as
# enforceSize() is dropped: tiled windows pushed off their tile (Ghostty after a
# Flameshot overlay) never snap back. The fix parents timers to the root item
# of the instance that is starting, and drops pooled timers from the old one.
# patches/kwin-scripts-krohnkite-git/fix-timer-pool-after-reload.patch is the
# same fix as a source patch, for rebuild-krohnkite.sh.
#
# Idempotent. Never fails the pacman transaction: if the code it expects has
# moved, it says so and leaves the files alone.
#
# Usage: krohnkite-timer-hotfix.sh [contents-dir]
#   default: /usr/share/kwin/scripts/krohnkite/contents

set -uo pipefail

DIR="${1:-/usr/share/kwin/scripts/krohnkite/contents}"
JS="$DIR/code/script.js"
QML="$DIR/ui/main.qml"
MARK="KROHNKITE_TIMER_FIX"
OLD_CALL='Timer {}", scriptRoot)'
NEW_CALL='Timer {}", KWinTimerPool.liveParent || scriptRoot)'
ANCHOR='const api = {'

say() { echo "krohnkite-timer-hotfix: $*" >&2; }

if [[ ! -f "$JS" || ! -f "$QML" ]]; then
  say "no Krohnkite at $DIR; nothing to do"
  exit 0
fi

# The source patch (rebuild-krohnkite.sh) is already in this build.
if grep -q 'this.parent !== null ? this.parent : scriptRoot' "$JS" \
   && grep -q '"timerParent": scriptRoot' "$QML"; then
  say "source patch already present; nothing to do"
  exit 0
fi

if grep -q "$MARK" "$QML" && grep -qF "$NEW_CALL" "$JS"; then
  say "already applied"
  exit 0
fi

js_hits=$(grep -cF "$OLD_CALL" "$JS")
qml_hits=$(grep -cF "$ANCHOR" "$QML")
if [[ "$js_hits" != 1 || "$qml_hits" != 1 ]]; then
  say "WARNING: Krohnkite's code changed (timer call: $js_hits, api anchor: $qml_hits; expected 1 each)."
  say "WARNING: the timer fix was NOT applied. Update $0."
  exit 0
fi

tmp_js=$(mktemp) && tmp_qml=$(mktemp) || exit 0
trap 'rm -f "$tmp_js" "$tmp_qml"' EXIT

# Fixed-string replacement; the strings hold regex metacharacters.
OLD="$OLD_CALL" NEW="$NEW_CALL" awk '{
  i = index($0, ENVIRON["OLD"])
  if (i) $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"]))
  print
}' "$JS" > "$tmp_js"

ANCHOR="$ANCHOR" MARK="$MARK" awk '{
  i = index($0, ENVIRON["ANCHOR"])
  if (i) {
    pad = substr($0, 1, i - 1)
    print pad "// " ENVIRON["MARK"] ": parent timers to this instance, not a stale scriptRoot."
    print pad "K.KWinTimerPool.liveParent = scriptRoot;"
    print pad "K.KWinTimerPool.instance.timers = [];"
  }
  print
}' "$QML" > "$tmp_qml"

if ! grep -qF "$NEW_CALL" "$tmp_js" || ! grep -q "$MARK" "$tmp_qml"; then
  say "WARNING: rewrite failed; files left unchanged"
  exit 0
fi

cat "$tmp_js" > "$JS" && cat "$tmp_qml" > "$QML"
say "applied to $DIR (takes effect at the next login or Krohnkite reload)"
