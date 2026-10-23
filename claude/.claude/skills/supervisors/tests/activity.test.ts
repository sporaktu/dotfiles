import { expect, test } from 'claude-code/testing'

import { activityOf, isAsleep, isLongOf } from '../hooks/activity'
import { buildTree } from '../hooks/model'
import type { Activity, AgentRow } from '../types'

const NOW = 100_000

function row(fields: Partial<AgentRow> = {}): AgentRow {
  return { id: 'a', description: 'task', type: 'general-purpose', status: 'running', directions: [], ...fields }
}

function activity(fields: Partial<AgentRow>, others: AgentRow[] = []) {
  const target = row(fields)

  return activityOf(target, buildTree([target, ...others]), NOW)
}

test('a pending or just-spawned agent arrives', () => {
  expect(activity({ status: 'pending' })).toBe('arrive')
  expect(activity({ startedAt: NOW - 1000, lastBlock: 'tool', tool: 'Bash' })).toBe('arrive')
  expect(activity({ startedAt: NOW - 3000, lastBlock: 'tool', tool: 'Bash' })).toBe('type')
})

test('a running agent thinks when its last block was text', () => {
  expect(activity({ lastBlock: 'text', tool: 'Bash' })).toBe('think')
  expect(activity({})).toBe('think')
})

test('editing, running commands and unknown tools type', () => {
  for (const tool of ['Edit', 'Write', 'MultiEdit', 'NotebookEdit', 'Bash', 'mcp__server__tool', 'Skill']) {
    expect(activity({ lastBlock: 'tool', tool })).toBe('type')
  }
})

test('reading and searching search', () => {
  for (const tool of ['Read', 'Grep', 'Glob', 'LS', 'WebFetch', 'WebSearch', 'ToolSearch']) {
    expect(activity({ lastBlock: 'tool', tool })).toBe('search')
  }
})

test('starting an agent recruits, sending a message messages', () => {
  expect(activity({ lastBlock: 'tool', tool: 'Agent' })).toBe('recruit')
  expect(activity({ lastBlock: 'tool', tool: 'SendMessage' })).toBe('message')
})

test('waiting with a live team member waits on the team, otherwise idles', () => {
  const member = row({ id: 'm', parentId: 'a', status: 'running' })
  expect(activity({ status: 'waiting' }, [member])).toBe('waitTeam')
  expect(activity({ status: 'idle' }, [{ ...member, status: 'completed' }])).toBe('idle')
  expect(activity({ status: 'idle' })).toBe('idle')
})

test('a finished agent celebrates for 4 seconds, then rests', () => {
  expect(activity({ status: 'completed', endedAt: NOW - 3000 })).toBe('celebrate')
  expect(activity({ status: 'completed', endedAt: NOW - 5000 })).toBe('rest')
  expect(activity({ status: 'completed', endedAt: 0 })).toBe('rest')
  expect(activity({ status: 'completed' })).toBe('rest')
})

test('an agent is asleep when it rests and so does all its team', () => {
  const asleep = (fields: Partial<AgentRow>, others: AgentRow[] = []) => {
    const target = row(fields)

    return isAsleep(target, buildTree([target, ...others]))
  }
  const member = (activity: Activity) => row({ id: 'm', parentId: 'a', activity })

  expect(asleep({ status: 'completed', activity: 'rest' })).toBe(true)
  for (const activity of ['celebrate', 'idle', 'waitTeam', 'failed', 'killed', 'type'] as const) {
    expect(asleep({ activity })).toBe(false)
  }
  expect(asleep({ status: 'completed', activity: 'rest' }, [member('rest')])).toBe(true)
  expect(asleep({ status: 'completed', activity: 'rest' }, [member('type')])).toBe(false)
  expect(asleep({ status: 'completed', activity: 'rest' }, [member('failed')])).toBe(false)
  expect(asleep({ status: 'completed', activity: 'rest' }, [member('idle')])).toBe(false)
})

test('failed and stopped agents show it', () => {
  expect(activity({ status: 'failed' })).toBe('failed')
  expect(activity({ status: 'killed' })).toBe('killed')
})

test('a tool call running past 15 seconds is long', () => {
  expect(isLongOf(row({ lastBlock: 'tool', tool: 'Bash', toolSince: NOW - 14_000 }), NOW)).toBe(false)
  expect(isLongOf(row({ lastBlock: 'tool', tool: 'Bash', toolSince: NOW - 16_000 }), NOW)).toBe(true)
  expect(isLongOf(row({ lastBlock: 'text', tool: 'Bash', toolSince: NOW - 16_000 }), NOW)).toBe(false)
})

test('after a tool returns, the agent is thinking, not typing', () => {
  expect(activity({ lastBlock: 'result', tool: 'Bash' })).toBe('think')
  expect(isLongOf(row({ lastBlock: 'result', tool: 'Bash', toolSince: NOW - 16_000 }), NOW)).toBe(false)
})
