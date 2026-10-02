import QtQuick
import qs.theme

Item {
  id: root

  property bool checked: false
  signal toggled()

  implicitWidth: 32
  implicitHeight: 16
  opacity: enabled ? 1 : 0.4

  Rectangle {
    anchors.fill: parent
    radius: Theme.controlRadius
    color: root.checked ? Theme.accent : Theme.track
    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
      y: 2
      x: root.checked ? parent.width - width - 2 : 2
      width: 12
      height: 12
      radius: Math.max(0, Theme.controlRadius - 1)
      color: root.checked ? Theme.background : Theme.foreground
      Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.toggled()
  }
}
