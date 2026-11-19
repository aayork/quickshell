import QtQuick
import qs.theme

// The Tailscale mark: a 3x3 grid of dots. Drawn rather than loaded, so it
// stays crisp at bar size and takes the bar's colour.
//
// It shows state the way Tailscale's own menu bar icon does: every dot dim
// while off, the T lit while connected, and while connecting it plays
// Tailscale's loading animation (the frames from tailscale's client/systray,
// 500ms each). With `exitNode` a small arrow sits in the bottom-right corner.
Item {
  id: root

  property real size: 13
  property color color: Theme.foreground
  // Tailscale is off: every dot dimmed.
  property bool off: false
  // Connecting, or switching on or off: play the loading frames.
  property bool busy: false
  // Traffic goes out through an exit node.
  property bool exitNode: false

  readonly property real dot: Math.max(2, size * 0.24)
  readonly property real mid: (size - dot) / 2
  readonly property real end: size - dot

  readonly property var logo: [0, 0, 0, 1, 1, 1, 0, 1, 0]
  readonly property var blank: [0, 0, 0, 0, 0, 0, 0, 0, 0]
  readonly property var frames: [
    [0, 1, 1, 1, 0, 1, 0, 0, 1],
    [0, 1, 1, 0, 0, 1, 0, 1, 0],
    [0, 1, 1, 0, 0, 0, 0, 0, 1],
    [0, 0, 1, 0, 1, 0, 0, 0, 0],
    [0, 1, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 1, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 1, 0, 0],
    [0, 0, 0, 0, 0, 0, 1, 1, 0],
    [0, 0, 0, 1, 0, 0, 1, 1, 0],
    [0, 0, 0, 1, 1, 0, 0, 1, 0],
    [0, 0, 0, 1, 1, 0, 0, 1, 1],
    [0, 0, 0, 1, 1, 1, 0, 0, 1],
    [0, 1, 0, 0, 1, 1, 1, 0, 1]
  ]
  property int frame: 0

  readonly property var lit: busy ? frames[frame] : off ? blank : logo

  implicitWidth: size
  implicitHeight: size

  onBusyChanged: frame = 0

  Timer {
    interval: 500
    repeat: true
    running: root.busy && root.visible
    onTriggered: root.frame = (root.frame + 1) % root.frames.length
  }

  component Dot: Rectangle {
    required property int index
    readonly property bool hidden: root.exitNode && !root.busy && index === 8

    x: (index % 3) * root.mid
    y: Math.floor(index / 3) * root.mid
    width: root.dot
    height: root.dot
    radius: width / 2
    color: root.color
    visible: !hidden
    opacity: root.lit[index] ? 1 : 0.3

    Behavior on opacity {
      enabled: !root.busy
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
  }

  Repeater {
    model: 9
    Dot {}
  }

  // Exit node: an arrow out of the bottom-right corner, in place of that dot.
  Canvas {
    id: arrow
    visible: root.exitNode && !root.busy
    x: root.end - root.dot * 0.4
    y: root.end - root.dot * 0.4
    width: root.dot * 1.8
    height: root.dot * 1.8
    onPaint: {
      var c = getContext("2d")
      var w = width, s = Math.max(1, root.dot * 0.45)
      c.reset()
      c.strokeStyle = root.color
      c.lineWidth = s
      c.lineCap = "round"
      c.lineJoin = "round"
      c.beginPath()
      c.moveTo(s, w - s); c.lineTo(w - s, s)
      c.moveTo(w * 0.4, s); c.lineTo(w - s, s); c.lineTo(w - s, w * 0.6)
      c.stroke()
    }
    onVisibleChanged: requestPaint()
    Connections { target: root; function onColorChanged() { arrow.requestPaint() } }
  }
}
