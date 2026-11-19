import QtQuick
import qs.theme
import qs.ui

// A small square button showing where a to-do can go, in that list's
// colour. The trash one turns red and waits for a second click.
Rectangle {
  id: mover
  property int glyph: 0
  property color tint: Theme.foreground
  property bool armedLook: false
  signal clicked()

  implicitWidth: 26
  implicitHeight: 24
  radius: Theme.controlRadius
  color: armedLook ? Theme.alpha(Theme.red, 0.15) : moveMouse.containsMouse ? Theme.hover : "transparent"

  Label {
    anchors.centerIn: parent
    text: Icons.glyph(mover.glyph)
    color: mover.tint
    font.pixelSize: Theme.iconSize
    elide: Text.ElideNone
  }

  MouseArea {
    id: moveMouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: mover.clicked()
  }
}
