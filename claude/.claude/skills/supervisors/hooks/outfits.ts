import type { AgentRow, Outfit, TeamColor } from '../types'

import { HAT_ORDER, TEAM_ORDER } from './clawd'
import { buildTree, isSupervisor } from './model'
import type { Tree } from './model'

// Each team has 24 looks: the 12 hats in its color, then in its light tint.
const LOOKS = HAT_ORDER.length * 2

function lookKey(outfit: Outfit): string {
  return `${outfit.tone}|${outfit.hat}`
}

// The first look none of `worn` uses; past 24 wearers, looks repeat in order.
function nextLook(color: TeamColor, worn: Outfit[]): Outfit {
  const taken = new Set(worn.map(lookKey))
  for (let i = 0; i < LOOKS; i++) {
    const look: Outfit = { color, tone: i < HAT_ORDER.length ? 'main' : 'light', hat: HAT_ORDER[i % HAT_ORDER.length]! }
    if (!taken.has(lookKey(look))) {
      return look
    }
  }
  const i = worn.length % LOOKS

  return { color, tone: i < HAT_ORDER.length ? 'main' : 'light', hat: HAT_ORDER[i % HAT_ORDER.length]! }
}

// The first team color no crown wears; past 6 teams, colors repeat in order.
function nextCrown(crowns: Outfit[]): Outfit {
  const taken = new Set(crowns.map(crown => crown.color))
  const color = TEAM_ORDER.find(c => !taken.has(c)) ?? TEAM_ORDER[crowns.length % TEAM_ORDER.length]!

  return { color, tone: 'main', hat: 'crown' }
}

// Dresses every row: supervisors in a crown of their team's color, members in
// their team's color with a look no teammate wears, everyone else in grey.
// Outfits already on rows stay, except that an agent which starts leading a
// team changes once, to a crown.
export function dressRows(rows: readonly AgentRow[]): AgentRow[] {
  const tree: Tree = buildTree(rows)
  const dressed = new Map<string, Outfit>()
  for (const row of rows) {
    if (row.outfit !== undefined) {
      dressed.set(row.id, row.outfit)
    }
  }
  const crowns = () => [...dressed.values()].filter(outfit => outfit.hat === 'crown')
  const wornBy = (others: AgentRow[]) =>
    others.flatMap(other => {
      const outfit = dressed.get(other.id)

      return outfit !== undefined && outfit.hat !== 'crown' ? [outfit] : []
    })

  const visit = (row: AgentRow) => {
    const outfit = dressed.get(row.id)
    if (isSupervisor(row, tree)) {
      if (outfit?.hat !== 'crown') {
        dressed.set(row.id, nextCrown(crowns()))
      }
    } else if (outfit === undefined) {
      const lead = row.parentId !== undefined ? tree.byId.get(row.parentId) : undefined
      const team = lead !== undefined ? (tree.childrenOf.get(lead.id) ?? []) : tree.roots.filter(r => !isSupervisor(r, tree))
      const color = lead !== undefined ? (dressed.get(lead.id)?.color ?? 'grey') : 'grey'
      dressed.set(row.id, nextLook(color, wornBy(team.filter(other => other.id !== row.id))))
    }
    for (const member of tree.childrenOf.get(row.id) ?? []) {
      visit(member)
    }
  }
  tree.roots.forEach(visit)

  return rows.map(row => {
    const outfit = dressed.get(row.id)

    return outfit !== undefined ? { ...row, outfit } : row
  })
}
