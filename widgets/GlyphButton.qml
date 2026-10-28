import QtQuick
import qs.theme

// A white glyph on a gadget that brightens under the pointer.
Text {
  id: root

  signal clicked()

  color: area.containsMouse ? "#ffffff" : Theme.alpha("#ffffff", 0.75)
  font.family: Theme.iconFamily
  font.pixelSize: 14

  MouseArea {
    id: area
    anchors.fill: parent
    anchors.margins: -5
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
