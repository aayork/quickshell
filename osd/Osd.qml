import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui

// A brief readout when the volume changes from somewhere other than the
// control center: media keys, the bar's scroll wheel, another app.
PanelWindow {
  id: root

  readonly property real level: Audio.volume(Audio.sink)
  readonly property bool muted: Audio.muted(Audio.sink)
  property bool showing: false
  // Volume settles a moment after startup; nothing to announce until then.
  property bool ready: false

  function announce() {
    if (!ready || PopupState.active !== null) return
    showing = true
    hide.restart()
  }

  onLevelChanged: announce()
  onMutedChanged: announce()

  Timer {
    interval: 1500
    running: true
    onTriggered: root.ready = true
  }

  Timer {
    id: hide
    interval: 1400
    onTriggered: root.showing = false
  }

  screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
  visible: (showing || card.opacity > 0) && !Session.screensaver
  anchors.bottom: true
  margins.bottom: 80
  implicitWidth: 260
  implicitHeight: 44
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  mask: Region {}
  WlrLayershell.namespace: "aayork-osd"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  Glass {
    id: card
    anchors.fill: parent
    opacity: root.showing ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 10

      Label {
        text: Icons.volume(root.level, root.muted)
        font.pixelSize: Theme.iconLarge
        color: root.muted ? Theme.dim : Theme.foreground
        elide: Text.ElideNone
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 4
        radius: Theme.controlRadius
        color: Theme.track

        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, root.level))
          height: parent.height
          radius: parent.radius
          color: root.muted ? Theme.dim : Theme.accent
        }
      }

      Label {
        text: Math.round(root.level * 100) + "%"
        color: root.muted ? Theme.dim : Theme.foreground
        font.pixelSize: Theme.fontSmall
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 34
        elide: Text.ElideNone
      }
    }
  }
}
