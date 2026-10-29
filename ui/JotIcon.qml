import QtQuick

// Jot's hover-bar icons, drawn to match Antinote's (thin strokes, 16 units):
// "settings" three sliders with ring knobs, "search" a magnifier whose lens
// has an orbit round it, "compose" a rounded square with an arrow leaving its
// top-right corner, "pin" a ring on a stem standing on a base.
Item {
  id: root

  property string kind: "settings"
  property color color: "#888888"
  property real size: 16

  signal clicked()

  implicitWidth: 26
  implicitHeight: 26

  Rectangle {
    anchors.fill: parent
    radius: 6
    color: Qt.rgba(root.color.r, root.color.g, root.color.b, mouse.pressed ? 0.16 : mouse.containsMouse ? 0.09 : 0)
  }

  Canvas {
    id: canvas
    anchors.centerIn: parent
    width: root.size
    height: root.size
    readonly property var look: [root.kind, root.color, root.size]
    onLookChanged: requestPaint()

    onPaint: {
      var c = getContext("2d")
      c.reset()
      var s = width / 16
      c.scale(s, s)
      c.strokeStyle = root.color
      c.fillStyle = root.color
      c.lineWidth = 1.25
      c.lineCap = "round"
      c.lineJoin = "round"

      function ring(x, y, r) {
        c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.stroke()
      }
      function line(x1, y1, x2, y2) {
        c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.stroke()
      }

      if (root.kind === "settings") {
        // Three tracks, knobs at different places, a gap round each knob.
        var knobs = [[3.5, 7.2], [8, 11], [12.5, 5.2]]
        for (var i = 0; i < knobs.length; i++) {
          var y = knobs[i][0], k = knobs[i][1]
          line(1.5, y, k - 2.1, y)
          line(k + 2.1, y, 14.5, y)
          ring(k, y, 1.6)
        }
      } else if (root.kind === "search") {
        ring(7, 7, 4.6)
        // The orbit, a flat ellipse through the lens, broken where the lens hides it.
        c.save()
        c.beginPath()
        c.ellipse(0.6, 6.3, 12.8, 3.6)
        c.restore()
        c.stroke()
        line(10.4, 10.6, 13.6, 14.2)
      } else if (root.kind === "compose") {
        // A rounded square open at the top-right corner.
        c.beginPath()
        c.moveTo(8.5, 2.5)
        c.lineTo(4, 2.5)
        c.arcTo(2.5, 2.5, 2.5, 4, 1.6)
        c.lineTo(2.5, 12)
        c.arcTo(2.5, 13.5, 4, 13.5, 1.6)
        c.lineTo(12, 13.5)
        c.arcTo(13.5, 13.5, 13.5, 12, 1.6)
        c.lineTo(13.5, 7.5)
        c.stroke()
        line(7.2, 8.8, 13.6, 2.4)
        c.beginPath(); c.arc(14.2, 1.8, 0.75, 0, Math.PI * 2); c.fill()
      } else if (root.kind === "pin") {
        ring(8, 4.6, 3.1)
        line(8, 7.7, 8, 13.6)
        line(3, 13.6, 13, 13.6)
        c.beginPath(); c.arc(10.3, 12.2, 0.55, 0, Math.PI * 2); c.fill()
      } else if (root.kind === "pinned") {
        c.beginPath(); c.arc(8, 4.6, 3.1, 0, Math.PI * 2); c.fill()
        line(8, 7.7, 8, 13.6)
        line(3, 13.6, 13, 13.6)
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.clicked()
  }
}
