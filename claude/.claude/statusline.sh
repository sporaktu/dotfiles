#!/bin/bash
# Claude Code status line: session cost, context usage, and token usage by type.
#   Line 1: model │ project │ session cost │ context bar + composition of the current context (last API call)
#   Line 2: session-cumulative tokens by type, summed from the transcript and its subagent transcripts
#   Line 3+: subagents — active and used counts by tier (agent / sub-agent), then one row per
#           running top-level agent with its description and running team — only once the
#           session has spawned one
#   Last:   plan rate limits (5h / 7d / spend limit) — only when Claude Code sends them
#           (claude.ai Pro/Max, or an apps-gateway spend limit; absent on Enterprise)
# Pair with "refreshInterval" in settings.json: Claude Code doesn't re-run this while the
# main agent idles waiting on background subagents, so line 3 would freeze otherwise.
# Input schema: https://code.claude.com/docs/en/statusline#available-data

input=$(cat)

DIM=$'\033[2m'; RST=$'\033[0m'; BOLD=$'\033[1m'
GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; CYN=$'\033[36m'; MAG=$'\033[35m'; BLU=$'\033[34m'
SEP="${DIM} │ ${RST}"
US=$'\x1f'

# Human-readable token counts: 950, 12.3k, 4.56M
JQ_DEFS='def h: if . >= 999500 then "\((. / 10000 | round) / 100)M" elif . >= 999.5 then "\((. / 100 | round) / 10)k" else "\(. | round)" end;'

IFS="$US" read -r model cost pct ctx_used ctx_size has_cu cu_in cu_cr cu_cw cu_out transcript \
  rl5_pct rl5_reset rl7_pct rl7_reset rls_pct rls_reset dir project <<<"$(
  jq -r "$JQ_DEFS"'
    # [used %, local reset time] for one rate-limit window, or two empties when absent
    def rl($fmt): if .used_percentage == null then ["", ""]
      else [(.used_percentage | floor), (.resets_at | if . == null then "" else strflocaltime($fmt) end)] end;
    (.context_window // {}) as $cw
    | ($cw.current_usage // null) as $cu
    | [
        (.model.display_name // .model.id // "?"),
        (.cost.total_cost_usd // 0),
        ($cw.used_percentage // 0 | floor),
        (($cw.total_input_tokens // 0) | h),
        (($cw.context_window_size // 200000) | h),
        (if $cu == null then 0 else 1 end),
        (($cu.input_tokens // 0) | h),
        (($cu.cache_read_input_tokens // 0) | h),
        (($cu.cache_creation_input_tokens // 0) | h),
        (($cu.output_tokens // 0) | h),
        (.transcript_path // "")
      ]
      + ((.rate_limits.five_hour // {}) | rl("%H:%M"))
      + ((.rate_limits.seven_day // {}) | rl("%a %H:%M"))
      + ((.rate_limits.spend_limit // {}) | rl("%b %d"))
      + [(.workspace.current_dir // .cwd // ""), (.workspace.project_dir // "")]
      | map(tostring) | join("\u001f")' <<<"$input" 2>/dev/null
)"

# ── Line 1: model, cost, context ────────────────────────────────────────────
pct=${pct:-0}
if   [ "$pct" -ge 80 ]; then bar_color=$RED
elif [ "$pct" -ge 50 ]; then bar_color=$YEL
else                         bar_color=$GRN
fi
filled=$(( (pct + 5) / 10 )); [ "$filled" -gt 10 ] && filled=10
bar=""
for ((i = 0; i < 10; i++)); do
  if [ "$i" -lt "$filled" ]; then bar+="▓"; else bar+="░"; fi
done

# Project: the dir Claude was launched in, plus the subpath when cwd is deeper
if [ -n "$project" ] && [[ "$dir" == "$project"/* ]]; then
  proj="${project##*/}/${dir#"$project"/}"
elif [ -n "$project" ]; then
  proj="${project##*/}"
else
  proj="${dir##*/}"
fi

line1="${BOLD}${model:-?}${RST}${SEP}"
[ -n "$proj" ] && line1+="${BOLD}${BLU}${proj}${RST}${SEP}"
line1+="${GRN}\$$(printf '%.2f' "${cost:-0}")${RST}${SEP}"
line1+="ctx ${bar_color}${bar} ${pct}%${RST} ${ctx_used:-0}/${ctx_size:-200k}"
if [ "$has_cu" = "1" ]; then
  line1+=" ${DIM}(last call: cache read ${cu_cr} · cache write ${cu_cw} · input ${cu_in} · out ${cu_out})${RST}"
fi

# ── Line 2: session totals by token type ────────────────────────────────────
line2="${DIM}session tokens: none yet${RST}"
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  files=("$transcript")
  nsub=0
  subdir="${transcript%.jsonl}/subagents"
  if [ -d "$subdir" ]; then
    for f in "$subdir"/*.jsonl; do
      [ -f "$f" ] && files+=("$f") && nsub=$((nsub + 1))
    done
  fi

  # One transcript line per content block, all repeating the same usage, so
  # dedupe by message id (last record wins) before summing. Advisor sub-calls
  # appear only in usage.iterations (type "advisor_message"), not the top level.
  IFS="$US" read -r calls t_all t_in t_out t_think t_cr t_cw adv_n adv_in adv_out <<<"$(
    grep -h '"type":"assistant"' "${files[@]}" 2>/dev/null | jq -Rrn "$JQ_DEFS"'
      def s(f): map(f // 0) | add // 0;
      def ins: (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0);
      reduce (inputs | fromjson? | select(.type == "assistant" and .message.usage != null)) as $e
        ({}; .[$e.message.id // $e.requestId // $e.uuid] = $e.message.usage)
      | [.[]] as $u
      | [$u[].iterations[]? | select(.type == "advisor_message")] as $adv
      | ($u | s(.input_tokens) + s(.output_tokens) + s(.cache_read_input_tokens) + s(.cache_creation_input_tokens)) as $main
      | ($adv | map(ins + (.output_tokens // 0)) | add // 0) as $advall
      | [ ($u | length),
          ($main + $advall | h),
          ($u | s(.input_tokens) | h),
          ($u | s(.output_tokens) | h),
          ($u | s(.output_tokens_details.thinking_tokens) | h),
          ($u | s(.cache_read_input_tokens) | h),
          ($u | s(.cache_creation_input_tokens) | h),
          ($adv | length),
          ($adv | map(ins) | add // 0 | h),
          ($adv | s(.output_tokens) | h)
        ] | map(tostring) | join("\u001f")' 2>/dev/null
  )"

  if [ -n "$calls" ] && [ "$calls" != "0" ]; then
    out="${t_out}"
    [ "$t_think" != "0" ] && out+=" ${DIM}(thinking ${t_think})${RST}"
    line2="${BOLD}Σ ${t_all}${RST} tokens${SEP}"
    line2+="${CYN}cache read${RST} ${t_cr} · ${CYN}cache write${RST} ${t_cw} · ${CYN}input${RST} ${t_in} · ${MAG}output${RST} ${out}"
    [ "${adv_n:-0}" != "0" ] && line2+="${SEP}${YEL}advisor${RST} in ${adv_in} · out ${adv_out} ${DIM}(${adv_n}×)${RST}"
    line2+="${SEP}${DIM}${calls} API calls"
    [ "$nsub" -gt 0 ] && line2+=" incl. ${nsub} subagent$([ "$nsub" -gt 1 ] && echo s)"
    line2+="${RST}"
  fi
fi

# ── Line 3: running subagents, colored by tier, plus session totals ─────────
# Spawned = subagents/agent-<id>.meta.json (agentType, spawnDepth). Done = the latest
# <task-notification> for that id (background) or a non-async Agent tool_result
# (foreground) in whichever transcript spawned it. A finished agent can be resumed
# with SendMessage, which appends to its transcript after the notification, so a
# transcript written >2s after its latest notification counts as running again. A "completed" notification
# whose note says the agent stopped with background work of its own still
# running is interim (a final one follows), so it stays running too. No finish
# signal and no transcript write for 30m = stale (e.g. the session exited mid-run).
# Model = the first "message":{"model":…} in the agent's own transcript ("?" until
# its first response lands). First, not latest: a subagent keeps one model, and
# BSD grep -o over every record costs ~60ms per refresh on a busy session.
# Only running agents are listed; done/failed/stale ones are just counted in "used".
# Tier = spawnDepth: 1 = spawned by this session (blue), 2 = by one of those (pink), 3+ (gold).
# Agents are labelled by their Agent-call description, and each sub-agent is filed under
# its top-level ancestor (parentAgentId chain), so a supervisor's row carries its team:
#   agents 3 active (1 agent · 2 sub-agents) │ used 17 (5 agents · 12 sub-agents) · 1 failed
#    ● Supervisor: refresh job wiring Opus 5.5 · 14m ─ team 2 active · 9 used: ● Implement Task 3 · ● Review Task 2
line3=""
if [ -n "$transcript" ] && [ -d "${transcript%.jsonl}/subagents" ]; then
  metas=("${transcript%.jsonl}/subagents"/agent-*.meta.json)
  if [ -e "${metas[0]}" ]; then
    logs=("${metas[@]/%.meta.json/.jsonl}")
    if [[ $OSTYPE == darwin* ]]; then
      mtimes=$(stat -f '%m %N' "${logs[@]}" 2>/dev/null)
    else
      mtimes=$(stat -c '%Y %n' "${logs[@]}" 2>/dev/null)
    fi
    # Meta JSON (one line) and each transcript's first-record timestamp (spawn order)
    rows=$(awk 'FNR == 1 {
        if (FILENAME ~ /\.meta\.json$/) print "M\t" FILENAME "\t" $0
        else if (match($0, /"timestamp":"[^"]+"/)) print "F\t" FILENAME "\t" substr($0, RSTART + 13, RLENGTH - 14)
        nextfile
      }' "${metas[@]}" "${logs[@]}" 2>/dev/null)
    # First model per transcript as <path>:"message":{"model":"<id>"; [^"<] skips <synthetic>
    models=$(grep -m1 -oH '"message":{"model":"[^"<][^"]*"' "${logs[@]}" 2>/dev/null)
    # An agent's finish signal lands in its spawner's transcript: this session's, or the
    # parentAgentId's. Scanning only those skips the leaf transcripts (most of the bytes).
    spawners=("$transcript")
    while IFS= read -r p; do
      [ -n "$p" ] && spawners+=("${transcript%.jsonl}/subagents/agent-$p.jsonl")
    done < <(grep -ho '"parentAgentId":"[^"]*"' "${metas[@]}" 2>/dev/null | cut -d'"' -f4 | sort -u)

    line3=$(
      { grep -h '"operation":"enqueue"' "${spawners[@]}" 2>/dev/null | grep '<task-notification>'
        # Every subagent record carries its own top-level agentId, so match one inside toolUseResult
        grep -h -F '"toolUseResult":{' "${spawners[@]}" 2>/dev/null | grep -v '"status":"async_launched"' \
          | grep -E '"toolUseResult":\{.*"agentId":"'
      } | jq -nRr --arg rows "$rows" --arg mtimes "$mtimes" --arg models "$models" '
        def ts: sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;
        def aid: capture("agent-(?<id>[^/]+)\\.(meta\\.json|jsonl)$").id;
        # Descriptions are model-written: strip control chars so they cannot emit escapes
        def clip($n): gsub("[[:cntrl:]]"; "") | if length > $n then .[:$n - 1] + "…" else . end;
        def dur: floor | if . < 60 then "\(.)s" elif . < 3600 then "\(. / 60 | floor)m"
          else "\(. / 3600 | floor)h\(. % 3600 / 60 | floor | tostring | if length < 2 then "0" + . else . end)m" end;
        # Top-level ancestor id, following parentAgentId while the parent is a known agent
        def root($m; $n): ($m[.].parentAgentId // null) as $p
          | if $n > 0 and $p != null and $m[$p] != null then $p | root($m; $n - 1) else . end;
        # claude-haiku-4-5-20251001 -> Haiku 4.5; ids that do not fit pass through minus "claude-"
        def mlabel: if . == null then "?" else
          sub("^claude-"; "") | sub("-[0-9]{8}$"; "") | . as $m
          | (capture("^(?<f>[a-z]+)-(?<v>[0-9]+(-[0-9]+)*)$") // null)
          | if . == null then $m else (.f[:1] | ascii_upcase) + .f[1:] + " " + (.v | gsub("-"; ".")) end end;
        def esc($c): "\u001b[\($c)m";
        def dot: esc("2") + " · " + esc("0");
        def tcolor: [81, 213, 221][[., 3] | min | . - 1];
        def tname($k): (if . == 1 then "agent" elif . == 2 then "sub-agent" else "depth-\(.) agent" end)
          + (if $k == 1 then "" else "s" end);
        # "2 agents · 1 sub-agent", each in its tier color
        def by_tier: . as $a | [$a[].tier] | unique
          | map(. as $t | ($a | map(select(.tier == $t)) | length) as $k
                | esc("38;5;\($t | tcolor)") + "\($k) " + ($t | tname($k)) + esc("0"))
          | join(dot);

        ($rows | split("\n") | map(split("\t") | select(length == 3))) as $r
        | ($r | map(select(.[0] == "M") | {key: (.[1] | aid), value: (.[2] | fromjson? // {})}) | from_entries) as $meta
        | ($r | map(select(.[0] == "F") | {key: (.[1] | aid), value: .[2]}) | from_entries) as $first
        | ($mtimes | split("\n") | map(capture("^(?<t>[0-9]+) (?<f>.+)$")? | {key: (.f | aid), value: (.t | tonumber)}) | from_entries) as $mt
        | ($models | split("\n") | map(capture("agent-(?<id>[^/:]+)\\.jsonl:\"message\":\\{\"model\":\"(?<m>[^\"]+)\"$")?
            | {key: .id, value: .m}) | from_entries) as $model
        # id -> latest finish {s: status, t: epoch, i: interim}
        | (reduce (inputs | fromjson? // empty) as $e ({};
            (if $e.type == "queue-operation" then
               ($e.content | tostring) as $c
               | [(try ($c | capture("<task-id>(?<v>[^<]+)</task-id>").v) catch null),
                  (try ($c | capture("<status>(?<v>[^<]+)</status>").v) catch null),
                  ($c | test("background work of its own still running"))]
             elif ($e.toolUseResult | type) == "object" and $e.toolUseResult.status != "async_launched" then
               [$e.toolUseResult.agentId, ($e.toolUseResult.status // "completed"), false]
             else [] end) as [$id, $s, $i]
            | ($e.timestamp | ts? // 0) as $t
            | if $id != null and $s != null and $t >= (.[$id].t // 0) then .[$id] = {s: $s, t: $t, i: $i} else . end
          )) as $fin
        | now as $now
        | [$meta | to_entries[] | .key as $id | .value as $v | ($mt[$id] // 0) as $w | $fin[$id] as $f
            | {id: $id, root: ($id | root($meta; 8)), type: ($v.agentType // "agent"),
               desc: ($v.description // $v.agentType // "agent" | tostring),
               model: ($model[$id] | mlabel), first: ($first[$id] // ""),
               tier: ([$v.spawnDepth // 1, 1] | max),
               st: (if $f != null and ($f.i | not) and $w <= $f.t + 2 then (if $f.s == "completed" then "done" else "failed" end)
                    elif $now - $w > 1800 then "stale"
                    else "running" end)}]
        | sort_by(.first) as $agents
        | ($agents | map({key: .id, value: .}) | from_entries) as $by
        | ($agents | map(select(.st == "running"))) as $live
        | ($agents | map(.st) | group_by(.) | map({key: .[0], value: length}) | from_entries) as $n
        | ([$live[].root] | unique | sort_by($by[.].first)) as $roots
        | [ esc("1") + "agents" + esc("0") + " "
            + (if $live == [] then esc("2") + "none active" + esc("0")
               else esc("1") + "\($live | length) active" + esc("0") + esc("2") + " (" + esc("0") + ($live | by_tier) + esc("2") + ")" + esc("0") end)
            + esc("2") + " │ used " + esc("0") + esc("1") + "\($agents | length)" + esc("0")
            + esc("2") + " (" + esc("0") + ($agents | by_tier) + esc("2") + ")" + esc("0")
            + (if $n.failed then dot + esc("31") + "\($n.failed) failed" + esc("0") else "" end)
            + (if $n.stale then dot + esc("2") + "\($n.stale) stale" + esc("0") else "" end),
            # One row per top-level agent that is running or has a running team member
            ( $roots[:6][] as $r
              | $by[$r] as $a
              | ($agents | map(select(.root == $r and .id != $r))) as $team
              | ($team | map(select(.st == "running"))) as $mem
              | " " + (if $a.st == "running" then esc("1;38;5;\($a.tier | tcolor)") + "● " + esc("0") + ($a.desc | clip(40))
                       else esc("2") + "○ " + ($a.desc | clip(40)) + esc("0") end)
                + (if $a.type == "general-purpose" then "" else " " + esc("2") + "[" + ($a.type | split(":") | last) + "]" + esc("0") end)
                + " " + esc("2") + $a.model + " · "
                + (if $a.st == "running" then (try ($now - ($a.first | ts) | dur) catch "?") else $a.st end) + esc("0")
                + (if $team == [] then ""
                   else esc("2") + " ─ team " + esc("0")
                     + (if $mem == [] then "" else esc("1") + "\($mem | length) active" + esc("0") + dot end)
                     + esc("2") + "\($team | length) used" + esc("0")
                     + (if $mem == [] then ""
                        else esc("2") + ": " + esc("0")
                          + ($mem[:3] | map(esc("38;5;\(.tier | tcolor)") + "● " + (.desc | clip(28)) + esc("0")) | join(dot))
                          + (if ($mem | length) > 3 then esc("2") + " +\(($mem | length) - 3)" + esc("0") else "" end) end) end) ),
            (if ($roots | length) > 6 then esc("2") + " +\(($roots | length) - 6) more" + esc("0") else empty end)
          ] | join("\n")
      ' 2>/dev/null
    )
  fi
fi

# ── Last line: rate limits (omitted entirely when Claude Code doesn't send them)
line4=""
add_limit() {  # label, used %, reset time
  local c=$GRN
  [ -n "$2" ] || return 0
  [ "$2" -ge 50 ] && c=$YEL
  [ "$2" -ge 80 ] && c=$RED
  [ -n "$line4" ] && line4+="$SEP"
  line4+="$1 ${c}$2%${RST}"
  [ -n "$3" ] && line4+=" ${DIM}resets $3${RST}"
  return 0
}
add_limit "5h" "$rl5_pct" "$rl5_reset"
add_limit "7d" "$rl7_pct" "$rl7_reset"
add_limit "spend" "$rls_pct" "$rls_reset"

printf '%s\n%s\n' "$line1" "$line2"
[ -n "$line3" ] && printf '%s\n' "$line3"
[ -n "$line4" ] && printf '%s\n' "${BOLD}limits${RST} ${line4}"
exit 0
