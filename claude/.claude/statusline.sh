#!/bin/bash
# Claude Code status line: session cost, context usage, and token usage by type.
#   Line 1: model │ project │ session cost │ context bar + composition of the current context (last API call)
#   Line 2: session-cumulative tokens by type, summed from the transcript and its subagent transcripts
#   Line 3: plan rate limits (5h / 7d / spend limit) — only when Claude Code sends them
#           (claude.ai Pro/Max, or an apps-gateway spend limit; absent on Enterprise)
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

# ── Line 3: rate limits (omitted entirely when Claude Code doesn't send them) ─
line3=""
add_limit() {  # label, used %, reset time
  local c=$GRN
  [ -n "$2" ] || return 0
  [ "$2" -ge 50 ] && c=$YEL
  [ "$2" -ge 80 ] && c=$RED
  [ -n "$line3" ] && line3+="$SEP"
  line3+="$1 ${c}$2%${RST}"
  [ -n "$3" ] && line3+=" ${DIM}resets $3${RST}"
  return 0
}
add_limit "5h" "$rl5_pct" "$rl5_reset"
add_limit "7d" "$rl7_pct" "$rl7_reset"
add_limit "spend" "$rls_pct" "$rls_reset"

printf '%s\n%s\n' "$line1" "$line2"
[ -n "$line3" ] && printf '%s\n' "${BOLD}limits${RST} ${line3}"
exit 0
