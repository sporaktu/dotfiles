# overwrite greeting
# potentially disabling fastfetch
# function fish_greeting
#    echo "Welcome, $USER!"
#    echo "System Information:"
#    uname -a
# end

set -Ux EDITOR nvim
set -Ux VISUAL nvim
set -U fish_user_paths /usr/bin $fish_user_paths
starship init fish | source

