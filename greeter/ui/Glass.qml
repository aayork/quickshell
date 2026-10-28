import QtQuick
import QtQuick.Effects
import qs.theme

// A Vista / Windows 7 glass pane: translucent gradient, a gloss band over the
// top, a bright inner edge and a soft white outline. Children draw on top.
Rectangle {
  id: root

  property real shine: 1

  radius: Theme.radius
  border.width: 1
  border.color: Theme.glassBorder
  gradient: Gradient {
    GradientStop { position: 0; color: Theme.glassTop }
    GradientStop { position: 1; color: Theme.glassBottom }
  }


  // Gloss band, inset past the corner curve so it stays inside round shapes.
  Rectangle {
    readonly property real curve: Math.min(root.radius, root.height / 2)
    x: Math.max(2, curve * 0.45)
    y: 2
    width: root.width - 2 * x
    height: Math.min(parent.height * 0.45, 90)
    radius: Math.min(height / 2, Math.max(0, curve - x * 0.5))
    opacity: root.shine
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.gloss }
      GradientStop { position: 1; color: "transparent" }
    }
  }

  // Liquid glass rim: a thin ring that catches the light, brightest along the
  // top, dim down the sides and lit again faintly at the bottom.
  Item {
    id: rimLight
    anchors.fill: parent
    visible: false
    layer.enabled: true
    Rectangle {
      anchors.fill: parent
      radius: root.radius
      gradient: Gradient {
        // Faint on smoked glass, where a bright rim reads as a hard line.
        GradientStop { position: 0; color: Theme.alpha("#ffffff", Theme.dark ? 0.32 : 0.8) }
        GradientStop { position: 0.3; color: Theme.alpha("#ffffff", Theme.dark ? 0.08 : 0.22) }
        GradientStop { position: 0.75; color: Theme.alpha("#ffffff", Theme.dark ? 0.04 : 0.1) }
        GradientStop { position: 1; color: Theme.alpha("#ffffff", Theme.dark ? 0.14 : 0.45) }
      }
    }
  }
  Item {
    id: rimShape
    anchors.fill: parent
    visible: false
    layer.enabled: true
    Rectangle {
      anchors.fill: parent
      radius: root.radius
      color: "transparent"
      border.width: 1
      border.color: "#ffffff"
    }
  }
  MultiEffect {
    anchors.fill: parent
    source: rimLight
    maskEnabled: true
    maskSource: rimShape
  }
}
