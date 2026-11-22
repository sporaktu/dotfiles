import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { commitMessage, findSecrets, pullFastForward, syncOut } from "./lib.ts";

const sh = (cwd: string, ...args: string[]) =>
	execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();

/** Bare remote plus two clones (a, b) sharing an initial commit with pi/settings.json. */
function setup() {
	const root = mkdtempSync(join(tmpdir(), "dsync-"));
	const remote = join(root, "remote.git");
	sh(root, "init", "-q", "--bare", "-b", "main", remote);
	const clone = (name: string) => {
		const dir = join(root, name);
		sh(root, "clone", "-q", remote, dir);
		sh(dir, "config", "user.email", "t@t");
		sh(dir, "config", "user.name", "t");
		return dir;
	};
	const a = clone("a");
	mkdirSync(join(a, "pi"));
	writeFileSync(join(a, "pi", "settings.json"), '{"packages":[]}\n');
	writeFileSync(join(a, "other.txt"), "x\n");
	sh(a, "add", ".");
	sh(a, "commit", "-qm", "init");
	sh(a, "push", "-q", "-u", "origin", "main");
	const b = clone("b");
	return { a, b };
}

test("findSecrets flags common key shapes", () => {
	assert.deepEqual(findSecrets("key: sk-ant-api03-abcdefghijklmnopqrstuv").length, 1);
	assert.equal(findSecrets("AIzaSyA1234567890abcdefghijklmnopqrstu").length, 1);
	assert.equal(findSecrets("ghp_abcdefghijklmnopqrstuvwxyz0123456789").length, 1);
	assert.equal(findSecrets("-----BEGIN OPENSSH PRIVATE KEY-----").length, 1);
	assert.equal(findSecrets('{"apiKey": "abc"}').length, 1);
});

test("findSecrets ignores normal settings content", () => {
	assert.deepEqual(findSecrets('{"packages":["npm:pi-lens"],"extensions":["-builtin:mcp"],"cacheMaxEntries":256}'), []);
});

test("commitMessage names the host", () => {
	assert.equal(commitMessage("mbp"), "chore(pi): sync config from mbp");
});

test("syncOut commits only pi/ and leaves other staged files staged", async () => {
	const { a } = setup();
	writeFileSync(join(a, "pi", "settings.json"), '{"packages":["npm:x"]}\n');
	writeFileSync(join(a, "other.txt"), "changed\n");
	sh(a, "add", "other.txt");
	const res = await syncOut(a, "mbp");
	assert.equal(res.committed, true);
	assert.equal(sh(a, "log", "-1", "--format=%s"), "chore(pi): sync config from mbp");
	assert.equal(sh(a, "show", "--name-only", "--format=", "HEAD"), "pi/settings.json");
	assert.equal(sh(a, "diff", "--cached", "--name-only"), "other.txt");
});

test("syncOut includes new untracked files under pi/", async () => {
	const { a } = setup();
	writeFileSync(join(a, "pi", "new.ts"), "export {};\n");
	const res = await syncOut(a, "mbp");
	assert.equal(res.committed, true);
	assert.equal(sh(a, "show", "--name-only", "--format=", "HEAD"), "pi/new.ts");
});

test("syncOut refuses to commit a secret", async () => {
	const { a } = setup();
	const head = sh(a, "rev-parse", "HEAD");
	writeFileSync(join(a, "pi", "settings.json"), '{"token":"ghp_abcdefghijklmnopqrstuvwxyz0123456789"}\n');
	const res = await syncOut(a, "mbp");
	assert.equal(res.committed, false);
	assert.match(res.reason ?? "", /secret/i);
	assert.equal(sh(a, "rev-parse", "HEAD"), head);
	assert.equal(sh(a, "diff", "--cached", "--name-only"), "");
});

test("syncOut does nothing without changes", async () => {
	const { a } = setup();
	const res = await syncOut(a, "mbp");
	assert.equal(res.committed, false);
});

test("pullFastForward fast-forwards when behind", async () => {
	const { a, b } = setup();
	writeFileSync(join(a, "pi", "settings.json"), "{}\n");
	sh(a, "commit", "-qam", "a change");
	sh(a, "push", "-q");
	const res = await pullFastForward(b);
	assert.equal(res.ok, true);
	assert.equal(sh(b, "rev-parse", "HEAD"), sh(a, "rev-parse", "HEAD"));
});

test("pullFastForward never merges diverged history", async () => {
	const { a, b } = setup();
	writeFileSync(join(a, "pi", "settings.json"), "{}\n");
	sh(a, "commit", "-qam", "a change");
	sh(a, "push", "-q");
	writeFileSync(join(b, "other.txt"), "b\n");
	sh(b, "commit", "-qam", "b change");
	const head = sh(b, "rev-parse", "HEAD");
	const res = await pullFastForward(b);
	assert.equal(res.ok, false);
	assert.equal(sh(b, "rev-parse", "HEAD"), head);
});

test("pullFastForward reports failure without throwing when the remote is gone", async () => {
	const { b } = setup();
	sh(b, "remote", "set-url", "origin", "/nonexistent/remote.git");
	const res = await pullFastForward(b);
	assert.equal(res.ok, false);
});
