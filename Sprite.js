.pragma library

// Row and frame durations (ms) per pose.
var POSES = {
  idle:    { row: 0, durations: [280, 110, 110, 140, 140, 320] },
  waving:  { row: 3, durations: [140, 140, 140, 280] },
  jumping: { row: 4, durations: [140, 140, 140, 140, 280] },
  waiting: { row: 6, durations: [150, 150, 150, 150, 150, 260] },
  running: { row: 7, durations: [120, 120, 120, 120, 120, 220] }
}

// Random behaviour pool, played ACTION_LOOPS times.
var ACTIONS = ["waving", "jumping", "waiting", "running"]
var ACTION_LOOPS = 2

// Stroll speed while walking, px per second.
var WALK_SPEED = 60

// Rest between strolls, ms.
function walkDwellMs(random) {
  return 2000 + Math.floor(random * 3001)
}

// Uniform point in a ring between minR and maxR, minR 0 gives a disc (u1, u2 in [0, 1)).
function randomRingPoint(u1, u2, minR, maxR) {
  var angle = u2 * 2 * Math.PI
  var r = Math.sqrt(u1 * (maxR * maxR - minR * minR) + minR * minR)
  return { x: r * Math.cos(angle), y: r * Math.sin(angle) }
}

// One step of at most `step` px from (x, y) toward (tx, ty); arrived snaps onto it.
function walkToward(x, y, tx, ty, step) {
  var dx = tx - x
  var dy = ty - y
  var d = Math.sqrt(dx * dx + dy * dy)
  if (d === 0 || d <= step) return { x: tx, y: ty, arrived: true }
  return { x: x + dx / d * step, y: y + dy / d * step, arrived: false }
}

function pickAction(previous, random) {
  var pool = ACTIONS.filter(function(name) { return name !== previous })
  return pool[Math.floor(random * pool.length)]
}

function drawWaitMs(random) {
  return 8000 + Math.floor(random * 12001)
}

// Rows 9-10: 16-way look wheel, index 0 = up, clockwise.
var LOOK_ROWS = 11
var NEUTRAL_FRAME = 6

function lookCell(dx, dy) {
  var index = Math.round(((Math.atan2(dx, -dy) * 180 / Math.PI + 360) % 360) / 22.5) % 16
  return { row: 9 + Math.floor(index / 8), frame: index % 8 }
}
