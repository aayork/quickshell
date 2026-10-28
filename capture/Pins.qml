import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui

// Captures pinned to the screen: they float above every window until closed.
// Drag to move, scroll to resize.
Scope {
  Variants {
    model: Captures.pins

    PanelWindow {
      visible: !Session.screensaver
      id: pin
      required property var modelData

      // Where it sits, from the top-left of the screen.
      property real pinX: 60 + (Captures.pins.indexOf(modelData) % 6) * 28
      property real pinY: 60 + (Captures.pins.indexOf(modelData) % 6) * 28
      property real zoom: 1
      readonly property real fit: Math.min(1, 520 / Math.max(1, picture.implicitWidth), 420 / Math.max(1, picture.implicitHeight))

      screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
      anchors { top: true; left: true }
      margins { top: Math.round(pinY); left: Math.round(pinX) }
      implicitWidth: Math.max(80, Math.round(picture.implicitWidth * fit * zoom)) + 4
      implicitHeight: Math.max(60, Math.round(picture.implicitHeight * fit * zoom)) + 4
      color: Theme.background
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "aayork-pin"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: hover.hovered ? Theme.accent : Theme.alpha(Theme.foreground, 0.3)
        z: 2
      }

      Image {
        id: picture
        anchors.fill: parent
        anchors.margins: 2
        source: "file://" + pin.modelData.path
        fillMode: Image.PreserveAspectFit
        asynchronous: false
        cache: false
        mipmap: true
      }

      HoverHandler { id: hover }

      MouseArea {
        anchors.fill: parent
        property real startX: 0
        property real startY: 0
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        // The window moves under the pointer as it is dragged, so the
        // pointer's own position in it is what has to stay put.
        onPressed: function(event) { startX = event.x; startY = event.y }
        onPositionChanged: function(event) {
          if (!pressed) return
          pin.pinX = Math.max(0, pin.pinX + event.x - startX)
          pin.pinY = Math.max(0, pin.pinY + event.y - startY)
        }
        onWheel: function(event) { pin.zoom = Math.max(0.3, Math.min(3, pin.zoom * (event.angleDelta.y > 0 ? 1.1 : 0.9))) }
      }

      Row {
        visible: hover.hovered
        anchors { top: parent.top; right: parent.right; margins: 8 }
        spacing: 6
        z: 3

        Repeater {
          model: [
            { glyph: 0xF018F, run: () => Captures.copy(pin.modelData.path) },
            { glyph: 0xF0193, run: () => Captures.save(pin.modelData.path) },
            { glyph: 0xF03EB, run: () => { Captures.edit(pin.modelData.path); Captures.unpin(pin.modelData.id) } },
            { glyph: 0xF0156, run: () => Captures.unpin(pin.modelData.id) }
          ]

          Rectangle {
            required property var modelData
            width: 26
            height: 26
            radius: 13
            color: buttonMouse.containsMouse ? Theme.accent : Theme.alpha(Theme.background, 0.85)
            border.width: 1
            border.color: Theme.alpha(Theme.foreground, 0.25)

            Label {
              anchors.centerIn: parent
              text: Icons.glyph(parent.modelData.glyph)
              color: buttonMouse.containsMouse ? Theme.background : Theme.foreground
              font.pixelSize: Theme.fontSize
              elide: Text.ElideNone
            }
            MouseArea {
              id: buttonMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: parent.modelData.run()
            }
          }
        }
      }
    }
  }
}
