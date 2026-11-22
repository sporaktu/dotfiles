# Pi dotfiles sync — design

**Status:** approved 2026-11-21

## Intent
Pi config changes on any machine should reach `sporaktu/dotfiles` and every other machine without manual git work.

## Goals / non-goals / anti-goals
- Goal: pull on Pi start, commit+push `pi/` on Pi exit.
- Non-goal: syncing anything outside `pi/`; syncing auth, sessions, memory, installed packages.
- Anti-goals: publishing a secret (repo is **public**); auto-merging diverged history; committing unrelated dirty work; slowing Pi exit; churn commits from Pi's version bookkeeping.

## Approaches
1. **Pi extension (picked by user).** Runs only while Pi runs, no per-OS setup, works on macOS and Linux.
2. launchd/systemd timer: catches out-of-Pi edits, but per-OS setup and always running.
3. File watcher: fastest, extra dependency, noisiest history.

## Design
- `pi/.pi/agent/extensions/dotfiles-sync/index.ts` (+ `lib.ts` for pure logic). Lives in the repo, so it syncs itself.
- `session_start` (reason `startup`): background `git pull --ff-only`; on failure notify, never merge. Pulled config applies next start/`/reload`.
- `session_shutdown`: if `git status --porcelain -- pi/` non-empty → secret scan of changed `pi/` files → `git add -- pi/` → `git commit -m "chore(pi): sync config from <hostname>" -- pi/` → detached `git push` (Pi exit not blocked).
- Secret scan patterns: `sk-`, `AIza`, `ghp_`/`github_pat_`, `xox[bp]-`, `"apiKey"`, `-----BEGIN ... PRIVATE KEY-----`. Any hit → skip commit, notify.
- Volatile keys: `.gitattributes` assigns `pi/.pi/agent/settings.json` to filter `pi-settings`; clean = `jq 'del(.lastChangelogVersion, .extensionChangelogVersions)'`. `install.sh` sets the filter in local git config. Trade-off: new machine shows Pi's what's-new once.
- Status: `dotfiles ✓` / `dotfiles ⚠` via `ctx.ui.setStatus`; notify on failures.
- Off switch: `PI_DOTFILES_SYNC=0`. Repo path: `PI_DOTFILES_DIR` or `~/dotfiles`.

## Left to builder
Exact notify wording; git timeouts (pick 20s pull, commit synchronous).
