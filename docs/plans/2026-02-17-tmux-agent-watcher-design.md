# Design: tmux Agent Watcher for Claude Code Agent Teams

**Date:** 2026-02-17
**Status:** Approved

## Problem

When Claude Code spawns background agent teams via the Task tool, there is no visibility into what each agent is doing. Output files accumulate in `/tmp` but are raw JSONL with no live view.

## Solution

A `PostToolUse` hook that automatically opens a named tmux window for every background agent, displaying a clean live feed of agent activity. Windows auto-close when the agent completes.

## Components

### 1. PostToolUse Hook (`~/.claude/hooks/tmux-agent-watcher.sh`)

A bash script registered in `~/.claude/settings.json` as an `async: true` PostToolUse hook scoped to the `Task` tool.

**Logic:**
- Read JSON from stdin
- Exit immediately (0) if not inside tmux (`$TMUX` not set)
- Exit immediately (0) if tool is not `Task`
- Exit immediately (0) if `tool_response` does not contain `output_file:` (foreground tasks have no output file)
- Extract `description` from `tool_input` JSON
- Extract `output_file` path from `tool_response` text
- Create a new tmux window named `⚡ <description>` (description truncated to 25 chars)
- Run `python3 ~/.claude/hooks/watch-agent.py <output_file> "<description>"` in that window
- Exit 0

**Registration in `~/.claude/settings.json`:**
```json
"hooks": {
  "PostToolUse": [
    {
      "matcher": "Task",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/tmux-agent-watcher.sh",
          "async": true,
          "timeout": 5
        }
      ]
    }
  ]
}
```

### 2. Python Watcher (`~/.claude/hooks/watch-agent.py`)

A Python script that runs inside the tmux window and provides a live, readable view of agent activity.

**Logic:**
- Accept `output_file` and `description` as CLI args
- Print a header showing the agent name
- Poll until the output file exists (handles brief creation delay)
- Follow the file line-by-line, parsing JSONL
- Display only signal events:
  - `🔧 ToolName` — when a tool call fires
  - `💬 <text>` — assistant reasoning/commentary (first 80 chars)
  - `✓ <summary>` — final result text
- Detect completion: assistant message with `"stop_reason": "end_turn"` (non-null)
- Sleep 1.5 seconds after completion, then exit (tmux auto-closes the window)

## Data Flow

```
Claude Code calls Task(run_in_background=true)
  → Task tool creates output file at /tmp/.../tasks/<id>.output
  → PostToolUse fires → tmux-agent-watcher.sh runs (async)
    → New tmux window "⚡ <description>" opens
    → watch-agent.py starts, polls for file
    → Reads JSONL lines, prints formatted output
    → Agent finishes (stop_reason: end_turn)
    → watch-agent.py sleeps 1.5s, exits
    → tmux window closes automatically
```

## Constraints

- Hook is `async: true` — never blocks Claude's main conversation
- Only activates inside a tmux session (`$TMUX` check)
- Only activates for background tasks (output_file presence check)
- Foreground Task calls (no `run_in_background`) are ignored
- All errors in the hook are silent — never surfaces to the user

## Files

| File | Purpose |
|------|---------|
| `~/.claude/hooks/tmux-agent-watcher.sh` | PostToolUse hook, creates tmux window |
| `~/.claude/hooks/watch-agent.py` | Live JSONL formatter, runs in tmux window |
| `~/.claude/settings.json` | Hook registration |
