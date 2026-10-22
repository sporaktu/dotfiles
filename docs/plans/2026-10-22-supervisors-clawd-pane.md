# Supervisors pane with Clawd avatars: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every agent in the `supervisors` mod's pane an animated, team-dressed Clawd whose loop shows its current activity, add two settings, and ship the mod through Gray's dotfiles and a public marketplace.

**Architecture:** Pure modules compute everything: `clawd.ts` draws a 24×16 frame for an activity and outfit, `outfits.ts` dresses rows, `activity.ts` picks each row's loop. `refresh` stores outfit and activity on each row in `$.state`; the pane draws a `Client` (terminal, half-block text driven by the surface's frame clock) or an `Svg` flipbook (desktop, VS Code, mobile) per row.

**Tech Stack:** Claude Code function-hook mod (TypeScript/TSX, `claude-code` API 2.1.299), `claude plugin validate|test`, `tsc` 5.6.

**Spec:** `docs/plans/2026-10-22-supervisors-clawd-pane-design.md`

## Global Constraints

- Mod folder while building: `MOD=/Users/gray.karegeannes/.claude/dev-mods/bd0be390-a6b4-400c-8510-5606faa83741/supervisors` (hot-reloads in this session). Final home: `claude/.claude/skills/supervisors/` in dotfiles.
- Art source of truth: `/private/tmp/claude-502/-Users-gray-karegeannes--claude-spares-spare-qy4QoQ/bd0be390-a6b4-400c-8510-5606faa83741/scratchpad/crabs/engine2.js` (approved). Port sprites, hats, colors, vignettes and timings exactly.
- Scene 24×16 pixels; terminal Clawd 24 columns × 8 rows.
- Team colors in order: blue, green, purple, red (`#D42A2A`/`#8C1C1C`/`#F08A8A`), teal, pink; grey for no team.
- Typing: arms swap every 40 ms; in the terminal, typing Clawds after the first 8 in pane order swap every 1000 ms.
- Thresholds: arrive 2000 ms after spawn, celebrate 4000 ms after ending, sweat after 15000 ms on one tool.
- Settings `autoOpen` and `animate`, both boolean, default true.
- No mod code throws into the engine: observers return what `next` returned.
- Commits: one commit on dotfiles `main` at the end, conventional subject, no Claude attribution lines; Gray's unrelated uncommitted changes stay out of it.

## Review Focus

- Agents already running or finished when the mod (re)loads: they get outfits, and finished ones show `rest`, not `celebrate`. Test in Task 3.
- A reload mid-session: every row keeps its outfit (rows seeded from `$.state`). Test in Task 2.
- A seventh team or a 25th team member: colors and hats wrap rather than break. Test in Task 2.
- A row whose parent is not in the rows (dropped or workflow parent): it is a root, dressed grey or as a supervisor. Test in Task 2.
- The largest flipbook stays under the `Svg` source limit (131072 characters), and 60 agents still render on both surfaces. Tests in Tasks 4 and 5.

---

### Task 1: Clawd engine

**Files:**
- Create: `$MOD/hooks/clawd.ts`, `$MOD/tests/clawd.test.ts`
- Modify: `$MOD/types/index.d.ts` (add the types below)

**Interfaces:**
- Produces, in `types/index.d.ts`: `TeamColor = 'blue'|'green'|'purple'|'red'|'teal'|'pink'|'grey'`; `HatName` (the 12 names in the spec's order); `Outfit = { color: TeamColor; tone: 'main'|'light'; hat: HatName|'crown' }`; `Activity = 'arrive'|'think'|'type'|'search'|'recruit'|'message'|'waitTeam'|'idle'|'celebrate'|'rest'|'failed'|'killed'`; `FrameInfo = { isLong?: boolean; slowTyping?: boolean }`.
- Produces, in `hooks/clawd.ts`: `SCENE = { width: 24, height: 16 }`; `type Grid = (string | null)[][]`; `TEAM_ORDER: TeamColor[]` (6, no grey); `HAT_ORDER: HatName[]` (12); `loopOf(activity, info): { ms: number; step: number }`; `frameAt(activity, outfit, t, info): Grid`; `framesOf(activity, outfit, info): Grid[]` (samples t = 0, step, … < ms).

- [ ] **Step 1: Write failing tests** in `tests/clawd.test.ts`:
  - every activity × every hat and the crown × every color × tone renders a 16×24 grid at t = 0, 41, 333, 1001, 2999;
  - `type` differs between t = 0 and t = 40 and repeats at t = 80; with `slowTyping`, t = 0 and t = 999 match and t = 1000 differs;
  - `celebrate`: blush `#F06090` at the cheek pixels at t = 310, absent at t = 0;
  - `rest`: eyes are lines (four `#000000` pixels on one row, none on the row above);
  - a red-team hat uses `#D42A2A`; a grey outfit uses `#8A8F98`.
- [ ] **Step 2: Run** `claude plugin test $MOD`. Expected: the new tests fail (module missing).
- [ ] **Step 3: Implement** `hooks/clawd.ts` by porting `engine2.js` to typed TypeScript (no behavior change, except that `loopOf('type', { slowTyping: true })` returns `{ ms: 2000, step: 1000 }`).
- [ ] **Step 4: Run** `claude plugin test $MOD` and `tsc -p` with the header tsconfig. Expected: all pass, no type errors.

### Task 2: Outfits

**Files:**
- Create: `$MOD/hooks/outfits.ts`, `$MOD/tests/outfits.test.ts`
- Modify: `$MOD/types/index.d.ts` (`AgentRow.outfit?: Outfit`), `$MOD/hooks/model.ts` (`formatOutline` names outfits)

**Interfaces:**
- Consumes: `Outfit`, `TEAM_ORDER`, `HAT_ORDER`; `buildTree`, `isSupervisor` from `model.ts`.
- Produces: `dressRows(rows: readonly AgentRow[]): AgentRow[]` (pure; same order; existing outfits kept except the late-supervisor rule); `outfitName(outfit: Outfit): string` (`"blue cowboy hat"`, `"light blue beanie"`, `"green crown"`).

- [ ] **Step 1: Write failing tests:**
  - two supervisors in order get `blue` then `green` crowns; their members get their color, hats in `HAT_ORDER`;
  - member 13 gets `tone: 'light'` and the first hat again; member 25 wraps to `main` and the first hat;
  - a seventh supervisor gets `blue` again;
  - a root with no children and no "Supervisor:" prefix gets grey;
  - dressing the output again changes nothing (stable), including after a row is removed;
  - a worker that gains a child switches once to a crown in the next team color; its child gets that color;
  - a row whose `parentId` names no row is dressed as a root;
  - `formatOutline` shows `[running, …] · blue cowboy hat`.
- [ ] **Step 2: Run** `claude plugin test $MOD`. Expected: fail.
- [ ] **Step 3: Implement** `dressRows`: walk rows in tree order (parents first); a supervisor without a crown takes `TEAM_ORDER[teamsSoFar % 6]`; a member takes its supervisor's color and the next index of its team (`HAT_ORDER[i % 12]`, tone `light` when `Math.floor(i / 12) % 2 === 1`); teams and indexes are counted from outfits already on the rows.
- [ ] **Step 4: Run** tests and `tsc`. Expected: pass.

### Task 3: Activity

**Files:**
- Create: `$MOD/hooks/activity.ts`, `$MOD/tests/activity.test.ts`
- Modify: `$MOD/types/index.d.ts` (`AgentRow` gains `activity?: Activity`, `isLong?: boolean`, `tool?: string`, `lastBlock?: 'text'|'tool'`, `toolSince?: number`, `endedAt?: number`), `$MOD/hooks/register.tsx` (capture and store them)

**Interfaces:**
- Consumes: `Tree`, `hasLive` from `model.ts`.
- Produces: `activityOf(row: AgentRow, tree: Tree, now: number): Activity`; `isLongOf(row: AgentRow, now: number): boolean`. `refresh` writes `activity`, `isLong` and `outfit` onto every row.

- [ ] **Step 1: Write failing tests** for `activityOf`, one per table row in the spec (`pending` → `arrive`; spawned 1 s ago → `arrive`; text last → `think`; `Edit`, `Bash`, an MCP tool → `type`; `Read`, `Grep`, `WebFetch` → `search`; `Agent` → `recruit`; `SendMessage` → `message`; waiting with a live child → `waitTeam`; idle without → `idle`; ended 3 s ago → `celebrate`; ended 5 s ago → `rest`; `endedAt: 0` → `rest`; `failed`, `killed`), and `isLongOf` false at 14 s, true at 16 s.
- [ ] **Step 2: Extend** `tests/supervisors.test.ts`: after a supervisor's `tool_use` row for `Bash`, the outline/state shows its row with `activity: 'type'`; an agent listed already `completed` at the first refresh gets `rest`.
- [ ] **Step 3: Run** tests. Expected: fail.
- [ ] **Step 4: Implement** `activity.ts`; in `register.tsx` record `tool`, `lastBlock` and `toolSince` (from `$.clock.now()`) in the `session.append` hook, set `endedAt` in `refresh` when a row first reads as ended (0 for rows ended at the first listing), and run `dressRows` then `activityOf`/`isLongOf` before writing rows.
- [ ] **Step 5: Run** tests and `tsc`. Expected: pass.

### Task 4: Renderers

**Files:**
- Create: `$MOD/hooks/halfblock.ts`, `$MOD/hooks/svg.ts`, `$MOD/hooks/clawd-client.tsx`, `$MOD/tests/render.test.ts`

**Interfaces:**
- Consumes: `framesOf`, `frameAt`, `loopOf`, `Grid`.
- Produces: `halfBlockRows(grid: Grid): Segment[][]` with `Segment = { text: string; color?: string; backgroundColor?: string }` (8 rows; `▀`/`▄`/space; runs of equal cells merged); `flipbookSvg(frames: Grid[], step: number, scale: number): string` (one `path` per color per frame, frames cycled by one CSS `steps(1)` animation, identical consecutive frames merged; one frame → no animation); `ClawdClient` (default export, `ClientModule<ClawdProps>`), `ClawdProps = { activity: Activity; outfit: Outfit; info: FrameInfo; animate: boolean }`, which draws `frameAt(…, elapsed)` and ticks on `surface.every(loopOf(…).step)` only when `animate`.

- [ ] **Step 1: Write failing tests:** `halfBlockRows` of a known grid yields the expected segments (top-only `▀`, bottom-only `▄`, both `▀` with background, merged runs); `flipbookSvg` for every activity stays under 131072 characters and contains one `<g>` per distinct frame; mounting a Pane that draws `ClawdClient` on `terminal` shows text, and after `ui.advance(40)` a `type` Clawd's drawing changes.
- [ ] **Step 2: Run** tests. Expected: fail.
- [ ] **Step 3: Implement** the three modules.
- [ ] **Step 4: Run** tests and `tsc`. Expected: pass.

### Task 5: Pane integration and settings

**Files:**
- Modify: `$MOD/hooks/register.tsx`, `$MOD/.claude-plugin/plugin.json`, `$MOD/tests/supervisors.test.ts`

**Interfaces:**
- Consumes: everything above. `register(on, options)` reads `options.autoOpen` and `options.animate` (default true when unset).

- [ ] **Step 1: Add** `userConfig` to `plugin.json`: `autoOpen` and `animate`, type boolean, default true, a title and description each.
- [ ] **Step 2: Write failing tests:** each row draws a `Client` (key `clawd-<id>`) on terminal and an `Svg` (alt naming the outfit and activity) on desktop, beside the existing text; with 10 typing rows, the `Client`s after the first 8 get `slowTyping: true` (read through the props the test kit exposes, or via `find` on the drawing); with `{ options: { animate: false } }` the drawing does not change after `advance(1000)`; with `{ options: { autoOpen: false } }` no `ui.open` happens when a supervisor appears; 60 agents mount on both surfaces.
- [ ] **Step 3: Run** tests. Expected: fail.
- [ ] **Step 4: Implement**: the avatar beside each row's text block (row `Box` with the avatar, then the text column), `slowTyping` computed in pane order for terminal only, `animate` passed through, auto-open gated by `autoOpen`.
- [ ] **Step 5: Run** `claude plugin validate $MOD`, `tsc`, `claude plugin test $MOD`. Expected: validation passes (only directory warnings), no type errors, all tests pass.

### Task 6: Live check in this session

- [ ] **Step 1:** End the turn so the mod reloads; start a background "Supervisor: smoke test 3" (haiku) that starts two workers which use Bash and Read, and messages one.
- [ ] **Step 2:** Call `mcp__supervisors__teams` while they run. Expected: outfits named (crown and two team hats), activities `type`/`search`/`waitTeam` as they work, then `celebrate` and `rest`.
- [ ] **Step 3:** Ask Gray to look at the pane in the desktop app (and a terminal session if he can) and report what he sees; fix anything he flags before packaging.

### Task 7: Package and land in dotfiles

**Files:**
- Create: `$MOD/README.md`, `$MOD/LICENSE` (MIT, Gray Karegeannes, 2026), dotfiles `.claude-plugin/marketplace.json`
- Modify: `$MOD/.claude-plugin/plugin.json` (version 0.2.0, author, license, homepage `https://github.com/sporaktu/dotfiles`), dotfiles `.gitignore`
- Copy: `$MOD` → `claude/.claude/skills/supervisors/` (without `.claude-plugin/types/`)

- [ ] **Step 1:** Write README: what it does, install from dotfiles (stow) or `/plugin install supervisors --marketplace sporaktu/dotfiles` (and the shell and desktop-app equivalents from the plugin-authoring reference), "use one route per machine", settings, `/supervisors`, the `teams` tool, credits (animation style: the clawd-animation skill; body: Claude Code's banner Clawd; Clawd is Anthropic's mascot).
- [ ] **Step 2:** Write `marketplace.json` (`name: "sporaktu"`, `owner: { name: "Gray Karegeannes" }`, one plugin entry `supervisors`, `source: "./claude/.claude/skills/supervisors"`), add `!claude/.claude/skills/supervisors/` to `.gitignore`, copy the mod.
- [ ] **Step 3: Verify:** `claude plugin validate claude/.claude/skills/supervisors` and `claude plugin validate .` (marketplace) pass; `git status` shows only the plugin, `.gitignore`, `marketplace.json` and the two docs as new or changed by this work; `claude plugin details supervisors` resolves the skills-folder copy.
- [ ] **Step 4: Commit and push** on `main`:

```bash
git add .gitignore .claude-plugin/marketplace.json claude/.claude/skills/supervisors docs/plans/2026-10-22-supervisors-clawd-pane-design.md docs/plans/2026-10-22-supervisors-clawd-pane.md
git commit -m "feat(claude): supervisors plugin, a pane of team-dressed animated Clawds"
git push origin main
```

Expected: push succeeds; `git log origin/main -1` shows the commit.
