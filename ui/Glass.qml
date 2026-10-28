import QtQuick
import QtQuick.Effects
import qs.theme

// A Frutiger Aero glass pane: pale gradient, a white gloss over the top,
// a white inner edge and a soft blue outline. Children draw on top.
Rectangle {
  id: root

  // How strong the gloss band is, 0 to 1.
  property real shine: 1
  // Height of the gloss band, as a share of the pane.
  property real shineHeight: 0.45

  radius: Theme.radius
  border.width: 1
  border.color: Theme.glassBorder
  gradient: Gradient {
    GradientStop { position: 0; color: Theme.glassTop }
    GradientStop { position: 1; color: Theme.glassBottom }
  }


  // Gloss over the top: the pane's own shape, fading to clear partway
  // down, so it follows the corners exactly with no second edge.
  Rectangle {
    id: glossFill
    anchors.fill: parent
    anchors.margins: 1
    radius: Math.max(0, root.radius - 1)
    opacity: root.shine
    readonly property real stop: Math.max(0.01, Math.min(1, (Math.min(root.height * root.shineHeight, 80)) / Math.max(1, root.height)))
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.gloss }
      GradientStop { position: glossFill.stop; color: "transparent" }
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
