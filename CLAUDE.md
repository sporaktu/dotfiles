# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive dotfiles repository that configures a Fish shell-based development environment with tuios, Neovim, terminal emulators, and macOS window management. The configuration uses GNU Stow for symlink management and supports both macOS and Linux systems.

## Setup and Installation

### Quick Setup
```bash
./install.sh mac    # For macOS
./install.sh linux  # For Linux
```

### Manual Setup with Stow
Link configurations to `$HOME`:
```bash
stow --target=$HOME fish kitty nvim tuios ghostty superfile claude
stow --target=$HOME sketchybar yabai skhd   # macOS only
```

Add specific applications as needed:
```bash
stow --target=$HOME APP
```

## Key Components

### Shell Environment
- **Fish Shell**: Primary shell with Starship prompt
- **Fish config**: `fish/.config/fish/config.fish`
- Key paths: `/opt/homebrew/bin`, `~/.volta/bin`
- Custom functions in `fish/.config/fish/functions/`

### Terminal Multiplexing
- **tuios**: Terminal multiplexer and window manager with a session daemon and coding-agent support
- Config: `tuios/.config/tuios/config.toml` (hot-reloaded; settings-page changes are written here, so review them before committing)
- Per-machine overrides: optional, untracked `~/.config/tuios/local.toml`
- macOS: tuios reads `~/Library/Application Support/tuios/config.toml`, so `install.sh mac` symlinks that file to `~/.config/tuios/config.toml`
- Leader: `Ctrl-Space`, with the tmux key preset (a tmux window is a workspace, a tmux pane is a window)
- Auto-starts with both Kitty and Ghostty terminals, attaching to session `main`
- Claude Code: `tuios integration install claude-code` writes hooks into `settings.json` and a tuios skill; `claude-teams` runs agent teams in panes through `tuios tmux-shim`
- **tmux**: Previous multiplexer; config kept in `tmux/` but not installed or stowed by `install.sh`

### Window Management (macOS)
- **yabai**: Tiling window manager (primary; space focus/move needs the scripting addition, which needs SIP partly disabled)
- **skhd**: Hotkey daemon driving yabai
- **sketchybar**: Custom status bar with widgets
- **AeroSpace**: Alternative i3-like config kept in the repo; not installed or stowed
- Config files:
  - `yabai/.config/yabai/yabairc`
  - `skhd/.config/skhd/skhdrc`
  - `sketchybar/.config/sketchybar/sketchybarrc`
  - `aerospace/.config/aerospace/aerospace.toml` (unused)
- Custom scripts in respective `scripts/` and `plugins/` directories

### Terminal Emulators
- **Kitty**: Uses MesloLGS Nerd Font, Catppuccin theme, launches tuios
- **Ghostty**: Launches tuios, uses Catppuccin themes

## Architecture

### Configuration Management
- Uses GNU Stow with `--target=$HOME` for symlink creation
- Most apps: `APP/.config/APP/*` → `~/.config/APP/*`
- Dotfile apps (e.g. claude): `APP/.APP/*` → `~/.APP/*`
- Variables and themes defined in separate files (e.g., `sketchybar/variables.sh`)

### macOS Integration
- Sketchybar widgets for system monitoring (CPU, RAM, battery, notifications)
- yabai window management with skhd keybindings (Alt+hjkl focus, Shift+Alt+hjkl warp) and custom padding
- App-specific rules for excluding applications from tiling
- Display-aware padding adjustment (built-in vs external monitors)

### Cross-Platform Support
- Platform-specific package installation in `install.sh`
- Conditional configurations where needed
- Font installation handled per platform

## Development Workflow

### Making Changes to Configurations
1. Edit files in the dotfiles directory (e.g., `fish/.config/fish/config.fish`)
2. Changes are immediately reflected via Stow symlinks
3. Restart applications or reload configs as needed:
   - Fish: `source ~/.config/fish/config.fish`
   - tuios: saves apply at once; `tuios config apply` forces a reload
   - yabai: `yabai --restart-service`
   - skhd: `skhd --reload`
   - sketchybar: `sketchybar --reload`

### Adding New Applications
1. Create directory structure: `APP/.config/APP/` (or `APP/.APP/` for dotfile dirs)
2. Add configuration files in the appropriate subdirectory
3. Run `stow --target=$HOME APP` to link
4. Update `install.sh` if new dependencies are needed

## Dependencies

### Core Tools
- Fish shell, Starship prompt, tuios, Neovim, Stow, ripgrep
- Git (for repository management)

### macOS Specific
- yabai, skhd (`asmvik/formulae`), sketchybar (`FelixKratz/formulae`), all installed by `install.sh mac`
- Nerd Fonts (MesloLGS, CaskaydiaCove)

### Terminal Emulators
- Kitty and/or Ghostty
- Both configured to launch tuios automatically