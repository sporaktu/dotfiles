#!/usr/bin/env node
/**
 * dotfiles-sync for Claude Code: the same behavior as the Pi extension, applied to ~/dotfiles/claude.
 *   start (SessionStart startup): `git pull --ff-only` (never merges), retry unpushed sync commits,
 *         ensure the Pi settings clean filter, and report the last exit-time failure.
 *   end   (SessionEnd): on main only, commit changed files under claude/ (secret-scanned), then push
 *         detached if every unpushed commit is a sync commit (Pi's or Claude's).
 * Env: CLAUDE_DOTFILES_SYNC=0 disables; CLAUDE_DOTFILES_DIR (or PI_DOTFILES_DIR) overrides the repo
 *      (default ~/dotfiles); CLAUDE_DOTFILES_BRANCH (or PI_DOTFILES_BRANCH) overrides the branch (default main).
 * Shares its git logic with pi/.pi/agent/extensions/dotfiles-sync/lib.ts so both harnesses behave identically.
 */
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir, hostname } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const mode = process.argv[2];
const repo = process.env.CLAUDE_DOTFILES_DIR ?? process.env.PI_DOTFILES_DIR ?? join(homedir(), "dotfiles");
const branch = process.env.CLAUDE_DOTFILES_BRANCH ?? process.env.PI_DOTFILES_BRANCH ?? "main";
const host = hostname().split(".")[0] ?? "unknown";
const libPath = join(repo, "pi", ".pi", "agent", "extensions", "dotfiles-sync", "lib.ts");

function say(message: string): void {
	// systemMessage is shown to the user; it never reaches the model.
	process.stdout.write(JSON.stringify({ systemMessage: `dotfiles-sync: ${message}` }));
}

async function main(): Promise<void> {
	if (process.env.CLAUDE_DOTFILES_SYNC === "0") return;
	if (!existsSync(join(repo, ".git")) || !existsSync(libPath)) return;
	const lib = await import(pathToFileURL(libPath).href);
	const dir: string | undefined = await lib.gitDir(repo);
	if (!dir) return;
	const errorFile = join(dir, "claude-dotfiles-sync.last-error");
	const logFile = join(dir, "claude-dotfiles-sync.log");

	async function pushIfSafe(): Promise<string | undefined> {
		const ahead = await lib.unpushed(repo);
		if (ahead.count <= 0) return;
		if (!ahead.onlySync) return `${ahead.count} unpushed commit(s) include non-sync work; not pushing. Push ~/dotfiles by hand.`;
		lib.pushDetached(repo, logFile);
	}

	if (mode === "start") {
		const problems: string[] = [];
		if (existsSync(errorFile)) {
			problems.push(`last exit: ${readFileSync(errorFile, "utf8").trim()}`);
			rmSync(errorFile, { force: true });
		}
		if ((await lib.ensureCleanFilter(repo)) === "no-jq") problems.push("jq not found; Pi settings.json version keys will be committed");
		const pull = await lib.pullFastForward(repo);
		if (pull.ok) {
			const warn = await pushIfSafe();
			if (warn) problems.push(warn);
		} else problems.push(`pull skipped (not a fast-forward, offline, or not on a branch). Sync ~/dotfiles by hand.\n${pull.msg}`);
		if (problems.length) say(problems.join("\n"));
	} else if (mode === "end") {
		// The session is closing, so failures are persisted and reported at the next start.
		const res = await lib.syncOut(repo, host, branch, lib.CLAUDE);
		let problem: string | undefined;
		if (res.committed) problem = await pushIfSafe();
		else if (res.reason !== "no changes" && !res.reason?.startsWith("not on ")) problem = res.reason;
		if (problem) writeFileSync(errorFile, `${new Date().toISOString()} ${problem}\n`);
	}
}

main().catch((e) => {
	if (mode === "start") say(`hook failed: ${e}`);
});
