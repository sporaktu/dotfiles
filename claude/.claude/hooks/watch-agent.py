#!/usr/bin/env python3
"""Live watcher for Claude Code background agent output files.

Usage: watch-agent.py <output_file> <description>

Reads the JSONL output file produced by a background Task agent,
displays a clean live feed, and exits when the agent completes.
Colors are drawn from the active Catppuccin palette (Frappe for dark
mode, Latte for light mode) to match the Ghostty theme.
"""

import sys
import json
import time
import os
import subprocess
import hashlib

DONE_TIMEOUT = 10
MAX_STALE = 300

# Catppuccin accent colors: (name, frappe_hex, latte_hex)
ACCENT_COLORS = [
    ("blue",    "8caaee", "1e66f5"),
    ("green",   "a6d189", "40a02b"),
    ("mauve",   "ca9ee6", "8839ef"),
    ("peach",   "ef9f76", "fe640b"),
    ("pink",    "f4b8e4", "ea76cb"),
    ("teal",    "81c8be", "179299"),
    ("yellow",  "e5c890", "df8e1d"),
    ("red",     "e78284", "d20f39"),
]

# Catppuccin base colors: (frappe_hex, latte_hex)
SUBTEXT = ("a5adce", "6c6f85")  # muted text
OVERLAY = ("737994", "9ca0b0")  # even more muted


def detect_dark_mode():
    """Check macOS system appearance. Returns True for dark mode."""
    try:
        result = subprocess.run(
            ["defaults", "read", "-g", "AppleInterfaceStyle"],
            capture_output=True, text=True, timeout=2
        )
        return result.stdout.strip() == "Dark"
    except Exception:
        return True  # default to dark


def hex_to_rgb(h):
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def fg(hex_color):
    """Return ANSI true-color foreground escape for a hex color."""
    r, g, b = hex_to_rgb(hex_color)
    return f"\033[38;2;{r};{g};{b}m"


RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"


def pick_accent(description, is_dark):
    """Pick a consistent accent color based on the description string."""
    idx = int(hashlib.md5(description.encode()).hexdigest(), 16) % len(ACCENT_COLORS)
    _, frappe, latte = ACCENT_COLORS[idx]
    return frappe if is_dark else latte


def truncate(text, max_len=80):
    text = text.replace("\n", " ").strip()
    return text[:max_len] + "…" if len(text) > max_len else text


class Watcher:
    def __init__(self, output_file, description):
        self.output_file = output_file
        self.description = description
        self.is_dark = detect_dark_mode()
        self.accent = pick_accent(description, self.is_dark)
        self.sub = SUBTEXT[0] if self.is_dark else SUBTEXT[1]
        self.muted = OVERLAY[0] if self.is_dark else OVERLAY[1]

    def print_header(self):
        a = fg(self.accent)
        s = fg(self.sub)
        bar = "─" * min(len(self.description) + 9, 60)
        print(f"\n  {a}{BOLD}⚡ Agent: {self.description}{RESET}")
        print(f"  {s}{bar}{RESET}")
        print()

    def print_line(self, icon, text, color=None):
        c = fg(color) if color else fg(self.sub)
        print(f"  {c}{icon}{RESET} {text}")

    def print_complete(self):
        a = fg(self.accent)
        print()
        print(f"  {a}{BOLD}✓ Agent complete{RESET}")
        print()

    def print_stale(self):
        m = fg(self.muted)
        print(f"\n  {m}⏱ No output for {int(MAX_STALE)}s — closing watcher.{RESET}")

    def run(self):
        self.print_header()

        # Wait for file
        waited = 0.0
        while not os.path.exists(self.output_file):
            if waited == 0:
                m = fg(self.muted)
                print(f"  {m}Waiting for agent to start...{RESET}", end="", flush=True)
            time.sleep(0.3)
            waited += 0.3
            if waited > 30:
                print(f"\n  {fg(self.accent)}✗ Timed out waiting for output file.{RESET}")
                sys.exit(1)
        if waited > 0:
            print()

        self.follow_file()

    def follow_file(self):
        stale_seconds = 0.0
        has_seen_output = False
        with open(self.output_file, "r") as f:
            while True:
                try:
                    line = f.readline()
                except IOError:
                    time.sleep(0.2)
                    continue

                if not line:
                    time.sleep(0.2)
                    stale_seconds += 0.2
                    if has_seen_output and stale_seconds > DONE_TIMEOUT:
                        self.print_complete()
                        time.sleep(1.5)
                        return
                    if stale_seconds > MAX_STALE:
                        self.print_stale()
                        return
                    continue

                stale_seconds = 0.0
                line = line.strip()
                if not line:
                    continue

                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue

                self.handle_line(obj)
                has_seen_output = True

    def handle_line(self, obj):
        msg_type = obj.get("type")
        message = obj.get("message", {})

        if msg_type == "assistant":
            content = message.get("content", [])
            for block in content:
                block_type = block.get("type")

                if block_type == "text":
                    text = block.get("text", "").strip()
                    if text:
                        self.print_line("💬", truncate(text), self.sub)

                elif block_type == "tool_use":
                    tool_name = block.get("name", "unknown")
                    tool_input = block.get("input", {})
                    hint = ""
                    for key in ("command", "description", "pattern", "file_path", "query", "prompt"):
                        if key in tool_input:
                            hint = f": {truncate(str(tool_input[key]), 50)}"
                            break
                    self.print_line("🔧", f"{tool_name}{hint}", self.accent)


def main():
    if len(sys.argv) < 3:
        print("Usage: watch-agent.py <output_file> <description>")
        sys.exit(1)

    watcher = Watcher(sys.argv[1], sys.argv[2])
    watcher.run()


if __name__ == "__main__":
    main()
