{ ... }:
{
  # Makes Nix-installed programs behave on a non-NixOS distro (XDG data dirs,
  # locale archive, terminfo).
  targets.genericLinux.enable = true;

  # Linux-only CLI packages go here.
  #
  # Still installed by pacman: Hyprland, waybar, wofi, kitty, pipewire and the
  # rest of the desktop. GUI and GL programs from Nix need wrappers on Arch.
  home.packages = [ ];
}
