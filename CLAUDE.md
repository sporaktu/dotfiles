# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive dotfiles repository that configures a Fish shell-based development environment with tmux, Neovim, terminal emulators, and macOS window management. The configuration uses GNU Stow for symlink management and supports both macOS and Linux systems.

## Setup and Installation

### Quick Setup
```bash
./install.sh mac    # For macOS
./install.sh linux  # For Linux
```

### Manual Setup with Stow
Link configurations to `~/.config`:
```bash
stow --target=$HOME/.config fish kitty nvim tmux
```

Add specific applications as needed:
```bash
stow --target=$HOME/.config sketchybar yabai ghostty
```

## Key Components

### Shell Environment
- **Fish Shell**: Primary shell with Starship prompt
- **Fish config**: `fish/.config/fish/config.fish`
- Key paths: `/opt/homebrew/bin`, `~/.volta/bin`
- Custom functions in `fish/.config/fish/functions/`

### Terminal Multiplexing
- **tmux**: Session management with plugin support
- Config: `tmux/.config/tmux/tmux.conf`
- Prefix: `Ctrl-Space`
- Auto-starts with both Kitty and Ghostty terminals
- Plugins: tpm, resurrect, continuum, yank, prefix-highlight

### Window Management (macOS)
- **yabai**: Tiling window manager
- **sketchybar**: Custom status bar with widgets
- Config files: `yabai/.config/yabai/yabairc`, `sketchybar/.config/sketchybar/sketchybarrc`
- Custom scripts in respective `scripts/` and `plugins/` directories

### Terminal Emulators
- **Kitty**: Uses MesloLGS Nerd Font, Catppuccin theme, launches tmux
- **Ghostty**: Auto-starts tmux session named "main", uses Catppuccin themes

## Architecture

### Configuration Management
- Uses GNU Stow for symlink creation from `APP/.config/APP/*` to `~/.config/APP/*`
- Each application has its own directory with `.config` subdirectory structure
- Variables and themes defined in separate files (e.g., `sketchybar/variables.sh`)

### macOS Integration
- Sketchybar widgets for system monitoring (CPU, RAM, battery, notifications)
- yabai window management with focus-follows-mouse and custom padding
- App-specific rules for excluding applications from tiling
- Display-aware padding adjustment via custom scripts

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
   - tmux: `tmux source-file ~/.config/tmux/tmux.conf`
   - yabai: `yabai --restart-service`
   - sketchybar: `sketchybar --reload`

### Adding New Applications
1. Create directory structure: `APP/.config/APP/`
2. Add configuration files in the appropriate subdirectory
3. Run `stow --target=$HOME/.config APP` to link
4. Update `install.sh` if new dependencies are needed

## Dependencies

### Core Tools
- Fish shell, Starship prompt, tmux, Neovim, Stow, ripgrep
- Git (for repository management)

### macOS Specific
- yabai, sketchybar (via Homebrew)
- Nerd Fonts (MesloLGS, CaskaydiaCove)

### Terminal Emulators
- Kitty and/or Ghostty
- Both configured to launch tmux automatically