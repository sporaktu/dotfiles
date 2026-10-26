#!/usr/bin/env bash
# teams-agent-disclosure.sh
# PreToolUse hook: every Teams message Claude sends on Gray's behalf must say so.
# If the body doesn't already end with it, a last line in italics, "Sent by
# Claude on Gray’s behalf", is appended via updatedInput; the rest of tool_input
# is passed through as-is.
#
# Teams draws italics only in HTML, so a plain-text body is converted to HTML
# first, its newlines kept as <br>. An HTML body with markup that could hide the
# line (a comment, a hidden-content tag, a style or hidden attribute) is denied.
#
# Wired to the Microsoft 365 connector's teams_send_chat_message,
# teams_send_channel_message and teams_reply_channel_message tools.

set -euo pipefail

# A failed hook must stop the send, never let an unsigned message through:
# exit 2 blocks the tool call.
trap 'echo "teams-agent-disclosure: could not add the disclosure line, so the message was not sent" >&2; exit 2' ERR

SIGNATURE="Sent by Claude on Gray’s behalf"

HIDING='<!--|<\s*/?\s*(style|script|template|noscript|details|summary|iframe|object)\b|<[^>]*\s(style|hidden)\b[^>]*>'

# Read the payload straight from stdin: piping it through echo can turn the JSON's
# \n escapes into raw newlines, which jq rejects.
jq -c --arg sig "$SIGNATURE" --arg hiding "$HIDING" '
  def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
  def rtrim: sub("\\s+$"; "");
  .tool_input as $in
  | if ($in.body // "" | type) != "string" then error("body is not a string") else . end
  | ($in.body // "" | rtrim) as $body
  | ("<p><em>" + ($sig | esc) + "</em></p>") as $line
  | if ($in.bodyType // "text") == "html" then
      if ($body | test($hiding; "i")) then
        {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
          permissionDecisionReason: "teams-agent-disclosure: this HTML body has markup that could hide the disclosure line (a comment, a hidden-content tag, or a style or hidden attribute). Resend it without that markup."}}
      elif ($body | endswith($line)) then
        empty
      else
        {hookSpecificOutput: {hookEventName: "PreToolUse",
          updatedInput: ($in + {body: ($body + $line)})}}
      end
    else
      {hookSpecificOutput: {hookEventName: "PreToolUse",
        updatedInput: ($in + {bodyType: "html",
          body: ("<p>" + ($body | esc | gsub("\n"; "<br>")) + "</p>" + $line)})}}
    end
'
