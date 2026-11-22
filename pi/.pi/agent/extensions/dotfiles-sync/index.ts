/**
 * dotfiles-sync: keep ~/dotfiles/pi in sync across machines.
 *   - Pi start: `git pull --ff-only` in the background (never merges), retry any unpushed sync commits,
 *     ensure the settings.json clean filter, and surface the last exit-time failure.
 *   - Pi exit:  on main only, commit changed files under pi/ (secret-scanned), then push detached
 *     if every unpushed commit is a sync commit.
 * Env: PI_DOTFILES_SYNC=0 disables; PI_DOTFILES_DIR overrides the repo (default ~/dotfiles);
 *      PI_DOTFILES_BRANCH overrides the sync branch (default main).
 * Pulled config takes effect on the next start or /reload.
 */
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir, hostname } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { ensureCleanFilter, gitDir, pullFastForward, pushDetached, syncOut, unpushed } from "./lib.ts";

const STATUS_KEY = "dotfiles";

export default function (pi: ExtensionAPI) {
	if (process.env.PI_DOTFILES_SYNC === "0") return;
	const repo = process.env.PI_DOTFILES_DIR ?? join(homedir(), "dotfiles");
	if (!existsSync(join(repo, ".git"))) return;
	const branch = process.env.PI_DOTFILES_BRANCH ?? "main";
	const host = hostname().split(".")[0] ?? "unknown";
	let startup: Promise<void> = Promise.resolve();

	// Exit-time failures can't be shown reliably while the TUI tears down; persist and show next start.
	const errorFile = (dir: string) => join(dir, "pi-dotfiles-sync.last-error");
	const logFile = (dir: string) => join(dir, "pi-dotfiles-sync.log");

	async function pushIfSafe(dir: string, ctx: ExtensionContext): Promise<void> {
		const ahead = await unpushed(repo);
		if (ahead.count <= 0) return;
		if (!ahead.onlySync) {
			ctx.ui.setStatus(STATUS_KEY, "dotfiles ⚠");
			ctx.ui.notify(`dotfiles-sync: ${ahead.count} unpushed commit(s) include non-sync work; not pushing. Push ~/dotfiles by hand.`, "warning");
			return;
		}
		pushDetached(repo, logFile(dir));
	}

	async function onStart(ctx: ExtensionContext): Promise<void> {
		const dir = await gitDir(repo);
		if (!dir) return;
		const problems: string[] = [];
		if (existsSync(errorFile(dir))) {
			problems.push(`last exit: ${readFileSync(errorFile(dir), "utf8").trim()}`);
			rmSync(errorFile(dir), { force: true });
		}
		if ((await ensureCleanFilter(repo)) === "no-jq") problems.push("jq not found; settings.json version keys will be committed");
		const pull = await pullFastForward(repo);
		if (pull.ok) await pushIfSafe(dir, ctx); // retries a previous push that didn't land
		else problems.push(`pull skipped (not a fast-forward, offline, or not on a branch). Sync ~/dotfiles by hand.\n${pull.msg}`);
		ctx.ui.setStatus(STATUS_KEY, problems.length ? "dotfiles ⚠" : "dotfiles ✓");
		if (problems.length) ctx.ui.notify(`dotfiles-sync: ${problems.join("\n")}`, "warning");
	}

	pi.on("session_start", (event, ctx) => {
		if (event.reason !== "startup") return;
		ctx.ui.setStatus(STATUS_KEY, "dotfiles ↻");
		startup = onStart(ctx).catch(() => {});
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		await startup; // don't commit while the startup pull is still running
		const dir = await gitDir(repo);
		if (!dir) return;
		const res = await syncOut(repo, host, branch);
		if (res.committed) {
			await pushIfSafe(dir, ctx);
		} else if (res.reason !== "no changes" && !res.reason?.startsWith("not on ")) {
			writeFileSync(errorFile(dir), `${new Date().toISOString()} ${res.reason}\n`);
			ctx.ui.notify(`dotfiles-sync: ${res.reason}`, "warning");
		}
	});
}
