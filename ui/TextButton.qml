import QtQuick
import qs.theme

// A labelled button inside a popup, optionally led by a glyph. `selected`
// marks the current choice in a group.
Rectangle {
  id: root

  property string text: ""
  property string icon: ""
  property bool selected: false
  // Unselected, the glyph is accent-coloured unless dimmed.
  property bool dimIcon: false
  signal clicked()

  readonly property color ink: selected ? "#ffffff" : Theme.foreground

  implicitWidth: content.implicitWidth + 20
  implicitHeight: Theme.rowHeight
  radius: Theme.controlRadius
  opacity: enabled ? 1 : 0.4
  // Unselected: a glassy white button that warms to pale blue on hover.
  border.width: 1
  border.color: mouse.containsMouse ? Theme.glassBorder : Theme.alpha(Theme.foreground, 0.22)
  gradient: Gradient {
    GradientStop { position: 0; color: mouse.pressed ? Qt.tint(Theme.background, Theme.alpha(Theme.accent, 0.25)) : "#ffffff" }
    GradientStop { position: 0.5; color: Qt.tint(Theme.background, Theme.alpha(Theme.accent, mouse.containsMouse ? 0.12 : 0.03)) }
    GradientStop { position: 1; color: Qt.tint(Theme.background, Theme.alpha(Theme.accent, mouse.containsMouse ? 0.22 : 0.1)) }
  }

  Gel {
    anchors.fill: parent
    radius: root.radius
    visible: root.selected
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 6

    Label {
      visible: root.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.selected ? root.ink : root.dimIcon ? Theme.dim : Theme.accent
      style: root.selected ? Text.Raised : Text.Normal
      styleColor: Theme.alpha("#000000", 0.25)
      font.pixelSize: Theme.iconSize
      elide: Text.ElideNone
    }
    Label {
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: root.ink
      elide: Text.ElideNone
      style: root.selected ? Text.Raised : Text.Normal
      styleColor: Theme.alpha("#000000", 0.25)
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.clicked()
  }
}
