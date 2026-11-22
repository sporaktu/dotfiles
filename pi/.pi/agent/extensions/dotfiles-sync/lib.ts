/** Pure git + scan helpers for the dotfiles-sync extension. Imports only node:* so tests run under plain `node --test`. */
import { spawn } from "node:child_process";
import { closeSync, openSync, readFileSync } from "node:fs";
import { join } from "node:path";

/** Only this subtree is ever staged or committed. */
export const SYNC_PATH = "pi/";

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
	return `chore(pi): sync config from ${host}`;
}

const GIT_ENV = { ...process.env, GIT_TERMINAL_PROMPT: "0", GIT_SSH_COMMAND: process.env.GIT_SSH_COMMAND ?? "ssh -o BatchMode=yes" };

/** Run git; never throws. code -1 means spawn failure or timeout. */
export function git(repo: string, args: string[], timeoutMs = 20_000): Promise<{ code: number; out: string }> {
	return new Promise((resolve) => {
		let out = "";
		const child = spawn("git", args, { cwd: repo, env: GIT_ENV, stdio: ["ignore", "pipe", "pipe"] });
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

/** Fast-forward only; a diverged or unreachable remote leaves HEAD untouched. */
export async function pullFastForward(repo: string): Promise<{ ok: boolean; msg: string }> {
	const r = await git(repo, ["pull", "--ff-only", "--quiet"]);
	return { ok: r.code === 0, msg: r.out };
}

/** Commit changes under pi/ (secret-scanned) without touching anything else in the index. Does not push. */
export async function syncOut(repo: string, host: string): Promise<{ committed: boolean; reason?: string }> {
	const status = await git(repo, ["status", "--porcelain", "--", SYNC_PATH]);
	if (status.code !== 0) return { committed: false, reason: `git status failed: ${status.out}` };
	if (!status.out) return { committed: false, reason: "no changes" };

	const changed = await git(repo, ["ls-files", "-z", "--modified", "--others", "--exclude-standard", "--", SYNC_PATH]);
	const hits: string[] = [];
	for (const file of changed.out.split("\0").filter(Boolean)) {
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
	// Pathspec commit (--only) records just pi/, leaving other staged work staged.
	const commit = await git(repo, ["commit", "--quiet", "--no-verify", "-m", commitMessage(host), "--", SYNC_PATH]);
	if (commit.code !== 0) return { committed: false, reason: `git commit failed: ${commit.out}` };
	return { committed: true };
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
