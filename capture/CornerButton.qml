import QtQuick
import qs.theme
import qs.ui

// A small round button for a corner of a capture thumbnail: dark glass with
// a white glyph, solid white under the pointer.
Rectangle {
  id: root

  property int glyph: 0
  property bool danger: false
  signal clicked()

  width: 26
  height: 26
  radius: 13
  color: mouse.containsMouse ? (danger ? Theme.red : "#ffffff") : Theme.alpha("#000000", 0.55)
  border.width: 1
  border.color: Theme.alpha("#ffffff", 0.25)
  Behavior on color { ColorAnimation { duration: 100 } }

  Label {
    anchors.centerIn: parent
    text: Icons.glyph(root.glyph)
    color: mouse.containsMouse && !root.danger ? "#111111" : "#ffffff"
    font.pixelSize: 13
    elide: Text.ElideNone
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
