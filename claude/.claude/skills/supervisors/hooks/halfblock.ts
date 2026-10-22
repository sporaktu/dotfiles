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

function cellOf(top: string | null, bottom: string | null): Segment {
  if (top === null && bottom === null) {
    return { text: ' ' }
  }
  if (top === null) {
    return { text: '▄', color: bottom! }
  }

  return bottom === null ? { text: '▀', color: top } : { text: '▀', color: top, backgroundColor: bottom }
}
