import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.ui

// Wi-Fi at a glance, from the bar.
BarButton {
  id: root

  readonly property alias popup: popup

  text: Net.icon
  active: popup.open
  onClicked: popup.toggle()

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 300
    contentHeight: panel.implicitHeight

    WifiPanel {
      id: panel
      width: parent.width
      active: popup.open
    }
  }
}
