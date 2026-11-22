# Remind machines that pulled the repo but haven't linked the Pi config yet (see scripts/setup-pi.sh).
if status is-interactive; and command -q pi; and not test -e ~/.pi/agent/extensions/dotfiles-sync
    set_color yellow
    echo "dotfiles: Pi config isn't linked on this machine. Run ~/dotfiles/scripts/setup-pi.sh"
    set_color normal
end
