#!/usr/bin/env bash
# tmux-agent-watcher.sh
# PostToolUse hook: opens a tmux pane for each background Claude Code agent.
#
# Layout: agents open as vertical splits on the right side of the current
# window, stacking below each other. The first agent splits the Claude pane
# horizontally (right side). Subsequent agents split the rightmost pane
# vertically (below existing agent panes).
#
# Receives JSON on stdin with fields:
#   tool_name       - "Task"
#   tool_input      - { description, prompt, subagent_type, run_in_background, ... }
#   tool_response   - { isAsync, status, agentId, outputFile, description, ... }

set -euo pipefail

INPUT=$(cat)

# --- Guard: only act on Task tool ---
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Task" ]]; then
    exit 0
fi

# --- Guard: only act on async (background) tasks ---
IS_ASYNC=$(echo "$INPUT" | jq -r '.tool_response.isAsync // false')
if [[ "$IS_ASYNC" != "true" ]]; then
    exit 0
fi

# --- Guard: only act when tmux is available ---
if [[ -z "${TMUX:-}" ]]; then
    if ! tmux list-sessions &>/dev/null; then
        exit 0
    fi
fi

# --- Extract output file and description ---
OUTPUT_FILE=$(echo "$INPUT" | jq -r '.tool_response.outputFile // empty')
if [[ -z "$OUTPUT_FILE" ]]; then
    exit 0
fi

DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_response.description // .tool_input.description // "agent"')

# Use printf %q for safe shell quoting
SAFE_OUTPUT=$(printf '%q' "$OUTPUT_FILE")
SAFE_DESC=$(printf '%q' "$DESCRIPTION")

WATCHER_CMD="python3 $HOME/.claude/hooks/watch-agent.py $SAFE_OUTPUT $SAFE_DESC; exit 0"

# --- Determine pane layout ---
# Count existing panes in the current window
PANE_COUNT=$(tmux list-panes | wc -l | tr -d ' ')

if [[ "$PANE_COUNT" -eq 1 ]]; then
    # First agent: split horizontally (creates right-side pane)
    tmux split-window -h "$WATCHER_CMD"
    # Reselect the left pane (where Claude is running) so Claude stays focused
    tmux select-pane -L
else
    # Subsequent agents: split the rightmost pane vertically (stack below)
    # Find the rightmost pane (highest pane index in the right column)
    LAST_PANE=$(tmux list-panes -F '#{pane_index}' | tail -1)
    tmux split-window -v -t "$LAST_PANE" "$WATCHER_CMD"
    # Reselect the first pane (Claude)
    tmux select-pane -t 0
fi

exit 0
