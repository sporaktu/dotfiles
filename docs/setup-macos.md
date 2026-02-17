# macOS Terminal Environment Setup Guide

A comprehensive guide to setting up a modern, productive terminal development environment on macOS. This guide walks through installing and configuring Fish shell, Ghostty, tmux, Neovim, Starship, Yazi, and Volta from scratch.

**Target audience:** A developer comfortable with terminals who is setting up a new machine.

**Note on architecture paths:** All configurations in this guide use Apple Silicon paths (`/opt/homebrew/bin`). If you are on an Intel Mac, replace `/opt/homebrew` with `/usr/local` throughout.

---

## Table of Contents

1. [Homebrew](#1-homebrew)
2. [Fish Shell](#2-fish-shell)
3. [Ghostty Terminal](#3-ghostty-terminal)
4. [tmux](#4-tmux)
5. [Neovim](#5-neovim)
6. [Starship Prompt](#6-starship-prompt)
7. [Yazi File Manager](#7-yazi-file-manager)
8. [Volta (Node.js Version Manager)](#8-volta-nodejs-version-manager)
9. [Quick Reference](#quick-reference)

---

## 1. Homebrew

Homebrew is the de facto package manager for macOS. Almost everything else in this guide is installed through it, so it must come first.

### Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

The installer will prompt you for your password and will install the Xcode Command Line Tools if they are not already present.

After installation, follow the printed instructions to add Homebrew to your PATH. On Apple Silicon, add this to your shell profile:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Verify

```bash
brew --version
# Expected output: Homebrew 4.x.x (or similar)
brew doctor
# Expected output: Your system is ready to brew.
```

---

## 2. Fish Shell

Fish (Friendly Interactive SHell) is a modern shell with excellent autosuggestions, syntax highlighting, and tab completions out of the box — no plugins required for the basics. It uses a slightly different scripting syntax than bash/zsh, but for interactive use it is considerably more pleasant.

### Install

```bash
brew install fish
```

### Add Fish to Allowed Shells

macOS maintains a list of approved shells in `/etc/shells`. You must add Fish to this list before you can set it as your default shell.

```bash
echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
```

### Set Fish as the Default Shell

```bash
chsh -s /opt/homebrew/bin/fish
```

Log out and back in (or open a new terminal session) for the change to take effect.

### Configure Fish

Fish's primary configuration file lives at `~/.config/fish/config.fish`. Create it if it does not exist:

```bash
mkdir -p ~/.config/fish
touch ~/.config/fish/config.fish
```

Below is the complete `config.fish` with all integrations (Starship, Volta, and Yazi) included. You can build this up incrementally as you install each tool, or put it all in place at once.

```fish
# ~/.config/fish/config.fish

# ─── Starship Prompt ────────────────────────────────────────────────────────
# Initializes the Starship prompt. Must come after PATH setup so starship
# is discoverable. See the Starship section for installation.
starship init fish | source

# ─── Volta (Node.js Version Manager) ────────────────────────────────────────
# Volta manages Node.js, npm, and yarn versions per-project automatically.
# These two lines make the `volta` binary and any installed node/npm/yarn
# binaries available in Fish.
set -gx VOLTA_HOME "$HOME/.volta"
fish_add_path "$VOLTA_HOME/bin"

# ─── Yazi Shell Wrapper ──────────────────────────────────────────────────────
# This function wraps the `yazi` binary so that when you quit Yazi, your
# shell's working directory changes to wherever you navigated inside Yazi.
# Without this wrapper, Yazi cannot change the parent shell's directory on exit
# because a child process cannot modify its parent's environment.
#
# Usage: type `y` instead of `yazi` to get the cd-on-exit behavior.
function y
    set tmp (mktemp -t "yazi-cwd.XXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
```

### Verify

```bash
fish --version
# Expected: fish, version 3.x.x

echo $SHELL
# Expected: /opt/homebrew/bin/fish
```

---

## 3. Ghostty Terminal

Ghostty is a fast, feature-rich terminal emulator built in Zig. It supports GPU rendering, native macOS tabs, and has excellent tmux integration. It is configured in a simple key-value format (no TOML or JSON required).

### Install

```bash
brew install --cask ghostty
```

### Configure

Ghostty's config file lives at `~/.config/ghostty/config`. Create it:

```bash
mkdir -p ~/.config/ghostty
touch ~/.config/ghostty/config
```

```
# ~/.config/ghostty/config

# Launch tmux on startup, attaching to or creating a session named "main".
# The session starts in your home directory and uses Fish as the shell inside.
# The -A flag means "attach if the session exists, create it if not" —
# so reopening Ghostty always drops you back into your running session.
command = "/opt/homebrew/bin/tmux new-session -A -s main -c ~ '/opt/homebrew/bin/fish --login --interactive'"

# Use the Catppuccin theme. The dark/light syntax lets Ghostty switch
# automatically based on your macOS appearance setting.
theme = dark:catppuccin-frappe,light:catppuccin-latte
```

### Install Catppuccin Themes

Ghostty loads themes from `~/.config/ghostty/themes/`. Create the directory and add both Catppuccin theme files.

```bash
mkdir -p ~/.config/ghostty/themes
```

**Catppuccin Frappe (dark theme)**

Create `~/.config/ghostty/themes/catppuccin-frappe`:

```
# Catppuccin Frappe for Ghostty
palette = 0=#51576d
palette = 1=#e78284
palette = 2=#a6d189
palette = 3=#e5c890
palette = 4=#8caaee
palette = 5=#f4b8e4
palette = 6=#81c8be
palette = 7=#a5adce
palette = 8=#626880
palette = 9=#e78284
palette = 10=#a6d189
palette = 11=#e5c890
palette = 12=#8caaee
palette = 13=#f4b8e4
palette = 14=#81c8be
palette = 15=#c6d0f5
background = 303446
foreground = c6d0f5
cursor-color = f2d5cf
selection-background = 626880
selection-foreground = c6d0f5
```

**Catppuccin Latte (light theme)**

Create `~/.config/ghostty/themes/catppuccin-latte`:

```
# Catppuccin Latte for Ghostty
palette = 0=#5c5f77
palette = 1=#d20f39
palette = 2=#40a02b
palette = 3=#df8e1d
palette = 4=#1e66f5
palette = 5=#ea76cb
palette = 6=#179299
palette = 7=#acb0be
palette = 8=#6c6f85
palette = 9=#d20f39
palette = 10=#40a02b
palette = 11=#df8e1d
palette = 12=#1e66f5
palette = 13=#ea76cb
palette = 14=#179299
palette = 15=#bcc0cc
background = eff1f5
foreground = 4c4f69
cursor-color = dc8a78
selection-background = acb0be
selection-foreground = 4c4f69
```

### Verify

Launch Ghostty from Spotlight or the Applications folder. It should open directly into a tmux session named "main" (tmux must be installed first — see next section). The color scheme will match your macOS light/dark mode setting.

---

## 4. tmux

tmux is a terminal multiplexer: it lets you run multiple terminal sessions inside a single window, detach from sessions (leaving processes running in the background), and reattach later. With tmux Resurrect and Continuum, your sessions persist across reboots.

### Install

```bash
brew install tmux
```

### Install TPM (tmux Plugin Manager)

TPM handles downloading and managing tmux plugins.

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

### Configure

tmux reads its config from `~/.config/tmux/tmux.conf`. Create it:

```bash
mkdir -p ~/.config/tmux
```

```tmux
# ~/.config/tmux/tmux.conf

# ─── Shell ──────────────────────────────────────────────────────────────────
# Use Fish as the default shell inside tmux panes. The `-l` flag ensures
# Fish is started as a login shell so all profile setup runs correctly.
set-option -g default-shell /opt/homebrew/bin/fish
set -g default-command "/opt/homebrew/bin/fish -l"

# ─── Terminal Colors ─────────────────────────────────────────────────────────
# Tell tmux to advertise 256-color support to programs running inside it.
# This is important for Neovim themes and other color-aware tools.
set -g default-terminal "screen-256color"

# ─── Mouse Support ──────────────────────────────────────────────────────────
# Enable mouse for scrolling, pane selection, and resizing.
set -g mouse on

# ─── Prefix Key ─────────────────────────────────────────────────────────────
# Replace the default Ctrl-b prefix with Ctrl-Space.
# Ctrl-b requires a full hand movement; Ctrl-Space is more ergonomic.
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# ─── Vi Mode ────────────────────────────────────────────────────────────────
# Use vi-style keybindings in copy mode (scrollback buffer navigation).
setw -g mode-keys vi

# ─── Pane Resizing ──────────────────────────────────────────────────────────
# Resize panes with prefix + h/j/k/l (vi-style, 5 cells at a time).
# The -r flag makes these repeatable without re-pressing the prefix.
bind -r h resize-pane -L 5
bind -r j resize-pane -D 5
bind -r k resize-pane -U 5
bind -r l resize-pane -R 5

# ─── Pane Splitting ─────────────────────────────────────────────────────────
# More intuitive split keys: | for vertical split, - for horizontal split.
# Unbind the defaults first to keep things clean.
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# ─── Indexing ───────────────────────────────────────────────────────────────
# Start window and pane numbering at 1 instead of 0.
# This makes the number row on the keyboard match window order naturally.
set -g base-index 1
setw -g pane-base-index 1

# ─── Status Bar ─────────────────────────────────────────────────────────────
set -g status-bg colour235
set -g status-fg white
set -g status-interval 5
set -g status-left-length 40
set -g status-right-length 100
set -g status-left '#[fg=green]#S'
set -g status-right '#[fg=yellow]%Y-%m-%d #[fg=cyan]%H:%M'
set-window-option -g window-status-current-style fg=black,bg=green

# ─── Plugins ────────────────────────────────────────────────────────────────
# tpm: Plugin manager itself
set -g @plugin 'tmux-plugins/tpm'

# tmux-sensible: A set of sensible tmux options everyone can agree on
set -g @plugin 'tmux-plugins/tmux-sensible'

# tmux-resurrect: Save and restore tmux sessions across reboots
#   prefix + Ctrl-s  →  save session
#   prefix + Ctrl-r  →  restore session
set -g @plugin 'tmux-plugins/tmux-resurrect'

# tmux-continuum: Automatically saves the session every 15 minutes
#   and restores it on tmux server start
set -g @plugin 'tmux-plugins/tmux-continuum'

# tmux-prefix-highlight: Highlights the status bar when the prefix is active
set -g @plugin 'tmux-plugins/tmux-prefix-highlight'

# tmux-yank: Copy to system clipboard in copy mode (vi yank with `y`)
set -g @plugin 'tmux-plugins/tmux-yank'

# ─── Initialize TPM ─────────────────────────────────────────────────────────
# This line MUST stay at the very bottom of tmux.conf.
run '~/.tmux/plugins/tpm/tpm'
```

### Install Plugins

Start tmux (or source the config in an existing session):

```bash
tmux
# Inside tmux, source the config:
tmux source-file ~/.config/tmux/tmux.conf
```

Then press `Ctrl-Space + I` (capital I) to install all plugins. TPM will clone each plugin and print a success message when done.

### Verify

```bash
tmux -V
# Expected: tmux 3.x
```

Inside a tmux session, verify plugins are loaded by checking that `~/.tmux/plugins/` contains subdirectories for each plugin.

---

## 5. Neovim

Neovim is a modernized Vim fork with built-in LSP support, Lua scripting, and a rich plugin ecosystem. This setup uses NvChad as a base framework, which provides a curated set of defaults and a plugin configuration layer on top of lazy.nvim.

### Install

```bash
brew install neovim
# ripgrep is required for Telescope's live grep functionality
brew install ripgrep
```

### Install NvChad

NvChad provides the base configuration framework. Clone its starter template into your Neovim config directory:

```bash
git clone https://github.com/NvChad/starter ~/.config/nvim
```

### First Launch

Open Neovim. lazy.nvim will bootstrap itself and install all plugins automatically. This may take a minute or two on first run.

```bash
nvim
```

Wait for the installation to complete. You will see a progress window showing each plugin being installed.

### Customize the Theme

NvChad uses a theme system called base46. To set zenburn as your theme, open the NvChad theme picker inside Neovim:

```
<Space> + t + h
```

Search for "zenburn" and select it. NvChad saves the selection automatically.

Alternatively, set it in `~/.config/nvim/lua/chadrc.lua`:

```lua
-- ~/.config/nvim/lua/chadrc.lua
local M = {}

M.base46 = {
  theme = "zenburn",
}

return M
```

### Install LSP Servers

NvChad includes Mason, a package manager for LSP servers, linters, and formatters. Inside Neovim, run:

```
:MasonInstall html-lsp css-lsp omnisharp typescript-language-server
```

Or open the Mason UI with `:Mason` and install servers interactively.

**Key LSP servers for this setup:**

| Server       | Language            | Mason name                   |
|--------------|---------------------|------------------------------|
| html-lsp     | HTML                | `html-lsp`                   |
| cssls        | CSS/SCSS            | `css-lsp`                    |
| omnisharp    | C#                  | `omnisharp`                  |
| tsserver     | TypeScript/JS/TSX   | `typescript-language-server` |

### Key Plugins Included via NvChad

- **telescope.nvim** — fuzzy finder for files, buffers, grep results
- **nvim-treesitter** — syntax highlighting for C#, TypeScript, JavaScript, TSX, Lua, and more
- **nvim-lspconfig** — LSP client configuration
- **nvim-cmp** — autocompletion engine
- **conform.nvim** — code formatting
- **nvim-dap** — debug adapter protocol for interactive debugging

### Verify

```bash
nvim --version
# Expected: NVIM v0.10.x (or later)
```

Inside Neovim:
- `:checkhealth` — runs a full diagnostic report
- `:Mason` — opens the LSP/tool installer
- `:Lazy` — opens the plugin manager

---

## 6. Starship Prompt

Starship is a minimal, fast, and customizable prompt written in Rust. It works with any shell and shows contextual information (git branch, language version, exit codes) without requiring you to configure anything to get a useful setup.

### Install

```bash
brew install starship
```

### Configure Fish Integration

The initialization line was already included in the `config.fish` shown in the Fish section:

```fish
starship init fish | source
```

This line tells Fish to run `starship init` at shell startup. Starship hooks into the prompt and renders it before each command.

No custom `starship.toml` is needed — the defaults are sensible and look great. If you want to customize later, the config lives at `~/.config/starship.toml`. See the [Starship documentation](https://starship.rs/) for the full list of modules and options.

### Verify

Open a new Fish shell session. Your prompt should now show the Starship-rendered prompt. Navigate into a git repository:

```bash
cd ~/dotfiles
```

You should see the current branch name appear in the prompt automatically.

---

## 7. Yazi File Manager

Yazi is a blazing fast terminal file manager written in Rust. It supports image previews in the terminal, video thumbnails, PDF previews, and an extensible plugin system. The `y` shell wrapper function (added to `config.fish` above) makes Yazi change your shell's working directory when you quit — the feature that makes it genuinely useful as a navigation tool.

### Install Yazi and Dependencies

```bash
brew install yazi

# Required and recommended dependencies for previews and features:
brew install ffmpegthumbnailer  # Video thumbnails
brew install sevenzip           # Archive previews
brew install jq                 # JSON processing
brew install poppler            # PDF previews
brew install fd                 # Fast file finder (used internally)
brew install ripgrep            # Content search
brew install fzf                # Fuzzy finder integration
brew install zoxide             # Smart directory jumping
brew install imagemagick        # Image processing and previews

# For Markdown previews:
brew install glow               # Markdown renderer
brew install piper              # Pipes output through a command
```

### Configure Yazi

Yazi's config directory is `~/.config/yazi/`. Create it and add three configuration files.

```bash
mkdir -p ~/.config/yazi
```

#### yazi.toml

This is the main configuration file. It controls the file manager's behavior.

```toml
# ~/.config/yazi/yazi.toml

[mgr]
# Show hidden files (dotfiles) by default
show_hidden = true

# Panel width ratio: left sidebar : file list : preview pane
# 1:3:5 gives the preview pane the most space, which is useful for
# reading file contents without opening an editor.
ratio = [1, 3, 5]

# ─── Markdown Preview ────────────────────────────────────────────────────────
# Pipe .md files through glow for rendered Markdown preview.
# piper passes the file path as $1 to glow, which renders with a dark style.
[[plugin.prepend_previewers]]
name = "*.md"
run = 'piper -- glow -s dark "$1"'
```

#### keymap.toml

Custom keybindings for the plugins you will install. Add these to `~/.config/yazi/keymap.toml`:

```toml
# ~/.config/yazi/keymap.toml

[manager]
prepend_keymap = [
  # bypass: Open a file with a specific application
  { on = [ "o" ], run = "plugin bypass", desc = "Open file with bypass" },

  # compress: Create archives from selected files
  { on = [ "C" ], run = "plugin compress", desc = "Compress selected files" },

  # diff: Show diff between two selected files
  { on = [ "D" ], run = "plugin diff", desc = "Diff selected files" },

  # copy-file-contents: Copy the contents of a file to the clipboard
  { on = [ "Y" ], run = "plugin copy-file-contents", desc = "Copy file contents to clipboard" },

  # what-size: Show the disk usage of selected files/directories
  { on = [ ".", "s" ], run = "plugin what-size", desc = "Show size of selection" },

  # save-clipboard-to-file: Save clipboard contents to a new file
  { on = [ ".", "p" ], run = "plugin save-clipboard-to-file", desc = "Save clipboard to file" },
]
```

#### init.lua

The Lua init file is used to configure plugins that need initialization. Create `~/.config/yazi/init.lua`:

```lua
-- ~/.config/yazi/init.lua
-- Plugin initialization lives here. Add require() calls for any
-- plugins that expose a setup() function.
```

### Install Yazi Plugins

Yazi uses `ya pack` to manage plugins. Install the following:

```bash
# Navigate utilities
ya pack -a yazi-rs/plugins:bypass
ya pack -a yazi-rs/plugins:compress
ya pack -a yazi-rs/plugins:diff
ya pack -a yazi-rs/plugins:copy-file-contents
ya pack -a yazi-rs/plugins:what-size
ya pack -a yazi-rs/plugins:save-clipboard-to-file
```

### The Shell Wrapper Function

The `y` function already added to `config.fish` handles the "change directory on exit" behavior. To use it: type `y` instead of `yazi`. When you press `q` to quit Yazi, your terminal will `cd` to whatever directory you were in when you quit.

### Verify

```bash
yazi --version
# Expected: Yazi x.x.x

# Launch with the wrapper
y
```

Press `q` to quit and confirm your shell's working directory changed to match your last location in Yazi.

---

## 8. Volta (Node.js Version Manager)

Volta is a JavaScript toolchain manager that automatically switches Node.js (and npm/yarn) versions based on your project's `package.json`. Unlike nvm, Volta is written in Rust and adds zero overhead to shell startup — version switching happens transparently when you `cd` into a project directory.

### Install

Use the official Volta installer:

```bash
curl https://get.volta.sh | bash
```

The installer typically adds setup lines to `~/.bash_profile` or `~/.zshenv`. Since you are using Fish shell, skip those and instead use the Fish-specific setup already in `config.fish`:

```fish
set -gx VOLTA_HOME "$HOME/.volta"
fish_add_path "$VOLTA_HOME/bin"
```

These two lines are sufficient for Fish to find Volta and all binaries it manages.

### Install Node.js

```bash
# Install the latest LTS version of Node and set it as the global default
volta install node

# Or install a specific version
volta install node@20

# Or explicitly request LTS
volta install node@lts
```

`volta install node` downloads the specified version, installs it under `~/.volta/`, and sets it as the default for any project that does not pin a specific version.

### Verify Global Default

```bash
volta list
# Expected output lists node and npm with their installed versions

node --version
# Expected: v20.x.x (or whatever version you installed)

npm --version
# Expected: 10.x.x (bundled with the Node version)
```

### Pin a Version to a Project

When you are inside a project that should use a specific Node version, pin it:

```bash
cd ~/my-project
volta pin node@18
```

This writes a `volta` field to `package.json`. Anyone using Volta who clones the repo will automatically get the correct Node version.

### Install Global Tools

Use `volta install` for global CLI tools to keep them version-managed:

```bash
volta install yarn
volta install pnpm
volta install typescript
```

These tools will be pinned to the Node version that was active when you installed them, avoiding version mismatch issues.

---

## Quick Reference

### Tool Versions Check

```bash
brew --version
fish --version
ghostty --version
tmux -V
nvim --version
starship --version
yazi --version
volta --version
node --version
```

### Key Keybindings

#### tmux (prefix: `Ctrl-Space`)

| Keybinding          | Action                        |
|---------------------|-------------------------------|
| `Ctrl-Space \|`     | Split pane vertically         |
| `Ctrl-Space -`      | Split pane horizontally       |
| `Ctrl-Space h/j/k/l`| Resize pane (5 cells)         |
| `Ctrl-Space d`      | Detach from session           |
| `Ctrl-Space [`      | Enter copy/scroll mode        |
| `Ctrl-Space Ctrl-s` | Save session (resurrect)      |
| `Ctrl-Space Ctrl-r` | Restore session (resurrect)   |
| `Ctrl-Space I`      | Install plugins (TPM)         |

#### Neovim (NvChad)

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Space f f`     | Find files (Telescope)    |
| `Space f g`     | Live grep (Telescope)     |
| `Space t h`     | Change theme              |
| `Space c h`     | NvChad cheatsheet         |
| `:Mason`        | Open LSP installer        |
| `:Lazy`         | Open plugin manager       |

#### Yazi

| Keybinding | Action                      |
|------------|-----------------------------|
| `o`        | Open with bypass            |
| `C`        | Compress selected files     |
| `D`        | Diff selected files         |
| `Y`        | Copy file contents          |
| `. s`      | Show size of selection      |
| `. p`      | Save clipboard to file      |
| `q`        | Quit (and cd to current dir if using `y` wrapper) |

### Config File Locations

| Tool      | Config Path                              |
|-----------|------------------------------------------|
| Fish      | `~/.config/fish/config.fish`             |
| Ghostty   | `~/.config/ghostty/config`               |
| tmux      | `~/.config/tmux/tmux.conf`               |
| Neovim    | `~/.config/nvim/`                        |
| Starship  | `~/.config/starship.toml` (optional)     |
| Yazi      | `~/.config/yazi/`                        |
| Volta     | `~/.volta/` (managed automatically)      |

### Common Operations

```bash
# Reload Fish config without restarting
source ~/.config/fish/config.fish

# Reload tmux config inside a running session
tmux source-file ~/.config/tmux/tmux.conf

# Attach to (or create) the main tmux session
tmux new-session -A -s main

# List all tmux sessions
tmux ls

# Launch Yazi with directory-change-on-exit
y

# Install a Node.js version with Volta
volta install node@20

# Check what Volta is managing
volta list

# Update all Homebrew packages
brew upgrade
```

### Useful Homebrew Commands

```bash
brew list          # List installed packages
brew outdated      # Show packages with updates available
brew upgrade       # Upgrade all packages
brew cleanup       # Remove old versions
brew info <pkg>    # Show info about a package
brew search <pkg>  # Search for a package
```
