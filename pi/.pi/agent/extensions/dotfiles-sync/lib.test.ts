import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { CLAUDE, commitMessage, ensureCleanFilter, findSecrets, pullFastForward, pushDetached, syncOut, unpushed } from "./lib.ts";

// Isolate from the user's global git config (gpgsign, hooksPath, pull.rebase...).
process.env.GIT_CONFIG_GLOBAL = "/dev/null";

// Secret-shaped fixtures are built by concatenation so this file never matches the scanner itself.
const FAKE = {
	sk: "sk" + "-ant-api03-abcdefghijklmnopqrstuv",
	aiza: "AI" + "zaSyA1234567890abcdefghijklmnopqrstu",
	ghp: "gh" + "p_abcdefghijklmnopqrstuvwxyz0123456789",
	pem: "-----BEGIN OPENSSH " + "PRIVATE KEY-----",
	apiKey: '{"api' + 'Key": "abc"}',
};

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
	mkdirSync(join(a, "claude"));
	writeFileSync(join(a, "claude", "settings.json"), '{"hooks":{}}\n');
	writeFileSync(join(a, "other.txt"), "x\n");
	sh(a, "add", ".");
	sh(a, "commit", "-qm", "init");
	sh(a, "push", "-q", "-u", "origin", "main");
	const b = clone("b");
	return { a, b };
}

test("findSecrets flags common key shapes", () => {
	for (const s of Object.values(FAKE)) assert.equal(findSecrets(s).length, 1, s);
});

test("this test file does not trip the scanner", () => {
	assert.deepEqual(findSecrets(readFileSync(new URL(import.meta.url), "utf8")), []);
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
	writeFileSync(join(a, "pi", "settings.json"), `{"token":"${FAKE.ghp}"}\n`);
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

test("syncOut treats changes removed by a clean filter as no changes", async () => {
	const { a } = setup();
	sh(a, "config", "filter.strip.clean", "jq --indent 2 'del(.v)'");
	sh(a, "config", "filter.strip.smudge", "cat");
	writeFileSync(join(a, ".gitattributes"), "pi/settings.json filter=strip\n");
	writeFileSync(join(a, "pi", "settings.json"), '{\n  "packages": []\n}\n');
	sh(a, "add", ".gitattributes", "pi/settings.json");
	sh(a, "commit", "-qm", "attrs");
	writeFileSync(join(a, "pi", "settings.json"), '{"v": "1.0.0-longer", "packages": []}');
	const head = sh(a, "rev-parse", "HEAD");
	const res = await syncOut(a, "mbp");
	assert.equal(res.committed, false);
	assert.equal(res.reason, "no changes");
	assert.equal(sh(a, "rev-parse", "HEAD"), head);
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

test("syncOut scans files that were already staged", async () => {
	const { a } = setup();
	const head = sh(a, "rev-parse", "HEAD");
	writeFileSync(join(a, "pi", "settings.json"), `{"token":"${FAKE.ghp}"}\n`);
	sh(a, "add", "pi/settings.json");
	const res = await syncOut(a, "mbp");
	assert.equal(res.committed, false);
	assert.match(res.reason ?? "", /secret/i);
	assert.equal(sh(a, "rev-parse", "HEAD"), head);
});

test("syncOut does nothing off the sync branch", async () => {
	const { a } = setup();
	sh(a, "checkout", "-qb", "feature");
	writeFileSync(join(a, "pi", "settings.json"), "{}\n");
	const res = await syncOut(a, "mbp");
	assert.equal(res.committed, false);
	assert.match(res.reason ?? "", /not on main/);
});

test("syncOut does nothing while a merge or rebase is in progress", async () => {
	const { a } = setup();
	writeFileSync(join(a, ".git", "MERGE_HEAD"), `${sh(a, "rev-parse", "HEAD")}\n`);
	writeFileSync(join(a, "pi", "settings.json"), "{}\n");
	const res = await syncOut(a, "mbp");
	assert.equal(res.committed, false);
	assert.match(res.reason ?? "", /in progress/);
});

test("unpushed counts sync commits and flags foreign ones", async () => {
	const { a } = setup();
	assert.deepEqual(await unpushed(a), { count: 0, onlySync: true });
	writeFileSync(join(a, "pi", "settings.json"), "{}\n");
	await syncOut(a, "mbp");
	assert.deepEqual(await unpushed(a), { count: 1, onlySync: true });
	writeFileSync(join(a, "other.txt"), "mine\n");
	sh(a, "commit", "-qam", "private work");
	assert.deepEqual(await unpushed(a), { count: 2, onlySync: false });
});

test("pushDetached lands the sync commit on the remote", async () => {
	const { a, b } = setup();
	writeFileSync(join(a, "pi", "settings.json"), "{}\n");
	await syncOut(a, "mbp");
	pushDetached(a, join(a, ".git", "push.log"));
	const want = sh(a, "rev-parse", "HEAD");
	for (let i = 0; i < 50; i++) {
		sh(b, "fetch", "-q");
		if (sh(b, "rev-parse", "origin/main") === want) return;
		await new Promise((r) => setTimeout(r, 100));
	}
	assert.fail("push never reached the remote");
});

test("ensureCleanFilter configures the filter when missing", async () => {
	const { a } = setup();
	assert.equal(await ensureCleanFilter(a), "set");
	assert.match(sh(a, "config", "--get", "filter.pi-settings.clean"), /lastChangelogVersion/);
	assert.equal(await ensureCleanFilter(a), "ok");
	assert.ok(existsSync(join(a, ".git")));
});

test("claude scope commits only claude/ under its own subject", async () => {
	const { a } = setup();
	writeFileSync(join(a, "claude", "settings.json"), '{"hooks":{"x":1}}\n');
	writeFileSync(join(a, "pi", "settings.json"), '{"packages":["npm:y"]}\n');
	const res = await syncOut(a, "mbp", "main", CLAUDE);
	assert.equal(res.committed, true);
	assert.equal(sh(a, "log", "-1", "--format=%s"), "chore(claude): sync config from mbp");
	assert.equal(sh(a, "show", "--name-only", "--format=", "HEAD"), "claude/settings.json");
	assert.match(sh(a, "status", "--porcelain"), /pi\/settings.json/);
});

test("unpushed treats pi and claude sync commits alike", async () => {
	const { a } = setup();
	writeFileSync(join(a, "pi", "settings.json"), "{}\n");
	await syncOut(a, "mbp");
	writeFileSync(join(a, "claude", "settings.json"), "{}\n");
	await syncOut(a, "mbp", "main", CLAUDE);
	assert.deepEqual(await unpushed(a), { count: 2, onlySync: true });
});

test("claude scope still refuses secrets", async () => {
	const { a } = setup();
	writeFileSync(join(a, "claude", "settings.json"), FAKE.sk);
	const res = await syncOut(a, "mbp", "main", CLAUDE);
	assert.equal(res.committed, false);
	assert.match(res.reason ?? "", /possible secret/);
});
