import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.ui

// Razer mouse: battery, DPI stages, polling rate, acceleration and speed.
// Only on the bar while the mouse is on, like the Bose widget.
BarButton {
  id: root

  readonly property alias popup: popup

  visible: Mouse.connected
  onVisibleChanged: if (!visible) popup.close()
  minimumWidth: 34
  active: popup.open
  onClicked: popup.toggle()

  RazerLogo {
    anchors.centerIn: parent
    size: 16
    color: root.foreground
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 340
    contentHeight: settings.implicitHeight

    onOpenChanged: Mouse.watching = open

    MouseSettings {
      id: settings
      width: parent.width
    }
  }
}
