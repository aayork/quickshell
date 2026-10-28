import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui

// Fresh captures wait here, stacked in the bottom-left corner, newest at the
// bottom, like CleanShot X's Quick Access Overlay (capture/CaptureCard.qml).
// Nothing leaves until you say so.
PanelWindow {
  id: root

  readonly property int cardWidth: 200
  // Room round the cards for their shadows.
  readonly property int pad: 18

  screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
  visible: Captures.stack.length > 0 && !Session.screensaver
  anchors { bottom: true; left: true }
  margins { bottom: 4; left: 4 }
  implicitWidth: cardWidth + 2 * pad
  implicitHeight: Math.max(1, column.implicitHeight + 2 * pad)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "aayork-captures"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  // Only the cards take the pointer; the shadow margin passes clicks through.
  mask: Region { item: column }

  Column {
    id: column
    x: root.pad
    y: root.pad
    width: root.cardWidth
    spacing: 12

    Repeater {
      // Oldest at the top, so the newest lands nearest the corner.
      model: Captures.stack.slice().reverse()

      CaptureCard {
        required property string modelData
        path: modelData
        cardWidth: root.cardWidth
      }
    }
  }
}
