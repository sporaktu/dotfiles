# overwrite greeting
# potentially disabling fastfetch
# function fish_greeting
#    echo "Welcome, $USER!"
#    echo "System Information:"
#    uname -a
# end
fish_add_path /opt/homebrew/bin
fish_add_path $HOME/.volta/bin
fish_add_path $HOME/.local/bin
set -Ux EDITOR nvim
set -Ux VISUAL nvim
alias localllama="python3 ~/claude_local.py"
alias y="yazi"

starship init fish | source

