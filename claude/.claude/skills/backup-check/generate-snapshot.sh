#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT_PATH="$HOME/.claude/skills/backup-check/MACHINE-SNAPSHOT.md"

echo "Generating machine snapshot..."

cat > "$SNAPSHOT_PATH" << 'HEADER'
# Machine Snapshot

> Auto-generated restore document. Claude Code can consume this to restore a Mac to this state.
> To restore: give this file to Claude Code and say "restore my machine from this snapshot".

HEADER

# Timestamp
echo "**Generated:** $(date +%Y-%m-%d\ %H:%M:%S)" >> "$SNAPSHOT_PATH"
echo "**Machine:** $(scutil --get ComputerName 2>/dev/null || hostname)" >> "$SNAPSHOT_PATH"
echo "**macOS:** $(sw_vers -productVersion 2>/dev/null || echo unknown)" >> "$SNAPSHOT_PATH"
echo "**Arch:** $(uname -m)" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- Homebrew ---
echo "## 1. Homebrew Packages" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Install Homebrew first: \`/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\`" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo '```ruby' >> "$SNAPSHOT_PATH"
brew bundle dump --file=- 2>/dev/null >> "$SNAPSHOT_PATH"
echo '```' >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Restore: save the above as \`Brewfile\` and run \`brew bundle install --file=Brewfile\`" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- Volta / Node ---
echo "## 2. Node.js (Volta)" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Install Volta: \`curl https://get.volta.sh | bash\`" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo '```bash' >> "$SNAPSHOT_PATH"
volta list all 2>/dev/null | while IFS= read -r line; do
    echo "# $line"
done >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "volta install node@$(node -v 2>/dev/null | tr -d 'v')" >> "$SNAPSHOT_PATH"
# Global npm packages
npm list -g --depth=0 --json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
deps = data.get('dependencies', {})
skip = {'corepack', 'npm'}
for name, info in deps.items():
    if name not in skip:
        print(f'npm install -g {name}@{info.get(\"version\", \"latest\")}')
" 2>/dev/null >> "$SNAPSHOT_PATH"
echo '```' >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- Python ---
echo "## 3. Python Packages" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo '```bash' >> "$SNAPSHOT_PATH"
echo "# Python $(python3 --version 2>/dev/null | awk '{print $2}') (installed via Homebrew)" >> "$SNAPSHOT_PATH"
pip3 list --user --format=freeze 2>/dev/null | while IFS= read -r pkg; do
    echo "pip3 install --user $pkg"
done >> "$SNAPSHOT_PATH"
echo '```' >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- Git Repos ---
echo "## 4. Git Repositories" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Clone all repos to restore project directories:" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo '```bash' >> "$SNAPSHOT_PATH"

{
# Top-level repos
for dir in "$HOME"/*/; do
    if [ -d "$dir/.git" ]; then
        name=$(basename "$dir")
        remote=$(git -C "$dir" remote get-url origin 2>/dev/null || echo "")
        branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "main")
        if [ -n "$remote" ]; then
            echo "git clone $remote ~/$name && git -C ~/$name checkout $branch"
        fi
    fi
done

# Nested repos in known directories
for parent in projects work; do
    echo ""
    echo "# ~/$parent/"
    echo "mkdir -p ~/$parent"
    for dir in "$HOME/$parent"/*/; do
        if [ -d "$dir/.git" ]; then
            name=$(basename "$dir")
            remote=$(git -C "$dir" remote get-url origin 2>/dev/null || echo "")
            branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "main")
            if [ -n "$remote" ]; then
                echo "git clone $remote ~/$parent/$name && git -C ~/$parent/$name checkout $branch"
            fi
        fi
    done
done 2>/dev/null
} >> "$SNAPSHOT_PATH"

echo '```' >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- Dotfiles ---
echo "## 5. Dotfiles (GNU Stow)" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Your dotfiles repo manages configs for: fish, ghostty, nvim, sketchybar, skhd, yabai, tmux, yazi, and more." >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo '```bash' >> "$SNAPSHOT_PATH"
echo "# Clone dotfiles repo (already in git repos above), then:" >> "$SNAPSHOT_PATH"
echo "cd ~/dotfiles" >> "$SNAPSHOT_PATH"
# List stow packages (directories with no leading dot that aren't docs/scripts)
for pkg in "$HOME"/dotfiles/*/; do
    name=$(basename "$pkg")
    case "$name" in docs|scripts|screenshots) continue ;; esac
    echo "stow $name"
done >> "$SNAPSHOT_PATH"
echo '```' >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- Git Config ---
echo "## 6. Git Configuration" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo '```bash' >> "$SNAPSHOT_PATH"
git config --global --list 2>/dev/null | while IFS='=' read -r key val; do
    echo "git config --global $key \"$val\""
done >> "$SNAPSHOT_PATH"
echo '```' >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- SSH Keys ---
echo "## 7. SSH Keys" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Copy \`~/.ssh/\` from backup. Keys present:" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
ls "$HOME/.ssh/" 2>/dev/null | while IFS= read -r f; do
    echo "- \`$f\`"
done >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "After copying, fix permissions: \`chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_* ~/.ssh/*_id_*\`" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- LaunchAgents ---
echo "## 8. LaunchAgents (Services)" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Active user services:" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
ls "$HOME/Library/LaunchAgents/" 2>/dev/null | while IFS= read -r f; do
    echo "- \`$f\`"
done >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Homebrew services restore automatically via \`brew services\`. Custom plists need manual restore from dotfiles or backup." >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- macOS Apps (non-Homebrew) ---
echo "## 9. macOS Applications" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Apps installed outside Homebrew (install manually or from company MDM):" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# Get brew cask apps for comparison
brew_apps=$(brew list --cask 2>/dev/null | tr '[:upper:]' '[:lower:]')

ls /Applications/ 2>/dev/null | grep "\.app$" | sed 's/\.app$//' | while IFS= read -r app; do
    app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    if ! echo "$brew_apps" | grep -q "$app_lower"; then
        echo "- $app"
    fi
done >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- Claude Code ---
echo "## 10. Claude Code Configuration" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
echo "Key paths to restore from backup:" >> "$SNAPSHOT_PATH"
echo "- \`~/.claude/CLAUDE.md\` — global instructions" >> "$SNAPSHOT_PATH"
echo "- \`~/.claude/settings.json\` — settings" >> "$SNAPSHOT_PATH"
echo "- \`~/.claude/settings.local.json\` — local settings" >> "$SNAPSHOT_PATH"
echo "- \`~/.claude/skills/\` — custom skills" >> "$SNAPSHOT_PATH"
echo "- \`~/.claude/hooks/\` — hooks configuration" >> "$SNAPSHOT_PATH"
echo "- \`~/.claude/plugins/\` — plugins" >> "$SNAPSHOT_PATH"
echo "- \`~/.claude/commands/\` — custom commands" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"

# --- Restore Order ---
echo "## Restore Order" >> "$SNAPSHOT_PATH"
echo "" >> "$SNAPSHOT_PATH"
cat >> "$SNAPSHOT_PATH" << 'RESTORE'
1. Install Xcode Command Line Tools: `xcode-select --install`
2. Install Homebrew
3. Run `brew bundle install --file=Brewfile` (installs all packages, casks, taps)
4. Install Volta and Node.js
5. Install global npm packages
6. Install Python user packages
7. Clone dotfiles repo and run `stow` for each package
8. Clone all git repos
9. Copy SSH keys from backup, fix permissions
10. Copy Claude Code config from backup (`~/.claude/`)
11. Set fish as default shell: `chsh -s /opt/homebrew/bin/fish`
12. Start services: `brew services start ollama && brew services start sketchybar`
13. Load custom LaunchAgents
14. Install remaining macOS apps manually
RESTORE

echo ""
echo "Snapshot saved to: $SNAPSHOT_PATH"
