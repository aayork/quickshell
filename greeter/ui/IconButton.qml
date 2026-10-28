import QtQuick
import qs.theme

// A round glass button holding one glyph. `gel` fills it with a glossy
// colour instead, like the red shut down button on Windows 7.
Item {
  id: root

  property string icon: ""
  property int size: Theme.iconSize
  property color foreground: Theme.foreground
  property color gel: "transparent"

  signal clicked()

  implicitWidth: Theme.rowHeight
  implicitHeight: Theme.rowHeight
  opacity: enabled ? 1 : 0.4

  Glass {
    anchors.fill: parent
    radius: width / 2
    visible: root.gel.a === 0
    opacity: mouse.containsMouse ? 1 : 0.8
    border.color: mouse.containsMouse ? Theme.alpha(Theme.accent, 0.7) : Theme.glassBorder
  }

  Gel {
    anchors.fill: parent
    visible: root.gel.a > 0
    base: root.gel
    opacity: mouse.containsMouse ? 1 : 0.88
  }

  Label {
    anchors.centerIn: parent
    text: root.icon
    color: root.gel.a > 0 ? "#ffffff" : root.foreground
    font.pixelSize: root.size
    style: Text.Raised
    styleColor: root.gel.a > 0 ? Theme.alpha("#000000", 0.3) : Theme.alpha("#ffffff", 0.6)
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
