import QtQuick
import qs.theme

// A labelled button inside a popup. `selected` marks the current choice in a
// group.
Rectangle {
  id: root

  property string text: ""
  property bool selected: false
  signal clicked()

  implicitWidth: label.implicitWidth + 20
  implicitHeight: Theme.rowHeight
  radius: Theme.controlRadius
  opacity: enabled ? 1 : 0.4
  color: selected ? Theme.accent : mouse.pressed ? Theme.pressed : mouse.containsMouse ? Theme.hover : Theme.alpha(Theme.foreground, 0.04)
  border.width: selected ? 0 : 1
  border.color: Theme.alpha(Theme.foreground, 0.2)

  Label {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.selected ? Theme.background : Theme.foreground
    elide: Text.ElideNone
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.clicked()
  }
}
