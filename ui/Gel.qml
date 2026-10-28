import QtQuick
import qs.theme

// A glossy aqua "gel" fill, for anything switched on or chosen: the accent
// lighter at the top, with a bright highlight over the upper half.
Rectangle {
  id: root

  property color base: Theme.accent

  radius: height / 2
  border.width: 1
  border.color: Qt.darker(base, 1.35)
  gradient: Gradient {
    GradientStop { position: 0; color: Qt.lighter(root.base, 1.45) }
    GradientStop { position: 0.5; color: Qt.lighter(root.base, 1.1) }
    GradientStop { position: 0.51; color: root.base }
    GradientStop { position: 1; color: Qt.lighter(root.base, 1.25) }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 1.5
    height: parent.height * 0.48
    radius: Math.max(0, root.radius - 1.5)
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.75) }
      GradientStop { position: 1; color: Theme.alpha("#ffffff", 0.15) }
    }
  }
}
