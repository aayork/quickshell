import QtQuick
import Quickshell.Hyprland
import qs.theme

// Every workspace is its number on a small square tile (no border, a
// barely-there rounding). Empty ones are a faint tile with a dim number, ones holding
// windows a stronger tile with a solid strip along the bottom, and the
// focused one the strongest. While a special workspace is open, the
// workspace underneath fades back.
// Clicking any number closes it.
Row {
  id: root

  property color foreground: Theme.foreground

  readonly property int box: 16
  readonly property int gap: 4

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

  // Name of the special workspace open on the focused monitor, "" if none.
  // Quickshell has no property for it, so follow Hyprland's activespecial
  // event ("special:name,MONITOR" or ",MONITOR") and seed it from hyprctl.
  property string activeSpecial: ""

  function seedSpecial() {
    var monitor = Hyprland.focusedMonitor
    var ipc = monitor ? monitor.lastIpcObject : null
    activeSpecial = ipc && ipc.specialWorkspace ? (ipc.specialWorkspace.name ?? "") : ""
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "activespecial") {
        var data = event.data
        var comma = data.lastIndexOf(",")
        var monitor = Hyprland.focusedMonitor
        if (monitor && data.slice(comma + 1) !== monitor.name) return
        root.activeSpecial = data.slice(0, comma)
      } else if (event.name === "focusedmon") {
        Hyprland.refreshMonitors()
      }
    }
  }
  Connections {
    target: Hyprland.focusedMonitor
    function onLastIpcObjectChanged() { root.seedSpecial() }
  }
  Component.onCompleted: Hyprland.refreshMonitors()

  height: Theme.barHeight
  spacing: root.gap

  Repeater {
    model: root.ids

    Item {
      id: slot
      required property int modelData

      readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === modelData) ?? null
      readonly property int windows: workspace ? workspace.toplevels.values.length : 0
      readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
      readonly property bool urgent: workspace !== null && workspace.urgent === true && !focused
      readonly property bool under: focused && root.activeSpecial !== ""
      readonly property bool hovered: area.containsMouse

      width: root.box
      height: root.height

      Rectangle {
        id: frame
        anchors.centerIn: parent
        width: root.box
        height: root.box
        radius: 2
        color: Qt.alpha(root.foreground,
          slot.focused && !slot.under ? 0.35
          : (slot.windows > 0 ? 0.18 : 0.05) + (slot.hovered ? 0.08 : 0))

        // The urgent pulse multiplies in, so it does not fight the Behavior.
        property real baseOpacity: slot.under ? 0.45 : 1
        property real pulse: 1
        opacity: baseOpacity * pulse

        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on baseOpacity { NumberAnimation { duration: 160 } }

        // A solid strip along the bottom marks a workspace with windows.
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          // Inset so the strip stays inside the rounded corners.
          anchors.leftMargin: parent.radius
          anchors.rightMargin: parent.radius
          height: 1.25
          color: root.foreground
          opacity: slot.windows > 0 ? 0.9 : 0
          Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        Text {
          anchors.centerIn: parent
          text: slot.modelData
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSmall
          font.weight: slot.focused ? Font.Medium : Font.Normal
          color: root.foreground
          opacity: slot.focused || slot.windows > 0 ? 1 : 0.35
          Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        SequentialAnimation {
          running: slot.urgent
          loops: Animation.Infinite
          NumberAnimation { target: frame; property: "pulse"; to: 0.3; duration: 500; easing.type: Easing.InOutSine }
          NumberAnimation { target: frame; property: "pulse"; to: 1; duration: 500; easing.type: Easing.InOutSine }
          onRunningChanged: if (!running) frame.pulse = 1
        }
      }

      MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        // Hyprland runs a Lua config here, so dispatchers are Lua calls.
        // A special workspace stays drawn over whatever workspace is focused,
        // so close it first: clicking any number is how you get out of it.
        onClicked: {
          if (root.activeSpecial !== "") {
            var name = root.activeSpecial.replace(/^special:/, "")
            Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"" + name + "\")")
            root.activeSpecial = ""
            if (slot.focused) return
          }
          Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + slot.modelData + "\" })")
        }
      }
    }
  }
}
