import QtQuick
import QtQuick.Shapes
import qs.theme

// A small drawn battery: the percentage, a rounded body filled to the charge,
// and a bolt while charging. Yellow when getting low, red when nearly empty.
Row {
  id: root

  property int level: 0
  property bool charging: false

  readonly property real fraction: Math.max(0, Math.min(100, level)) / 100
  readonly property bool critical: level <= 15 && !charging
  readonly property bool lowish: level <= 30 && !charging
  readonly property color fillColor: critical ? Theme.red
    : lowish ? Theme.yellow
    : charging ? Theme.green
    : Theme.alpha(Theme.foreground, 0.75)
  readonly property color outline: critical ? Theme.alpha(Theme.red, 0.7) : Theme.alpha(Theme.foreground, 0.35)

  spacing: 5

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: root.level + "%"
    color: root.critical ? Theme.red : Theme.dim
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSmall
  }

  Item {
    anchors.verticalCenter: parent.verticalCenter
    width: body.width + 3
    height: body.height

    Rectangle {
      id: body
      width: 23
      height: 12
      radius: 3.5
      color: Theme.alpha(Theme.foreground, 0.06)
      border.width: 1
      border.color: root.outline

      // Inset so the fill keeps the body's rounded shape.
      Rectangle {
        x: 2
        y: 2
        height: parent.height - 4
        width: Math.max(height / 2, (parent.width - 4) * root.fraction)
        radius: 2
        color: root.fillColor
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 200 } }
      }

      // Bolt over the middle while charging; the dark edge keeps it readable
      // over both the fill and the empty part.
      Shape {
        visible: root.charging
        anchors.centerIn: parent
        width: 7
        height: 10
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          fillColor: Theme.brightForeground
          strokeColor: Theme.background
          strokeWidth: 1
          joinStyle: ShapePath.RoundJoin
          startX: 4.2; startY: 0
          PathLine { x: 0.4; y: 5.8 }
          PathLine { x: 3.2; y: 5.8 }
          PathLine { x: 2.6; y: 10 }
          PathLine { x: 6.6; y: 4.0 }
          PathLine { x: 3.8; y: 4.0 }
          PathLine { x: 4.2; y: 0 }
        }
      }
    }

    // The tip.
    Rectangle {
      anchors.verticalCenter: body.verticalCenter
      x: body.width + 1
      width: 2
      height: 5
      radius: 1
      color: root.outline
    }
  }
}
