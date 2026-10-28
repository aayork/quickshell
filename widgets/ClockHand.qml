import QtQuick
import QtQuick.Shapes

// A tapered clock hand, broad at the centre and narrowing to a point.
// Fills the dial; `length` and `tail` are shares of its radius.
Item {
  id: taper
  property real angle: 0
  property real length: 0.5   // share of the radius
  property real base: 6
  property real tail: 0.14
  property color color: "#15191d"
  readonly property real cx: width / 2
  readonly property real cy: height / 2
  readonly property real r: width / 2
  anchors.fill: parent
  rotation: angle
  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: taper.color
      strokeColor: "transparent"
      startX: taper.cx - taper.base / 2; startY: taper.cy + taper.r * taper.tail
      PathLine { x: taper.cx - 0.6; y: taper.cy - taper.r * taper.length }
      PathLine { x: taper.cx + 0.6; y: taper.cy - taper.r * taper.length }
      PathLine { x: taper.cx + taper.base / 2; y: taper.cy + taper.r * taper.tail }
      PathLine { x: taper.cx - taper.base / 2; y: taper.cy + taper.r * taper.tail }
    }
  }
}
