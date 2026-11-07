function claude-teams --description 'Run Claude Code agent teams with teammates as tuios panes'
    tuios tmux-shim -- env CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude $argv
end
