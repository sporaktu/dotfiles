import { expect, test } from 'claude-code/testing'

import { HAT_ORDER, SCENE, TEAM_ORDER, frameAt, framesOf, loopOf, stillOf } from '../hooks/clawd'
import type { Activity, Outfit, TeamColor } from '../types'

const ACTIVITIES: Activity[] = [
  'arrive', 'think', 'type', 'search', 'recruit', 'message', 'waitTeam', 'idle', 'celebrate', 'rest', 'failed', 'killed',
]
const COLORS: TeamColor[] = [...TEAM_ORDER, 'grey']
const BLUE_COWBOY: Outfit = { color: 'blue', tone: 'main', hat: 'cowboy hat' }

const signature = (activity: Activity, t: number, slowTyping = false) =>
  JSON.stringify(frameAt(activity, BLUE_COWBOY, t, { slowTyping }))

test('every loop draws a 24x16 scene for every outfit', () => {
  for (const activity of ACTIVITIES) {
    for (const hat of [...HAT_ORDER, 'crown' as const]) {
      for (const color of COLORS) {
        for (const tone of ['main', 'light'] as const) {
          for (const t of [0, 41, 333, 1001, 2999]) {
            const grid = frameAt(activity, { color, tone, hat }, t, { isLong: true })
            expect(grid.length).toBe(SCENE.height)
            expect(grid.every(row => row.length === SCENE.width)).toBe(true)
          }
        }
      }
    }
  }
})

test('typing swaps arms every 40 ms in an 80 ms loop', () => {
  expect(signature('type', 0)).not.toBe(signature('type', 40))
  expect(signature('type', 0)).toBe(signature('type', 80))
  expect(loopOf('type', {})).toEqual({ ms: 80, step: 40 })
})

test('slow typing swaps arms once a second', () => {
  expect(signature('type', 0, true)).toBe(signature('type', 999, true))
  expect(signature('type', 0, true)).not.toBe(signature('type', 1000, true))
  expect(loopOf('type', { slowTyping: true })).toEqual({ ms: 2000, step: 1000 })
})

test('a just-finished Clawd flashes his blush', () => {
  const cheeks = (t: number) =>
    frameAt('celebrate', BLUE_COWBOY, t, {}).flatMap(row => row.slice(0, 19)).filter(c => c === '#F06090').length
  expect(cheeks(310)).toBe(2)
  expect(cheeks(0)).toBe(0)
})

test('a resting Clawd has line eyes', () => {
  const rows = frameAt('rest', BLUE_COWBOY, 0, {}).filter(row => row.includes('#000000'))
  expect(rows.length).toBe(1)
  expect(rows[0]?.filter(c => c === '#000000').length).toBe(4)
})

test('team colors reach the hats', () => {
  const has = (outfit: Outfit, color: string) => frameAt('idle', outfit, 0, {}).flat().includes(color)
  expect(has({ color: 'red', tone: 'main', hat: 'cowboy hat' }, '#D42A2A')).toBe(true)
  expect(has({ color: 'grey', tone: 'main', hat: 'beanie' }, '#8A8F98')).toBe(true)
})

test('frames sample a loop at its step', () => {
  expect(framesOf('type', BLUE_COWBOY, {}).length).toBe(2)
  expect(framesOf('rest', BLUE_COWBOY, {}).length).toBe(3)
})

test('every loop has a still frame that shows Clawd', () => {
  for (const activity of ACTIVITIES) {
    expect(stillOf(activity, BLUE_COWBOY, {}).flat().includes('#CD6E58')).toBe(true)
  }
})
