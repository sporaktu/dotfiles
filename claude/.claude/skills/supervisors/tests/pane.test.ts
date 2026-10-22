import type { AgentInfo, On, Register } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import type { AgentRow } from '../types'

const PANE = {
  plugin: 'supervisors',
  component: 'Pane',
  requestId: 'supervisors',
  props: {
    title: 'Supervisors',
    isFocused: false,
    bodyColumns: 120,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 400 },
    view: {},
  },
} as const

const lead = (id: string): AgentInfo => ({ id, description: `Supervisor: ${id}`, type: 'general-purpose', status: 'running' })
const worker = (id: string, parentId: string): AgentInfo => ({
  id,
  parentId,
  description: `work ${id}`,
  type: 'general-purpose',
  status: 'running',
})

// A session whose agents were all running before the mod loaded, each
// worker's last response block a Bash call.
async function start($: Engine, on: On, agents: AgentInfo[]) {
  const clock = mock.clock(on, { now: 10 * 60_000 })
  const opened: string[] = []
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('tool.register', ($, e) => ({ value: { tool: `mcp__supervisors__${e.name}` } }))
  on('ui.open', ($, e) => (opened.push(e.id), { value: { isPlaced: true } }))
  on('agent.list', () => ({ value: agents }))
  await $.session.start({ cwd: '/tmp', surface: 'terminal', isInteractive: true })
  for (const agent of agents.filter(a => a.parentId !== undefined)) {
    await $.session.append({
      message: {
        type: 'assistant',
        role: 'assistant',
        content: [{ type: 'tool_use', id: `toolu_${agent.id}`, name: 'Bash', input: { command: 'npm test' } }],
      },
      door: 'response',
      origin: { kind: 'model', model: 'opus' },
      uuid: `u_${agent.id}`,
      agentId: agent.id,
    })
  }
  await clock.advance(1600)

  return { clock, opened }
}

test('every agent gets a Clawd beside its row', async ($, on) => {
  await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])

  const terminal = await $.ui.mount({ ...PANE, surface: 'terminal' })
  const clawd = await terminal.find({ type: 'Client', key: 'clawd-w-1' })
  expect(clawd?.props.props).toMatchObject({
    activity: 'type',
    outfit: { color: 'blue', tone: 'main', hat: 'cowboy hat' },
    animate: true,
  })
  expect(await terminal.find({ type: 'Client', key: 'clawd-sup-1' })).toBeDefined()
  await terminal.unmount()

  const desktop = await $.ui.mount({ ...PANE, surface: 'desktop' })
  const alts = (await desktop.findAll({ type: 'Svg' })).map(svg => svg.props.alt)
  expect(alts).toEqual(['Supervisor: sup-1: blue crown, thinking', 'work w-1: blue cowboy hat, typing'])
  await desktop.unmount()
})

test('the terminal Clawd animates on the frame clock', async ($, on) => {
  await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  const before = JSON.stringify(await ui.drawn({ in: 'clawd-w-1' }))
  await ui.advance(40)
  expect(JSON.stringify(await ui.drawn({ in: 'clawd-w-1' }))).not.toBe(before)
  await ui.unmount()
})

test('typing Clawds past the first 8 tap once a second', async ($, on) => {
  const workers = Array.from({ length: 10 }, (_, i) => worker(`w-${i}`, 'sup-1'))
  await start($, on, [lead('sup-1'), ...workers])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  const slow = async (id: string) =>
    ((await ui.find({ type: 'Client', key: `clawd-${id}` }))?.props.props as { info: { slowTyping?: boolean } }).info
      .slowTyping === true
  expect(await slow('w-7')).toBe(false)
  expect(await slow('w-8')).toBe(true)
  expect(await slow('w-9')).toBe(true)
  await ui.unmount()
})

test('with animation off a Clawd holds still', { options: { animate: false } }, async ($, on) => {
  await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  const before = JSON.stringify(await ui.drawn({ in: 'clawd-w-1' }))
  await ui.advance(1000)
  expect(JSON.stringify(await ui.drawn({ in: 'clawd-w-1' }))).toBe(before)
  await ui.unmount()
})

test('with auto-open off the pane waits for /supervisors', { options: { autoOpen: false } }, async ($, on) => {
  const { opened } = await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  expect(opened).toEqual([])
})

test('sixty agents draw on both surfaces', async ($, on) => {
  const agents = ['a', 'b', 'c'].flatMap(id => [lead(id), ...Array.from({ length: 19 }, (_, i) => worker(`${id}-${i}`, id))])
  await start($, on, agents)
  const terminal = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await terminal.findAll({ type: 'Client' })).length).toBe(60)
  await terminal.unmount()
  const desktop = await $.ui.mount({ ...PANE, surface: 'desktop' })
  expect((await desktop.findAll({ type: 'Svg' })).length).toBe(60)
  await desktop.unmount()
})

test('desktop Clawds play as interactive images', async ($, on) => {
  await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  const svgs = await ui.findAll({ type: 'Svg' })
  expect(svgs.map(svg => svg.props.isInteractive)).toEqual([true, true])
  await ui.unmount()
})

test('with animation off an arriving Clawd still shows', { options: { animate: false } }, async ($, on) => {
  await start($, on, [lead('sup-1'), { ...worker('w-1', 'sup-1'), status: 'pending' }])
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  const svgs = await ui.findAll({ type: 'Svg' })
  expect(svgs.every(svg => String(svg.props.source).includes('#CD6E58'))).toBe(true)
  expect(svgs.map(svg => svg.props.isInteractive)).toEqual([undefined, undefined])
  await ui.unmount()
})

const clawdProps = async (ui: { find: (q: { type: string; key: string }) => Promise<{ props: Record<string, unknown> } | undefined> }, id: string) =>
  (await ui.find({ type: 'Client', key: `clawd-${id}` }))?.props.props as { activity: string; info: { isLong?: boolean } }

test('a returned tool call turns typing into thinking', async ($, on) => {
  const { clock } = await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  await $.session.append({
    message: { type: 'user', role: 'user', content: [{ type: 'tool_result', tool_use_id: 'toolu_w-1', content: 'ok' }] },
    door: 'tool-result',
    origin: { kind: 'tool', tool: 'Bash' },
    uuid: 'r_w-1',
    agentId: 'w-1',
  })
  await clock.advance(1600)
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await clawdProps(ui, 'w-1')).activity).toBe('think')
  await ui.unmount()
})

test('a tool call still running after 15 seconds breaks a sweat', async ($, on) => {
  const { clock } = await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await clawdProps(ui, 'w-1')).info.isLong).toBe(false)
  await ui.unmount()
  await clock.advance(16_000)
  const later = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await clawdProps(later, 'w-1')).info.isLong).toBe(true)
  await later.unmount()
})

// A helper plugin for tests: its tool answers the supervisors rows as stored.
const PEEK = {
  name: 'peek',
  register: (on => {
    on('tool.call', { tool: 'mcp__peek__rows' }, async $ => {
      const { value = [] } = await $.state.get({ plugin: 'supervisors', key: 'rows' })

      return { result: value }
    })
  }) as Register,
}

test('a tool call is stamped at the next refresh, so appends wait on nothing', { plugins: [PEEK] }, async ($, on) => {
  const { clock } = await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  // Appended at 601600 ms, between refreshes; the next refresh ticks at 603000 ms.
  await $.session.append({
    message: { type: 'assistant', role: 'assistant', content: [{ type: 'tool_use', id: 'toolu_r', name: 'Read', input: { file_path: 'a.ts' } }] },
    door: 'response',
    origin: { kind: 'model', model: 'opus' },
    uuid: 'u_r',
    agentId: 'w-1',
  })
  await clock.advance(1500)
  const rows = (await $.tool.call({ tool: 'mcp__peek__rows' })).result as AgentRow[]
  expect(clock.now()).toBe(603_100)
  expect(rows.find(row => row.id === 'w-1')?.toolSince).toBe(603_000)
})
