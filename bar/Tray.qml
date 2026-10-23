import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.theme
import qs.ui

// The system tray, folded behind one button: the apps that put an icon there
// (Steam, Discord, Spotify…) are listed in a dropdown. Click one to bring
// up its menu, which takes the place of the list; right-click activates it.
BarButton {
  id: root

  readonly property alias popup: popup
  // The tray item whose menu is showing; null while the list is.
  property var shown: null

  function name(item) {
    return item.tooltipTitle || item.title || item.id
  }

  visible: SystemTray.items.values.length > 0
  text: Icons.chevronDown
  active: popup.open
  onClicked: popup.toggle()

  // An app that quits takes its menu with it.
  Connections {
    target: SystemTray.items
    function onValuesChanged() {
      if (root.shown && SystemTray.items.values.indexOf(root.shown) < 0) root.shown = null
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 240
    contentHeight: root.shown ? menu.implicitHeight : list.implicitHeight

    onOpenChanged: if (open) root.shown = null

    ColumnLayout {
      id: list
      visible: !root.shown
      width: parent.width
      spacing: 0

      Repeater {
        model: SystemTray.items

        Rectangle {
          id: slot
          required property var modelData

          Layout.fillWidth: true
          implicitHeight: Theme.rowHeight
          radius: Theme.controlRadius
          color: mouse.containsMouse ? Theme.hover : "transparent"

          IconImage {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 16
            source: slot.modelData.icon
          }

          Label {
            anchors.left: icon.right
            anchors.leftMargin: Theme.spacing
            anchors.right: more.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.name(slot.modelData)
          }

          Label {
            id: more
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: slot.modelData.hasMenu ? Icons.chevronRight : ""
            color: Theme.dim
            elide: Text.ElideNone
          }

          MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: function(event) {
              var item = slot.modelData
              // Left click opens the menu: many apps (Steam, Discord, Electron)
              // ignore activate, so a click that only activated did nothing.
              if (event.button === Qt.MiddleButton) {
                item.secondaryActivate()
                popup.close()
              } else if (item.hasMenu && event.button === Qt.LeftButton) {
                root.shown = item
              } else {
                item.activate()
                popup.close()
              }
            }
            onWheel: function(event) { slot.modelData.scroll(event.angleDelta.y, false) }
          }
        }
      }
    }

    TrayMenu {
      id: menu
      visible: root.shown !== null
      width: parent.width
      handle: root.shown ? root.shown.menu : null
      title: root.shown ? root.name(root.shown) : ""
      onExited: root.shown = null
      onDone: popup.close()
    }
  }
}
