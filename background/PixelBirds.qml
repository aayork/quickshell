import QtQuick

// Birds crossing the scene, drawn pixel by pixel, for LivePixel: they flap
// for a while, glide for a while, and bob a little as they go.
//   cfg: { count, area: [x0,y0,x1,y1] (the band they fly in; they enter
//          and leave past its sides), speed: [min,max] px/s, color,
//          pause (longest wait between crossings, s) }
Item {
  id: root

  // LivePixel: its tick signal, dt, rand() and pick().
  required property Item clock
  required property var cfg

  // [x, y] pixels: wings up, level, down (a gull's flat "m").
  readonly property var frames: [
    [[0,0],[4,0],[1,1],[3,1],[2,2]],
    [[0,1],[1,1],[3,1],[4,1],[2,2]],
    [[2,1],[0,2],[1,2],[3,2],[4,2]]
  ]

  Repeater {
    model: root.cfg ? root.cfg.count : 0

    Item {
      id: bird

      readonly property var cfg: root.cfg
      property real fx: 0
      property real fy: 0
      property real vx: 10
      property real wing: 0
      property real flap: 8
      property real glide: 0
      property real wait: 0
      property real t: 0
      // Flapping goes up, level, down, level; gliding holds level.
      readonly property int frame: glide > 0 ? 1 : [0, 1, 2, 1][Math.floor(wing) % 4]

      x: Math.round(fx)
      y: Math.round(fy + Math.sin(t * 1.3) * 1.2)
      visible: wait <= 0

      function reset(first) {
        var c = root.clock
        var speed = cfg.speed || [8, 16]
        var left = Math.random() < 0.5
        vx = c.rand(speed[0], speed[1]) * (left ? 1 : -1)
        fx = first ? c.rand(cfg.area[0], cfg.area[2]) : (left ? cfg.area[0] - 6 : cfg.area[2] + 1)
        fy = c.rand(cfg.area[1], cfg.area[3])
        flap = c.rand(6, 10)
        glide = 0
        t = c.rand(0, 10)
        wait = first ? c.rand(0, 4) : c.rand(1, cfg.pause ?? 10)
      }

      Component.onCompleted: reset(true)

      Connections {
        target: root.clock
        function onTick() {
          var c = root.clock
          var dt = c.dt
          if (bird.wait > 0) { bird.wait -= dt; return }
          bird.t += dt
          bird.fx += bird.vx * dt
          if (bird.glide > 0) bird.glide -= dt
          else {
            bird.wing += bird.flap * dt
            // Now and then it stops flapping and glides.
            if (Math.random() < dt * 0.25) bird.glide = c.rand(1, 3)
          }
          if (bird.fx < bird.cfg.area[0] - 8 || bird.fx > bird.cfg.area[2] + 3) bird.reset(false)
        }
      }

      Repeater {
        model: 5
        Rectangle {
          required property int index
          readonly property var p: root.frames[bird.frame][index]
          x: p[0]
          y: p[1]
          width: 1
          height: 1
          color: bird.cfg.color
        }
      }
    }
  }
}
