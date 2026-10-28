import QtQuick
import qs.theme
import qs.ui

// The buttons in the middle of a hovered thumbnail, CleanShot's "Copy" and
// "Save": small light grey pills with dark text.
Rectangle {
  id: root

  property alias text: label.text
  signal clicked()

  width: 64
  height: 26
  radius: 13
  color: mouse.pressed ? "#d4d4d4" : mouse.containsMouse ? "#ffffff" : Theme.alpha("#f2f2f2", 0.94)
  border.width: 1
  border.color: Theme.alpha("#000000", 0.08)
  Behavior on color { ColorAnimation { duration: 100 } }

  Label {
    id: label
    anchors.centerIn: parent
    color: "#1c1c1e"
    font.pixelSize: Theme.fontSmall + 1
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
