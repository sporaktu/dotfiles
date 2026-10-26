import type { Activity, AgentRow } from '../types'

import { ENDED, hasLive } from './model'
import type { Tree } from './model'

export const ARRIVE_MS = 2000
export const CELEBRATE_MS = 4000
export const LONG_TOOL_MS = 15_000

const SEARCH_TOOLS = new Set(['Read', 'Grep', 'Glob', 'LS', 'WebFetch', 'WebSearch', 'ToolSearch'])

// The loop a row's Clawd plays now. `endedAt` 0 means it had already ended
// when the mod first listed it: no celebration for that.
export function activityOf(row: AgentRow, tree: Tree, now: number): Activity {
  switch (row.status) {
    case 'failed':
      return 'failed'
    case 'killed':
      return 'killed'
    case 'completed':
      return row.endedAt !== undefined && row.endedAt > 0 && now - row.endedAt < CELEBRATE_MS ? 'celebrate' : 'rest'
    case 'pending':
      return 'arrive'
    case 'waiting':
    case 'idle':
      return (tree.childrenOf.get(row.id) ?? []).some(member => !ENDED.has(member.status)) ? 'waitTeam' : 'idle'
    case 'running':
      break
  }
  if (row.startedAt !== undefined && now - row.startedAt < ARRIVE_MS) {
    return 'arrive'
  }
  if (row.lastBlock !== 'tool' || row.tool === undefined) {
    return 'think'
  }
  if (SEARCH_TOOLS.has(row.tool)) {
    return 'search'
  }
  if (row.tool === 'Agent') {
    return 'recruit'
  }

  return row.tool === 'SendMessage' ? 'message' : 'type'
}

// A Clawd asleep (done a while) whose team, if it leads one, sleeps too: the
// pane drops its row. Idle and waiting agents stay, waiting for more work, and
// a message that resumes an agent brings it back.
export function isAsleep(row: AgentRow, tree: Tree): boolean {
  return row.activity === 'rest' && (tree.childrenOf.get(row.id) ?? []).every(member => isAsleep(member, tree))
}

// What the person chose to leave out: done agents (Hide done), and agents
// `/supervisors clear` removed, by the `endedAt` they had when it ran.
export type View = { isHidingDone: boolean; cleared: Readonly<Record<string, number>> }

// Whether the pane and the mini line show a row. A cleared agent stays gone
// until it ends again; one leading live work stays with its team.
export function isShown(row: AgentRow, tree: Tree, view: View): boolean {
  const isLive = hasLive(row, tree)
  const isCleared = !isLive && view.cleared[row.id] === (row.endedAt ?? 0)

  return !isAsleep(row, tree) && !isCleared && (!view.isHidingDone || isLive)
}

// A tool call still running past 15 seconds: the typing Clawd breaks a sweat.
export function isLongOf(row: AgentRow, now: number): boolean {
  return row.lastBlock === 'tool' && row.toolSince !== undefined && now - row.toolSince > LONG_TOOL_MS
}
