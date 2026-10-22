import type { AgentRow, AgentRowStatus } from '../types'

import { activityLabel, outfitName } from './clawd'

export const MAIN = 'main'

export const ENDED: ReadonlySet<AgentRowStatus> = new Set(['completed', 'failed', 'killed'])

export const GLYPH: Record<AgentRowStatus, string> = {
  pending: '○',
  running: '●',
  waiting: '◐',
  idle: '◌',
  completed: '✓',
  failed: '✗',
  killed: '■',
}

export const TONE: Record<AgentRowStatus, string> = {
  pending: 'subtle',
  running: 'claude',
  waiting: 'warning',
  idle: 'suggestion',
  completed: 'success',
  failed: 'error',
  killed: 'inactive',
}

export function oneLine(text: string, max: number): string {
  const line = text.replace(/\s+/g, ' ').trim()

  return line.length > max ? `${line.slice(0, max - 1)}…` : line
}

export function lastLine(text: string, max: number): string | undefined {
  const lines = text
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')
  const last = lines.at(-1)

  return last === undefined ? undefined : oneLine(last, max)
}

// Where a brief is kept until its agent's id is known: the loop that spawned
// it and the description it gave, which `$.agent.list()` reports back.
export function briefKey(parent: string, description: string): string {
  return `${parent}\u0000${description}`
}

function shortPath(path: string): string {
  return path.split('/').filter(Boolean).slice(-2).join('/')
}

const ARG_KEYS = ['command', 'pattern', 'url', 'query', 'skill', 'prompt'] as const

export function describeToolUse(tool: string, input: Record<string, unknown>): string {
  const text = (key: string) => (typeof input[key] === 'string' ? (input[key] as string) : undefined)

  if (tool === 'Agent') {
    return oneLine(`spawn ${text('description') ?? 'agent'}`, 120)
  }
  if (tool === 'SendMessage') {
    return oneLine(`message ${String(input.to ?? '?')}: ${text('summary') ?? text('message') ?? ''}`, 120)
  }

  const name = tool.startsWith('mcp__') ? tool.slice(5).replace('__', ':') : tool
  const path = text('file_path') ?? text('path') ?? text('notebook_path')
  if (path !== undefined) {
    return oneLine(`${name} ${shortPath(path)}`, 120)
  }
  for (const key of ARG_KEYS) {
    const value = text(key)
    if (value !== undefined && value !== '') {
      return oneLine(`${name} ${value}`, 120)
    }
  }

  return name
}

export type Tree = {
  roots: AgentRow[]
  childrenOf: Map<string, AgentRow[]>
  byId: Map<string, AgentRow>
}

export function buildTree(rows: readonly AgentRow[]): Tree {
  const ids = new Set(rows.map(row => row.id))
  const childrenOf = new Map<string, AgentRow[]>()
  const roots: AgentRow[] = []

  for (const row of rows) {
    if (row.parentId === undefined || !ids.has(row.parentId)) {
      roots.push(row)
      continue
    }
    const siblings = childrenOf.get(row.parentId) ?? []
    siblings.push(row)
    childrenOf.set(row.parentId, siblings)
  }

  return { roots, childrenOf, byId: new Map(rows.map(row => [row.id, row])) }
}

// A SendMessage recipient as the pane names it: the agent's name or task when
// the address is one of this session's agent ids, else the address as given.
export function recipient(to: string, tree: Tree): string {
  const row = tree.byId.get(to)

  return row?.name ?? row?.description ?? to
}

export function isSupervisor(row: AgentRow, tree: Tree): boolean {
  return (tree.childrenOf.get(row.id)?.length ?? 0) > 0 || /^supervisor\b/i.test(row.description)
}

export function hasLive(row: AgentRow, tree: Tree): boolean {
  return !ENDED.has(row.status) || (tree.childrenOf.get(row.id) ?? []).some(child => hasLive(child, tree))
}

export function descendants(row: AgentRow, tree: Tree): AgentRow[] {
  return (tree.childrenOf.get(row.id) ?? []).flatMap(child => [child, ...descendants(child, tree)])
}

export function formatAge(ms: number): string {
  const minutes = Math.floor(ms / 60_000)
  if (minutes < 1) {
    return '<1m'
  }
  if (minutes < 60) {
    return `${minutes}m`
  }

  return `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, '0')}m`
}

// The tree as plain text, for the model: every supervisor and its team.
export function formatOutline(rows: readonly AgentRow[]): string {
  const tree = buildTree(rows)
  const leads = tree.roots.filter(row => isSupervisor(row, tree))
  const lines: string[] = []
  const walk = (row: AgentRow, depth: number) => {
    const pad = '  '.repeat(depth)
    const name = row.name !== undefined ? `, ${row.name}` : ''
    const outfit = row.outfit !== undefined ? ` · ${outfitName(row.outfit)}` : ''
    const loop = row.activity !== undefined ? ` · ${activityLabel(row.activity)}` : ''
    lines.push(`${pad}${GLYPH[row.status]} ${row.description} [${row.status}${name}]${outfit}${loop}`)
    if (row.brief !== undefined) {
      lines.push(`${pad}    brief: ${row.brief}`)
    }
    if (row.doing !== undefined && !ENDED.has(row.status)) {
      lines.push(`${pad}    doing: ${row.doing}`)
    }
    if (row.says !== undefined) {
      lines.push(`${pad}    says: ${row.says}`)
    }
    for (const sent of row.directions) {
      lines.push(`${pad}    → ${recipient(sent.to, tree)}: ${sent.text}`)
    }
    for (const member of tree.childrenOf.get(row.id) ?? []) {
      walk(member, depth + 1)
    }
  }
  for (const row of leads) {
    walk(row, 0)
  }

  return lines.length === 0 ? 'No supervisors in this session yet.' : lines.join('\n')
}
