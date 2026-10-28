import QtQuick
import qs.theme

// The frame every sidebar gadget sits in, after the Vista Sidebar: smoked
// glass with rounded corners, a black outline, a faint white inner edge and
// a gloss over the top. Children draw on top.
Rectangle {
  id: root

  radius: 7
  border.width: 1
  border.color: Theme.alpha("#000000", 0.6)
  gradient: Gradient {
    GradientStop { position: 0; color: Theme.alpha("#2a3a48", 0.62) }
    GradientStop { position: 1; color: Theme.alpha("#05090d", 0.72) }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: 1
    radius: root.radius - 1
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha("#ffffff", 0.16)
  }

  Rectangle {
    x: 3
    y: 2
    width: parent.width - 6
    height: Math.min(parent.height * 0.4, 40)
    radius: root.radius - 2
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.16) }
      GradientStop { position: 1; color: Theme.alpha("#ffffff", 0) }
    }
  }
}
