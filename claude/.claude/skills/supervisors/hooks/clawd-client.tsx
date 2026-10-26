import type { ClientModule } from 'claude-code'

import type { Activity, FrameInfo, Outfit } from '../types'
import { frameAt, loopOf, stillOf } from './clawd'
import { halfBlockRows, halfScale } from './halfblock'

export type ClawdProps = { activity: Activity; outfit: Outfit; info: FrameInfo; animate: boolean }

// Elapsed loop time, and the clock that advances it at the loop's own step.
type Clock = { t: number; step: number; stop: () => void }

// The terminal's Clawd: draws his frame at half scale in half blocks (12x4
// cells) and advances it on the surface's frame clock, so animation costs the
// hooks module nothing.
const ClawdClient: ClientModule<ClawdProps, Clock> = (props, surface) => {
  const { Box, Text } = surface.elements
  const step = props.animate ? loopOf(props.activity, props.info).step : 0
  const clock = surface.state
  if (clock === undefined || clock.step !== step) {
    clock?.stop()
    const t = clock?.t ?? 0
    const stop =
      step > 0
        ? surface.every(step, () => {
            const now = surface.state
            if (now !== undefined) {
              surface.setState({ ...now, t: now.t + step })
            }
          })
        : () => {}
    surface.setState({ t, step, stop })
  }
  const grid = halfScale(
    props.animate
      ? frameAt(props.activity, props.outfit, surface.state?.t ?? 0, props.info)
      : stillOf(props.activity, props.outfit, props.info),
  )

  return (
    <Box flexDirection="column">
      {halfBlockRows(grid).map(segments => (
        <Text>
          {segments.map(segment => (
            <Text
              {...(segment.color !== undefined ? { color: segment.color } : {})}
              {...(segment.backgroundColor !== undefined ? { backgroundColor: segment.backgroundColor } : {})}
            >
              {segment.text}
            </Text>
          ))}
        </Text>
      ))}
    </Box>
  )
}

export default ClawdClient
