export type AgentRowStatus = 'pending' | 'running' | 'waiting' | 'idle' | 'completed' | 'failed' | 'killed'

// A team's color; grey dresses agents on no team.
export type TeamColor = 'blue' | 'green' | 'purple' | 'red' | 'teal' | 'pink' | 'grey'

export type HatName =
  | 'cowboy hat'
  | 'beanie'
  | 'cap'
  | 'top hat'
  | 'wizard hat'
  | 'party hat'
  | 'chef hat'
  | 'viking helmet'
  | 'propeller cap'
  | 'beret'
  | 'bucket hat'
  | 'grad cap'

// What a Clawd wears: supervisors a crown, everyone else a hat.
export type Outfit = { color: TeamColor; tone: 'main' | 'light'; hat: HatName | 'crown' }

// The loop a Clawd plays, from what its agent is doing now.
export type Activity =
  | 'arrive'
  | 'think'
  | 'type'
  | 'search'
  | 'recruit'
  | 'message'
  | 'waitTeam'
  | 'idle'
  | 'celebrate'
  | 'rest'
  | 'failed'
  | 'killed'

// Per-frame details: a sweat drop on a long tool call, slowed typing past the cap.
export type FrameInfo = { isLong?: boolean; slowTyping?: boolean }

// A message an agent sent with SendMessage: how a supervisor steers its team.
export type Direction = { to: string; text: string }

// One agent as the pane draws it. Optional keys are left out, never undefined.
export type AgentRow = {
  id: string
  parentId?: string
  description: string
  type: string
  status: AgentRowStatus
  name?: string
  // The first part of the prompt its parent gave it.
  brief?: string
  // The last line of its latest text.
  says?: string
  // Its latest tool use, summarised.
  doing?: string
  directions: Direction[]
  startedAt?: number
  // Assigned once and kept for the session (see dressRows).
  outfit?: Outfit
  // The loop its Clawd plays now, and whether its tool call is a long one.
  activity?: Activity
  isLong?: boolean
  // Its latest block: a tool call (which, since when), that call's result, or text.
  tool?: string
  lastBlock?: 'text' | 'tool' | 'result'
  toolSince?: number
  // When it ended; 0 when it had already ended at the mod's first listing.
  endedAt?: number
}

declare module 'claude-code' {
  interface PluginState {
    supervisors: {
      rows: AgentRow[]
      // The time to the minute, for ages; written once a minute while agents run.
      now: number
      collapsed: string[]
      hideDone: boolean
      fullBriefs: boolean
      autoOpened: boolean
    }
  }
}
