import QtQuick

// Leaves tumbling and swaying down, drawn pixel by pixel, for LivePixel.
// One set per depth: "small" far away, "medium" in the scene, "large" close
// to the viewer.
//   cfg: { count, spawn: [x0,y0,x1,y1], land: [y0,y1], colors,
//          fall: [min,max] px/s, sway: [min,max] px, darken (1 = as given),
//          fade (opacity) }
Item {
  id: root

  // LivePixel: its tick signal, dt, rand() and pick().
  required property Item clock
  required property var cfg
  property string size: "medium"

  // [x, y, 0 main / 1 shade / 2 stem and edge], four turns of a leaf
  // falling: flat, tilted, edge-on, tilted the other way.
  readonly property var shapes: ({
    small: [
      [[0,0,0],[1,0,0],[1,1,1]],
      [[0,0,0],[0,1,1],[1,1,0]],
      [[0,0,1],[1,0,1]],
      [[1,0,0],[0,1,0],[1,1,1]]
    ],
    medium: [
      [[1,0,0],[2,0,0],[0,1,0],[1,1,0],[2,1,0],[3,1,1],[1,2,0],[2,2,1],[3,2,1],[4,2,2],[2,3,2]],
      [[2,0,0],[1,1,0],[2,1,0],[3,1,0],[0,2,0],[1,2,0],[2,2,1],[3,2,1],[4,2,0],[2,3,2]],
      [[0,0,0],[1,0,0],[2,0,1],[3,0,1],[4,0,2]],
      [[2,0,0],[3,0,0],[1,1,1],[2,1,0],[3,1,0],[4,1,0],[0,2,2],[1,2,1],[2,2,1],[3,2,0],[2,3,2]]
    ],
    large: [
      root.grid(["...M...", ".M.M.M.", ".MMMMM.", "MMMSMMM", ".MSSSM.", "...D...", "...D..."]),
      root.grid(["....M..", "..M.MM.", ".MMMMM.", "MMMSSM.", ".MSSM..", "..D....", ".D....."]),
      root.grid(["....MM", "..MMS.", ".MSS..", "D....."]),
      root.grid(["..M....", ".MM.M..", ".MMMMM.", ".MSSMMM", "..MSSM.", "....D..", ".....D."])
    ]
  })
  readonly property var frames: shapes[size] || shapes.medium
  readonly property int most: Math.max.apply(null, frames.map(f => f.length))

  function grid(rows) {
    var out = []
    for (var y = 0; y < rows.length; y++)
      for (var x = 0; x < rows[y].length; x++) {
        var k = "MSD".indexOf(rows[y][x])
        if (k >= 0) out.push([x, y, k])
      }
    return out
  }

  Repeater {
    model: root.cfg ? root.cfg.count : 0

    Item {
      id: leaf

      readonly property var cfg: root.cfg
      property real fx: 0
      property real fy: 0
      property real fall: 10
      property real sway: 4
      property real spin: 2
      property real phase: 0
      property real land: 400
      property real wait: 0
      property color main: "orange"
      property color shade: "brown"
      property color edge: "black"
      readonly property var frame: root.frames[Math.floor(phase / (Math.PI / 2)) % 4]

      x: Math.round(fx + Math.sin(phase) * sway)
      y: Math.round(fy)
      visible: wait <= 0
      opacity: cfg.fade ?? 1

      function reset(first) {
        var c = root.clock
        var fallRange = cfg.fall || [9, 18]
        var swayRange = cfg.sway || [3, 9]
        fx = c.rand(cfg.spawn[0], cfg.spawn[2])
        fy = first ? c.rand(cfg.spawn[1], cfg.land[1]) : c.rand(cfg.spawn[1], cfg.spawn[3])
        fall = c.rand(fallRange[0], fallRange[1])
        sway = c.rand(swayRange[0], swayRange[1])
        spin = c.rand(1.6, 3.2) * (fallRange[1] > 30 ? 1.6 : 1)
        phase = c.rand(0, Math.PI * 2)
        land = c.rand(cfg.land[0], cfg.land[1])
        wait = first ? c.rand(0, 3) : c.rand(0, cfg.pause ?? 4)
        main = Qt.darker(c.pick(cfg.colors), cfg.darken ?? 1)
        shade = Qt.darker(main, 1.3)
        edge = Qt.darker(main, 2.2)
      }

      Component.onCompleted: reset(true)

      Connections {
        target: root.clock
        function onTick() {
          var dt = root.clock.dt
          if (leaf.wait > 0) { leaf.wait -= dt; return }
          leaf.fy += leaf.fall * dt
          leaf.phase = (leaf.phase + leaf.spin * dt) % (Math.PI * 8)
          if (leaf.fy > leaf.land) leaf.reset(false)
        }
      }

      Repeater {
        model: root.most
        Rectangle {
          required property int index
          readonly property var p: index < leaf.frame.length ? leaf.frame[index] : null
          x: p ? p[0] : 0
          y: p ? p[1] : 0
          width: 1
          height: 1
          visible: p !== null
          color: !p ? "transparent" : p[2] === 2 ? leaf.edge : p[2] === 1 ? leaf.shade : leaf.main
        }
      }
    }
  }
}
