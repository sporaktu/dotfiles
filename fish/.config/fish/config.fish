# overwrite greeting
# potentially disabling fastfetch
# function fish_greeting
#    echo "Welcome, $USER!"
#    echo "System Information:"
#    uname -a
# end
fish_add_path /opt/homebrew/bin
fish_add_path $HOME/.volta/bin
set -Ux EDITOR nvim
set -Ux VISUAL nvim
set -U fish_user_paths /opt/homebrew/bin/fish $fish_user_paths
starship init fish | source

