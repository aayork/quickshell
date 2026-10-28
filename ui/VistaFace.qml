import QtQuick
import qs.theme

// The Windows Vista button face: two-tone glass with a hard step across the
// middle and a white inner edge. Silver at rest, light blue under the
// pointer, deeper blue pressed (or chosen, with `lit`).
Rectangle {
  id: root

  property bool hovered: false
  property bool pressed: false
  property bool lit: false

  readonly property var face: pressed || lit
    ? ["#e5f4fc", "#c4e5f6", "#98d1ef", "#68b3db", "#2c628b"]
    : hovered
      ? ["#eaf6fd", "#d9f0fc", "#bee6fd", "#a7d9f5", "#3c7fb1"]
      : ["#f2f2f2", "#ebebeb", "#dddddd", "#cfcfcf", "#707070"]

  radius: 3
  border.width: 1
  border.color: face[4]
  gradient: Gradient {
    GradientStop { position: 0; color: root.face[0] }
    GradientStop { position: 0.49; color: root.face[1] }
    GradientStop { position: 0.5; color: root.face[2] }
    GradientStop { position: 1; color: root.face[3] }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: 1
    radius: Math.max(0, root.radius - 1)
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha("#ffffff", root.pressed ? 0.3 : 0.75)
  }
}
