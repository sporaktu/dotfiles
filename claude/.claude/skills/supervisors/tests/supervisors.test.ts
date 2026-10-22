import type { AgentInfo, Register } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'

import type { AgentRow } from '../types'

const SURFACES = ['terminal', 'desktop'] as const
const ENGINE = { plugin: 'engine', tier: 'core' } as const
const PANE = {
  plugin: 'supervisors',
  component: 'Pane',
  requestId: 'supervisors',
  props: {
    title: 'Supervisors',
    isFocused: false,
    bodyColumns: 100,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 40 },
    view: {},
  },
} as const

const SUPERVISOR: AgentInfo = {
  id: 'sup-1',
  description: 'Supervisor: auth refactor',
  type: 'general-purpose',
  status: 'running',
}
const WORKER: AgentInfo = {
  id: 'w-1',
  parentId: 'sup-1',
  description: 'Fix token refresh',
  type: 'general-purpose',
  status: 'running',
  name: 'token-fixer',
}
const AUDITOR: AgentInfo = {
  id: 'w-2',
  parentId: 'sup-1',
  description: 'Audit routes',
  type: 'Explore',
  status: 'completed',
}

function spawnInput(description: string, prompt: string, parentAgentId?: string) {
  return {
    tool_use_id: `toolu_${description}`,
    prompt,
    description,
    subagentType: 'general-purpose',
    provider: ENGINE,
    parentModel: 'opus',
    background: true,
    fork: false,
    ...(parentAgentId !== undefined ? { parentAgentId } : {}),
  }
}

function response(agentId: string, uuid: string, block: Record<string, unknown> & { type: string }) {
  return {
    message: { type: 'assistant' as const, role: 'assistant' as const, content: [block] },
    door: 'response' as const,
    origin: { kind: 'model' as const, model: 'opus' },
    uuid,
    agentId,
  }
}

test('shows each supervisor with what it does and how it directs its team', async ($, on) => {
  const clock = mock.clock(on, { now: 10 * 60_000 })
  let agents: AgentInfo[] = []
  const opened: string[] = []
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('tool.register', ($, e) => ({ value: { tool: `mcp__supervisors__${e.name}` } }))
  on('ui.open', ($, e) => (opened.push(e.id), { value: { isPlaced: true } }))
  on('agent.list', () => ({ value: agents }))
  on('agent.spawn', ($, e) => ({ model: 'opus', agentId: e.parentAgentId === undefined ? 'sup-1' : 'w-1' }))
  on('session.send', () => ({ isDelivered: true }))

  await $.session.start({ cwd: '/tmp', surface: 'desktop', isInteractive: true })

  // The main loop spawns the supervisor, so the exact hook hears it.
  await $.agent.spawn(spawnInput('Supervisor: auth refactor', 'Own the auth refactor end to end.'))
  // The supervisor's own response rows: narration and its Agent call, whose
  // brief reaches the worker through its description.
  await $.session.append(response('sup-1', 'u1', { type: 'text', text: 'Plan ready.\nSpawning two workers for the token code.' }))
  await $.session.append(
    response('sup-1', 'u2', {
      type: 'tool_use',
      id: 'toolu_w1',
      name: 'Agent',
      input: { description: 'Fix token refresh', prompt: 'Fix the refresh race in src/auth/token.ts.\nRun the tests after.' },
    }),
  )
  await $.session.append(
    response('w-1', 'u3', { type: 'tool_use', id: 'toolu_b', name: 'Bash', input: { command: 'npm test -- token' } }),
  )
  await $.session.send({ to: 'w-1', text: 'Stop after token.ts and report back', origin: { kind: 'model' }, agentId: 'sup-1' })
  // A background supervisor woken by a task notification: a resumed spawn
  // whose prompt is the notification, which must not replace its brief.
  await $.agent.spawn({
    ...spawnInput('Supervisor: auth refactor', '<task-notification>worker done</task-notification>'),
    resume: { agentId: 'sup-1' },
  })

  agents = [SUPERVISOR, WORKER, AUDITOR]
  await clock.advance(1600)

  expect(opened).toEqual(['supervisors'])

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ text: /task-notification/ })).toBeUndefined()
    for (const text of [
      'Supervisor: auth refactor',
      'Own the auth refactor end to end.',
      'Spawning two workers for the token code.',
      'token-fixer: Stop after token.ts and report back',
      'team 2 · 1 active · 1 done',
      'Fix the refresh race in src/auth/token.ts. Run the tests after.',
      'Bash npm test -- token',
      'Audit routes',
    ]) {
      expect(await ui.find({ text })).toBeDefined()
    }

    await ui.press({ key: 'hide-done' })
    expect(await ui.find({ text: 'Audit routes' })).toBeUndefined()
    expect(await ui.find({ text: 'Fix token refresh' })).toBeDefined()

    await ui.press({ key: 'fold-sup-1' })
    expect(await ui.find({ text: 'Fix token refresh' })).toBeUndefined()

    await ui.press({ key: 'fold-sup-1' })
    await ui.press({ key: 'hide-done' })
    await ui.unmount()
  }

  const outline = await $.tool.call({ tool: 'mcp__supervisors__teams' })
  expect(outline.deny).toBeUndefined()
  expect(String(outline.result)).toContain('Supervisor: auth refactor [running]')
  expect(String(outline.result)).toContain('\n  ● Fix token refresh [running, token-fixer]')
  expect(String(outline.result)).toContain('→ token-fixer: Stop after token.ts and report back')
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

test('stores each agent\'s loop and outfit on its row', { plugins: [PEEK] }, async ($, on) => {
  const clock = mock.clock(on, { now: 10 * 60_000 })
  const done: AgentInfo = { ...AUDITOR, id: 'w-9' }
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('tool.register', ($, e) => ({ value: { tool: `mcp__supervisors__${e.name}` } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('agent.list', () => ({ value: [SUPERVISOR, WORKER, done] }))

  // All three were running or done before the mod loaded.
  await $.session.start({ cwd: '/tmp', surface: 'terminal', isInteractive: true })
  await $.session.append(
    response('w-1', 'u1', { type: 'tool_use', id: 'toolu_b', name: 'Bash', input: { command: 'npm test' } }),
  )
  await clock.advance(1600)

  const rows = (await $.tool.call({ tool: 'mcp__peek__rows' })).result as AgentRow[]
  const byId = (id: string) => rows.find(row => row.id === id)
  expect(byId('sup-1')?.outfit).toEqual({ color: 'blue', tone: 'main', hat: 'crown' })
  expect(byId('w-1')?.outfit).toEqual({ color: 'blue', tone: 'main', hat: 'cowboy hat' })
  expect(byId('w-1')?.activity).toBe('type')
  expect(byId('w-9')?.activity).toBe('rest')
  expect(byId('sup-1')?.activity).toBe('think')
})

test('keeps an agent the engine dropped, ended as its last turn ended', async ($, on) => {
  const clock = mock.clock(on)
  let agents: AgentInfo[] = [SUPERVISOR, WORKER]
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('tool.register', ($, e) => ({ value: { tool: `mcp__supervisors__${e.name}` } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('agent.list', () => ({ value: agents }))
  on('turn.complete', ($, e) => ({ text: e.answer }))

  await $.session.start({ cwd: '/tmp', surface: 'terminal', isInteractive: true })
  await clock.advance(1600)

  await $.turn.complete({ answer: '', durationMs: 5, isAborted: false, turnId: 't1', agentId: 'w-1', reason: 'error' })
  agents = [SUPERVISOR]
  await clock.advance(1600)

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ text: 'Fix token refresh' })).toBeDefined()
  expect(await ui.find({ text: /failed/ })).toBeDefined()
  await ui.unmount()
})

test('says so when no agent leads a team', async ($, on) => {
  mock.clock(on)
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('tool.register', ($, e) => ({ value: { tool: `mcp__supervisors__${e.name}` } }))
  on('agent.list', () => ({ value: [] }))

  await $.session.start({ cwd: '/tmp', surface: 'desktop', isInteractive: true })

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ text: /No supervisors yet/ })).toBeDefined()
    await ui.unmount()
  }
})
