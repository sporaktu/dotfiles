#!/bin/bash
# Claude Code Statusline - GSD Edition
# Shows: model │ project │ context (bar, used%, used/max) │ session cost

input=$(cat)

# One field per line: empty fields must survive, so don't split on IFS whitespace.
mapfile -t fields < <(
    printf '%s' "$input" | jq -r '[
        (.model.display_name // "?"),
        (.workspace.current_dir // .cwd // ""),
        (.workspace.project_dir // ""),
        (.context_window.used_percentage // ""),
        (.context_window.total_input_tokens // ""),
        (.context_window.context_window_size // ""),
        (.cost.total_cost_usd // 0)
    ] | .[]'
)

model=${fields[0]}
dir=${fields[1]}
project=${fields[2]}
used_pct=${fields[3]}
cur_tok=${fields[4]}
max_tok=${fields[5]}
cost=${fields[6]}

# --- project (repo/dir Claude was launched in, plus subpath if we're deeper) ---
if [[ -n "$project" && "$dir" == "$project"/* ]]; then
    proj="$(basename "$project")/${dir#"$project"/}"
elif [[ -n "$project" ]]; then
    proj="$(basename "$project")"
else
    proj="$(basename "$dir")"
fi

# --- context: bar + used% + current/max tokens ---
ctx=""
if [[ -n "$used_pct" ]]; then
    used=$(printf "%.0f" "$used_pct")

    # 10-segment bar, fills as context is consumed
    filled=$((used / 10))
    ((filled > 10)) && filled=10
    bar=""
    for ((i = 0; i < filled; i++)); do bar+="█"; done
    for ((i = filled; i < 10; i++)); do bar+="░"; done

    # "142k/1M" — current context vs max context window
    tokens=$(awk -v c="$cur_tok" -v m="$max_tok" '
        function f(n,   v) {
            if (n == "" || n + 0 <= 0) return ""
            if (n >= 1000000) { v = n / 1000000; return (v == int(v)) ? sprintf("%dM", v) : sprintf("%.1fM", v) }
            if (n >= 1000) return sprintf("%dk", int(n / 1000 + 0.5))
            return sprintf("%d", n)
        }
        BEGIN { a = f(c); b = f(m); if (a == "") exit; print (b == "") ? a : a "/" b }')

    body="$bar $used%"
    [[ -n "$tokens" ]] && body+=" $tokens"

    # Color by usage, blinking skull at 80%+
    if [ "$used" -lt 50 ]; then
        ctx=$'\033[32m'"$body"$'\033[0m'
    elif [ "$used" -lt 65 ]; then
        ctx=$'\033[33m'"$body"$'\033[0m'
    elif [ "$used" -lt 80 ]; then
        ctx=$'\033[38;5;208m'"$body"$'\033[0m'
    else
        ctx=$'\033[5;31m💀 '"$body"$'\033[0m'
    fi
fi

# --- session cost (omitted when free / effectively zero) ---
cost_str=$(awk -v c="$cost" 'BEGIN { if (c + 0 > 0.005) printf "$%.2f", c }')

# --- assemble ---
parts=()
parts+=($'\033[2m'"$model"$'\033[0m')
[[ -n "$proj" && "$proj" != "/" ]] && parts+=($'\033[1m'"$proj"$'\033[0m')
[[ -n "$ctx" ]] && parts+=("$ctx")
[[ -n "$cost_str" ]] && parts+=($'\033[2m'"$cost_str"$'\033[0m')

out=""
for p in "${parts[@]}"; do
    [[ -n "$out" ]] && out+=" │ "
    out+="$p"
done
printf '%s' "$out"
