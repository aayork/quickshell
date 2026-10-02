import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui

// Fresh captures wait here, stacked in the bottom-left corner, newest at the
// bottom. Click one to edit it; the buttons on hover copy, save, pin or
// dismiss it. Nothing leaves until you say so.
PanelWindow {
  id: root

  readonly property int cardWidth: 240
  readonly property int cardHeight: 150

  screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
  visible: Captures.stack.length > 0
  anchors { bottom: true; left: true }
  margins { bottom: 12; left: 12 }
  implicitWidth: cardWidth
  implicitHeight: Math.max(1, column.implicitHeight)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "aayork-captures"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  component Action: Rectangle {
    id: action
    property int glyph: 0
    property string hint: ""
    signal clicked()

    width: 30
    height: 30
    radius: 15
    color: actionMouse.containsMouse ? Theme.accent : Theme.alpha(Theme.background, 0.85)
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.25)

    Label {
      anchors.centerIn: parent
      text: Icons.glyph(action.glyph)
      color: actionMouse.containsMouse ? Theme.background : Theme.foreground
      font.pixelSize: Theme.iconSize
      elide: Text.ElideNone
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: action.clicked()
    }
  }

  ColumnLayout {
    id: column
    width: parent.width
    spacing: 8

    Repeater {
      // Oldest at the top, so the newest lands nearest the corner.
      model: Captures.stack.slice().reverse()

      Rectangle {
        id: card
        required property string modelData

        Layout.fillWidth: true
        implicitHeight: root.cardHeight
        color: Theme.background
        border.width: Theme.borderWidth
        border.color: hover.hovered ? Theme.accent : Theme.alpha(Theme.foreground, 0.3)
        radius: Theme.controlRadius + 4

        HoverHandler { id: hover }

        Image {
          anchors.fill: parent
          anchors.margins: Theme.borderWidth + 4
          source: "file://" + card.modelData
          fillMode: Image.PreserveAspectFit
          sourceSize.width: root.cardWidth * 2
          sourceSize.height: root.cardHeight * 2
          asynchronous: true
          cache: false
        }

        MouseArea {
          anchors.fill: parent
          onClicked: Captures.edit(card.modelData)
        }

        // Dim the picture a little so the buttons read.
        Rectangle {
          anchors.fill: parent
          anchors.margins: Theme.borderWidth
          visible: hover.hovered
          color: Theme.alpha(Theme.background, 0.45)

          Label {
            anchors.centerIn: parent
            text: "Click to edit"
            color: Theme.brightForeground
            font.pixelSize: Theme.fontSmall
          }
        }

        Action {
          visible: hover.hovered
          anchors { top: parent.top; left: parent.left; margins: 8 }
          glyph: 0xF018F
          onClicked: {
            Captures.copy(card.modelData)
            Captures.dismiss(card.modelData)
          }
        }
        Action {
          visible: hover.hovered
          anchors { top: parent.top; right: parent.right; margins: 8 }
          glyph: 0xF0156
          onClicked: Captures.dismiss(card.modelData)
        }
        Action {
          visible: hover.hovered
          anchors { bottom: parent.bottom; left: parent.left; margins: 8 }
          glyph: 0xF0403
          onClicked: Captures.pin(card.modelData)
        }
        Action {
          visible: hover.hovered
          anchors { bottom: parent.bottom; right: parent.right; margins: 8 }
          glyph: 0xF0193
          onClicked: {
            Captures.save(card.modelData)
            Captures.dismiss(card.modelData)
          }
        }
      }
    }
  }
}
