/**
 * Pi status line — a port of ~/dotfiles/claude/.claude/statusline.sh.
 * It replaces Pi's built-in footer with:
 *   Line 1: model (thinking level) │ project (branch) │ session cost │ context bar + makeup of the last call
 *   Line 2: session tokens by type, plus LLM usage from tools (advisor etc.) and compaction / cache warming
 *   Line 3+: subagents (pi-subagents), shown once the session has started one: active and used counts, then one row per running agent
 *   Next:   plan rate limits (5h / 7d), shown only when the provider sends the headers (Anthropic OAuth, Codex)
 *   Last:   other extensions' setStatus() texts, which the built-in footer would have shown
 *
 * /statusline toggles between this footer and the built-in one.
 */

import type { AssistantMessage, Usage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

const ESC = "\x1b[";
const c = (code: string, s: string) => `${ESC}${code}m${s}${ESC}0m`;
const DIM = (s: string) => c("2", s);
const BOLD = (s: string) => c("1", s);
const GRN = (s: string) => c("32", s);
const YEL = (s: string) => c("33", s);
const RED = (s: string) => c("31", s);
const CYN = (s: string) => c("36", s);
const MAG = (s: string) => c("35", s);
const BLU = (s: string) => c("34", s);
const SEP = DIM(" │ ");
const DOT = DIM(" · ");
// Tier colors from the Claude script: depth 1 blue, depth 2 pink, depth 3+ gold
const TIER = [81, 213, 221];
const tier = (depth: number, s: string) => c(`38;5;${TIER[Math.min(Math.max(depth, 1), 3) - 1]}`, s);

/** Human-readable token counts: 950, 12.3k, 4.56M */
function h(n: number): string {
	if (n >= 999_500) return `${Math.round(n / 10_000) / 100}M`;
	if (n >= 999.5) return `${Math.round(n / 100) / 10}k`;
	return `${Math.round(n)}`;
}

function dur(ms: number): string {
	const s = Math.floor(ms / 1000);
	if (s < 60) return `${s}s`;
	if (s < 3600) return `${Math.floor(s / 60)}m`;
	return `${Math.floor(s / 3600)}h${String(Math.floor((s % 3600) / 60)).padStart(2, "0")}m`;
}

const pctColor = (p: number) => (p >= 80 ? RED : p >= 50 ? YEL : GRN);

function clip(s: string, n: number): string {
	// Labels can come from the model, so strip control characters before printing them
	const t = s.replace(/[\x00-\x1f\x7f]/g, "");
	return t.length > n ? `${t.slice(0, n - 1)}…` : t;
}

// ── State fed by events ──────────────────────────────────────────────────────

type Agent = { id: string; label: string; depth: number; started: number; async: boolean };
const running = new Map<string, Agent>();
let used = 0;
let failed = 0;

type Limit = { pct: number; reset?: number };
const limits: { five?: Limit; seven?: Limit } = {};

let requestRender: (() => void) | undefined;
let ticker: ReturnType<typeof setInterval> | undefined;
let enabled = true;

function syncTicker() {
	// Running agents show elapsed time, so redraw every second while any are running
	if (running.size > 0 && !ticker) ticker = setInterval(() => requestRender?.(), 1000);
	if (running.size === 0 && ticker) {
		clearInterval(ticker);
		ticker = undefined;
	}
	requestRender?.();
}

function startAgent(a: Agent) {
	if (running.has(a.id)) return;
	running.set(a.id, a);
	used++;
	syncTicker();
}

function endAgent(id: string | undefined, ok: boolean) {
	if (!id || !running.delete(id)) return;
	if (!ok) failed++;
	syncTicker();
}

function subagentLabel(args: any): string {
	if (!args || typeof args !== "object") return "subagent";
	if (typeof args.agent === "string") return args.agent;
	if (Array.isArray(args.tasks)) return args.tasks.map((t: any) => t?.agent ?? "?").join("+");
	if (Array.isArray(args.chain)) return `chain: ${args.chain.map((s: any) => s?.agent ?? "…").join("→")}`;
	return "subagent";
}

// ── Rate-limit headers ───────────────────────────────────────────────────────

function num(v: unknown): number | undefined {
	const n = typeof v === "string" ? Number.parseFloat(v) : typeof v === "number" ? v : Number.NaN;
	return Number.isFinite(n) ? n : undefined;
}

function readLimits(headers: Record<string, string | string[] | undefined>) {
	const get = (k: string) => {
		const v = headers[k] ?? headers[k.toLowerCase()];
		return Array.isArray(v) ? v[0] : v;
	};
	// Anthropic subscription (OAuth): utilization is 0–1, reset is epoch seconds
	for (const [key, win] of [["five", "5h"], ["seven", "7d"]] as const) {
		const u = num(get(`anthropic-ratelimit-unified-${win}-utilization`));
		if (u !== undefined) {
			const r = num(get(`anthropic-ratelimit-unified-${win}-reset`));
			limits[key] = { pct: u <= 1 ? u * 100 : u, reset: r ? r * 1000 : undefined };
		}
	}
	// OpenAI Codex (ChatGPT plan): primary = 5h window, secondary = weekly window
	for (const [key, win] of [["five", "primary"], ["seven", "secondary"]] as const) {
		const u = num(get(`x-codex-${win}-used-percent`));
		if (u !== undefined) {
			const after = num(get(`x-codex-${win}-reset-after-seconds`));
			limits[key] = { pct: u, reset: after !== undefined ? Date.now() + after * 1000 : undefined };
		}
	}
}

// ── Rendering ────────────────────────────────────────────────────────────────

function addUsage(t: Usage, u: Usage | undefined) {
	if (!u) return;
	t.input += u.input ?? 0;
	t.output += u.output ?? 0;
	t.cacheRead += u.cacheRead ?? 0;
	t.cacheWrite += u.cacheWrite ?? 0;
	t.reasoning = (t.reasoning ?? 0) + (u.reasoning ?? 0);
	t.cost.total += u.cost?.total ?? 0;
}

const zero = (): Usage => ({
	input: 0,
	output: 0,
	cacheRead: 0,
	cacheWrite: 0,
	reasoning: 0,
	totalTokens: 0,
	cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
});
const all = (u: Usage) => u.input + u.output + u.cacheRead + u.cacheWrite;

function render(pi: ExtensionAPI, ctx: ExtensionContext, branch: string | null, statuses: ReadonlyMap<string, string>): string[] {
	// Session totals over every entry, matching the built-in footer (branches and compacted history count too)
	const main = zero();
	const toolUse = new Map<string, Usage & { n: number }>();
	const bg = zero();
	let calls = 0;
	let last: Usage | undefined;
	for (const e of ctx.sessionManager.getEntries() as any[]) {
		if (e.type === "message" && e.message.role === "assistant") {
			const u = (e.message as AssistantMessage).usage;
			addUsage(main, u);
			calls++;
		} else if (e.type === "message" && e.message.role === "toolResult" && e.message.usage) {
			const name = e.message.toolName ?? "tool";
			const t = toolUse.get(name) ?? Object.assign(zero(), { n: 0 });
			addUsage(t, e.message.usage);
			t.n++;
			toolUse.set(name, t);
		} else if (e.type === "usage" || ((e.type === "compaction" || e.type === "branch_summary") && e.usage)) {
			addUsage(bg, e.usage);
		}
	}
	// Last call = the latest assistant message on the current branch
	const br = ctx.sessionManager.getBranch() as any[];
	for (let i = br.length - 1; i >= 0; i--) {
		const e = br[i];
		if (e.type === "message" && e.message.role === "assistant") {
			last = e.message.usage;
			break;
		}
	}

	let cost = main.cost.total + bg.cost.total;
	for (const t of toolUse.values()) cost += t.cost.total;

	// ── Line 1
	const m = ctx.model;
	let model = BOLD(m?.name ?? m?.id ?? "?");
	if (m?.reasoning) {
		const lvl = pi.getThinkingLevel();
		if (lvl && lvl !== "off") model += DIM(` ${lvl}`);
	}
	const cwd = ctx.sessionManager.getCwd();
	const proj = cwd.split("/").filter(Boolean).pop() ?? cwd;
	const cu = ctx.getContextUsage();
	const win = cu?.contextWindow ?? m?.contextWindow ?? 0;
	const pct = cu?.percent == null ? null : Math.floor(cu.percent);
	let ctxStr: string;
	if (pct == null) {
		ctxStr = `ctx ${DIM("░░░░░░░░░░ ?%")} ?/${h(win)}`;
	} else {
		const filled = Math.min(10, Math.floor((pct + 5) / 10));
		const bar = "▓".repeat(filled) + "░".repeat(10 - filled);
		ctxStr = `ctx ${pctColor(pct)(`${bar} ${pct}%`)} ${h(cu?.tokens ?? 0)}/${h(win)}`;
	}
	if (last) {
		ctxStr += ` ${DIM(`(last call: cache read ${h(last.cacheRead)} · cache write ${h(last.cacheWrite)} · input ${h(last.input)} · out ${h(last.output)})`)}`;
	}
	const line1 = [
		model,
		BOLD(BLU(proj)) + (branch ? DIM(` (${branch})`) : ""),
		GRN(`$${cost.toFixed(2)}`),
		ctxStr,
	].join(SEP);

	// ── Line 2
	let line2: string;
	if (calls === 0 && toolUse.size === 0) {
		line2 = DIM("session tokens: none yet");
	} else {
		let total = all(main) + all(bg);
		for (const t of toolUse.values()) total += all(t);
		let out = h(main.output);
		if (main.reasoning) out += ` ${DIM(`(thinking ${h(main.reasoning)})`)}`;
		line2 = `${BOLD(`Σ ${h(total)}`)} tokens${SEP}`;
		line2 += `${CYN("cache read")} ${h(main.cacheRead)} · ${CYN("cache write")} ${h(main.cacheWrite)} · ${CYN("input")} ${h(main.input)} · ${MAG("output")} ${out}`;
		for (const [name, t] of [...toolUse].sort((a, b) => all(b[1]) - all(a[1]))) {
			const label = name === "ask_advisor" ? "advisor" : name;
			line2 += `${SEP}${YEL(label)} in ${h(t.input + t.cacheRead + t.cacheWrite)} · out ${h(t.output)} ${DIM(`(${t.n}×)`)}`;
		}
		if (all(bg) > 0) line2 += `${SEP}${DIM(`compaction/warm ${h(all(bg))}`)}`;
		line2 += `${SEP}${DIM(`${calls} API calls`)}`;
	}

	const lines = [line1, line2];

	// ── Subagents (only once the session has started one)
	if (used > 0) {
		const live = [...running.values()].sort((a, b) => a.started - b.started);
		let head = `${BOLD("agents")} `;
		head += live.length === 0 ? DIM("none active") : BOLD(`${live.length} active`);
		head += `${DIM(" │ used ")}${BOLD(String(used))}`;
		if (failed) head += DOT + RED(`${failed} failed`);
		lines.push(head);
		const now = Date.now();
		for (const a of live.slice(0, 6)) {
			lines.push(
				` ${tier(a.depth, `● ${clip(a.label, 40)}`)} ${DIM(`${a.async ? "async" : "fg"} · ${dur(now - a.started)}`)}`,
			);
		}
		if (live.length > 6) lines.push(DIM(` +${live.length - 6} more`));
	}

	// ── Rate limits (only when the provider sends them)
	const lim: string[] = [];
	const fmtReset = (t: number | undefined, long: boolean) => {
		if (!t) return "";
		const d = new Date(t);
		const hm = d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit", hour12: false });
		return DIM(` resets ${long ? `${d.toLocaleDateString(undefined, { weekday: "short" })} ` : ""}${hm}`);
	};
	if (limits.five) lim.push(`5h ${pctColor(limits.five.pct)(`${Math.floor(limits.five.pct)}%`)}${fmtReset(limits.five.reset, false)}`);
	if (limits.seven) lim.push(`7d ${pctColor(limits.seven.pct)(`${Math.floor(limits.seven.pct)}%`)}${fmtReset(limits.seven.reset, true)}`);
	if (lim.length) lines.push(`${BOLD("limits")} ${lim.join(SEP)}`);

	// ── Other extensions' statuses
	if (statuses.size > 0) {
		lines.push(
			[...statuses.entries()]
				.sort(([a], [b]) => a.localeCompare(b))
				.map(([, t]) => t.replace(/[\r\n\t]+/g, " "))
				.join(" "),
		);
	}
	return lines;
}

// ── Wiring ───────────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	const install = (ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		ctx.ui.setFooter((tui, _theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsub = footerData.onBranchChange(() => tui.requestRender());
			return {
				dispose() {
					unsub();
					requestRender = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					return render(pi, ctx, footerData.getGitBranch(), footerData.getExtensionStatuses()).map((l) =>
						truncateToWidth(l, width, DIM("…")),
					);
				},
			};
		});
	};

	pi.on("session_start", async (_e, ctx) => {
		running.clear();
		used = 0;
		failed = 0;
		syncTicker();
		if (enabled) install(ctx);
	});
	pi.on("session_shutdown", async () => {
		if (ticker) clearInterval(ticker);
		ticker = undefined;
	});

	pi.on("after_provider_response", (event) => {
		if (event.headers) {
			readLimits(event.headers as any);
			requestRender?.();
		}
	});

	for (const ev of ["model_select", "thinking_level_select", "turn_end", "message_end", "session_compact"] as const) {
		pi.on(ev as any, async () => requestRender?.());
	}

	// Foreground subagent calls run for the whole tool call. Async ones return at once
	// and are tracked through pi-subagents' lifecycle events below.
	pi.on("tool_execution_start", async (e) => {
		if (e.toolName === "subagent" && !(e.args as any)?.async && !(e.args as any)?.action) {
			startAgent({ id: e.toolCallId, label: subagentLabel(e.args), depth: 1, started: Date.now(), async: false });
		}
	});
	pi.on("tool_execution_end", async (e) => endAgent(e.toolCallId, !e.isError));

	pi.events.on("subagent:async-started", (p: any) => {
		const id = p?.id ?? p?.runId;
		if (!id) return;
		const label = Array.isArray(p.chain) && p.chain.length > 1 ? `chain: ${p.chain.join("→")}` : (p.agent ?? "subagent");
		startAgent({ id, label: String(label), depth: p.parentRunId || p.parentWorkflowRunId ? 2 : 1, started: Date.now(), async: true });
	});
	pi.events.on("subagent:async-complete", (p: any) => {
		endAgent(p?.id ?? p?.runId, p?.success !== false && p?.state !== "failed");
	});

	pi.registerCommand("statusline", {
		description: "Toggle the Claude-style status line footer",
		handler: async (_args, ctx) => {
			enabled = !enabled;
			if (enabled) install(ctx);
			else ctx.ui.setFooter(undefined);
			ctx.ui.notify(enabled ? "Status line enabled" : "Built-in footer restored", "info");
		},
	});
}
