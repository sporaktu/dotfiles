import type { AgentInfo, On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const PANE = {
  plugin: 'supervisors',
  component: 'Pane',
  requestId: 'supervisors',
  props: {
    title: 'Supervisors',
    isFocused: false,
    bodyColumns: 80,
    placement: 'inline',
    scroll: { offset: 0, bodyRows: 40 },
    view: {},
  },
} as const

const lead = (id: string, status: AgentInfo['status'] = 'running'): AgentInfo => ({
  id,
  description: `Supervisor: ${id}`,
  type: 'general-purpose',
  status,
})
const worker = (id: string, parentId: string, status: AgentInfo['status'] = 'running'): AgentInfo => ({
  id,
  parentId,
  description: `work ${id}`,
  type: 'general-purpose',
  status,
})

// A session whose agents were all running before the mod loaded, with every
// pane open, close and status line the mod asks for recorded.
async function start($: Engine, on: On, agents: AgentInfo[]) {
  const clock = mock.clock(on, { now: 10 * 60_000 })
  const opened: { id: string; rows?: number; columns?: number }[] = []
  const closed: string[] = []
  const statuses: (string | undefined)[] = []
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('tool.register', ($, e) => ({ value: { tool: `mcp__supervisors__${e.name}` } }))
  on('ui.open', ($, e) => (opened.push({ id: e.id, rows: e.rows, columns: e.columns }), { value: { isPlaced: true } }))
  on('ui.close', ($, e) => (closed.push(e.id), { value: undefined }))
  on('ui.status', ($, e) => (statuses.push(e.text), { value: undefined }))
  on('agent.list', () => ({ value: agents }))
  await $.session.start({ cwd: '/tmp', surface: 'terminal', isInteractive: true })
  await clock.advance(1600)

  return { clock, opened, closed, statuses }
}

// The person typing `/supervisors <args>` at the prompt.
const run = async ($: Engine, args: string) =>
  (
    await $.command.run({
      command: 'supervisors',
      args,
      origin: { kind: 'composer' },
      presentation: { isFullscreen: false, columns: 120 },
    })
  ).text

async function shown($: Engine, ids: string[]) {
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  const found: string[] = []
  for (const id of ids) {
    if ((await ui.find({ type: 'Client', key: `clawd-${id}` })) !== undefined) {
      found.push(id)
    }
  }
  await ui.unmount()

  return found
}

test('the pane asks for a short inline block and a narrow dock', async ($, on) => {
  const { opened } = await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  expect(opened).toEqual([{ id: 'supervisors', rows: 14, columns: 60 }])
})

test('terminal Clawds are 12 columns by 4 rows', async ($, on) => {
  await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  const clawd = await ui.find({ type: 'Client', key: 'clawd-w-1' })
  expect([clawd?.props.width, clawd?.props.height]).toEqual([12, 4])
  await ui.unmount()
})

test('/supervisors close closes the pane, and /supervisors opens it again', async ($, on) => {
  const { opened, closed } = await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  expect(await run($, 'close')).toBe('Supervisors pane closed.')
  expect(closed).toEqual(['supervisors'])
  expect(await run($, '')).toBe('Supervisors pane opened.')
  expect(await run($, 'open')).toBe('Supervisors pane opened.')
  expect(opened.map(pane => pane.id)).toEqual(['supervisors', 'supervisors', 'supervisors'])
})

test('closed before any supervisor appears, the pane stays closed', async ($, on) => {
  const agents: AgentInfo[] = []
  const { clock, opened } = await start($, on, agents)
  await run($, 'close')
  agents.push(lead('sup-1'), worker('w-1', 'sup-1'))
  await clock.advance(1600)
  expect(opened).toEqual([])
})

test('/supervisors mini shrinks the pane to one line of teams under the prompt', async ($, on) => {
  const agents = [lead('sup-1'), worker('w-1', 'sup-1'), worker('w-2', 'sup-1'), lead('sup-2'), worker('w-3', 'sup-2')]
  const { clock, closed, statuses } = await start($, on, agents)

  expect(await run($, 'mini')).toBe('Supervisors shrunk to a line under the prompt. /supervisors opens the pane again.')
  expect(closed).toEqual(['supervisors'])
  expect(statuses.at(-1)).toBe('♛ sup-1 ●● · ♛ sup-2 ●')

  agents[2] = worker('w-2', 'sup-1', 'completed')
  await clock.advance(1600)
  expect(statuses.at(-1)).toBe('♛ sup-1 ●✓ · ♛ sup-2 ●')
  const count = statuses.length
  await clock.advance(1600)
  expect(statuses.length).toBe(count)

  expect(await run($, 'open')).toBe('Supervisors pane opened.')
  expect(statuses.at(-1)).toBeUndefined()
})

test('the mini line says so when no team is at work', async ($, on) => {
  const { statuses } = await start($, on, [])
  await run($, 'mini')
  expect(statuses.at(-1)).toBe('♛ no teams at work')
})

test('/supervisors close also clears the mini line', async ($, on) => {
  const { statuses } = await start($, on, [lead('sup-1'), worker('w-1', 'sup-1')])
  await run($, 'mini')
  expect(await run($, 'close')).toBe('Supervisors pane closed.')
  expect(statuses.at(-1)).toBeUndefined()
})

test('/supervisors clear removes finished agents now; a resumed one comes back', async ($, on) => {
  const agents = [
    lead('sup-1'),
    worker('w-1', 'sup-1'),
    worker('w-2', 'sup-1', 'failed'),
    lead('sup-2', 'completed'),
    worker('w-3', 'sup-2'),
  ]
  const all = agents.map(agent => agent.id)
  const { clock, statuses } = await start($, on, agents)
  expect(await shown($, all)).toEqual(all)

  // A finished supervisor whose worker still runs stays with its team.
  expect(await run($, 'clear')).toBe('Cleared 1 finished agent.')
  expect(await shown($, all)).toEqual(['sup-1', 'w-1', 'sup-2', 'w-3'])
  await run($, 'mini')
  expect(statuses.at(-1)).toBe('♛ sup-1 ● · ♛ sup-2 ●')

  agents[2] = worker('w-2', 'sup-1')
  await clock.advance(1600)
  expect(await shown($, all)).toEqual(all)

  agents[2] = worker('w-2', 'sup-1', 'completed')
  await clock.advance(1600)
  expect(await shown($, all)).toEqual(all)
  expect(await run($, 'clear')).toBe('Cleared 1 finished agent.')
  expect(await run($, 'clear')).toBe('No finished agents to clear.')
})

test('an unknown subcommand prints the usage', async ($, on) => {
  await start($, on, [])
  expect(await run($, 'shrink')).toBe('Usage: /supervisors [open | close | clear | mini]')
})
