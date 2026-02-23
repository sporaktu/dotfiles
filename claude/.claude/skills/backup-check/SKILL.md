---
name: backup-check
description: Use when the user wants to verify all home directories are backed up — either pushed to git remotes or synced to OneDrive. Also use when the user mentions "backup", "sync to OneDrive", "push everything", or "make sure everything is saved".
---

# Backup Check

## Overview

Runs `backup-check.sh` to ensure every top-level `~/` directory is either fully pushed to a git remote or mirrored to OneDrive.

## When to Use

- User asks to back up their directories
- User wants to verify nothing is unsaved before a format, migration, or travel
- User says "backup check", "sync everything", "push everything"

## Usage

Run the script:

```bash
~/.claude/skills/backup-check/backup-check.sh
```

The script handles everything automatically. Review the summary table it prints at the end.

## What It Does

- **Git repos**: stages all changes, commits, and pushes. On push failure, creates a `backup/YYYY-MM-DD_HH-MM-SS-unmerged` branch and pushes that instead.
- **Non-git dirs**: rsyncs to `~/OneDrive - Jackson Healthcare/` preserving directory structure. Nested git repos inside non-git dirs are excluded from sync.
- **Machine snapshot**: generates `MACHINE-SNAPSHOT.md` with everything needed to restore the machine (Brewfile, git repos, npm/pip packages, dotfiles, SSH keys, apps, services). Saved locally and to OneDrive.
- **Excludes**: `Library`, `Applications`, `OneDrive - Jackson Healthcare`, `dotfiles`

## Restoring From Snapshot

Give Claude Code the `MACHINE-SNAPSHOT.md` file and say "restore my machine from this snapshot". It contains install commands in execution order.

## Common Issues

- If OneDrive folder is missing, the script will exit with an error
- If a git repo has no remote configured, it will be reported as needing manual attention
