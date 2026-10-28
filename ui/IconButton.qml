import QtQuick
import qs.theme

// A glyph button inside a popup: flat until the pointer is on it, then a
// Windows Vista toolbar button lights up behind it.
Item {
  id: root

  property string icon: ""
  property int size: Theme.iconSize
  property color foreground: Theme.foreground

  signal clicked()

  implicitWidth: Theme.rowHeight
  implicitHeight: Theme.rowHeight
  opacity: enabled ? 1 : 0.4

  VistaFace {
    anchors.fill: parent
    visible: mouse.containsMouse
    hovered: true
    pressed: mouse.pressed
  }

  Label {
    anchors.centerIn: parent
    text: root.icon
    color: mouse.containsMouse ? "#1e1e1e" : root.foreground
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
