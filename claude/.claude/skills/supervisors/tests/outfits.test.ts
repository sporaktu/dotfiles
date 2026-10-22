import { expect, test } from 'claude-code/testing'

import { HAT_ORDER, outfitName } from '../hooks/clawd'
import { formatOutline } from '../hooks/model'
import { dressRows } from '../hooks/outfits'
import type { AgentRow } from '../types'

function row(id: string, parentId?: string, description = `task ${id}`): AgentRow {
  return {
    id,
    ...(parentId !== undefined ? { parentId } : {}),
    description,
    type: 'general-purpose',
    status: 'running',
    directions: [],
  }
}

const outfitOf = (rows: AgentRow[], id: string) => rows.find(r => r.id === id)?.outfit

test('supervisors get crowns in team order and members wear their color', () => {
  const rows = dressRows([
    row('a', undefined, 'Supervisor: one'),
    row('b', undefined, 'Supervisor: two'),
    row('a1', 'a'),
    row('a2', 'a'),
    row('b1', 'b'),
  ])
  expect(outfitOf(rows, 'a')).toEqual({ color: 'blue', tone: 'main', hat: 'crown' })
  expect(outfitOf(rows, 'b')).toEqual({ color: 'green', tone: 'main', hat: 'crown' })
  expect(outfitOf(rows, 'a1')).toEqual({ color: 'blue', tone: 'main', hat: HAT_ORDER[0] })
  expect(outfitOf(rows, 'a2')).toEqual({ color: 'blue', tone: 'main', hat: HAT_ORDER[1] })
  expect(outfitOf(rows, 'b1')).toEqual({ color: 'green', tone: 'main', hat: HAT_ORDER[0] })
})

test('a team past 12 members switches to the light tint, past 24 it wraps', () => {
  const members = Array.from({ length: 25 }, (_, i) => row(`m${i}`, 'lead'))
  const rows = dressRows([row('lead', undefined, 'Supervisor: big'), ...members])
  expect(outfitOf(rows, 'm12')).toEqual({ color: 'blue', tone: 'light', hat: HAT_ORDER[0] })
  expect(outfitOf(rows, 'm24')).toEqual({ color: 'blue', tone: 'main', hat: HAT_ORDER[0] })
})

test('a seventh team reuses the first color', () => {
  const leads = Array.from({ length: 7 }, (_, i) => row(`s${i}`, undefined, `Supervisor: ${i}`))
  expect(outfitOf(dressRows(leads), 's6')).toEqual({ color: 'blue', tone: 'main', hat: 'crown' })
})

test('an agent on no team wears grey', () => {
  expect(outfitOf(dressRows([row('solo')]), 'solo')).toEqual({ color: 'grey', tone: 'main', hat: HAT_ORDER[0] })
})

test('dressing again changes nothing, even after a row is dropped', () => {
  const once = dressRows([row('a', undefined, 'Supervisor: one'), row('a1', 'a'), row('a2', 'a'), row('x')])
  expect(dressRows(once)).toEqual(once)
  const dropped = once.filter(r => r.id !== 'a1')
  expect(dressRows(dropped)).toEqual(dropped)
})

test('an agent that starts leading a team changes once, to a crown', () => {
  const before = dressRows([row('a', undefined, 'Supervisor: one'), row('a1', 'a')])
  const after = dressRows([...before, row('a1x', 'a1')])
  expect(outfitOf(after, 'a1')).toEqual({ color: 'green', tone: 'main', hat: 'crown' })
  expect(outfitOf(after, 'a1x')).toEqual({ color: 'green', tone: 'main', hat: HAT_ORDER[0] })
  expect(dressRows(after)).toEqual(after)
})

test('a row whose parent is gone is dressed as a root', () => {
  expect(outfitOf(dressRows([row('orphan', 'missing')]), 'orphan')?.color).toBe('grey')
})

test('the outline names each outfit', () => {
  expect(outfitName({ color: 'blue', tone: 'main', hat: 'cowboy hat' })).toBe('blue cowboy hat')
  expect(outfitName({ color: 'blue', tone: 'light', hat: 'beanie' })).toBe('light blue beanie')
  expect(outfitName({ color: 'green', tone: 'main', hat: 'crown' })).toBe('green crown')
  const outline = formatOutline(dressRows([row('a', undefined, 'Supervisor: one'), row('a1', 'a', 'Fix it')]))
  expect(outline).toContain('Supervisor: one [running] · blue crown')
  expect(outline).toContain('Fix it [running] · blue cowboy hat')
})

test('the outline names what each Clawd is doing', () => {
  const rows = dressRows([row('a', undefined, 'Supervisor: one'), { ...row('a1', 'a', 'Fix it'), activity: 'type' }])
  expect(formatOutline(rows)).toContain('Fix it [running] · blue cowboy hat · typing')
})
