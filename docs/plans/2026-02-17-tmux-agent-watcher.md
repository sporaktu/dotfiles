# tmux Agent Watcher Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically open a named tmux window for every background Claude Code agent, showing a live readable feed of its activity, closing when the agent completes.

**Architecture:** A bash PostToolUse hook detects background Task tool calls, extracts the output file path from the tool response string, and spawns a tmux window running a Python watcher script. The watcher parses the JSONL output file in real time, displaying only meaningful events, and exits (auto-closing the window) when it detects `stop_reason: end_turn`.

**Tech Stack:** bash, Python 3 (stdlib only), tmux, jq, Claude Code hooks (`~/.claude/settings.json`)

---

### Task 1: Create the Python watcher script

**Files:**
- Create: `~/.claude/hooks/watch-agent.py`

**Step 1: Create the file with header and arg parsing**

```python
#!/usr/bin/env python3
"""Live watcher for Claude Code background agent output files.

Usage: watch-agent.py <output_file> <description>

Reads the JSONL output file produced by a background Task agent,
displays a clean live feed, and exits when the agent completes.
"""

import sys
import json
import time
import os


def truncate(text, max_len=80):
    text = text.replace("\n", " ").strip()
    return text[:max_len] + "…" if len(text) > max_len else text


def main():
    if len(sys.argv) < 3:
        print("Usage: watch-agent.py <output_file> <description>")
        sys.exit(1)

    output_file = sys.argv[1]
    description = sys.argv[2]

    print(f"\n  ⚡ Agent: {description}")
    print(f"  {'─' * min(len(description) + 9, 60)}")
    print()

    # Wait for file to appear (Task tool creates it shortly after hook fires)
    waited = 0
    while not os.path.exists(output_file):
        if waited == 0:
            print("  Waiting for agent to start...", end="", flush=True)
        time.sleep(0.3)
        waited += 0.3
        if waited > 30:
            print("\n  ✗ Timed out waiting for output file.")
            sys.exit(1)

    if waited > 0:
        print()

    # Follow the file line by line
    follow_file(output_file)


def follow_file(path):
    """Tail the JSONL output file and display meaningful events."""
    with open(path, "r") as f:
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.2)
                continue

            line = line.strip()
            if not line:
                continue

            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            if handle_line(obj):
                # Agent completed — pause briefly then exit
                time.sleep(1.5)
                return


def handle_line(obj):
    """
    Process one JSONL line. Returns True when agent is complete.

    The output file is a conversation transcript. Each line is one of:
      - type "assistant": Claude's response turn (may contain tool_use blocks)
      - type "user": tool results fed back to Claude
      - type "progress": hook lifecycle events (ignored)
    """
    msg_type = obj.get("type")
    message = obj.get("message", {})

    if msg_type == "assistant":
        content = message.get("content", [])
        stop_reason = message.get("stop_reason")

        for block in content:
            block_type = block.get("type")

            if block_type == "text":
                text = block.get("text", "").strip()
                if text:
                    print(f"  💬 {truncate(text)}")

            elif block_type == "tool_use":
                tool_name = block.get("name", "unknown")
                tool_input = block.get("input", {})
                # Show the most informative field from the tool input
                hint = ""
                for key in ("command", "description", "pattern", "file_path", "query", "prompt"):
                    if key in tool_input:
                        hint = f": {truncate(str(tool_input[key]), 50)}"
                        break
                print(f"  🔧 {tool_name}{hint}")

        # stop_reason is set on the final message of a turn
        if stop_reason == "end_turn":
            print()
            print("  ✓ Agent complete")
            print()
            return True  # Signal completion

    return False


if __name__ == "__main__":
    main()
```

**Step 2: Make it executable**

```bash
chmod +x ~/.claude/hooks/watch-agent.py
```

**Step 3: Smoke-test with a fake JSONL file**

Create `/tmp/test-agent.jsonl`:
```jsonl
{"type":"assistant","message":{"stop_reason":null,"content":[{"type":"text","text":"Let me look at the files first."}]}}
{"type":"assistant","message":{"stop_reason":null,"content":[{"type":"tool_use","name":"Glob","input":{"pattern":"**/*.ts"}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"src/index.ts\nsrc/utils.ts"}]}}
{"type":"assistant","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"Found 2 TypeScript files."}]}}
```

Run:
```bash
python3 ~/.claude/hooks/watch-agent.py /tmp/test-agent.jsonl "Test agent"
```

Expected output:
```
  ⚡ Agent: Test agent
  ─────────────────────

  💬 Let me look at the files first.
  🔧 Glob: **/*.ts
  💬 Found 2 TypeScript files.

  ✓ Agent complete
```

Script should exit cleanly with code 0 after ~1.5 seconds.

**Step 4: Commit**

```bash
git -C ~ add .claude/hooks/watch-agent.py
git -C ~ commit -m "feat: add tmux agent watcher Python script"
```

---

### Task 2: Create the PostToolUse hook shell script

**Files:**
- Create: `~/.claude/hooks/tmux-agent-watcher.sh`

**Step 1: Write the hook script**

```bash
#!/usr/bin/env bash
# tmux-agent-watcher.sh
# PostToolUse hook: opens a tmux window for each background Claude Code agent.
#
# Receives JSON on stdin:
#   tool_name    - name of the tool that was called
#   tool_input   - JSON object with the tool's input fields
#   tool_response - plain text response from the tool
#
# For background Task calls, tool_response contains a line like:
#   output_file: /private/tmp/claude-502/.../tasks/abc123.output

set -euo pipefail

# Read the full hook payload from stdin
INPUT=$(cat)

# --- Guard: only act on Task tool calls ---
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Task" ]]; then
    exit 0
fi

# --- Guard: only act when inside a tmux session ---
if [[ -z "${TMUX:-}" ]]; then
    exit 0
fi

# --- Guard: only act on background tasks (they have output_file in response) ---
TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty')
if ! echo "$TOOL_RESPONSE" | grep -q "output_file:"; then
    exit 0
fi

# --- Extract output file path ---
OUTPUT_FILE=$(echo "$TOOL_RESPONSE" | grep "output_file:" | head -1 | sed 's/.*output_file: *//' | tr -d '\r\n')
if [[ -z "$OUTPUT_FILE" ]]; then
    exit 0
fi

# --- Extract task description (truncated to 25 chars for window name) ---
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // "agent"')
SHORT_NAME=$(echo "$DESCRIPTION" | head -c 25)

WINDOW_NAME="⚡ ${SHORT_NAME}"

# --- Open new tmux window running the Python watcher ---
tmux new-window \
    -n "$WINDOW_NAME" \
    "python3 $HOME/.claude/hooks/watch-agent.py '$OUTPUT_FILE' '$DESCRIPTION'; exit 0"

exit 0
```

**Step 2: Make it executable**

```bash
chmod +x ~/.claude/hooks/tmux-agent-watcher.sh
```

**Step 3: Unit-test the hook with a simulated PostToolUse payload**

First create a fake output file so the watcher has something to read:
```bash
cat > /tmp/fake-agent.output << 'EOF'
{"type":"assistant","message":{"stop_reason":null,"content":[{"type":"text","text":"Searching the codebase..."}]}}
{"type":"assistant","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"Done."}]}}
EOF
```

Pipe a simulated hook payload into the script (must be inside a tmux session):
```bash
echo '{
  "tool_name": "Task",
  "tool_input": {"description": "Research fish config", "prompt": "..."},
  "tool_response": "Async agent launched.\noutput_file: /tmp/fake-agent.output\nTo check progress..."
}' | bash ~/.claude/hooks/tmux-agent-watcher.sh
```

Expected: a new tmux window named `⚡ Research fish config` opens and shows the watcher output, then closes after ~1.5 seconds.

**Step 4: Test the guard conditions**

```bash
# Should exit silently — wrong tool
echo '{"tool_name":"Bash","tool_input":{},"tool_response":"ok"}' \
    | bash ~/.claude/hooks/tmux-agent-watcher.sh
echo "Exit code: $?"   # Expected: 0, no window opened

# Should exit silently — foreground task (no output_file)
echo '{
  "tool_name": "Task",
  "tool_input": {"description": "quick task"},
  "tool_response": "Task completed successfully.\nResult: done"
}' | bash ~/.claude/hooks/tmux-agent-watcher.sh
echo "Exit code: $?"   # Expected: 0, no window opened
```

**Step 5: Commit**

```bash
git -C ~ add .claude/hooks/tmux-agent-watcher.sh
git -C ~ commit -m "feat: add tmux agent watcher hook script"
```

---

### Task 3: Register the hook in settings.json

**Files:**
- Modify: `~/.claude/settings.json`

**Step 1: Read current settings.json**

```bash
cat ~/.claude/settings.json
```

The file currently has `permissions`, `statusLine`, and `enabledPlugins` keys. No `hooks` key exists yet.

**Step 2: Add the hooks configuration**

Add a `hooks` key to `~/.claude/settings.json`. The full updated file should be:

```json
{
  "permissions": {
    "allow": [
      "Allow webfetch",
      "Allow pull request creation and merge"
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "$HOME/.claude/hooks/statusline.sh"
  },
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
  },
  "enabledPlugins": {
    "frontend-design@claude-plugins-official": true,
    "github@claude-plugins-official": true,
    "feature-dev@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true,
    "atlassian@claude-plugins-official": true,
    "playwright@claude-plugins-official": true,
    "agent-sdk-dev@claude-plugins-official": true,
    "pr-review-toolkit@claude-plugins-official": true,
    "figma@claude-plugins-official": true,
    "ralph-wiggum@claude-plugins-official": true,
    "pyright-lsp@claude-plugins-official": true,
    "explanatory-output-style@claude-plugins-official": true,
    "hookify@claude-plugins-official": true,
    "greptile@claude-plugins-official": true,
    "csharp-lsp@claude-plugins-official": true,
    "swift-lsp@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true,
    "huggingface-skills@claude-plugins-official": true,
    "circleback@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true
  },
  "skipDangerousModePermissionPrompt": true,
  "effortLevel": "medium"
}
```

**Step 3: Validate JSON is well-formed**

```bash
python3 -m json.tool ~/.claude/settings.json > /dev/null && echo "✓ Valid JSON" || echo "✗ Invalid JSON"
```

Expected: `✓ Valid JSON`

**Step 4: Commit**

```bash
git -C ~ add .claude/hooks/tmux-agent-watcher.sh .claude/hooks/watch-agent.py .claude/settings.json
git -C ~ commit -m "feat: register tmux agent watcher PostToolUse hook"
```

---

### Task 4: End-to-end verification

**Step 1: Reload Claude Code**

The hooks take effect immediately — no restart needed. Open a new Claude Code session (or continue in the current one).

**Step 2: Spawn a real background agent and observe**

In Claude Code, run a prompt that dispatches a background agent, e.g.:

```
Use the Task tool with run_in_background=true to search for all .fish files in ~/dotfiles
```

Expected: A new tmux window `⚡ <description>` appears within ~1 second, showing live tool calls and assistant text. The window closes automatically when the agent finishes.

**Step 3: Verify guard — foreground agents don't open windows**

Spawn a foreground Task (no `run_in_background`). Verify no extra tmux window appears.

**Step 4: Verify guard — non-tmux environments**

If you ever run Claude Code outside tmux (e.g. directly in a terminal), verify no errors surface and the hook exits cleanly.

**Step 5: Final commit of design doc**

```bash
git -C ~/dotfiles add docs/plans/
git -C ~/dotfiles commit -m "docs: add tmux agent watcher design and implementation plan"
```
