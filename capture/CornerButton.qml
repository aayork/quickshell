import QtQuick
import qs.theme
import qs.ui

// A small round button for a corner of a capture thumbnail, as CleanShot
// draws them: a light grey disc with a dark glyph, white under the pointer.
Rectangle {
  id: root

  property int glyph: 0
  property bool danger: false
  signal clicked()

  width: 22
  height: 22
  radius: 11
  color: mouse.containsMouse ? (danger ? Theme.red : "#ffffff") : Theme.alpha("#f2f2f2", 0.92)
  border.width: 1
  border.color: Theme.alpha("#000000", 0.08)
  Behavior on color { ColorAnimation { duration: 100 } }

  Label {
    anchors.centerIn: parent
    text: Icons.glyph(root.glyph)
    color: mouse.containsMouse && root.danger ? "#ffffff" : "#1c1c1e"
    font.pixelSize: 12
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
