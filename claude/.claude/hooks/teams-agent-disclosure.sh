#!/usr/bin/env bash
# teams-agent-disclosure.sh
# PreToolUse hook: every Teams message Claude sends on Gray's behalf must say so.
# If the body isn't already signed, a last line in italics, "Sent by Claude on
# Gray’s behalf", is appended via updatedInput; the rest of tool_input is passed
# through as-is.
#
# Teams draws italics only in HTML, so a plain-text body is converted to HTML
# first, its newlines kept as <br>.
#
# Wired to the Microsoft 365 connector's teams_send_chat_message,
# teams_send_channel_message and teams_reply_channel_message tools.

set -euo pipefail

SIGNATURE="Sent by Claude on Gray’s behalf"

# Bodies Claude already signed are left alone.
ALREADY_SIGNED="Sent by Claude on Gray"

# Read the payload straight from stdin: piping it through echo can turn the JSON's
# \n escapes into raw newlines, which jq rejects.
jq -c --arg sig "$SIGNATURE" --arg re "$ALREADY_SIGNED" '
  def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
  def rtrim: sub("\\s+$"; "");
  .tool_input as $in
  | ($in.body // "" | rtrim) as $body
  | ("<p><em>" + ($sig | esc) + "</em></p>") as $line
  | if ($body | test($re)) then
      empty
    elif ($in.bodyType // "text") == "html" then
      {hookSpecificOutput: {hookEventName: "PreToolUse",
        updatedInput: ($in + {body: ($body + $line)})}}
    else
      {hookSpecificOutput: {hookEventName: "PreToolUse",
        updatedInput: ($in + {bodyType: "html",
          body: ("<p>" + ($body | esc | gsub("\n"; "<br>")) + "</p>" + $line)})}}
    end
'
