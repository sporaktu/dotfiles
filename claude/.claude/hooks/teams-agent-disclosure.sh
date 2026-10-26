#!/usr/bin/env bash
# teams-agent-disclosure.sh
# PreToolUse hook: every Teams message Claude sends on Gray's behalf must say so.
# If the body doesn't already end with it, a last line in italics, "Sent by
# Claude on Gray’s behalf", is appended via updatedInput; the rest of tool_input
# is passed through as-is.
#
# Teams draws italics only in HTML, so a plain-text body is converted to HTML
# first, its newlines kept as <br>. An HTML body may use only plain formatting
# tags with no attributes (href on links aside); anything else that could hide
# the line, such as a comment, a style or an unclosed tag, gets the send denied.
#
# Wired to the Microsoft 365 connector's teams_send_chat_message,
# teams_send_channel_message and teams_reply_channel_message tools.

set -euo pipefail

# A failed hook must stop the send, never let an unsigned message through:
# exit 2 blocks the tool call.
trap 'echo "teams-agent-disclosure: could not add the disclosure line, so the message was not sent" >&2; exit 2' ERR

SIGNATURE="Sent by Claude on Gray’s behalf"

# The only tags an HTML body may carry: no attributes, save a quoted href on <a>.
ALLOWED_TAGS='</?(p|br|b|strong|i|em|u|s|ul|ol|li|code|pre|blockquote|h[1-6]|table|thead|tbody|tr|th|td)\s*/?>|<a\s+href="[^"<>]*"\s*>|</a\s*>'

# Read the payload straight from stdin: piping it through echo can turn the JSON's
# \n escapes into raw newlines, which jq rejects.
jq -c --arg sig "$SIGNATURE" --arg allowed "$ALLOWED_TAGS" '
  def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
  def rtrim: sub("\\s+$"; "");
  # Safe when no "<" is left once the allowed tags are removed.
  def safe: gsub($allowed; ""; "i") | test("<") | not;
  .tool_input as $in
  | if ($in.body // "" | type) != "string" then error("body is not a string") else . end
  | ($in.body // "" | rtrim) as $body
  | ("<p><em>" + ($sig | esc) + "</em></p>") as $line
  | if ($in.bodyType // "text") == "html" then
      if ($body | safe | not) then
        {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
          permissionDecisionReason: "teams-agent-disclosure: this HTML body uses markup the disclosure hook does not allow. Use only p, br, b, strong, i, em, u, s, ul, ol, li, code, pre, blockquote, h1-h6 and table tags with no attributes, links as <a href=\"...\">, and escape a literal < as &lt;."}}
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
