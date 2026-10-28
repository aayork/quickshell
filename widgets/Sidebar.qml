import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

// The Vista Sidebar: a column of gadgets down the right of the desktop, under
// the windows (it shows wherever the desktop does).
PanelWindow {
  id: root

  screen: Quickshell.screens[0]
  anchors { top: true; right: true; bottom: true }
  margins.top: Theme.barHeight + 10
  margins.right: 12
  implicitWidth: 176
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "aayork-sidebar"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  visible: !Session.screensaver

  // Only the gadgets take clicks; the gaps between them reach the desktop.
  mask: Region { item: column }

  ColumnLayout {
    id: column
    width: parent.width
    spacing: 14

    Slideshow { Layout.alignment: Qt.AlignHCenter }
    AnalogClock { Layout.alignment: Qt.AlignHCenter }
    WeatherGadget { Layout.alignment: Qt.AlignHCenter }
    Meters { Layout.alignment: Qt.AlignHCenter }
    NowPlayingGadget { Layout.alignment: Qt.AlignHCenter }
  }
}
