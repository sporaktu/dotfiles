{
  description = "CLI packages shared by the Mac and the Arch machines (configs stay on Stow)";

  # Scope: Nix owns the command-line tools only. Homebrew keeps casks, fonts and
  # yabai/skhd/sketchybar; pacman keeps the Hyprland desktop; Stow keeps every
  # config file. install.sh is untouched and still works without Nix.
  #
  # First run (the files must be known to git: `git add flake.nix home`):
  #   nix run home-manager/master -- switch --impure --flake .#mac    # Apple Silicon
  #   nix run home-manager/master -- switch --impure --flake .#arch   # x86_64 Linux
  # Later: home-manager switch --impure --flake .#mac
  # Update pins: nix flake update      Undo a switch: home-manager generations
  #
  # --impure is needed because the user name and home directory are read from
  # $USER and $HOME, so this public repo names no account.

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      mkHome =
        system: osModule:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            ./home/common.nix
            osModule
          ];
        };
    in
    {
      homeConfigurations = {
        mac = mkHome "aarch64-darwin" ./home/darwin.nix;
        arch = mkHome "x86_64-linux" ./home/linux.nix;
      };
    };
}
