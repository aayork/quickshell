import QtQuick
import qs.theme

// A glyph button inside a popup.
Item {
  id: root

  property string icon: ""
  property int size: Theme.iconSize
  property color foreground: Theme.foreground

  signal clicked()

  implicitWidth: Theme.rowHeight
  implicitHeight: Theme.rowHeight
  opacity: enabled ? 1 : 0.4

  Rectangle {
    anchors.fill: parent
    radius: Theme.controlRadius
    color: mouse.pressed ? Theme.alpha(Theme.accent, 0.25) : mouse.containsMouse ? Theme.alpha(Theme.accent, 0.12) : "transparent"
    border.width: mouse.containsMouse ? 1 : 0
    border.color: Theme.alpha(Theme.accent, 0.35)
  }

  Label {
    anchors.centerIn: parent
    text: root.icon
    color: root.foreground
    font.pixelSize: root.size
    elide: Text.ElideNone
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.clicked()
  }
}
