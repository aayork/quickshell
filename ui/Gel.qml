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

  // The highlight: a smaller pill across the top. It is inset from the
  // sides by more than the corner curve, so it never pokes out of a pill
  // or a circle.
  Rectangle {
    readonly property real curve: Math.min(root.radius, root.height / 2)
    x: Math.max(2, curve * 0.55)
    y: Math.max(1, root.height * 0.06)
    width: root.width - 2 * x
    height: root.height * 0.44
    radius: Math.min(height / 2, Math.max(0, curve - x * 0.5))
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.8) }
      GradientStop { position: 1; color: Theme.alpha("#ffffff", 0.12) }
    }
  }
}
