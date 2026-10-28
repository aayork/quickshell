import QtQuick
import qs.theme
import qs.ui

// The big white buttons in the middle of a hovered thumbnail, CleanShot's
// "Copy" and "Save".
Rectangle {
  id: root

  property alias text: label.text
  signal clicked()

  width: 96
  height: 30
  radius: 15
  color: mouse.pressed ? "#d8d8d8" : mouse.containsMouse ? "#ffffff" : Theme.alpha("#ffffff", 0.9)
  Behavior on color { ColorAnimation { duration: 100 } }

  Label {
    id: label
    anchors.centerIn: parent
    color: "#111111"
    font.pixelSize: Theme.fontSize
    font.bold: true
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
