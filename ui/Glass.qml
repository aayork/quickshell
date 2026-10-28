import QtQuick
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

  Rectangle {
    anchors.fill: parent
    anchors.margins: 1
    radius: Math.max(0, root.radius - 1)
    color: "transparent"
    border.width: 1
    border.color: Theme.glassEdge
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 2
    height: Math.min(parent.height * root.shineHeight, 80)
    radius: Math.max(0, root.radius - 2)
    opacity: root.shine
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.gloss }
      GradientStop { position: 1; color: "transparent" }
    }
  }
}
