import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.theme
import qs.ui

Row {
  id: root

  property color foreground: Theme.foreground

  height: Theme.barHeight

  Repeater {
    model: SystemTray.items

    Item {
      id: slot
      required property var modelData

      readonly property bool menuOpen: menu.open && menu.target === slot

      width: 24
      height: root.height

      Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        radius: Theme.controlRadius
        color: Theme.alpha(root.foreground, slot.menuOpen ? 0.16 : mouse.containsMouse ? 0.08 : 0)
      }

      IconImage {
        anchors.centerIn: parent
        implicitSize: 16
        source: slot.modelData.icon
      }

      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function(event) {
          var item = slot.modelData
          if (event.button === Qt.MiddleButton) {
            item.secondaryActivate()
          } else if (item.hasMenu && (event.button === Qt.RightButton || item.onlyMenu)) {
            if (slot.menuOpen) menu.close()
            else menu.show(slot, item.menu)
          } else {
            item.activate()
          }
        }
        onWheel: function(event) { slot.modelData.scroll(event.angleDelta.y, false) }
      }
    }
  }

  TrayMenu { id: menu }
}
