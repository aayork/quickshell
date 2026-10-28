import QtQuick
import qs.theme

// The Windows Vista button face: two-tone glass with a hard step across the
// middle and a bright inner edge. On a dark theme it is the glossy black of
// the Vista Start menu's power buttons, glowing blue under the pointer; on a
// light theme the silver of ordinary dialog buttons, light blue when hovered.
// Pressed (or chosen, with `lit`) goes a deeper blue either way.
Rectangle {
  id: root

  property bool hovered: false
  property bool pressed: false
  property bool lit: false

  readonly property var face: Theme.dark
    ? (pressed || lit
      ? ["#5d8fc4", "#2f6aa6", "#163f6e", "#2a62a0", "#06182b"]
      : hovered
        ? ["#6f8fb0", "#3e6185", "#16324f", "#2b5683", "#0a1a2a"]
        : ["#5b636b", "#353c43", "#15191d", "#0b0e10", "#000000"])
    : (pressed || lit
      ? ["#e5f4fc", "#c4e5f6", "#98d1ef", "#68b3db", "#2c628b"]
      : hovered
        ? ["#eaf6fd", "#d9f0fc", "#bee6fd", "#a7d9f5", "#3c7fb1"]
        : ["#f2f2f2", "#ebebeb", "#dddddd", "#cfcfcf", "#707070"])
  // Text and glyphs on this face.
  readonly property color ink: Theme.dark ? "#ffffff" : "#1e1e1e"

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
    border.color: Theme.alpha("#ffffff", Theme.dark ? (root.pressed ? 0.12 : 0.22) : (root.pressed ? 0.3 : 0.75))
  }
}
