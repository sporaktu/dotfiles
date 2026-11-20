#!/usr/bin/env bash
# Find the Claude sessions running on the dev VM(s) and reopen one in tuios.
#
#   devvm-sessions              open the picker in a tuios popup (same as: pick)
#   devvm-sessions refresh      query every machine now and update the cache (-q: quiet)
#   devvm-sessions dock         refresh, then print one dock cell ("devvm 2 · devvm2 off")
#   devvm-sessions list         print the cached sessions as a table
#   devvm-sessions open HOST N pane|window
#                               reopen session N (0-based) of HOST in a tuios pane or a new workspace
#
# Machines: one ssh alias per line in ~/.config/devvm/session-hosts ('#' comments allowed);
# without that file, just "devvm". The alias "devvm" reconnects through devvm-win, which
# also signs in to Azure, starts the VM and brings up the VPN; any other alias uses plain ssh.
# Each refresh sends devvm-sessions-remote.sh over one ssh call; nothing is installed on the VM.
# The tuios dock runs `dock` every 30s, so the cache stays fresh while tuios is open.
# Runs under macOS /bin/bash 3.2.
set -uo pipefail

SELF="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)/$(basename "$(realpath "${BASH_SOURCE[0]}")")"
SCRIPT_DIR="$(dirname "$SELF")"
REMOTE="$SCRIPT_DIR/devvm-sessions-remote.sh"
HOSTS_FILE="${DEVVM_SESSION_HOSTS:-$HOME/.config/devvm/session-hosts}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/devvm-sessions"
mkdir -p "$CACHE"

die() { printf '\033[1;31m[devvm-sessions]\033[0m %s\n' "$*" >&2; exit 1; }

hosts() {
  if [[ -r $HOSTS_FILE ]]; then
    sed -e 's/#.*//' -e 's/[[:space:]]//g' "$HOSTS_FILE" | grep -E '^[A-Za-z0-9._-]+$'
  else
    echo devvm
  fi
}

# ---- refresh: one ssh per machine, in parallel; keeps the last good list when a machine is down ----
refresh_host() {
  local h=$1 out err tmp="$CACHE/$1.tmp.$$" errf="$CACHE/$1.err.$$" now
  now=$(date +%s)
  if out=$(ssh -o BatchMode=yes -o ConnectTimeout=6 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
    "$h" bash -s <"$REMOTE" 2>"$errf") && jq -e '.sessions' >/dev/null 2>&1 <<<"$out"; then
    jq -c --arg alias "$h" --argjson t "$now" '. + {alias:$alias, ok:true, error:"", fetched:$t, last_ok:$t}' \
      <<<"$out" >"$tmp" && mv "$tmp" "$CACHE/$h.json"
  else
    # the last non-empty stderr line, minus devvm-access's progress chatter
    err=$(grep -v '^devvm-access: issuing' "$errf" | grep -v '^[[:space:]]*$' | tail -n 1 | cut -c1-80)
    [[ -n $err ]] || err="no answer"
    if [[ -r $CACHE/$h.json ]]; then
      jq -c --arg e "$err" --argjson t "$now" '. + {ok:false, error:$e, fetched:$t}' "$CACHE/$h.json" >"$tmp"
    else
      jq -cn --arg alias "$h" --arg e "$err" --argjson t "$now" \
        '{alias:$alias, hostname:"", ok:false, error:$e, fetched:$t, last_ok:null, sessions:[]}' >"$tmp"
    fi
    mv "$tmp" "$CACHE/$h.json"
  fi
  rm -f "$errf"
}

refresh() {
  # one refresh at a time (the dock and the picker can both ask); a stale lock is ignored after 60s
  local lock="$CACHE/.lock" h
  if ! mkdir "$lock" 2>/dev/null; then
    if [[ -n $(find "$lock" -maxdepth 0 -mmin -1 2>/dev/null) ]]; then
      while [[ -d $lock ]]; do sleep 0.3; done # wait for the running one, then use its result
      return 0
    fi
    rm -rf "$lock" && mkdir "$lock" || return 1
  fi
  trap 'rmdir "$CACHE/.lock" 2>/dev/null' EXIT
  for h in $(hosts); do refresh_host "$h" & done
  wait
  rmdir "$lock" 2>/dev/null
  trap - EXIT
}

# ---- reading the cache ----
all_json() { # every configured machine's cache, as one array
  local h f files=()
  for h in $(hosts); do
    f="$CACHE/$h.json"
    [[ -r $f ]] && files+=("$f")
  done
  if ((${#files[@]})); then jq -cs '.' "${files[@]}"; else echo '[]'; fi
}

# shellcheck disable=SC2016 # jq source, not shell
JQ_HELPERS='
  def ago: if . == null then "-" else (now - .) as $s |
    if $s < 60 then "just now" elif $s < 3600 then "\($s/60|floor)m ago"
    elif $s < 86400 then "\($s/3600|floor)h ago" else "\($s/86400|floor)d ago" end end;
  def clip($n): if length > $n then .[0:$n-1] + "…" else . end;
  def pad($n): clip($n) | . + (" " * ($n - length));
  def machine: if .hostname != "" and .hostname != .alias then "\(.alias) (\(.hostname))" else .alias end;
  def home: sub("^/home/[^/]+"; "~") | sub("^/Users/[^/]+"; "~");
  def kindname: {agent:"agent", tmux:"tmux", loose:"no tty"}[.] // .;
'

# one picker line per session: HOST<TAB>INDEX<TAB>visible columns
rows() {
  all_json | jq -r "$JQ_HELPERS"'
    .[] | . as $m | (.sessions | to_entries[]) |
    .value as $s |
    [ $m.alias, (.key|tostring),
      ( ($m | machine | pad(22)) + "  " + ($s.kind | kindname | pad(6)) + "  " +
        ((if $m.ok then $s.state else "stale" end) | pad(8)) + "  " +
        ((if $s.title != "" then $s.title else "(untitled)" end) | pad(30)) + "  " +
        ($s.name | pad(36)) + "  " + ($s.dir | home | pad(40)) + "  " + ($s.active | ago) )
    ] | @tsv'
}

header() {
  all_json | jq -r "$JQ_HELPERS"'
    (map(
      if .ok then "● \(machine): \(.sessions|length) session(s), checked \(.fetched|ago)"
      else "○ \(machine): unreachable (\(.error)), last seen \(.last_ok|ago)" end
    ) | join("\n")),
    ("MACHINE"|pad(22)) + "  " + ("TYPE"|pad(6)) + "  " + ("STATE"|pad(8)) + "  " + ("WHAT IT IS"|pad(30)) +
      "  " + ("NAME"|pad(36)) + "  " + ("DIRECTORY"|pad(40)) + "  LAST ACTIVE"'
  if [[ $(all_json) == "[]" ]]; then echo "(nothing cached yet: ctrl-r to check)"; fi
}

dock_cell() {
  all_json | jq -r '
    if length == 0 then "vm …" else
    map(if .ok then "\(.alias) \([.sessions[] | select(.state == "running")] | length)"
        else "\(.alias) off" end) | join(" · ") end'
}

# ---- open ----
open_session() {
  local h=$1 i=$2 mode=${3:-window} s kind name state attach title cmd label ws
  [[ $i =~ ^[0-9]+$ ]] || die "bad index '$i'"
  s=$(jq -c --argjson i "$i" '.sessions[$i] // empty' "$CACHE/$h.json" 2>/dev/null)
  [[ -n $s ]] || die "no session $i on $h (refresh and try again)"
  kind=$(jq -r .kind <<<"$s")
  name=$(jq -r .name <<<"$s")
  state=$(jq -r .state <<<"$s")
  attach=$(jq -r .attach <<<"$s")
  title=$(jq -r 'if .title != "" then .title else .name end' <<<"$s")

  if [[ $kind == agent && $state == killed ]]; then
    attach="devvm-agent resume $name && devvm-agent attach $name"
  fi
  if [[ -z $attach ]]; then
    case $kind in
      loose) die "$name on $h runs in a plain shell with no tmux, so it can't be reattached. Run 'ssh $h' and look at it there, or end it and continue the work with 'claude --resume'." ;;
      *) die "$name on $h is $state, so there's nothing to attach to. 'ssh $h devvm-agent ls' shows it." ;;
    esac
  fi
  # names come from the VM: allow only what devvm-agent and tmux targets use, so nothing can be injected
  [[ $attach =~ ^[A-Za-z0-9_.:\ \&-]+$ ]] || die "refusing an unexpected attach command from $h"

  label="$h·$(printf '%s' "$title" | cut -c1-24)"
  if [[ $h == devvm ]] && command -v devvm-win >/dev/null; then
    cmd=(devvm-win --inner -r "$attach")
  else
    cmd=(ssh -t "$h" "$attach")
  fi

  case $mode in
    pane)
      tuios new-window "$label" -- "${cmd[@]}" >/dev/null || die "tuios new-window failed"
      ;;
    window)
      # the lowest-numbered empty workspace (1-9), else a new pane here
      ws=$(tuios list-windows --json 2>/dev/null | jq -r '[.windows[].workspace] as $used |
        first(range(1;10) | select(. as $w | $used | index($w) | not)) // empty')
      if [[ -n $ws ]]; then
        tuios new-window "$label" --workspace "$ws" -- "${cmd[@]}" >/dev/null || die "tuios new-window failed"
        tuios set-workspace-name "$ws" "$label" >/dev/null 2>&1 || true
        tuios select-workspace "$ws" >/dev/null 2>&1 || true
      else
        tuios new-window "$label" -- "${cmd[@]}" >/dev/null || die "tuios new-window failed"
      fi
      ;;
    *) die "mode must be pane or window" ;;
  esac
}

# ---- picker (runs inside the popup) ----
picker() {
  local out key line h i
  [[ -n $(all_json | jq -r '.[0] // empty') ]] || refresh
  refresh & # show the cache now; ctrl-r reloads with what this fetched
  out=$(rows | fzf --delimiter=$'\t' --with-nth=3.. --no-sort --layout=reverse --no-multi \
    --header="$(header)" --header-first \
    --prompt='session> ' --info=inline-right \
    --footer='enter: new window   ctrl-p: new pane   ctrl-r: refresh   esc: close' \
    --expect=enter,ctrl-p \
    --bind="ctrl-r:reload($SELF refresh -q; $SELF rows)+transform-header($SELF header)" \
  ) || return 0
  key=$(sed -n 1p <<<"$out")
  line=$(sed -n 2p <<<"$out")
  [[ -n $line ]] || return 0
  h=$(cut -f1 <<<"$line")
  i=$(cut -f2 <<<"$line")
  if [[ $key == ctrl-p ]]; then open_session "$h" "$i" pane; else open_session "$h" "$i" window; fi || {
    printf '\nPress Enter to close. '
    read -r _
  }
}

sub=${1:-pick}
shift || true
case $sub in
  pick)
    if [[ -n ${TUIOS_SESSION:-} ]] || tuios list-windows >/dev/null 2>&1; then
      exec tuios popup --width 95% --height 60% -- "$SELF" _picker
    fi
    picker
    ;;
  _picker) picker ;;
  refresh)
    refresh
    [[ ${1:-} == -q ]] || header
    ;;
  dock)
    refresh
    dock_cell
    ;;
  list) header && rows | cut -f3- ;;
  rows) rows ;;
  header) header ;;
  open) open_session "$@" ;;
  -h | --help | help) sed -n '2,17p' "$SELF" ;;
  *) die "unknown command '$sub' (devvm-sessions --help)" ;;
esac
