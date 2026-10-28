import QtQuick
import Quickshell.Hyprland
import qs.theme
import qs.ui

// Every workspace is a glass bead, Frutiger Aero style: an empty one is a
// clear bubble, one with windows a pearl, and the focused one stretches into
// a glossy blue gel pill, a little longer for each extra window on it.
Row {
  id: root

  property color foreground: Theme.foreground

  readonly property int dot: 9
  readonly property int pill: 26
  readonly property int gap: 8
  readonly property int maxExtraWindows: 3

  // 1-4 always show. Anything past that shows only while Hyprland has it, and
  // Hyprland drops an empty workspace the moment it is left.
  readonly property var ids: {
    var list = [1, 2, 3, 4]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && list.indexOf(id) === -1) list.push(id)
    }
    return list.sort(function(a, b) { return a - b })
  }

  height: Theme.barHeight

  Repeater {
    model: root.ids

    Item {
      id: slot
      required property int modelData

      readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === modelData) ?? null
      readonly property int windows: workspace ? workspace.toplevels.values.length : 0
      readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
      readonly property bool urgent: workspace !== null && workspace.urgent === true && !focused
      readonly property bool filled: focused || windows > 0
      readonly property real length: focused
        ? root.pill + Math.min(Math.max(windows - 1, 0), root.maxExtraWindows) * root.dot
        : root.dot

      width: length + root.gap
      height: root.height
      Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      Item {
        id: indicator
        anchors.centerIn: parent
        width: slot.length
        height: root.dot

        // The urgent pulse multiplies in, so it does not fight the Behavior.
        property real baseOpacity: slot.focused || slot.urgent ? 1 : hover.hovered ? 1 : 0.85
        property real pulse: 1
        opacity: baseOpacity * pulse
        scale: hover.hovered && !slot.focused ? 1.15 : 1

        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on baseOpacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // A soft glow round the focused pill.
        Rectangle {
          anchors.fill: parent
          anchors.margins: -2
          radius: height / 2
          color: Theme.alpha(slot.urgent ? Theme.orange : Theme.accent, 0.28)
          opacity: slot.focused || slot.urgent ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        Gel {
          anchors.fill: parent
          base: slot.urgent ? Theme.orange : Theme.accent
          opacity: slot.focused || slot.urgent ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        // A pearl: a workspace with windows on it.
        Rectangle {
          anchors.fill: parent
          radius: height / 2
          opacity: slot.filled && !slot.focused && !slot.urgent ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 160 } }
          border.width: 1
          border.color: Theme.alpha("#0b2540", 0.35)
          gradient: Gradient {
            GradientStop { position: 0; color: "#ffffff" }
            GradientStop { position: 0.55; color: "#e9f3fb" }
            GradientStop { position: 1; color: "#b9d3e8" }
          }
          Rectangle {
            x: parent.width * 0.22
            y: 1
            width: parent.width * 0.5
            height: parent.height * 0.4
            radius: height / 2
            color: Theme.alpha("#ffffff", 0.95)
          }
        }

        // A bubble: an empty workspace. Clear, with a bright rim and a glint.
        Rectangle {
          anchors.fill: parent
          radius: height / 2
          opacity: slot.filled || slot.urgent ? 0 : 1
          Behavior on opacity { NumberAnimation { duration: 160 } }
          border.width: 1
          border.color: Theme.alpha("#ffffff", 0.9)
          gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.05) }
            GradientStop { position: 1; color: Theme.alpha("#ffffff", 0.35) }
          }
          // A faint dark outline so it still shows over pale sky.
          Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha("#0b2540", 0.18)
          }
          Rectangle {
            x: parent.width * 0.24
            y: parent.height * 0.2
            width: Math.max(1.5, parent.width * 0.2)
            height: width
            radius: width / 2
            color: Theme.alpha("#ffffff", 0.9)
          }
          Rectangle {
            x: parent.width * 0.62
            y: parent.height * 0.62
            width: Math.max(1, parent.width * 0.12)
            height: width
            radius: width / 2
            color: Theme.alpha("#ffffff", 0.55)
          }
        }

        SequentialAnimation {
          running: slot.urgent
          loops: Animation.Infinite
          NumberAnimation { target: indicator; property: "pulse"; to: 0.4; duration: 500; easing.type: Easing.InOutSine }
          NumberAnimation { target: indicator; property: "pulse"; to: 1; duration: 500; easing.type: Easing.InOutSine }
          onRunningChanged: if (!running) indicator.pulse = 1
        }
      }

      HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

      MouseArea {
        anchors.fill: parent
        // Hyprland runs a Lua config here, so dispatchers are Lua calls.
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + slot.modelData + "\" })")
      }
    }
  }
}
