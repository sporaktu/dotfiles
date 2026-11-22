/**
 * dotfiles-sync: keep ~/dotfiles/pi in sync across machines.
 *   - Pi start: `git pull --ff-only` in the background (never merges).
 *   - Pi exit:  commit changed files under pi/ (secret-scanned), then push detached.
 * Env: PI_DOTFILES_SYNC=0 disables; PI_DOTFILES_DIR overrides the repo (default ~/dotfiles).
 * Pulled config takes effect on the next start or /reload.
 */
import { existsSync } from "node:fs";
import { homedir, hostname } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { pullFastForward, pushDetached, syncOut } from "./lib.ts";

const STATUS_KEY = "dotfiles";

export default function (pi: ExtensionAPI) {
	if (process.env.PI_DOTFILES_SYNC === "0") return;
	const repo = process.env.PI_DOTFILES_DIR ?? join(homedir(), "dotfiles");
	if (!existsSync(join(repo, ".git"))) return;
	const host = hostname().split(".")[0] ?? "unknown";

	pi.on("session_start", (event, ctx) => {
		if (event.reason !== "startup") return;
		ctx.ui.setStatus(STATUS_KEY, "dotfiles ↻");
		void pullFastForward(repo).then((res) => {
			if (res.ok) {
				ctx.ui.setStatus(STATUS_KEY, "dotfiles ✓");
			} else {
				ctx.ui.setStatus(STATUS_KEY, "dotfiles ⚠");
				ctx.ui.notify(`dotfiles-sync: pull skipped (not a fast-forward or offline). Sync ~/dotfiles by hand.\n${res.msg}`, "warning");
			}
		});
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		const res = await syncOut(repo, host);
		if (res.committed) {
			pushDetached(repo, join(repo, ".git", "pi-dotfiles-sync.log"));
		} else if (res.reason !== "no changes") {
			ctx.ui.notify(`dotfiles-sync: ${res.reason}`, "warning");
		}
	});
}
