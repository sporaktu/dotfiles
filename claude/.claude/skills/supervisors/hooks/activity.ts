import type { Activity, AgentRow } from '../types'

import { ENDED } from './model'
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

// A tool call still running past 15 seconds: the typing Clawd breaks a sweat.
export function isLongOf(row: AgentRow, now: number): boolean {
  return row.lastBlock === 'tool' && row.toolSince !== undefined && now - row.toolSince > LONG_TOOL_MS
}
