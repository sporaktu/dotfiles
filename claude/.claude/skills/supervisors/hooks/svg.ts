import { SCENE } from './clawd'
import type { Grid } from './clawd'

// One path per color: each horizontal run of that color is a 1-pixel-tall box.
function paths(grid: Grid): string {
  const runs = new Map<string, string[]>()
  grid.forEach((row, y) => {
    let x = 0
    while (x < row.length) {
      const color = row[x]
      let end = x + 1
      while (end < row.length && row[end] === color) {
        end++
      }
      if (color !== null && color !== undefined) {
        const list = runs.get(color) ?? []
        list.push(`M${x} ${y}h${end - x}v1h-${end - x}z`)
        runs.set(color, list)
      }
      x = end
    }
  })

  return [...runs].map(([color, d]) => `<path fill="${color}" d="${d.join('')}"/>`).join('')
}

// A flipbook: every distinct frame is a group shown in turn by a CSS
// animation, so the surface plays it with no work from the hooks module.
// Consecutive equal frames merge into one longer frame.
export function flipbookSvg(frames: Grid[], step: number, scale: number): string {
  const shown: { body: string; steps: number }[] = []
  for (const frame of frames) {
    const body = paths(frame)
    const last = shown.at(-1)
    if (last !== undefined && last.body === body) {
      last.steps++
    } else {
      shown.push({ body, steps: 1 })
    }
  }
  const open =
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SCENE.width} ${SCENE.height}" ` +
    `width="${SCENE.width * scale}" height="${SCENE.height * scale}" shape-rendering="crispEdges">`
  if (shown.length === 1) {
    return `${open}${shown[0]!.body}</svg>`
  }

  const total = frames.length * step
  let at = 0
  const rules: string[] = []
  const groups: string[] = []
  shown.forEach((frame, i) => {
    const from = (at / total) * 100
    const to = ((at + frame.steps * step) / total) * 100
    at += frame.steps * step
    const stops = from === 0 ? `0%{visibility:visible}` : `0%{visibility:hidden}${from}%{visibility:visible}`
    rules.push(`@keyframes f${i}{${stops}${to}%{visibility:hidden}}`)
    rules.push(`.f${i}{visibility:hidden;animation:f${i} ${total}ms step-end infinite}`)
    groups.push(`<g class="f${i}">${frame.body}</g>`)
  })

  return `${open}<style>${rules.join('')}</style>${groups.join('')}</svg>`
}
