# Global agent instructions (Pi)

## Glimpse windows

Close a Glimpse window as soon as you are done with it. Never leave one open at the end of a turn.

- **Windows you open** (glimpse skill): use `prompt()` or `autoClose: true` for one-shot dialogs, and
  call `win.close()` on any window from `open()` once you have what you need.
- **Windows the MCP adapter opens** (an MCP tool with a UI, titled `MCP · <server> · <tool>`, for
  example Atlassian's create and edit tools): the adapter has no close action, so once the tool's
  result is back and nothing in the window is waiting on the user, close it with
  `pkill -f 'glimpseui/src/glimpse .*--title MCP '`.
- Leave a window open only while it is waiting for the user's input, or when the user asked to keep
  it. Before ending a turn, check with `pgrep -fl 'glimpseui/src/glimpse '` and close what is left.
