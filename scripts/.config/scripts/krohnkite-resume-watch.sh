#!/usr/bin/env bash
# Watch for resume-from-sleep and reload Krohnkite.
#
# Krohnkite can latch onto a destroyed output when monitors disappear and go
# permanently inert -- still "loaded", but nothing tiles and no shortcut works.
# See krohnkite-reload.sh for the full write-up. Suspend/resume is the most
# reliable way to trigger it, so reload unconditionally on every resume.
#
# systemd's *user* manager has no sleep.target/suspend.target on this system
# (checked on systemd 261), so binding a user unit to those is not an option.
# Instead watch logind's PrepareForSleep signal on the SYSTEM bus, which any
# user can subscribe to. PrepareForSleep(true) = going down,
# PrepareForSleep(false) = waking up.
#
# Run via krohnkite-resume-watch.service.

set -uo pipefail

RELOAD="$(dirname "$(readlink -f "$0")")/krohnkite-reload.sh"

# Outputs are not necessarily back when the resume signal fires; reloading too
# early just re-latches onto a half-built screen set. Give KWin time to settle.
SETTLE_SECONDS="${KROHNKITE_RESUME_SETTLE:-5}"

echo "krohnkite-resume-watch: watching logind PrepareForSleep"

gdbus monitor --system --dest org.freedesktop.login1 \
              --object-path /org/freedesktop/login1 2>/dev/null |
while read -r line; do
  case "$line" in
    *PrepareForSleep*false*)
      echo "krohnkite-resume-watch: resume detected, settling ${SETTLE_SECONDS}s"
      sleep "$SETTLE_SECONDS"
      if "$RELOAD" -q; then
        echo "krohnkite-resume-watch: krohnkite reloaded"
      else
        echo "krohnkite-resume-watch: reload FAILED" >&2
      fi
      ;;
    *PrepareForSleep*true*)
      echo "krohnkite-resume-watch: suspending"
      ;;
  esac
done
