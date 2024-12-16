source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
set -Ux EDITOR nvim
set -Ux VISUAL nvim
set -U fish_user_paths /usr/bin $fish_user_paths

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# cuda
set -Ux CC /usr/bin/gcc-13
set -Ux CXX /usr/bin/g++-13

set -Ux PATH /opt/cuda/bin $PATH
set -Ux LD_LIBRARY_PATH /opt/cuda/lib64 $LD_LIBRARY_PATH
set -U fish_user_paths /opt/cuda/bin $fish_user_paths


