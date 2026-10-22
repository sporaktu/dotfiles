import type { Activity, FrameInfo, HatName, Outfit, TeamColor } from '../types'

// Clawd's scene: a 24x16 pixel grid, each cell a color or null (clear).
//
// His body is Claude Code's startup-banner Clawd decoded to square pixels:
//    ▐▛███▜▌
//   ▝▜█████▛▘
//     ▘▘ ▝▝
// A quadrant block is half a cell wide and half tall, so each one is 1 pixel
// wide and 2 tall here: an 18x10 body with eyes two pixels tall.

export const SCENE = { width: 24, height: 16 } as const

export type Grid = (string | null)[][]

const OX = 1 // body x 1..18
const OY = 6 // body rows 6..15, hat rows 1..5, effects to the right

const C = {
  body: '#CD6E58',
  eye: '#000000',
  white: '#FFFFFF',
  blush: '#F06090', // the hearts' pink
  pink: '#F06090',
  dark: '#333333',
  mid: '#888888',
  light: '#BBBBBB',
  gold: '#F2C94C',
  glass: '#BFE3F5',
  rain: '#88BBDD',
  cloud: '#9AA0A6',
  armFar: '#B0583F',
  laptop: '#A0A0A0',
}

const BODY = [
  '...############...',
  '...############...',
  '...############...',
  '...############...',
  '.################.',
  '.################.',
  '...############...',
  '...############...',
  '....#.#....#.#....',
  '....#.#....#.#....',
]
const EYE_X = [5, 12]
const EYE_Y = 2 // eyes are rows 2-3

// Hats sit on rows -5..-1 above the 12-wide head (x 3..14): H team color,
// h its dark shade, L its light tint, w white, y gold, k near-black.
const CROWN = [
  '..................',
  '...H....HH....H...',
  '...HH..HHHH..HH...',
  '...HHHHHHHHHHHH...',
  '...HyHHHHHHHHyH...',
]
const HATS: Record<HatName, string[]> = {
  'cowboy hat': ['..................', '..................', '......HHHHHH......', '......hhhhhh......', '.HHHHHHHHHHHHHHHH.'],
  beanie: ['..................', '........ww........', '.....HHHHHHHH.....', '....HHHHHHHHHH....', '...hhhhhhhhhhhh...'],
  cap: ['..................', '..................', '..................', '...HHHHHHHHHH.....', '...HHHHHHHHHHHhhhh'],
  'top hat': ['.....HHHHHHHH.....', '.....HHHHHHHH.....', '.....HHHHHHHH.....', '.....wwwwwwww.....', '..HHHHHHHHHHHHHH..'],
  'wizard hat': ['........HH........', '.......HHHH.......', '......HHHHHH......', '.....HHHyHHHH.....', '..HHHHHHHHHHHHHH..'],
  'party hat': ['........yy........', '........LL........', '.......HHHH.......', '......LLLLLL......', '.....HHHHHHHH.....'],
  'chef hat': ['....ww..ww..ww....', '....wwwwwwwwww....', '.....wwwwwwww.....', '.....wwwwwwww.....', '....HHHHHHHHHH....'],
  'viking helmet': ['..................', '..................', '.w..............w.', '.ww..HHHHHHHH..ww.', '..wwHHHHHHHHHHww..'],
  'propeller cap': ['..................', '.....yyyyyyyy.....', '........kk........', '.....HHLLHHLL.....', '....HHLLHHLLHH....'],
  beret: ['..................', '..................', '............h.....', '.....HHHHHHHHH....', '...HHHHHHHHHHHHH..'],
  'bucket hat': ['..................', '..................', '.....HHHHHHHH.....', '.....HHHHHHHH.....', '..hhhhhhhhhhhhhh..'],
  'grad cap': ['..................', '..................', '.HHHHHHHHHHHHHHHH.', '......HHHHHH....y.', '.....HHHHHHHH...y.'],
}

export const HAT_ORDER = Object.keys(HATS) as HatName[]

const TEAMS: Record<TeamColor, [string, string, string]> = {
  blue: ['#3B6FD6', '#24479A', '#8FB0EF'],
  green: ['#3FA34D', '#256B30', '#93D29C'],
  purple: ['#7B4FD1', '#4F2F94', '#B9A0EA'],
  // Not the coral-adjacent red: that one rounds to Clawd's body at 256 colors.
  red: ['#D42A2A', '#8C1C1C', '#F08A8A'],
  teal: ['#2BA59B', '#1A6B64', '#8FD8D1'],
  pink: ['#E86FA8', '#A8457A', '#F4B4D2'],
  grey: ['#8A8F98', '#5D6169', '#C3C7CD'],
}

export const TEAM_ORDER: TeamColor[] = ['blue', 'green', 'purple', 'red', 'teal', 'pink']

const easeOut = (t: number) => 1 - Math.pow(1 - t, 3)
const lerp = (a: number, b: number, t: number) => a + (b - a) * t

function grid(): Grid {
  return Array.from({ length: SCENE.height }, () => Array<string | null>(SCENE.width).fill(null))
}

function put(g: Grid, x: number, y: number, color: string | null) {
  const row = g[y]
  if (row !== undefined && x >= 0 && x < SCENE.width) {
    row[x] = color
  }
}

function draw(g: Grid, rows: readonly string[], ox: number, oy: number, colors: Record<string, string>) {
  rows.forEach((row, r) =>
    [...row].forEach((ch, c) => {
      if (ch !== '.') {
        put(g, ox + c, oy + r, colors[ch] ?? ch)
      }
    }),
  )
}

function hatOf(outfit: Outfit): string[] {
  return outfit.hat === 'crown' ? CROWN : HATS[outfit.hat]
}

function hatColors(outfit: Outfit): Record<string, string> {
  const [main, dark, tint] = TEAMS[outfit.color]
  const isLight = outfit.tone === 'light'

  return { H: isLight ? tint : main, h: isLight ? main : dark, L: isLight ? main : tint, w: C.white, y: C.gold, k: C.dark }
}

type Eyes = 'forward' | 'right' | 'left' | 'down' | 'blink' | 'closed'
type Pose = { eyes?: Eyes; legs?: 'tap'; arms?: 'wave' }

const LOOK: Record<'forward' | 'right' | 'left' | 'down', [number, number]> = {
  forward: [0, 0],
  right: [1, 0],
  left: [-1, 0],
  down: [0, 1],
}

// Front-facing Clawd in his outfit.
function clawd(g: Grid, outfit: Outfit, ox: number, oy: number, pose: Pose = {}) {
  const body = BODY.slice()
  if (pose.legs === 'tap') {
    body[9] = '....#.#....#......'
  }
  draw(g, body, ox, oy, { '#': C.body })
  if (pose.arms === 'wave') {
    put(g, ox + 16, oy + 5, null)
    put(g, ox + 17, oy + 3, C.body)
    put(g, ox + 17, oy + 4, C.body)
  }
  draw(g, hatOf(outfit), ox, oy - 5, hatColors(outfit))
  const eyes = pose.eyes ?? 'forward'
  if (eyes === 'blink') {
    return
  }
  // Asleep: each eye a short horizontal line.
  if (eyes === 'closed') {
    for (const x of [5, 6, 11, 12]) {
      put(g, ox + x, oy + EYE_Y + 1, C.eye)
    }
    return
  }
  const [dx, dy] = LOOK[eyes]
  for (const x of EYE_X) {
    put(g, ox + x + dx, oy + EYE_Y + dy, C.eye)
    put(g, ox + x + dx, oy + EYE_Y + dy + 1, C.eye)
  }
}

function blush(g: Grid, ox: number, oy: number) {
  put(g, ox + 4, oy + 3, C.blush)
  put(g, ox + 13, oy + 3, C.blush)
}

// Clawd side-on, facing right, as the desktop app draws him typing: a square
// block with both eyes showing, legs planted, arm blocks reaching forward.
const SIDE = [
  '########',
  '########',
  '#e#####e',
  '#e#####e',
  '########',
  '########',
  '########',
  '########',
  '#...#..#',
  '#...#..#',
]

// beat 0: the near arm is down on the keys (the laptop dips with it); 1: the far arm.
function clawdSide(g: Grid, outfit: Outfit, ox: number, oy: number, beat: number) {
  const far = beat === 1 ? 6 : 4
  const near = beat === 0 ? 7 : 4
  for (const y of [far, far + 1]) {
    for (const x of [9, 10]) {
      put(g, ox + x, oy + y, C.armFar)
    }
  }
  draw(g, SIDE, ox, oy, { '#': C.body, e: C.eye })
  for (const y of [near, near + 1]) {
    for (const x of [8, 9]) {
      put(g, ox + x, oy + y, C.body)
    }
  }
  // The front hats are 18 wide over a 12-wide head; center them on the 8-wide block.
  draw(g, hatOf(outfit), ox - 5, oy - 5, hatColors(outfit))
}

// A laptop seen side-on: a thin base on the ground, the screen a rising diagonal.
function laptop(g: Grid, ox: number, oy: number) {
  for (const x of [9, 10, 11, 12]) {
    put(g, ox + x, oy + 8, C.laptop)
  }
  for (const [x, y] of [[13, 8], [13, 7], [14, 6], [14, 5], [15, 4], [15, 3]] as const) {
    put(g, ox + x, oy + y, C.laptop)
  }
}

const HEART = ['p.p', 'ppp', '.p.']
const Z_SMALL = ['mmmm', '..m.', '.m..', 'mmmm']
const Z_BIG = ['ddddd', '...d.', '..d..', '.d...', 'ddddd']
const QUESTION = ['mmm', '..m', '.m.', '...', '.m.']
const EXCLAIM = ['d', 'd', 'd', '.', 'd']
const ENVELOPE = ['wwwww', 'wmwmw', 'wwmww', 'wwwww']
const GLASS = ['.gg.', 'gbbg', 'gbbg', '.gg.', '...g', '....g']
const CLOUD = ['..ccc..', '.ccccc.', 'ccccccc']

const FX = { p: C.pink, m: C.mid, d: C.dark, w: C.white, g: C.mid, b: C.glass, c: C.cloud }

type Vignette = {
  ms: number
  step: number
  draw: (g: Grid, outfit: Outfit, t: number, info: FrameInfo) => void
}

const VIGNETTES: Record<Activity, Vignette> = {
  // Just spawned: hops in from the left, then a "!".
  arrive: { ms: 1600, step: 100, draw(g, o, t) {
    const p = Math.min(t / 900, 1)
    const x = Math.round(lerp(-18, OX, easeOut(p)))
    const hop = p < 1 ? -Math.round(Math.abs(Math.sin(p * Math.PI * 3)) * 2) : 0
    clawd(g, o, x, OY + hop, { eyes: p < 1 ? 'right' : 'forward' })
    if (p >= 1) {
      draw(g, EXCLAIM, 23, 1, FX)
    }
  } },
  // Thinking: glances left and right while a "..." fills in.
  think: { ms: 2400, step: 200, draw(g, o, t) {
    const eyes = (['left', 'forward', 'right', 'forward'] as const)[Math.floor(t / 600) % 4]
    clawd(g, o, OX, OY, { eyes })
    const dots = Math.floor(t / 400) % 4
    for (let i = 0; i < dots; i++) {
      put(g, 19 + i * 2, 4, C.mid)
    }
  } },
  // Editing or running commands: side-on at a laptop, legs planted, the two
  // arm blocks taking turns on the keys, the laptop bouncing with them.
  type: { ms: 80, step: 40, draw(g, o, t, info) {
    const beat = Math.floor(t / (info.slowTyping ? 1000 : 40)) % 2
    const ox = 5
    const oy = 6
    const dip = beat === 0 ? 1 : 0
    laptop(g, ox, oy + dip)
    clawdSide(g, o, ox, oy, beat)
    put(g, ox + (beat ? 10 : 9), oy + 8 + dip, C.gold)
    if (info.isLong) {
      const drip = Math.floor(t / 120) % 2
      put(g, ox - 1, oy + 1 + drip, C.light)
      put(g, ox - 1, oy + 2 + drip, C.light)
    }
  } },
  // Reading or searching: scans with a magnifying glass.
  search: { ms: 2400, step: 300, draw(g, o, t) {
    clawd(g, o, OX, OY, { eyes: Math.floor(t / 600) % 2 ? 'right' : 'left' })
    draw(g, GLASS, 19, 7 + (Math.floor(t / 300) % 2), FX)
  } },
  // A supervisor starting a team member: waves them in, sparkle on the beat.
  recruit: { ms: 1200, step: 300, draw(g, o, t) {
    const isUp = Math.floor(t / 300) % 2 === 0
    clawd(g, o, OX, OY, isUp ? { eyes: 'right', arms: 'wave' } : { eyes: 'right' })
    if (isUp) {
      for (const [x, y] of [[22, 4], [21, 5], [23, 5], [22, 6]] as const) {
        put(g, x, y, C.gold)
      }
    }
  } },
  // Sending a message: holds up an envelope that flies off.
  message: { ms: 2000, step: 100, draw(g, o, t) {
    clawd(g, o, OX, OY, t < 1000 ? { eyes: 'right', arms: 'wave' } : { eyes: 'right' })
    const p = Math.max(0, (t - 1000) / 1000)
    if (t < 1000) {
      draw(g, ENVELOPE, 19, 4, FX)
    } else if (p < 0.8) {
      draw(g, ENVELOPE, 19 + Math.round(p * 6), 4 - Math.round(p * 4), FX)
    }
  } },
  // Waiting on its team: taps a foot and looks over with a "?".
  waitTeam: { ms: 2400, step: 300, draw(g, o, t) {
    const eyes = t < 1200 ? 'right' : 'down'
    clawd(g, o, OX, OY, Math.floor(t / 300) % 2 ? { eyes, legs: 'tap' } : { eyes })
    if (t >= 1200) {
      draw(g, QUESTION, 21, 0, FX)
    }
  } },
  // Idle: breathes and blinks.
  idle: { ms: 3200, step: 200, draw(g, o, t) {
    clawd(g, o, OX, OY + (Math.floor(t / 800) % 2), { eyes: t >= 3000 ? 'blink' : 'forward' })
  } },
  // Just finished: bounces with hearts, blush flashing.
  celebrate: { ms: 1500, step: 100, draw(g, o, t) {
    const p = t / 1500
    const hop = -Math.round(Math.abs(Math.sin(p * Math.PI * 2)) * 2)
    clawd(g, o, OX, OY + hop)
    if (Math.floor(t / 300) % 2) {
      blush(g, OX, OY + hop)
    }
    draw(g, HEART, 21, 10 - Math.round(p * 9), FX)
    if (p > 0.4) {
      draw(g, HEART, 21, 13 - Math.round((p - 0.4) * 12), FX)
    }
  } },
  // Done a while: asleep, eyes shut, blushing, with z's drifting up.
  rest: { ms: 2400, step: 800, draw(g, o, t) {
    clawd(g, o, OX, OY, { eyes: 'closed' })
    blush(g, OX, OY)
    const step = Math.floor(t / 800)
    draw(g, Z_SMALL, 20, 8 - step, FX)
    if (step >= 1) {
      draw(g, Z_BIG, 19, 2 - step, FX)
    }
  } },
  // Failed: looks down under a little rain cloud, sweat drop.
  failed: { ms: 1200, step: 200, draw(g, o, t) {
    clawd(g, o, OX, OY, { eyes: 'down' })
    draw(g, CLOUD, 17, 0, FX)
    const k = Math.floor(t / 200) % 3
    for (const [x, off] of [[18, 0], [20, 1], [22, 2]] as const) {
      put(g, x, 3 + ((k + off) % 3), C.rain)
    }
    put(g, OX + 17, OY + 1, C.light)
    put(g, OX + 17, OY + 2, C.light)
  } },
  // Stopped: looks down, still.
  killed: { ms: 1000, step: 1000, draw(g, o) {
    clawd(g, o, OX, OY, { eyes: 'down' })
  } },
}

// How long a loop runs and how often its frame changes.
export function loopOf(activity: Activity, info: FrameInfo): { ms: number; step: number } {
  if (activity === 'type' && info.slowTyping) {
    return { ms: 2000, step: 1000 }
  }
  const { ms, step } = VIGNETTES[activity]

  return { ms, step }
}

export function frameAt(activity: Activity, outfit: Outfit, t: number, info: FrameInfo): Grid {
  const g = grid()
  VIGNETTES[activity].draw(g, outfit, t % loopOf(activity, info).ms, info)

  return g
}

// A frame that stands for the loop when animation is off: arrive's opening
// frames have Clawd still off-scene, so it is drawn once he has hopped in.
export function stillOf(activity: Activity, outfit: Outfit, info: FrameInfo): Grid {
  return frameAt(activity, outfit, activity === 'arrive' ? 1000 : 0, info)
}

export function framesOf(activity: Activity, outfit: Outfit, info: FrameInfo): Grid[] {
  const { ms, step } = loopOf(activity, info)
  const frames: Grid[] = []
  for (let t = 0; t < ms; t += step) {
    frames.push(frameAt(activity, outfit, t, info))
  }

  return frames
}

// How the outline names an outfit: "blue cowboy hat", "light blue beanie", "green crown".
export function outfitName(outfit: Outfit): string {
  const tint = outfit.tone === 'light' && outfit.hat !== 'crown' ? 'light ' : ''

  return `${tint}${outfit.color} ${outfit.hat}`
}

const ACTIVITY_LABEL: Record<Activity, string> = {
  arrive: 'just started',
  think: 'thinking',
  type: 'typing',
  search: 'searching',
  recruit: 'starting a team member',
  message: 'sending a message',
  waitTeam: 'waiting on the team',
  idle: 'idle',
  celebrate: 'just finished',
  rest: 'resting',
  failed: 'failed',
  killed: 'stopped',
}

// What a Clawd is doing, in words: the image's alt text.
export function activityLabel(activity: Activity): string {
  return ACTIVITY_LABEL[activity]
}
