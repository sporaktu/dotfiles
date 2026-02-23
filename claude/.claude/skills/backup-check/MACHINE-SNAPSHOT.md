# Machine Snapshot

> Auto-generated restore document. Claude Code can consume this to restore a Mac to this state.
> To restore: give this file to Claude Code and say "restore my machine from this snapshot".

**Generated:** 2026-02-23 14:09:57
**Machine:** LT-CP9PN2Y6F9
**macOS:** 15.7.4
**Arch:** arm64

## 1. Homebrew Packages

Install Homebrew first: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

```ruby
tap "atlassian/acli"
tap "azure/functions"
tap "felixkratz/formulae"
tap "koekeishiya/formulae"
tap "microsoft/mssql-release"
tap "nikitabobko/tap"
brew "azure-cli"
brew "black"
brew "fish"
brew "gh"
brew "glow"
brew "go-jira"
brew "ios-deploy"
brew "lazygit"
brew "mypy"
brew "neovim"
brew "ollama", restart_service: :changed
brew "openjdk@17"
brew "pandoc"
brew "ripgrep"
brew "ruff"
brew "sevenzip"
brew "shellcheck"
brew "sqlcmd"
brew "starship"
brew "stow"
brew "tmux"
brew "volta"
brew "watchman"
brew "xcodegen"
brew "yazi"
brew "atlassian/acli/acli"
brew "azure/functions/azure-functions-core-tools@4"
brew "felixkratz/formulae/sketchybar"
brew "koekeishiya/formulae/skhd"
brew "koekeishiya/formulae/yabai"
cask "alfred"
cask "betterdisplay"
cask "bitwarden"
cask "dotnet-sdk"
cask "font-hack-nerd-font"
cask "ghostty"
cask "jetbrains-toolbox"
cask "jordanbaird-ice"
cask "miro"
cask "slack"
```

Restore: save the above as `Brewfile` and run `brew bundle install --file=Brewfile`

## 2. Node.js (Volta)

Install Volta: `curl https://get.volta.sh | bash`

```bash
# runtime node@22.16.0 (default)
# package-manager yarn@4.9.2 (default)
# package @github/copilot@0.0.342 / copilot / node@22.16.0 npm@built-in (default)
# package typescript@project / tsc, tsserver / node@project npm@project (current @ /Users/gray.karegeannes/nanoclaw/package.json)

volta install node@22.16.0
npm install -g @anthropic-ai/claude-code@2.1.45
```

## 3. Python Packages

```bash
# Python 3.14.3 (installed via Homebrew)
pip3 install --user et_xmlfile==2.0.0
pip3 install --user numpy==2.3.4
pip3 install --user openpyxl==3.1.5
pip3 install --user pandas==2.3.3
pip3 install --user python-dateutil==2.9.0.post0
pip3 install --user pytz==2025.2
pip3 install --user six==1.17.0
pip3 install --user tzdata==2025.2
```

## 4. Git Repositories

Clone all repos to restore project directories:

```bash
git clone git@github.com:sporaktu/dotfiles.git ~/dotfiles && git -C ~/dotfiles checkout main
git clone git@github.com:sporaktu/nanoclaw.git ~/nanoclaw && git -C ~/nanoclaw checkout main

# ~/projects/
mkdir -p ~/projects
git clone git@github.com:sporaktu/personal-assistant-agent.git ~/projects/personal-assistant-agent && git -C ~/projects/personal-assistant-agent checkout main

# ~/work/
mkdir -p ~/work
git clone git@ssh.dev.azure.com:v3/locumtenensdotcom1/Accounting%20Ecosystem/Accounting%20Ecosystem ~/work/Accounting%20Ecosystem && git -C ~/work/Accounting%20Ecosystem checkout main
git clone git@github.com:LocumTenens-com/actionable-agile.git ~/work/actionable-agile && git -C ~/work/actionable-agile checkout main
git clone git@github.com:LocumTenens-com/atlassian-admin.git ~/work/atlassian-admin && git -C ~/work/atlassian-admin checkout main
git clone git@github.com:LocumTenens-com/azure-subscription-permission-auditor.git ~/work/azure-subscription-permission-auditor && git -C ~/work/azure-subscription-permission-auditor checkout main
git clone git@ssh.dev.azure.com:v3/locumtenensdotcom1/Azure%20Tool%20Chest/Azure%20Tool%20Chest ~/work/azure && git -C ~/work/azure checkout main
git clone git@github.com:LocumTenens-com/claude-autonomous-agentic-programmer.git ~/work/claude-autonomous-agentic-programmer && git -C ~/work/claude-autonomous-agentic-programmer checkout main
git clone git@github.com:kevnm67/ClaudeTeamUsageApp.git ~/work/ClaudeTeamUsageApp && git -C ~/work/ClaudeTeamUsageApp checkout main
git clone git@ssh.dev.azure.com:v3/locumtenensdotcom1/Clinical%20Portal/Clinical%20Portal ~/work/Clinical%20Portal && git -C ~/work/Clinical%20Portal checkout master
git clone git@ssh.dev.azure.com:v3/locumtenensdotcom1/Coding%20Challenges/Coding%20Challenges ~/work/coding-challenges && git -C ~/work/coding-challenges checkout feature/blog-submission-system
git clone git@bitbucket.org:kimedicsllc/console-portal.git ~/work/console-portal && git -C ~/work/console-portal checkout main
git clone git@ssh.dev.azure.com:v3/locumtenensdotcom1/Data Lake/Data Lake ~/work/Data Lake && git -C ~/work/Data Lake checkout maint/update-job-rec-api-data
git clone git@github.com:LocumTenens-com/interview-challenges.git ~/work/interview-challenges && git -C ~/work/interview-challenges checkout main
git clone git@github.com:LocumTenens-com/JobRecommendationApi.git ~/work/JobRecommendationApi && git -C ~/work/JobRecommendationApi checkout fix/bicep-storage-bootstrap
git clone git@ssh.dev.azure.com:v3/ltmarketing/LocumTenens.com/LocumTenens.com ~/work/LocumTenens.com && git -C ~/work/LocumTenens.com checkout master
git clone git@github.com:LocumTenens-com/LT-Claude-Code-Skills.git ~/work/LT-Claude-Code-Skills && git -C ~/work/LT-Claude-Code-Skills checkout main
git clone git@ssh.dev.azure.com:v3/locumtenensdotcom1/LT%20Mobile/LT%20Mobile ~/work/LT%20Mobile && git -C ~/work/LT%20Mobile checkout claude/claude-docker-sandbox-setup
git clone git@ssh.dev.azure.com:v3/locumtenensdotcom1/LT%20Api/LTApi ~/work/LTApi && git -C ~/work/LTApi checkout master
git clone git@ssh.dev.azure.com:v3/locumtenensdotcom1/Mobile%20Automation/Mobile%20Automation ~/work/Mobile%20Automation && git -C ~/work/Mobile%20Automation checkout maint/claude-code-docker
git clone git@github.com:LocumTenens-com/user-deletion-dashboard.git ~/work/user-deletion-dashboard && git -C ~/work/user-deletion-dashboard checkout main
```

## 5. Dotfiles (GNU Stow)

Your dotfiles repo manages configs for: fish, ghostty, nvim, sketchybar, skhd, yabai, tmux, yazi, and more.

```bash
# Clone dotfiles repo (already in git repos above), then:
cd ~/dotfiles
stow aerospace
stow fish
stow ghostty
stow hypridle
stow hyprland
stow hyprpaper
stow kitty
stow nvim
stow sketchybar
stow skhd
stow superfile
stow tmux
stow waybar
stow wofi
stow wpaperd
stow yabai
stow yazi
```

## 6. Git Configuration

```bash
git config --global user.email "11544089+sporaktu@users.noreply.github.com"
git config --global user.name "Gray Karegeannes"
```

## 7. SSH Keys

Copy `~/.ssh/` from backup. Keys present:

- `ado_id_ed25519`
- `ado_id_ed25519.pub`
- `ado_id_rsa`
- `ado_id_rsa.pub`
- `config`
- `id_ed25519`
- `id_ed25519_ado`
- `id_ed25519_ado.pub`
- `id_ed25519_bitbucket`
- `id_ed25519_bitbucket.pub`
- `id_ed25519_lt_ado`
- `id_ed25519_lt_ado.pub`
- `id_ed25519.pub`
- `id_rsa`
- `id_rsa.pub`
- `known_hosts`
- `known_hosts.old`
- `lt_do_rsa`
- `lt_do_rsa.pub`

After copying, fix permissions: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_* ~/.ssh/*_id_*`

## 8. LaunchAgents (Services)

Active user services:

- `com.acsandmann.swipe.plist`
- `com.github.facebook.watchman.plist`
- `com.jetbrains.toolbox.plist`
- `com.koekeishiya.skhd.plist`
- `com.koekeishiya.yabai.plist`
- `com.nanoclaw.plist`
- `com.secondbrain.afternoon.plist`
- `com.secondbrain.morning.plist`
- `homebrew.mxcl.ollama.plist`
- `homebrew.mxcl.sketchybar.plist`

Homebrew services restore automatically via `brew services`. Custom plists need manual restore from dotfiles or backup.

## 9. macOS Applications

Apps installed outside Homebrew (install manually or from company MDM):

- 1Password
- Alfred 5
- Amphetamine
- Arc
- ChatGPT
- Claude
- Dia
- DisplayLink Manager
- Docker
- Endpoint Security VPN
- Figma
- Google Chrome
- Irvue
- Jamf Connect
- Logseq
- Microsoft Defender
- Microsoft Edge
- Microsoft Excel
- Microsoft OneNote
- Microsoft Outlook
- Microsoft PowerPoint
- Microsoft Teams
- Microsoft Word
- Obsidian
- OneDrive
- Postman
- RingCentral
- Safari
- Self Service
- Visual Studio Code
- Xcode
- zoom.us

## 10. Claude Code Configuration

Claude Code version: 2.1.50 (Claude Code)

Key paths to restore from backup:
- `~/.claude/CLAUDE.md` — global instructions
- `~/.claude/settings.json` — settings
- `~/.claude/settings.local.json` — local settings
- `~/.claude/skills/` — custom skills
- `~/.claude/hooks/` — hooks configuration
- `~/.claude/plugins/` — plugins
- `~/.claude/commands/` — custom commands

## Restore Order

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
