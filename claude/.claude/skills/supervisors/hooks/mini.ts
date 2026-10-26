import type { AgentRow } from '../types'

import { isShown } from './activity'
import type { View } from './activity'
import { GLYPH, buildTree, descendants, isSupervisor, oneLine } from './model'

const NAME_MAX = 18

// The pane shrunk to one plain line under the prompt, which takes no color:
// each team at work as a crown, its supervisor's name and one status glyph
// per member the pane would show.
export function miniLine(rows: readonly AgentRow[], view: View): string {
  const tree = buildTree(rows)
  const teams = tree.roots
    .filter(row => isSupervisor(row, tree) && isShown(row, tree, view))
    .map(row => {
      const name = oneLine(row.description.replace(/^supervisor\b:?\s*/i, ''), NAME_MAX) || row.description
      const glyphs = descendants(row, tree)
        .filter(member => isShown(member, tree, view))
        .map(member => GLYPH[member.status])
        .join('')

      return `♛ ${name} ${glyphs}`.trimEnd()
    })

  return teams.length === 0 ? '♛ no teams at work' : teams.join(' · ')
}
