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
set -gx EDITOR nvim
set -gx VISUAL nvim
alias localllama="python3 ~/claude_local.py"
alias y="yazi"

starship init fish | source

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
