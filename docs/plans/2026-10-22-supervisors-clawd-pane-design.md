# Supervisors pane with Clawd avatars: design

Date: 2026-10-22. Status: approved in conversation, ready to plan.

## Why

Gray runs Claude Code as a main agent that starts background "Supervisor:" agents, each of which runs its own team of sub-agents (often 5 supervisors and 50+ agents). He needs to see, at a glance, what each supervisor is doing and how it is directing its team, and to tell agents apart without reading every row. The existing `supervisors` mod (a pane plus a `teams` tool) shows this as text. This design gives every agent a small animated Clawd, dressed by team, whose loop shows what that agent is doing right now, and packages the mod so it reaches Gray's other machines and can be shared.

## Goals

- Every agent row in the Supervisors pane has its own animated Clawd.
- Team membership and identity are visible from the outfit alone.
- The Clawd's loop shows the agent's current activity.
- The mod reaches Gray's other machines through his dotfiles and can be installed by anyone from GitHub.
- Two settings: open the pane automatically, and animate the Clawds.

## Non-goals

- No change to how agents are spawned or directed; the mod only observes.
- No VS Code or mobile animation work beyond what the shared drawing gives for free.
- No publishing to the organization's claude.ai plugin library (a separate step, offered, not done).

## Anti-goals

- Animation must never slow Claude or the terminal noticeably, even with 50+ agents.
- The pane must never show a wrong team or a wrong activity for an agent.
- No Clawd art that departs from the decisions below without Gray seeing it first.

## What exists today

The mod lives at `~/.claude/dev-mods/bd0be390-a6b4-400c-8510-5606faa83741/supervisors/` (this session only):

- `hooks/register.tsx`: polls `$.agent.list()` every 1.5 s for the tree and statuses; hooks `session.append` (door `response`) for each agent's latest text and tool use and the brief in each Agent call; hooks `agent.spawn` (resumed runs ignored) for exact briefs; hooks `session.send` for messages; hooks `turn.complete` for how an agent ended. Keeps rows of agents the engine has dropped. Writes rows to `$.state`; draws the `Pane`; registers `/supervisors` and a `teams` tool (`mcp__supervisors__teams`) that returns the tree as text.
- `hooks/model.ts`: pure helpers (tree building, supervisor detection, tool-use summaries, outline text).
- `types/index.d.ts`: the `$.state` contract.
- `tests/supervisors.test.ts`: three tests through the engine's test kit.

All of that stays. This design adds avatars, settings and packaging.

## The Clawd model (decided)

- Style follows the clawd-animation skill (https://mmguo.dev/clawd/, repo lingbog/clawd-animation-skill): a coral `#CD6E58` Clawd with black eyes and no mouth, whose feeling comes from eyes, blush, marks, bubbles and motion. That skill has no license, so its body pixels are not used: Gray chose to redraw the body from Claude Code's own startup-banner Clawd (`▐▛███▜▌` / `▝▜█████▛▘` / `▘▘ ▝▝`) decoded to square pixels, an 18×10 body with eyes two pixels tall. Hats and loops are redrawn to fit it. Gray looks at the redraw before anything is published.
- Each Clawd is drawn in a 24×16 pixel scene (24 terminal columns × 8 rows): body at x 1–18, rows 6–15; hat rows 1–5; effects and props to the right.
- Reference implementations: the approved spike `/private/tmp/claude-502/-Users-gray-karegeannes--claude-spares-spare-qy4QoQ/bd0be390-a6b4-400c-8510-5606faa83741/scratchpad/crabs/engine.js` (loop behavior and timings), and its banner-body redraw `engine2.js` beside it (the art to port once Gray approves it).

## Outfits (decided)

- A supervisor (an agent with agents of its own, or whose description starts with "Supervisor:") wears a crown in its team's color.
- Team colors in the order supervisors appear: blue, green, purple, red, teal, pink, then repeat.
- Team members wear their team's color, each a different hat: cowboy hat, beanie, cap, top hat, wizard hat, party hat, chef hat, viking helmet, propeller cap, beret, bucket hat, grad cap; then the same 12 in the color's light tint (24 looks before a repeat).
- A supervisor inside another team wears a crown in its own team's color; the tree shows whose team it is on.
- Agents on no team wear grey hats.
- An agent keeps its outfit for the session, with one exception *(my call)*: an agent that starts leading a team after it first appeared changes once, to a crown in the next team color, and its members take that color.
- The `teams` tool names each agent's outfit ("blue cowboy hat", "green crown") so Gray and the main agent can refer to agents that way *(my call)*.
- Red team colors are `#D42A2A` / `#8C1C1C` / `#F08A8A` *(my call)*: the spike's red rounds to the same 256-color entry as Clawd's coral under Gray's tmux (`screen-256color`), which would hide red hats. Every team color stays distinct at 256 colors.

## Loops by activity (decided, as tuned)

| Activity | When | Loop |
| --- | --- | --- |
| arrive | status `pending`, or first 2 s after spawn | hops in from the left, then a "!" |
| think | running, last response block was text | glances left/right; "…" fills in |
| type | running, last tool is Edit, Write, MultiEdit, NotebookEdit, Bash or any tool not listed elsewhere | side-on Clawd (square block, both eyes, legs planted) at a side-view grey laptop; near and far arm blocks alternate on the keys every 40 ms (80 ms loop); the near arm swings two rows and the laptop dips a pixel with it; the struck key flashes; a sweat drop after 15 s on one tool |
| search | running, last tool is Read, Grep, Glob, LS, WebFetch, WebSearch, ToolSearch | eyes scan left/right behind a magnifying glass |
| recruit | running, last tool is Agent | raises a claw, gold sparkle on the beat |
| message | running, last tool is SendMessage | holds up an envelope that flies off |
| waitTeam | status `waiting`/`idle` and has a live team member | looks toward the team, taps a foot, "?" |
| idle | status `waiting`/`idle` otherwise | breathes, blinks |
| celebrate | `completed`, first 4 s after it ended | bounces, normal eyes, hearts rising, blush (hearts' pink `#F06090`) flashing every 300 ms |
| rest | `completed` after that | eyes as two 2-pixel horizontal lines, steady blush, a small grey "z" and a bigger dark "Z" drifting up every 2.4 s with a gap between them |
| failed | `failed` | looks down under a rain cloud with a sweat drop |
| killed | `killed` | `failed`'s pose without the cloud *(builder's call on the exact pose)* |

The thresholds (2 s arrive, 4 s celebrate, 15 s sweat) are my calls.

## Rendering (my calls)

- One pure engine module, `hooks/clawd.ts`, ported from the spike: `frames(activity, outfit, info) -> { stepMs, frames: Grid[] }`, a grid being 14 rows × 20 colors-or-null. The engine samples each vignette at its own step (type 40 ms, others 100–800 ms).
- Terminal: a `Client` surface module (`hooks/clawd-client.tsx`) per agent row, keyed by agent id, 20 columns × 7 rows. Each terminal row draws two pixel rows with `▀`/`▄` and `Text` colors, adjacent cells of the same colors merged into one `Text`. It advances frames on `surface.every(stepMs)`, picking the frame from elapsed time so it stays in phase when frames are dropped.
- Desktop, VS Code and mobile: an `Svg` (`isInteractive`) flipbook: every frame a `<g>` of row-merged `<rect>`s shown in turn by one CSS `steps` animation. No work in the hooks module per frame.
- Cost cap (decided by Gray): in the terminal, up to 8 typing Clawds tap at full speed; any typing Clawd beyond the first 8 (in pane order) taps once per second. Other loops step at 100 ms or slower and are not capped. Clawds in collapsed teams are not drawn. With "Animate Clawds" off, every Clawd shows its loop's first frame.
- Layout: each agent's Clawd sits left of its text block; the text block keeps today's lines (header, brief, doing, says, messages, team summary).

## Data the rows need (my calls)

Add to each `AgentRow`: `team` (a team index or none), `hat` (index 0–23, or crown), `tool` (last tool name), `lastBlock` (`text` or `tool`), `toolSince`, `endedAt`. Outfits are assigned in `refresh` when a row first appears and never change. The order teams and members appear is the order rows first appear.

## Settings (decided: toggles; my calls: names and defaults)

`userConfig` in `plugin.json`:
- `autoOpen` (boolean, default true): open the pane the first time a supervisor appears.
- `animate` (boolean, default true): animate the Clawds.

## Packaging and dotfiles (decided: dotfiles + distributable; my calls: layout)

- The plugin moves to `dotfiles/claude/.claude/skills/supervisors/`. Stow already links `~/.claude/skills` to that folder, and Claude Code loads a plugin it finds there, so every machine with the dotfiles gets it.
- `.gitignore` gains `!claude/.claude/skills/supervisors/`; the engine-generated `.claude-plugin/types/` stays ignored.
- The dotfiles repo (public, `sporaktu/dotfiles`) gains `.claude-plugin/marketplace.json` listing the plugin at `./claude/.claude/skills/supervisors`, so anyone can run `/plugin install supervisors --marketplace sporaktu/dotfiles`.
- The plugin folder gets `README.md` (what it does, both install routes, settings, credit to the clawd-animation skill for the animation style, and a note that Clawd is Anthropic's mascot drawn here from Claude Code's banner) and `LICENSE` (MIT for the plugin's code, my call). README warns not to install from the marketplace on a machine that already has the dotfiles copy (it would load twice).
- Build in this session's dev-mods folder (live reload); copy into dotfiles only when finished and Gray has approved the redrawn art, so no other session loads an unfinished plugin.
- Land it as one commit on `main`, pushed (decided by Gray), with Gray's unrelated uncommitted changes left out.

## Verification

- `claude plugin validate` clean (warnings about icon allowed); `tsc` clean.
- `claude plugin test`: engine (every activity × outfit renders a 14×20 grid; typing alternates every 40 ms; celebrate blush flashes; rest eyes are lines), outfit assignment (crowns, team colors in order, unique hats per team, grey for no team, stable across refreshes), activity mapping, and the pane mounting on terminal and desktop with a `Client` on terminal and an `Svg` on desktop.
- Live: a smoke supervisor with two workers in this session; read the tree through the `teams` tool. Gray looks at the pane in the desktop app and a terminal, since automated checks cannot see the real paint.
- A fresh `claude -p` run with no dev-mods confirms the dotfiles copy loads from `~/.claude/skills`.

## Left to the builder

File split inside `hooks/`, test structure, exact Svg/CSS encoding, `killed` pose details, README wording.
