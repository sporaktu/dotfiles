#!/usr/bin/env bash
# Pi starter kit for macOS: installs Pi and copies this repo's Pi config.
#
# Run it with the one-liner from the Confluence page, pinned to a commit:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sporaktu/dotfiles/<sha>/scripts/bootstrap-mac.sh)" bootstrap <sha>
#
# What it does (safe to re-run):
#   1. Xcode command line tools, Homebrew, then git, jq and Pi (pi-coding-agent, which brings Node).
#   2. Copies Pi settings, vision config and the status line extension into ~/.pi.
#      Copies, not symlinks: your config is yours and never syncs with this repo.
#      Any file it replaces is kept as <file>.bak-<timestamp>.
# What it leaves out on purpose: the dotfiles-sync extension (it would commit and push a ~/dotfiles repo),
# @gotgenes/pi-anthropic-auth (Claude Code impersonation, against Anthropic's terms),
# the tuios extension (needs tuios), Claude Code settings, shell, terminal and window manager configs.
set -euo pipefail

REPO_URL="https://github.com/sporaktu/dotfiles.git"
REF="${1:-main}"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '\n==> %s\n' "$*"; }
die() {
  printf 'bootstrap: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname -s)" == Darwin ]] || die "this script is for macOS"

say "Xcode command line tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  die "finish the Xcode command line tools install in the dialog, then run the same command again"
fi

say "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    :
  elif [[ -x /usr/local/bin/brew ]]; then
    :
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
fi
BREW="$(command -v brew || true)"
[[ -n "$BREW" ]] || BREW="$([[ -x /opt/homebrew/bin/brew ]] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew)"
eval "$("$BREW" shellenv)"
# Make brew available in new zsh terminals (macOS default shell).
# shellcheck disable=SC2016 # written literally; the shell expands it at login
grep -qF 'brew shellenv' "$HOME/.zprofile" 2>/dev/null ||
  echo "eval \"\$($BREW shellenv)\"" >>"$HOME/.zprofile"

say "git, jq and Pi"
brew install git jq pi-coding-agent

say "Fetching Pi config ($REF)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp/repo"
git -C "$tmp/repo" remote add origin "$REPO_URL"
git -C "$tmp/repo" fetch -q --depth 1 origin "$REF"
git -C "$tmp/repo" checkout -q FETCH_HEAD
src="$tmp/repo/pi/.pi"

pretty() { printf '%s' "~${1#"$HOME"}"; }

# install_file SRC DEST: copy, keeping any different existing file as DEST.bak-STAMP.
install_file() {
  local from="$1" to="$2"
  mkdir -p "$(dirname "$to")"
  if [[ -L "$to" ]]; then
    mv "$to" "$to.bak-$STAMP"
  elif [[ -e "$to" ]]; then
    if cmp -s "$from" "$to"; then
      echo "  unchanged $(pretty "$to")"
      return
    fi
    mv "$to" "$to.bak-$STAMP"
    echo "  kept old $(pretty "$to") as $(pretty "$to").bak-$STAMP"
  fi
  cp "$from" "$to"
  echo "  installed $(pretty "$to")"
}

say "Installing Pi config into ~/.pi"
# Drop per-machine version bookkeeping so Pi shows its own changelogs, and drop
# @gotgenes/pi-anthropic-auth: it disguises Pi as Claude Code, which breaks Anthropic's terms.
jq --indent 2 'del(.lastChangelogVersion, .extensionChangelogVersions)
  | .packages |= map(select(. != "npm:@gotgenes/pi-anthropic-auth"))' \
  "$src/agent/settings.json" >"$tmp/settings.json"
install_file "$tmp/settings.json" "$HOME/.pi/agent/settings.json"
install_file "$src/agent/vision.json" "$HOME/.pi/agent/vision.json"
install_file "$src/acp.json" "$HOME/.pi/acp.json"
install_file "$src/agent/extensions/statusline.ts" "$HOME/.pi/agent/extensions/statusline.ts"

say "Done"
cat <<'EOF'
Next steps:
  1. Open a new terminal and run:  pi
     The first start installs the Pi packages listed in ~/.pi/agent/settings.json; give it a minute.
  2. Get an Anthropic API key from the LT org (ask DevOps), then in Pi run /login, pick Anthropic
     and choose the API key option. Do not use the Claude account (OAuth) sign-in: it signs in
     as Claude Code, which Anthropic's terms do not allow for other tools.
  3. Optional: connect Atlassian by asking Pi to install the MCP server https://mcp.atlassian.com/v1/mcp

To update later, run the one-liner from the Confluence page again; it keeps backups of anything it replaces.
EOF
