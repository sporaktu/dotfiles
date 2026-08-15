#!/usr/bin/env bash
# tmux-tab-namer.sh
# PostToolUse hook: updates tmux window name and color based on what Claude is doing.
#
# Generates a 1-3 word description from tool context and picks a deterministic
# background color by hashing the description text.

set -euo pipefail

# Guard: only act when inside tmux
if [[ -z "${TMUX:-}" ]]; then
    exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only update on meaningful actions (skip noisy read/search tools)
case "$TOOL_NAME" in
    Edit|Write)
        FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
        NAME=$(basename "$FILE" 2>/dev/null || echo "file")
        # Strip extension for brevity
        NAME="${NAME%.*}"
        DESC="edit ${NAME}"
        ;;
    Bash)
        CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
        FIRST=$(echo "$CMD" | awk '{print $1}' | sed 's|.*/||')
        case "$FIRST" in
            git)   VERB=$(echo "$CMD" | awk '{print $2}'); DESC="git ${VERB}" ;;
            npm|yarn|pnpm|bun) DESC="$FIRST run" ;;
            docker|kubectl) DESC="$FIRST" ;;
            *)     DESC="run ${FIRST}" ;;
        esac
        ;;
    Task|Agent)
        RAW=$(echo "$INPUT" | jq -r '.tool_input.description // "agent"')
        DESC="${RAW}"
        ;;
    Skill)
        SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // "skill"')
        DESC="${SKILL}"
        ;;
    *)
        # Don't update for Read, Grep, Glob, etc.
        exit 0
        ;;
esac

# Truncate to keep tab readable
DESC="${DESC:0:24}"

# Deterministic color from description text
# Catppuccin Frappe palette - good contrast with dark text (#303446)
COLORS=(
    "#e78284"  # red
    "#ef9f76"  # peach
    "#e5c890"  # yellow
    "#a6d189"  # green
    "#81c8be"  # teal
    "#8caaee"  # blue
    "#ca9ee6"  # mauve
    "#f4b8e4"  # pink
    "#85c1dc"  # sapphire
    "#babbf1"  # lavender
)

HASH=$(echo -n "$DESC" | cksum | awk '{print $1}')
IDX=$((HASH % ${#COLORS[@]}))
BG="${COLORS[$IDX]}"
FG="#303446"  # Catppuccin Frappe base (dark)

# Update tmux window name and style
tmux rename-window "$DESC"
tmux set-option -w window-status-current-style "bg=${BG},fg=${FG},bold"

exit 0
