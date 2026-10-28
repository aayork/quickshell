import QtQuick
import qs.theme

// The Windows 7 Explorer selection: a soft, glassy blue fill with a blue
// edge and a bright top line. `selected` is stronger than a hover.
Rectangle {
  id: root

  property bool hovered: false
  property bool selected: false

  readonly property real strength: selected ? 1 : hovered ? 0.55 : 0

  visible: strength > 0
  radius: 3
  border.width: 1
  border.color: Theme.alpha("#7ab4ec", 0.3 + 0.4 * strength)
  gradient: Gradient {
    GradientStop { position: 0; color: Theme.alpha("#9fcff7", 0.1 + 0.18 * root.strength) }
    GradientStop { position: 1; color: Theme.alpha("#3f8fd8", 0.12 + 0.22 * root.strength) }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: 1
    radius: Math.max(0, root.radius - 1)
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha("#ffffff", 0.12 + 0.18 * root.strength)
  }
}
