import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui

// Captures pinned to the screen, CleanShot's floating screenshots: they sit
// above every window until closed, as rounded cards with a soft shadow.
//
//   drag            move it          scroll          resize it
//   Shift + scroll  opacity          arrow keys      nudge it (Shift: 10)
//   lock            clicks go through to the app behind (the badge unlocks)
//
// Hovering shows close in the top-left corner and copy, save, annotate and
// lock along the top right.
Scope {
  Variants {
    model: Captures.pins

    PanelWindow {
      id: pin
      required property var modelData

      visible: !Session.screensaver

      // Where it sits, from the top-left of the screen.
      property real pinX: 60 + (Captures.pins.indexOf(modelData) % 6) * 28
      property real pinY: 60 + (Captures.pins.indexOf(modelData) % 6) * 28
      property real zoom: 1
      property real fade: 1
      property bool locked: false
      readonly property real fit: Math.min(1, 520 / Math.max(1, picture.implicitWidth), 420 / Math.max(1, picture.implicitHeight))
      // Room round the card for its shadow.
      readonly property int pad: 14

      screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
      anchors { top: true; left: true }
      margins { top: Math.round(pinY); left: Math.round(pinX) }
      implicitWidth: card.width + 2 * pad
      implicitHeight: card.height + 2 * pad
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "aayork-pin"
      WlrLayershell.layer: WlrLayer.Top
      // Click it to give it the keys (arrows nudge it).
      WlrLayershell.keyboardFocus: locked ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand

      // Locked, only the badge takes the pointer; the rest is see-through
      // to clicks. Otherwise the card does, but not its shadow margin.
      mask: Region { item: pin.locked ? lockBadge : card }

      Item {
        id: card
        x: pin.pad
        y: pin.pad
        width: Math.max(80, Math.round(picture.implicitWidth * pin.fit * pin.zoom))
        height: Math.max(60, Math.round(picture.implicitHeight * pin.fit * pin.zoom))
        // Shaped like a window: the window rounding from Settings › Windows.
        readonly property int radius: Math.max(0, Number(Config.windows.rounding) || 0)
        opacity: pin.fade
        focus: true

        Keys.onPressed: function(event) {
          var step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1
          if (event.key === Qt.Key_Left) pin.pinX = Math.max(0, pin.pinX - step)
          else if (event.key === Qt.Key_Right) pin.pinX += step
          else if (event.key === Qt.Key_Up) pin.pinY = Math.max(0, pin.pinY - step)
          else if (event.key === Qt.Key_Down) pin.pinY += step
          else if (event.key === Qt.Key_Escape) Captures.unpin(pin.modelData.id)
          else return
          event.accepted = true
        }

        Item {
          anchors.fill: parent
          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: pinShape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
          }

          Rectangle { anchors.fill: parent; color: Theme.darkerBackground }

          Image {
            id: picture
            anchors.fill: parent
            source: "file://" + pin.modelData.path
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            cache: false
            smooth: true
            mipmap: true
          }
        }

        Item {
          id: pinShape
          anchors.fill: parent
          visible: false
          layer.enabled: true
          Rectangle { anchors.fill: parent; radius: card.radius }
        }

        Rectangle {
          anchors.fill: parent
          radius: card.radius
          color: "transparent"
          // The compositor's border colours: accent while it has the pointer
          // or the keys, muted otherwise.
          border.width: Theme.borderWidth
          border.color: hover.hovered || card.activeFocus ? Theme.accent : Theme.muted
        }

        HoverHandler { id: hover }

        MouseArea {
          anchors.fill: parent
          property real startX: 0
          property real startY: 0
          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

          // The window moves under the pointer as it is dragged, so the
          // pointer's own position in it is what has to stay put.
          onPressed: function(event) {
            card.forceActiveFocus()
            startX = event.x
            startY = event.y
          }
          onPositionChanged: function(event) {
            if (!pressed) return
            pin.pinX = Math.max(0, pin.pinX + event.x - startX)
            pin.pinY = Math.max(0, pin.pinY + event.y - startY)
          }
          onWheel: function(event) {
            var up = event.angleDelta.y > 0
            if (event.modifiers & Qt.ShiftModifier) pin.fade = Math.max(0.2, Math.min(1, pin.fade + (up ? 0.1 : -0.1)))
            else pin.zoom = Math.max(0.3, Math.min(3, pin.zoom * (up ? 1.1 : 0.9)))
          }
        }

        // Hover controls: a strip along the top, like a title bar.
        Rectangle {
          anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.borderWidth }
          height: Theme.rowHeight + 4
          visible: hover.hovered && !pin.locked
          color: Theme.alpha(Theme.background, 0.92)

          IconButton {
            anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
            icon: Icons.close
            onClicked: Captures.unpin(pin.modelData.id)
          }

          // Opacity, while it is not full.
          Label {
            visible: pin.fade < 0.99
            anchors.centerIn: parent
            text: Math.round(pin.fade * 100) + "%"
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideNone
          }

          Row {
            anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
            IconButton { icon: Icons.glyph(0xF018F); onClicked: Captures.copy(pin.modelData.path) }
            IconButton { icon: Icons.glyph(0xF0193); onClicked: Captures.save(pin.modelData.path) }
            IconButton { icon: Icons.glyph(0xF03EB); onClicked: { Captures.edit(pin.modelData.path); Captures.unpin(pin.modelData.id) } }
            IconButton { icon: Icons.glyph(0xF0341); onClicked: pin.locked = true }
          }
        }
      }

      // Locked: the one thing that still takes a click, to unlock.
      Rectangle {
        id: lockBadge
        visible: pin.locked
        x: card.x + card.width - width - 8
        y: card.y + 8
        width: 24
        height: 24
        radius: Theme.controlRadius
        color: Theme.background
        border.width: 1
        border.color: Theme.muted
        Label {
          anchors.centerIn: parent
          text: Icons.glyph(0xF0341)
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: pin.locked = false
        }
      }
    }
  }
}
