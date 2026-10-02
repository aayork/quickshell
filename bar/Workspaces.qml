import QtQuick
import Quickshell.Hyprland
import qs.theme

// Every workspace is a dot; the focused one stretches into a pill, a little
// longer for each extra window on it.
Row {
  id: root

  property color foreground: Theme.foreground

  readonly property int dot: 7
  readonly property int pill: 22
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

      Rectangle {
        id: indicator
        anchors.centerIn: parent
        width: slot.length
        height: root.dot
        radius: root.dot * 0.35
        color: slot.filled ? root.foreground : "transparent"
        border.width: slot.filled ? 0 : 1
        border.color: root.foreground

        // The urgent pulse multiplies in, so it does not fight the Behavior.
        property real baseOpacity: slot.filled ? 1 : 0.6
        property real pulse: 1
        opacity: baseOpacity * pulse

        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on baseOpacity { NumberAnimation { duration: 160 } }

        SequentialAnimation {
          running: slot.urgent
          loops: Animation.Infinite
          NumberAnimation { target: indicator; property: "pulse"; to: 0.3; duration: 500; easing.type: Easing.InOutSine }
          NumberAnimation { target: indicator; property: "pulse"; to: 1; duration: 500; easing.type: Easing.InOutSine }
          onRunningChanged: if (!running) indicator.pulse = 1
        }
      }

      MouseArea {
        anchors.fill: parent
        // Hyprland runs a Lua config here, so dispatchers are Lua calls.
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + slot.modelData + "\" })")
      }
    }
  }
}
