import QtQuick
import QtTest
import "../Sprite.js" as Sprite

TestCase {
  name: "Sprite"

  function test_rows() {
    compare(Sprite.POSES.idle.row, 0)
    compare(Sprite.POSES.waving.row, 3)
    compare(Sprite.POSES.jumping.row, 4)
    compare(Sprite.POSES.waiting.row, 6)
    compare(Sprite.POSES.running.row, 7)
  }

  function test_frame_counts() {
    compare(Sprite.POSES.idle.durations.length, 6)
    compare(Sprite.POSES.waving.durations.length, 4)
    compare(Sprite.POSES.jumping.durations.length, 5)
    compare(Sprite.POSES.waiting.durations.length, 6)
    compare(Sprite.POSES.running.durations.length, 6)
  }

  function test_idle_blink() {
    var d = Sprite.POSES.idle.durations
    compare(d[1], 110)
    compare(d[2], 110)
    verify(d[1] < d[0] && d[2] < d[3])
  }

  function test_last_frame_held_longest() {
    for (var name in Sprite.POSES) {
      var d = Sprite.POSES[name].durations
      var last = d[d.length - 1]
      for (var i = 0; i < d.length - 1; i++) verify(d[i] < last, name + " frame " + i)
    }
  }

  function test_pick_action_never_repeats() {
    for (var p = 0; p < Sprite.ACTIONS.length; p++) {
      var previous = Sprite.ACTIONS[p]
      var seen = {}
      for (var r = 0; r < 1; r += 0.05) {
        var picked = Sprite.pickAction(previous, r)
        verify(picked !== previous, "picked " + picked + " after " + previous)
        verify(Sprite.ACTIONS.indexOf(picked) !== -1, picked)
        seen[picked] = true
      }
      compare(Object.keys(seen).length, Sprite.ACTIONS.length - 1)
    }
  }

  function test_first_pick_covers_whole_pool() {
    var seen = {}
    for (var r = 0; r < 1; r += 0.05) seen[Sprite.pickAction("", r)] = true
    compare(Object.keys(seen).length, Sprite.ACTIONS.length)
  }

  function test_wait_range() {
    compare(Sprite.drawWaitMs(0), 8000)
    compare(Sprite.drawWaitMs(0.999999), 20000)
    verify(Sprite.drawWaitMs(0.5) >= 8000 && Sprite.drawWaitMs(0.5) <= 20000)
  }

  function test_walk_dwell_range() {
    compare(Sprite.walkDwellMs(0), 2000)
    compare(Sprite.walkDwellMs(0.999999), 5000)
    verify(Sprite.walkDwellMs(0.5) >= 2000 && Sprite.walkDwellMs(0.5) <= 5000)
  }

  function test_random_ring_point() {
    var p = Sprite.randomRingPoint(0, 0.77, 30, 100)
    verify(Math.abs(Math.hypot(p.x, p.y) - 30) < 1e-9, "inner " + Math.hypot(p.x, p.y))
    p = Sprite.randomRingPoint(1, 0.25, 30, 100)
    verify(Math.abs(p.x) < 1e-9, "x " + p.x)
    verify(Math.abs(p.y - 100) < 1e-9, "y " + p.y)
    p = Sprite.randomRingPoint(0, 0, 0, 100)
    compare(p.x, 0)
    compare(p.y, 0)
    for (var i = 0; i < 200; i++) {
      p = Sprite.randomRingPoint(Math.random(), Math.random(), 20, 80)
      var r = Math.hypot(p.x, p.y)
      verify(r >= 20 - 1e-9 && r <= 80, "r " + r)
    }
  }

  function test_walk_toward() {
    var p = Sprite.walkToward(0, 0, 100, 0, 40)
    compare(p.x, 40)
    compare(p.y, 0)
    compare(p.arrived, false)
    p = Sprite.walkToward(80, 0, 100, 0, 40)
    compare(p.x, 100)
    compare(p.arrived, true)
    p = Sprite.walkToward(100, 100, 100, 100, 40)
    compare(p.arrived, true)
    p = Sprite.walkToward(0, 0, 3, 4, 2.5)
    verify(Math.abs(Math.hypot(p.x, p.y) - 2.5) < 1e-9, "diag " + Math.hypot(p.x, p.y))
    compare(p.arrived, false)
  }

  function test_look_wheel_cardinals() {
    compare(Sprite.lookCell(0, -1), { row: 9, frame: 0 })
    compare(Sprite.lookCell(1, 0), { row: 9, frame: 4 })
    compare(Sprite.lookCell(0, 1), { row: 10, frame: 0 })
    compare(Sprite.lookCell(-1, 0), { row: 10, frame: 4 })
  }

  function test_look_wheel_diagonals_and_rounding() {
    compare(Sprite.lookCell(1, -1), { row: 9, frame: 2 })
    compare(Sprite.lookCell(-1, 1), { row: 10, frame: 2 })
    compare(Sprite.lookCell(Math.tan(11 * Math.PI / 180), -1), { row: 9, frame: 0 })
    compare(Sprite.lookCell(Math.tan(12 * Math.PI / 180), -1), { row: 9, frame: 1 })
    compare(Sprite.lookCell(-Math.tan(12 * Math.PI / 180), -1), { row: 10, frame: 7 })
  }
}
