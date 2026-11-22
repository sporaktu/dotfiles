# Pi dotfiles sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pi extension that pulls `~/dotfiles` on start and commits+pushes `pi/` on exit.

**Architecture:** Pure helpers in `lib.ts` (secret scan, commit message, git arg builders) tested with `node --test`; `index.ts` wires them to Pi lifecycle events. A git clean filter strips Pi's version bookkeeping from `settings.json`.

**Tech Stack:** TypeScript (Node 24 type stripping), `node:test`, git, jq, Pi extension API.

**Spec:** `docs/plans/2026-11-21-pi-dotfiles-sync-design.md`

## Global Constraints
- Only paths under `pi/` are ever staged or committed (`-- pi/` pathspec on add and commit).
- Repo is public: a secret-scan hit blocks the commit.
- Pull is `--ff-only`; never merge or rebase automatically.
- Push is detached; exit is not blocked.
- `PI_DOTFILES_SYNC=0` disables everything; repo = `PI_DOTFILES_DIR ?? ~/dotfiles`.
- `lib.ts` imports only `node:*` (it is not an extension entry; only `index.ts` loads).

## Review Focus
- Unrelated staged files in the repo must not be committed → integration test stages `other.txt` first and asserts it stays out.
- Diverged remote → pull fails, no merge commit → integration test.
- Secret in `pi/` → no commit → integration test.
- No upstream/offline → notify, no throw → covered by `syncOut` returning `{pushed:false}` without throwing when remote missing.
- Clean filter → `settings.json` with only volatile-key changes shows no diff → manual check in Task 2.

---

### Task 1: lib + tests
**Files:** Create `pi/.pi/agent/extensions/dotfiles-sync/lib.ts`, `pi/.pi/agent/extensions/dotfiles-sync/lib.test.ts`

**Interfaces (Produces):**
- `findSecrets(text: string): string[]` — names of matched patterns.
- `commitMessage(host: string): string` → `chore(pi): sync config from <host>`
- `git(repo: string, args: string[]): Promise<{code: number, out: string}>`
- `pullFastForward(repo: string): Promise<{ok: boolean, msg: string}>`
- `syncOut(repo: string, host: string): Promise<{committed: boolean, reason?: string}>` — status/scan/add/commit (no push).
- `pushDetached(repo: string): void`

- [ ] Tests: `findSecrets` hits `sk-ant-abc123...`, `AIzaSy...`, `ghp_...`, private-key header; empty for settings.json content. Integration (temp bare remote + clone): pi change committed alone while staged `other.txt` stays staged; secret blocks commit; no changes → `committed:false`; diverged remote → `pullFastForward` not ok and HEAD unchanged.
- [ ] Run `node --test pi/.pi/agent/extensions/dotfiles-sync/lib.test.ts` → FAIL, implement, → PASS.

### Task 2: extension wiring + clean filter
**Files:** Create `pi/.pi/agent/extensions/dotfiles-sync/index.ts`; create `.gitattributes`; modify `install.sh`.
- [ ] `index.ts`: on `session_start` reason `startup` → `pullFastForward` in background, set status; on `session_shutdown` → `syncOut`, then `pushDetached` if committed; notify on failures.
- [ ] `.gitattributes`: `pi/.pi/agent/settings.json filter=pi-settings`; `install.sh`: `git -C "$DOTFILES_DIR" config filter.pi-settings.clean "jq 'del(.lastChangelogVersion, .extensionChangelogVersions)'"` and `filter.pi-settings.smudge cat`.
- [ ] Verify: `tsc --strict --noEmit` clean; `git diff -- pi/.pi/agent/settings.json` empty after bumping only `lastChangelogVersion`; launch Pi in tmux, quit, confirm commit + push.
- [ ] Commit.
