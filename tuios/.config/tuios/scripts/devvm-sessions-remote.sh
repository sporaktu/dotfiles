#!/usr/bin/env bash
# Runs ON a dev VM (sent over ssh by devvm-sessions; nothing is installed there).
# Prints one JSON object: the machine and every Claude session on it, with how to reattach each.
#
#   kind   agent   a devvm-agent (tmux -L agents); reattach: devvm-agent attach NAME
#          tmux    claude inside a pane of the default tmux server; reattach: tmux attach -t TARGET
#          loose   claude in a plain ssh shell or with no terminal; it can't be reattached
# Titles come from the session transcript's newest ai-title (what Claude calls the session),
# never from prompt text.
set -uo pipefail
export LC_ALL=C

agents_root="$HOME/.local/state/devvm/agents"
now=$(date +%s)
rows=$(mktemp)
trap 'rm -f "$rows"' EXIT

transcript() { # session id -> transcript path
  [[ $1 =~ ^[0-9a-f-]{36}$ ]] || return 1
  find "$HOME/.claude/projects" -maxdepth 2 -name "$1.jsonl" -print -quit 2>/dev/null
}
title_of() { # transcript path -> newest ai-title
  [[ -n $1 && -r $1 ]] || return 0
  grep -F '"type":"ai-title"' "$1" 2>/dev/null | tail -n 1 | jq -r '.aiTitle // empty' 2>/dev/null
}
mtime() { [[ -n $1 ]] && stat -c %Y "$1" 2>/dev/null; }
# session id from a claude argv (--resume ID, --session-id ID, -r ID)
sid_of_pid() {
  tr '\0' '\n' <"/proc/$1/cmdline" 2>/dev/null |
    awk 'p {print; exit} /^(--resume|--session-id|-r)$/ {p=1}'
}
# newest transcript in the project folder of a directory (Claude's naming: / and . become -)
newest_transcript_in() {
  local d
  d="$HOME/.claude/projects/$(printf '%s' "$1" | sed 's#[/.]#-#g')"
  # shellcheck disable=SC2012 # newest by mtime; transcript names are uuids
  ls -t "$d"/*.jsonl 2>/dev/null | head -n 1
}
emit() { # kind name state title dir active started attach pid
  jq -cn --arg kind "$1" --arg name "$2" --arg state "$3" --arg title "$4" --arg dir "$5" \
    --arg active "$6" --arg started "$7" --arg attach "$8" --arg pid "$9" \
    '{kind:$kind,name:$name,state:$state,title:$title,dir:$dir,
      active:($active|tonumber? // null),started:($started|tonumber? // null),attach:$attach,pid:$pid}' >>"$rows"
}

# ttys that belong to agent panes, so their claude processes aren't listed twice
declare -A agent_tty=()
while IFS='|' read -r s tty; do
  [[ $s == agent-* ]] && agent_tty[$tty]=1
done < <(tmux -L agents list-panes -a -F '#{session_name}|#{pane_tty}' 2>/dev/null)

# ---- devvm-agent agents ----
for d in "$agents_root"/*/; do
  [[ -e $d/meta.json ]] || continue
  n=$(basename "$d")
  read -r st _ <"$d/state" 2>/dev/null || st=unknown
  if [[ $st == running* ]] && ! tmux -L agents has-session -t "=agent-$n:" 2>/dev/null; then
    st=killed # waiting for the boot resume
  fi
  sid=$(jq -r '.session_id // empty' "$d/meta.json" 2>/dev/null)
  cwd=$(jq -r '.cwd // empty' "$d/meta.json" 2>/dev/null)
  created=$(date -d "$(jq -r '.created // empty' "$d/meta.json" 2>/dev/null)" +%s 2>/dev/null)
  t=$(transcript "$sid")
  attach=""
  [[ $st == running* ]] && attach="devvm-agent attach $n"
  emit agent "$n" "${st%% *}" "$(title_of "$t")" "$cwd" "$(mtime "$t")" "$created" "$attach" ""
done

# ---- claude processes outside devvm-agent ----
declare -A tmux_pane=()
while IFS='|' read -r tty target; do
  tmux_pane[$tty]=$target
done < <(tmux list-panes -a -F '#{pane_tty}|#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null)

while read -r pid tty etimes comm; do
  [[ $comm == claude ]] || continue
  [[ $tty == "?" ]] && devtty="" || devtty="/dev/$tty"
  [[ -n $devtty && -n ${agent_tty[$devtty]:-} ]] && continue
  # only the top claude of a process tree (claude runs helper claude processes)
  ppid=$(ps -o ppid= -p "$pid" | tr -d ' ')
  [[ $(ps -o comm= -p "$ppid" 2>/dev/null) == claude ]] && continue
  cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null)
  sid=$(sid_of_pid "$pid")
  t=""
  [[ -n $sid ]] && t=$(transcript "$sid")
  [[ -z $t && -n $cwd ]] && t=$(newest_transcript_in "$cwd")
  started=$((now - etimes))
  if [[ -n $devtty && -n ${tmux_pane[$devtty]:-} ]]; then
    target=${tmux_pane[$devtty]}
    emit tmux "$target" running "$(title_of "$t")" "$cwd" "$(mtime "$t")" "$started" "tmux attach -t $target" "$pid"
  else
    emit loose "pid $pid" running "$(title_of "$t")" "$cwd" "$(mtime "$t")" "$started" "" "$pid"
  fi
done < <(ps -eo pid=,tty=,etimes=,comm=)

jq -cs --arg host "$(hostname)" --arg now "$now" \
  '{hostname:$host, now:($now|tonumber), sessions:.}' "$rows"
