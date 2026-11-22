/** Pure git + scan helpers for the dotfiles-sync extension. Imports only node:* so tests run under plain `node --test`. */
import { spawn } from "node:child_process";
import { closeSync, existsSync, openSync, readFileSync } from "node:fs";
import { join } from "node:path";

/** Only this subtree is ever staged or committed. */
export const SYNC_PATH = "pi/";
const SUBJECT_PREFIX = "chore(pi): sync config from ";
const FILTER_CLEAN = "jq --indent 2 'del(.lastChangelogVersion, .extensionChangelogVersions)'";

const SECRET_PATTERNS: Array<[string, RegExp]> = [
	["OpenAI/Anthropic key (sk-)", /\bsk-[A-Za-z0-9_-]{20,}/],
	["Google API key (AIza)", /\bAIza[0-9A-Za-z_-]{30,}/],
	["GitHub token", /\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})/],
	["Slack token", /\bxox[bpas]-[A-Za-z0-9-]{10,}/],
	["apiKey field", /"api[_-]?key"\s*:/i],
	["private key", /-----BEGIN [A-Z ]*PRIVATE KEY-----/],
];

/** Names of secret patterns found in text; empty when clean. */
export function findSecrets(text: string): string[] {
	return SECRET_PATTERNS.filter(([, re]) => re.test(text)).map(([name]) => name);
}

export function commitMessage(host: string): string {
	return `${SUBJECT_PREFIX}${host}`;
}

const GIT_ENV = { ...process.env, GIT_TERMINAL_PROMPT: "0", GIT_SSH_COMMAND: process.env.GIT_SSH_COMMAND ?? "ssh -o BatchMode=yes" };

/** Run a command; never throws. code -1 means spawn failure or timeout. */
function run(cmd: string, args: string[], cwd: string, timeoutMs = 20_000): Promise<{ code: number; out: string }> {
	return new Promise((resolve) => {
		let out = "";
		const child = spawn(cmd, args, { cwd, env: GIT_ENV, stdio: ["ignore", "pipe", "pipe"] });
		const timer = setTimeout(() => child.kill("SIGTERM"), timeoutMs);
		child.stdout.on("data", (d: Buffer) => (out += d));
		child.stderr.on("data", (d: Buffer) => (out += d));
		child.on("error", (e: Error) => {
			clearTimeout(timer);
			resolve({ code: -1, out: String(e) });
		});
		child.on("close", (code) => {
			clearTimeout(timer);
			resolve({ code: code ?? -1, out: out.trim() });
		});
	});
}

export function git(repo: string, args: string[], timeoutMs?: number): Promise<{ code: number; out: string }> {
	return run("git", args, repo, timeoutMs);
}

/** Absolute git dir (works for worktrees where .git is a file). */
export async function gitDir(repo: string): Promise<string | undefined> {
	const r = await git(repo, ["rev-parse", "--absolute-git-dir"]);
	return r.code === 0 ? r.out : undefined;
}

/** Fast-forward only; a diverged or unreachable remote leaves HEAD untouched. */
export async function pullFastForward(repo: string): Promise<{ ok: boolean; msg: string }> {
	const r = await git(repo, ["pull", "--ff-only", "--no-rebase", "--quiet"]);
	return { ok: r.code === 0, msg: r.out };
}

const lines = (s: string) => s.split("\0").filter(Boolean);

/** Commit changes under pi/ (secret-scanned) on `branch` only, without touching anything else in the index. Does not push. */
export async function syncOut(repo: string, host: string, branch = "main"): Promise<{ committed: boolean; reason?: string }> {
	const head = await git(repo, ["symbolic-ref", "--quiet", "--short", "HEAD"]);
	if (head.out !== branch) return { committed: false, reason: `not on ${branch} (on ${head.out || "detached HEAD"})` };
	const dir = await gitDir(repo);
	if (!dir) return { committed: false, reason: "not a git repo" };
	if (["MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply"].some((f) => existsSync(join(dir, f))))
		return { committed: false, reason: "a merge/rebase is in progress" };

	const status = await git(repo, ["status", "--porcelain", "--", SYNC_PATH]);
	if (status.code !== 0) return { committed: false, reason: `git status failed: ${status.out}` };
	if (!status.out) return { committed: false, reason: "no changes" };

	// Everything the pathspec commit would record: working tree vs HEAD (covers pre-staged files) plus untracked.
	const changed = await git(repo, ["diff", "--name-only", "-z", "HEAD", "--", SYNC_PATH]);
	const untracked = await git(repo, ["ls-files", "-z", "--others", "--exclude-standard", "--", SYNC_PATH]);
	const hits: string[] = [];
	for (const file of new Set([...lines(changed.out), ...lines(untracked.out)])) {
		let text: string;
		try {
			text = readFileSync(join(repo, file), "utf8");
		} catch {
			continue; // deleted
		}
		for (const name of findSecrets(text)) hits.push(`${file}: ${name}`);
	}
	if (hits.length) return { committed: false, reason: `possible secret, not committed (${hits.join("; ")})` };

	const add = await git(repo, ["add", "-A", "--", SYNC_PATH]);
	if (add.code !== 0) return { committed: false, reason: `git add failed: ${add.out}` };
	// status can flag files whose clean-filtered content is unchanged (e.g. only Pi version keys moved).
	const staged = await git(repo, ["diff", "--cached", "--quiet", "--", SYNC_PATH]);
	if (staged.code === 0) return { committed: false, reason: "no changes" };
	// Pathspec commit (--only) records just pi/, leaving other staged work staged.
	const commit = await git(repo, ["commit", "--quiet", "--no-verify", "-m", commitMessage(host), "--", SYNC_PATH]);
	if (commit.code !== 0) return { committed: false, reason: `git commit failed: ${commit.out}` };
	return { committed: true };
}

/** Commits ahead of upstream, and whether all of them are sync commits (safe to publish). count -1: no upstream. */
export async function unpushed(repo: string): Promise<{ count: number; onlySync: boolean }> {
	const r = await git(repo, ["log", "--format=%s", "@{u}..HEAD"]);
	if (r.code !== 0) return { count: -1, onlySync: false };
	const subjects = r.out ? r.out.split("\n") : [];
	return { count: subjects.length, onlySync: subjects.every((s) => s.startsWith(SUBJECT_PREFIX)) };
}

/** Push in a detached process so Pi can exit immediately; output goes to logPath. */
export function pushDetached(repo: string, logPath: string): void {
	const fd = openSync(logPath, "a");
	try {
		const child = spawn("git", ["push", "--quiet"], { cwd: repo, env: GIT_ENV, detached: true, stdio: ["ignore", fd, fd] });
		child.on("error", () => {});
		child.unref();
	} finally {
		closeSync(fd);
	}
}

/** Make sure this clone strips Pi's version keys from settings.json on commit. */
export async function ensureCleanFilter(repo: string): Promise<"ok" | "set" | "no-jq"> {
	const cur = await git(repo, ["config", "--get", "filter.pi-settings.clean"]);
	if (cur.code === 0 && cur.out) return "ok";
	if ((await run("jq", ["--version"], repo)).code !== 0) return "no-jq";
	await git(repo, ["config", "filter.pi-settings.clean", FILTER_CLEAN]);
	await git(repo, ["config", "filter.pi-settings.smudge", "cat"]);
	return "set";
}
