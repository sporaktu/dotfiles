# supervisors

A Claude Code pane for sessions where the main agent starts supervisor agents that run teams of their own. Each agent gets a row and a small animated Clawd. The Clawd's outfit says which team the agent is on, and its loop says what the agent is doing right now.

## What the pane shows

- **Supervisors**: any agent that has started agents of its own, or whose description starts with `Supervisor:`. Each one shows its status, its latest tool call, the last line it wrote, the messages it sent its team, and a team count.
- **Team members** under their supervisor: the brief the supervisor gave each one and its current tool call. Click a supervisor's row to fold its team; **Hide done** also hides failed, stopped and just-finished agents; **Full briefs** shows briefs whole.
- **Other agents**: anything not on a team.
- **Finished agents leave**: once an agent's Clawd falls asleep, its row goes, unless someone on its team is still at work, idle or failed. Idle and waiting agents stay, since they wait for more work, and a message that resumes an agent brings it back. The `teams` tool still lists everyone.

### The Clawds

- A supervisor wears a crown in its team's color. Teams get colors in the order they appear: blue, green, purple, red, teal, pink, then repeat.
- Team members wear their team's color, each in a different hat (cowboy hat, beanie, cap, top hat, wizard hat, party hat, chef hat, viking helmet, propeller cap, beret, bucket hat, grad cap), then the same twelve in a lighter tint. Agents on no team wear grey.
- An agent keeps its outfit for the session. An agent that starts leading a team switches once, to a crown in a new color.

| The agent is | Its Clawd |
| --- | --- |
| just started | hops in, then a "!" |
| writing text | glances around, "…" |
| editing or running commands | turns side-on and types on a laptop (a sweat drop after 15 s on one call) |
| reading or searching | scans with a magnifying glass |
| starting an agent | waves it in |
| sending a message | holds up an envelope |
| waiting on its team | taps a foot, "?" |
| idle | breathes and blinks |
| just finished | bounces with hearts, blushing |
| done a while | sleeps, z's drifting up, only while its team is still out; otherwise it leaves the pane |
| failed | under a rain cloud |
| stopped | looks down |

In a terminal each Clawd is 24 columns by 8 rows, drawn in half-block characters. Past 8 Clawds typing at once, the rest tap once a second so the terminal stays smooth. In the desktop app each Clawd is a small animated image.

## Commands and tools

- `/supervisors` opens the pane.
- The `teams` tool (`mcp__supervisors__teams`) gives the main agent the same tree as text, outfit and loop included, so you can ask "what are my supervisors doing?" without opening the pane.

## Settings

| Setting | Default | What it does |
| --- | --- | --- |
| `autoOpen` | on | Opens the pane the first time a supervisor appears. Off: open it with `/supervisors`. |
| `animate` | on | Plays the loops. Off: every Clawd shows a still frame. |

Change them in `/config`, or with `claude plugin configure supervisors`.

## Install

Use one route per machine; with both, the plugin loads twice.

**With these dotfiles** (GNU Stow): `stow --target=$HOME claude` links `~/.claude/skills` to this repository's `claude/.claude/skills`, and Claude Code loads the plugin from there in every new session.

**From the marketplace**, at the prompt of a terminal session:

```
/plugin install supervisors --marketplace sporaktu/dotfiles
```

From a shell:

```bash
claude plugin install supervisors --marketplace sporaktu/dotfiles
```

In the desktop app, where `/plugin` does not run: click + next to the prompt box, then Plugins, Add marketplace with `sporaktu/dotfiles`, then Add plugin.

## Developing

```bash
claude plugin validate claude/.claude/skills/supervisors
claude plugin test claude/.claude/skills/supervisors
```

The art lives in `hooks/clawd.ts`, a pure module: `frameAt(activity, outfit, t, info)` returns a 24×16 grid of colors.

## Credits

Clawd is Anthropic's Claude Code mascot. His body here is decoded from the Clawd that Claude Code prints at startup. The animation style (feeling shown through eyes, blush, marks, bubbles and motion) follows the clawd-animation skill by mmguo (https://mmguo.dev/clawd/); none of its art is copied.

The plugin's code is under the MIT license (see `LICENSE`).
