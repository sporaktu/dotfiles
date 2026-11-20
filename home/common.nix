{ pkgs, ... }:
let
  fromEnv =
    name:
    let
      value = builtins.getEnv name;
    in
    if value == "" then throw "\$${name} is empty: run home-manager with --impure." else value;
  user = fromEnv "USER";
  home = fromEnv "HOME";
in
{
  home.username = user;
  home.homeDirectory = home;

  # The home-manager release this config was first written against. It is not a
  # version pin; leave it alone when updating.
  home.stateVersion = "25.11";

  # The same list install.sh installs with brew and apt. Packages only: no
  # programs.<name> modules, because those write config files that Stow owns.
  home.packages = with pkgs; [
    fish
    fzf
    git
    jq
    lazydocker
    neovim
    ripgrep
    starship
    stow
    tuios
    yazi
  ];

  programs.home-manager.enable = true;
}
