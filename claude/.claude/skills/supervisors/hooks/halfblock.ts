import type { Grid } from './clawd'

// One run of terminal cells that look the same.
export type Segment = { text: string; color?: string; backgroundColor?: string }

// Packs pixel rows into terminal rows, two per cell: the upper half block
// carries the top pixel as its color and the bottom pixel as its background,
// so every pixel keeps its own color. Equal neighboring cells merge.
export function halfBlockRows(grid: Grid): Segment[][] {
  const rows: Segment[][] = []
  for (let y = 0; y < grid.length; y += 2) {
    const segments: Segment[] = []
    const top = grid[y] ?? []
    const bottom = grid[y + 1] ?? []
    for (let x = 0; x < top.length; x++) {
      const cell = cellOf(top[x] ?? null, bottom[x] ?? null)
      const last = segments.at(-1)
      if (last !== undefined && last.text.at(-1) === cell.text && last.color === cell.color && last.backgroundColor === cell.backgroundColor) {
        last.text += cell.text
      } else {
        segments.push(cell)
      }
    }
    rows.push(segments)
  }

  return rows
}

// Halves a grid for the terminal: each 2x2 block takes the color most of its
// pixels have, a tie going to the color rarer in the whole grid so eyes and
// marks survive the fill around them. A block with no pixel stays clear.
export function halfScale(grid: Grid): Grid {
  const totals = new Map<string, number>()
  for (const cell of grid.flat()) {
    if (cell !== null) {
      totals.set(cell, (totals.get(cell) ?? 0) + 1)
    }
  }
  const rows: Grid = []
  for (let y = 0; y < grid.length; y += 2) {
    const row: (string | null)[] = []
    for (let x = 0; x < (grid[y]?.length ?? 0); x += 2) {
      const counts = new Map<string, number>()
      for (const cell of [grid[y]?.[x], grid[y]?.[x + 1], grid[y + 1]?.[x], grid[y + 1]?.[x + 1]]) {
        if (cell !== null && cell !== undefined) {
          counts.set(cell, (counts.get(cell) ?? 0) + 1)
        }
      }
      let best: string | null = null
      for (const [color, count] of counts) {
        const held = best === null ? 0 : (counts.get(best) ?? 0)
        if (best === null || count > held || (count === held && (totals.get(color) ?? 0) < (totals.get(best) ?? 0))) {
          best = color
        }
      }
      row.push(best)
    }
    rows.push(row)
  }

  return rows
}

function cellOf(top: string | null, bottom: string | null): Segment {
  if (top === null && bottom === null) {
    return { text: ' ' }
  }
  if (top === null) {
    return { text: '▄', color: bottom! }
  }

  return bottom === null ? { text: '▀', color: top } : { text: '▀', color: top, backgroundColor: bottom }
}
