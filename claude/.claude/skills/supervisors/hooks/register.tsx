import { atom, read, update } from 'claude-code'
import type { AgentInfo, EngineInterface, Register, RenderElement } from 'claude-code'

import type { Activity, AgentRow, AgentRowStatus, Direction, FrameInfo, Outfit } from '../types'
import {
  ENDED,
  GLYPH,
  MAIN,
  TONE,
  briefKey,
  buildTree,
  describeToolUse,
  descendants,
  formatAge,
  formatOutline,
  hasLive,
  isSupervisor,
  lastLine,
  oneLine,
  recipient,
} from './model'
import { activityOf, isAsleep, isLongOf } from './activity'
import { activityLabel, framesOf, loopOf, outfitName, stillOf } from './clawd'
import { dressRows } from './outfits'
import { flipbookSvg } from './svg'

const PANE = 'supervisors'
const TITLE = 'Supervisors'
const REFRESH_MS = 1500
const BRIEF_MAX = 400
const KEPT_DIRECTIONS = 5
const KEPT_ROWS = 400
// Typing Clawds past this many, in pane order, tap once a second in the terminal.
const FAST_TYPISTS = 8
const SVG_SCALE = 3
const FLIPBOOKS_KEPT = 200

const rows = atom({ plugin: 'supervisors', key: 'rows' } as const, [])
const now = atom({ plugin: 'supervisors', key: 'now' } as const, 0)
const collapsed = atom({ plugin: 'supervisors', key: 'collapsed' } as const, [])
const hideDone = atom({ plugin: 'supervisors', key: 'hideDone' } as const, false)
const fullBriefs = atom({ plugin: 'supervisors', key: 'fullBriefs' } as const, false)
const autoOpened = atom({ plugin: 'supervisors', key: 'autoOpened' } as const, false)

type Seen = {
  says?: string
  doing?: string
  tool?: string
  lastBlock?: 'text' | 'tool' | 'result'
  toolSince?: number
  // A tool call seen since the last refresh, which stamps its start time.
  isToolNew?: boolean
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

// Flipbooks by loop and outfit: the desktop pane redraws often, the art rarely changes.
const flipbooks = new Map<string, string>()

function flipbookFor(activity: Activity, outfit: Outfit, info: FrameInfo): string {
  const key = JSON.stringify([activity, outfit, info])
  const kept = flipbooks.get(key)
  if (kept !== undefined) {
    return kept
  }
  const svg = flipbookSvg(framesOf(activity, outfit, info), loopOf(activity, info).step, SVG_SCALE)
  if (flipbooks.size >= FLIPBOOKS_KEPT) {
    flipbooks.clear()
  }
  flipbooks.set(key, svg)

  return svg
}

function endedAs(reason: string | undefined): AgentRowStatus {
  if (reason === 'error' || reason === 'refusal') {
    return 'failed'
  }

  return reason === 'aborted' ? 'killed' : 'completed'
}

// What the hooks saw, by agent id (MAIN for the main loop). A reload starts
// it over; `$.agent.list()` still gives the tree and every status.
type Tracker = {
  briefs: Map<string, string>
  pendingBriefs: Map<string, string>
  activity: Map<string, Seen>
  directions: Map<string, Direction[]>
  startedAt: Map<string, number>
  turnEnds: Map<string, string>
  preexisting: Set<string>
  // Rows keep their last state after the engine drops a finished agent from
  // its list, so a supervisor's whole team stays visible.
  known: Map<string, AgentRow>
  hasListed: boolean
  isRefreshing: boolean
  lastJson: string
  lastMinute: number
}

function newTracker(): Tracker {
  return {
    briefs: new Map(),
    pendingBriefs: new Map(),
    activity: new Map(),
    directions: new Map(),
    startedAt: new Map(),
    turnEnds: new Map(),
    preexisting: new Set(),
    known: new Map(),
    hasListed: false,
    isRefreshing: false,
    lastJson: '',
    lastMinute: -1,
  }
}

// Each field falls back to the row already kept, so what was seen before a
// reload (rows are seeded from $.state) is not lost to the empty tables.
function toRow(t: Tracker, agent: AgentInfo): AgentRow {
  const prev = t.known.get(agent.id)
  const brief =
    t.briefs.get(agent.id) ?? t.pendingBriefs.get(briefKey(agent.parentId ?? MAIN, agent.description)) ?? prev?.brief
  const seen = t.activity.get(agent.id) ?? {}
  const says = seen.says ?? prev?.says
  const doing = seen.doing ?? prev?.doing
  const tool = seen.tool ?? prev?.tool
  const lastBlock = seen.lastBlock ?? prev?.lastBlock
  const toolSince = seen.toolSince ?? prev?.toolSince
  const started = t.startedAt.get(agent.id) ?? prev?.startedAt
  // An agent resumed after it ended is live again: its end no longer stands.
  const endedAt = ENDED.has(agent.status) ? prev?.endedAt : undefined

  return {
    id: agent.id,
    ...(agent.parentId !== undefined ? { parentId: agent.parentId } : {}),
    description: agent.description || agent.name || agent.type,
    type: agent.type,
    status: agent.status,
    ...(agent.name !== undefined ? { name: agent.name } : {}),
    ...(brief !== undefined ? { brief } : {}),
    ...(says !== undefined ? { says } : {}),
    ...(doing !== undefined ? { doing } : {}),
    directions: t.directions.get(agent.id) ?? prev?.directions ?? [],
    ...(started !== undefined ? { startedAt: started } : {}),
    ...(prev?.outfit !== undefined ? { outfit: prev.outfit } : {}),
    ...(tool !== undefined ? { tool } : {}),
    ...(lastBlock !== undefined ? { lastBlock } : {}),
    ...(toolSince !== undefined ? { toolSince } : {}),
    ...(endedAt !== undefined ? { endedAt } : {}),
  }
}

async function refresh($: EngineInterface, t: Tracker, isAutoOpen: boolean) {
  if (t.isRefreshing) {
    return
  }
  t.isRefreshing = true
  try {
    const agents = await $.agent.list()
    const time = await $.clock.now()
    const listed = new Set(agents.map(agent => agent.id))
    for (const seen of t.activity.values()) {
      if (seen.isToolNew) {
        seen.toolSince = time
        seen.isToolNew = false
      }
    }

    for (const agent of agents) {
      if (!t.hasListed) {
        t.preexisting.add(agent.id)
      } else if (!t.startedAt.has(agent.id) && !t.preexisting.has(agent.id)) {
        t.startedAt.set(agent.id, time)
      }
      const row = toRow(t, agent)
      const isNewlyEnded = ENDED.has(row.status) && row.endedAt === undefined
      // Ended before the mod's first listing: 0, so it rests rather than celebrates.
      const endedAt = !t.known.has(agent.id) && !t.hasListed ? 0 : time
      t.known.set(agent.id, isNewlyEnded ? { ...row, endedAt } : row)
    }
    t.hasListed = true
    for (const [id, row] of t.known) {
      if (!listed.has(id) && !ENDED.has(row.status)) {
        t.known.set(id, { ...row, status: endedAs(t.turnEnds.get(id)), endedAt: time })
      }
    }
    for (const [id, row] of t.known) {
      if (t.known.size <= KEPT_ROWS) {
        break
      }
      if (!listed.has(id) && ENDED.has(row.status)) {
        t.known.delete(id)
      }
    }

    const dressed = dressRows([...t.known.values()])
    const dressedTree = buildTree(dressed)
    const next = dressed.map(row => ({
      ...row,
      activity: activityOf(row, dressedTree, time),
      isLong: isLongOf(row, time),
    }))
    for (const row of next) {
      t.known.set(row.id, row)
    }
    const json = JSON.stringify(next)
    if (json !== t.lastJson) {
      t.lastJson = json
      await $.state.set({ plugin: 'supervisors', key: 'rows' }, next)
    }

    const minute = Math.floor(time / 60_000) * 60_000
    if (minute !== t.lastMinute && (t.lastMinute === -1 || next.some(row => !ENDED.has(row.status)))) {
      t.lastMinute = minute
      await $.state.set({ plugin: 'supervisors', key: 'now' }, minute)
    }

    const tree = buildTree(next)
    const hasSupervisor = tree.roots.some(row => isSupervisor(row, tree) && hasLive(row, tree))
    if (isAutoOpen && hasSupervisor && !(await read($, autoOpened))) {
      await update($, autoOpened, () => true)
      void $.ui.open({ id: PANE, title: TITLE })
    }
  } finally {
    t.isRefreshing = false
  }
}

export const register: Register = (on, options) => {
  let t = newTracker()
  const isAutoOpen = options.autoOpen !== false
  const isAnimated = options.animate !== false

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'supervisors',
      description: 'Show supervisor agents, what they are doing, and how they direct their teams',
    })
    await $.tool.register({
      name: 'teams',
      description:
        "Lists this session's supervisor agents and their teams as an outline: each agent's status, what it is doing now, the brief its supervisor gave it, and the messages supervisors sent their team members.",
      inputSchema: { type: 'object', properties: {} },
    })
    if (t.known.size === 0) {
      for (const row of await read($, rows)) {
        t.known.set(row.id, row)
      }
    }
    $.clock.every(REFRESH_MS, () => void refresh($, t, isAutoOpen))
    void refresh($, t, isAutoOpen)

    return next(e)
  })

  on('session.end', ($, e, next) => {
    t = newTracker()

    return next(e)
  })

  on('tool.call', { tool: 'mcp__supervisors__teams' }, async $ => ({ result: formatOutline(await read($, rows)) }))

  on('command.run', { command: 'supervisors' }, async $ => {
    await $.ui.open({ id: PANE, title: TITLE })

    return { text: 'Supervisors pane opened.' }
  })

  // The exact brief for each new agent, when this hook hears its spawn. A
  // resumed run's prompt is the message that woke it, never its brief.
  on('agent.spawn', async ($, e, next) => {
    const started = await next(e)
    if (started.agentId !== undefined && e.workflow === undefined && e.resume === undefined) {
      t.briefs.set(started.agentId, oneLine(e.prompt, BRIEF_MAX))
      t.startedAt.set(started.agentId, await $.clock.now())
    }

    return started
  })

  // Every agent's response blocks: its narration, its latest tool use, and the
  // brief in each Agent call, matched to the child by its description. This
  // covers spawns nested where the agent.spawn hook above is not run.
  on('session.append', { door: 'response' }, ($, e, next) => {
    const loop = e.agentId ?? MAIN
    for (const block of e.message.content) {
      if (block.type === 'text' && typeof block.text === 'string') {
        const says = lastLine(block.text, 160)
        if (says !== undefined) {
          t.activity.set(loop, { ...t.activity.get(loop), says, lastBlock: 'text' })
        }
      }
      if (block.type === 'tool_use' && typeof block.name === 'string') {
        const input = isRecord(block.input) ? block.input : {}
        t.activity.set(loop, {
          ...t.activity.get(loop),
          doing: describeToolUse(block.name, input),
          tool: block.name,
          lastBlock: 'tool',
          isToolNew: true,
        })
        if (block.name === 'Agent' && typeof input.description === 'string' && typeof input.prompt === 'string') {
          t.pendingBriefs.set(briefKey(loop, input.description), oneLine(input.prompt, BRIEF_MAX))
        }
      }
    }

    return next(e)
  })

  // A tool's result: the call is over and the agent is thinking again.
  on('session.append', { door: 'tool-result' }, ($, e, next) => {
    const loop = e.agentId ?? MAIN
    const seen = t.activity.get(loop)
    if (seen?.lastBlock === 'tool') {
      t.activity.set(loop, { ...seen, lastBlock: 'result' })
    }

    return next(e)
  })

  on('session.send', async ($, e, next) => {
    const sent = await next(e)
    if (sent.isDelivered) {
      const loop = e.agentId ?? MAIN
      const kept = [...(t.directions.get(loop) ?? []), { to: e.to, text: oneLine(e.text, 160) }]
      t.directions.set(loop, kept.slice(-KEPT_DIRECTIONS))
    }

    return sent
  })

  on('turn.complete', ($, e, next) => {
    if (e.agentId !== undefined) {
      t.turnEnds.set(e.agentId, e.reason)
    }

    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const all = await read($, rows)
    const time = await read($, now)
    const folded = new Set(await read($, collapsed))
    const isHidingDone = await read($, hideDone)
    const isFull = await read($, fullBriefs)
    const tree = buildTree(all)
    const isShown = (row: AgentRow) => !isAsleep(row, tree) && (!isHidingDone || hasLive(row, tree))

    const statusOf = (row: AgentRow) =>
      row.startedAt !== undefined && time > 0 && !ENDED.has(row.status)
        ? `${row.status} · ${formatAge(time - row.startedAt)}`
        : row.status

    const head = (row: AgentRow, fold: string) => [
      fold,
      <Text color={TONE[row.status]}>{GLYPH[row.status]}</Text>,
      ' ',
      <Text bold={isSupervisor(row, tree)}>{row.description}</Text>,
      <Text dimColor> {statusOf(row)}</Text>,
    ]

    const detail = (label: string, text: string, isWrapped = false) => (
      <Text wrap={isWrapped ? 'wrap' : 'truncate'}>
        <Text dimColor>{label} </Text>
        {text}
      </Text>
    )

    // Typing Clawds counted in pane order, for the terminal's speed cap.
    let typists = 0
    const avatar = (row: AgentRow) => {
      if (row.outfit === undefined || row.activity === undefined) {
        return null
      }
      if (e.surface === 'terminal') {
        const { Client } = $.ui.resolve(e)
        const isSlow = row.activity === 'type' && ++typists > FAST_TYPISTS
        const info: FrameInfo = { isLong: row.isLong === true, slowTyping: isSlow }

        return (
          <Client
            key={`clawd-${row.id}`}
            module="./clawd-client.tsx"
            props={{ activity: row.activity, outfit: row.outfit, info, animate: isAnimated }}
            width={24}
            height={8}
          />
        )
      }
      const { Svg } = $.ui.resolve(e)
      const info: FrameInfo = { isLong: row.isLong === true }
      const alt = `${row.description}: ${outfitName(row.outfit)}, ${activityLabel(row.activity)}`
      // Animation needs the interactive frame: without it the surface draws an image.
      return isAnimated ? (
        <Svg
          source={flipbookFor(row.activity, row.outfit, info)}
          alt={alt}
          width={24 * SVG_SCALE}
          height={16 * SVG_SCALE}
          isInteractive
        />
      ) : (
        <Svg
          source={flipbookSvg([stillOf(row.activity, row.outfit, info)], 1, SVG_SCALE)}
          alt={alt}
          width={24 * SVG_SCALE}
          height={16 * SVG_SCALE}
        />
      )
    }

    const teamLine = (row: AgentRow) => {
      const team = descendants(row, tree)
      const running = team.filter(member => !ENDED.has(member.status)).length

      return `team ${team.length} · ${running} active · ${team.length - running} done`
    }

    const renderAgent = (row: AgentRow, depth: number): RenderElement => {
      const isLead = isSupervisor(row, tree)
      const isOpen = !folded.has(row.id)
      const isLive = !ENDED.has(row.status)
      const team = (tree.childrenOf.get(row.id) ?? []).filter(isShown)

      return (
        <Box key={`agent-${row.id}`} flexDirection="column" paddingLeft={depth === 0 ? 0 : 2}>
          <Box flexDirection="row" gap={1}>
            {avatar(row)}
            <Box flexDirection="column" flexGrow={1}>
              {isLead ? (
                <Button
                  key={`fold-${row.id}`}
                  plain
                  onPress={() =>
                    update($, collapsed, list =>
                      list.includes(row.id) ? list.filter(id => id !== row.id) : [...list, row.id],
                    )
                  }
                >
                  {head(row, isOpen ? '▾ ' : '▸ ')}
                </Button>
              ) : (
                <Text wrap="truncate">{head(row, '')}</Text>
              )}
              <Box flexDirection="column" paddingLeft={isLead ? 4 : 2}>
                {row.brief !== undefined && (!isLead || isOpen) && detail('brief', row.brief, isFull)}
                {isLive && row.doing !== undefined && (!isLead || isOpen) && detail('doing', row.doing)}
                {isLead && isOpen && isLive && row.says !== undefined && detail('says', row.says)}
                {isLead && isOpen && row.directions.slice(-3).map(sent => detail('→', `${recipient(sent.to, tree)}: ${sent.text}`))}
                {isLead && isOpen && <Text dimColor>{teamLine(row)}</Text>}
              </Box>
            </Box>
          </Box>
          {isLead && isOpen && team.map(member => renderAgent(member, depth + 1))}
        </Box>
      )
    }

    const leads = tree.roots.filter(row => isSupervisor(row, tree) && isShown(row))
    const others = tree.roots.filter(row => !isSupervisor(row, tree) && isShown(row))
    const members = leads.flatMap(row => descendants(row, tree))
    const active = members.filter(member => !ENDED.has(member.status)).length

    return (
      <Box flexDirection="column">
        <Box justifyContent="space-between">
          <Text dimColor wrap="truncate">
            {leads.length} supervisors · {members.length} in teams · {active} active
          </Text>
          <Box gap={1}>
            <Button
              key="hide-done"
              label={isHidingDone ? 'Show done' : 'Hide done'}
              onPress={() => update($, hideDone, value => !value)}
            />
            <Button
              key="full-briefs"
              label={isFull ? 'Short briefs' : 'Full briefs'}
              onPress={() => update($, fullBriefs, value => !value)}
            />
          </Box>
        </Box>
        {leads.length === 0 &&
          (tree.roots.some(row => isSupervisor(row, tree)) ? (
            <Text dimColor>No supervisors at work. Finished agents leave the pane; the teams tool still lists them.</Text>
          ) : (
            <Text dimColor>
              No supervisors yet. An agent shows here once it spawns agents of its own, or when its description starts
              with "Supervisor:".
            </Text>
          ))}
        {leads.map(row => (
          <Box key={`lead-${row.id}`} flexDirection="column" marginTop={1}>
            {renderAgent(row, 0)}
          </Box>
        ))}
        {others.length > 0 && (
          <Box flexDirection="column" marginTop={1}>
            <Text dimColor>Other agents</Text>
            {others.map(row => renderAgent(row, 1))}
          </Box>
        )}
      </Box>
    )
  })
}
