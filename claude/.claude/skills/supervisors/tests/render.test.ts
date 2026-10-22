import { expect, test } from 'claude-code/testing'

import ClawdClient from '../hooks/clawd-client'
import type { ClawdProps } from '../hooks/clawd-client'
import { framesOf, loopOf } from '../hooks/clawd'
import { halfBlockRows } from '../hooks/halfblock'
import { flipbookSvg } from '../hooks/svg'
import type { Activity, Outfit } from '../types'

const A = '#111111'
const B = '#222222'
const BLUE_COWBOY: Outfit = { color: 'blue', tone: 'main', hat: 'cowboy hat' }
const ACTIVITIES: Activity[] = [
  'arrive', 'think', 'type', 'search', 'recruit', 'message', 'waitTeam', 'idle', 'celebrate', 'rest', 'failed', 'killed',
]

test('half blocks pack two pixel rows into one text row, merging equal cells', () => {
  const rows = halfBlockRows([
    [A, A, null, A, null],
    [null, null, B, B, null],
  ])
  expect(rows).toEqual([
    [
      { text: '▀▀', color: A },
      { text: '▄', color: B },
      { text: '▀', color: A, backgroundColor: B },
      { text: ' ' },
    ],
  ])
})

test('every flipbook fits the Svg limit and keeps one group per distinct frame', () => {
  for (const activity of ACTIVITIES) {
    const info = { isLong: true }
    const svg = flipbookSvg(framesOf(activity, BLUE_COWBOY, info), loopOf(activity, info).step, 3)
    expect(svg.length).toBeLessThan(131072)
  }
  const typing = flipbookSvg(framesOf('type', BLUE_COWBOY, {}), 40, 3)
  expect(typing.match(/<g /g)?.length).toBe(2)
  expect(typing).toContain('80ms')
  const still = flipbookSvg(framesOf('killed', BLUE_COWBOY, {}), 1000, 3)
  expect(still).not.toContain('@keyframes')
})

// A stand-in surface: element constructors that return plain data, and a
// frame clock the test drives by hand.
function fakeSurface() {
  const timers: { ms: number; fn: () => void; isStopped: boolean }[] = []
  const surface = {
    elements: {
      Box: (props: object) => ({ type: 'Box', props }),
      Text: (props: object) => ({ type: 'Text', props }),
    },
    state: undefined as unknown,
    setState(next: unknown) {
      surface.state = next
    },
    columns: 24,
    rows: 8,
    every(ms: number, fn: () => void) {
      const timer = { ms, fn, isStopped: false }
      timers.push(timer)

      return () => {
        timer.isStopped = true
      }
    },
  }

  return { surface, timers }
}

const draw = (props: ClawdProps, surface: ReturnType<typeof fakeSurface>['surface']) =>
  JSON.stringify((ClawdClient as unknown as (p: ClawdProps, s: unknown) => unknown)(props, surface))

test('the terminal Clawd ticks at its loop step and moves', () => {
  const { surface, timers } = fakeSurface()
  const props: ClawdProps = { activity: 'type', outfit: BLUE_COWBOY, info: {}, animate: true }
  const first = draw(props, surface)
  expect(timers.filter(timer => !timer.isStopped).map(timer => timer.ms)).toEqual([40])
  timers[0]?.fn()
  expect(draw(props, surface)).not.toBe(first)
})

test('the terminal Clawd restarts its clock when its loop changes', () => {
  const { surface, timers } = fakeSurface()
  draw({ activity: 'rest', outfit: BLUE_COWBOY, info: {}, animate: true }, surface)
  draw({ activity: 'type', outfit: BLUE_COWBOY, info: { slowTyping: true }, animate: true }, surface)
  expect(timers.filter(timer => !timer.isStopped).map(timer => timer.ms)).toEqual([1000])
})

test('a still terminal Clawd starts no clock', () => {
  const { surface, timers } = fakeSurface()
  draw({ activity: 'type', outfit: BLUE_COWBOY, info: {}, animate: false }, surface)
  expect(timers.length).toBe(0)
})
