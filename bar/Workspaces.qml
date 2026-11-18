import QtQuick
import Quickshell.Hyprland
import qs.theme

// Every workspace is a dot; the focused one stretches into a pill, a little
// longer for each extra window on it. The scratchpad (special workspace) gets a
// diamond after the dots while it holds windows; while it is open the diamond
// becomes an accent pill with a halo and the workspace underneath fades back
// to an outline. Clicking any workspace dot closes it.
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

  // Name of the special workspace open on the focused monitor, "" if none.
  // Quickshell has no property for it, so follow Hyprland's activespecial
  // event ("special:name,MONITOR" or ",MONITOR") and seed it from hyprctl.
  property string activeSpecial: ""
  readonly property bool scratchpadOpen: activeSpecial === "special:scratchpad"
  readonly property var scratchpad: Hyprland.workspaces.values.find(w => w.name === "special:scratchpad") ?? null
  readonly property int scratchpadWindows: scratchpad ? scratchpad.toplevels.values.length : 0

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
        readonly property bool under: slot.focused && root.scratchpadOpen
        color: slot.filled && !under ? root.foreground : "transparent"
        border.width: slot.filled && !under ? 0 : 1
        border.color: root.foreground

        // The urgent pulse multiplies in, so it does not fight the Behavior.
        property real baseOpacity: under ? 0.35 : slot.filled ? 1 : 0.6
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
        // A special workspace stays drawn over whatever workspace is focused,
        // so close it first: clicking any dot is how you get out of it.
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

  // The scratchpad: a diamond while it holds windows, the pill while open.
  Item {
    id: scratch
    readonly property bool shown: root.scratchpadOpen || root.scratchpadWindows > 0
    readonly property real length: root.scratchpadOpen ? root.pill : root.dot

    visible: width > 0
    width: shown ? length + root.gap + 8 : 0
    height: root.height
    clip: true
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // While open: a soft accent halo behind the pill, so it never reads as
    // just another focused workspace.
    Rectangle {
      anchors.centerIn: mark
      width: mark.width + 6
      height: mark.height + 6
      radius: height / 2
      color: Theme.accent
      opacity: root.scratchpadOpen ? 0.3 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    Rectangle {
      id: mark
      anchors.verticalCenter: parent.verticalCenter
      x: 6 + (scratch.length - width) / 2
      width: root.scratchpadOpen ? scratch.length : root.dot - 1
      height: root.scratchpadOpen ? root.dot : root.dot - 1
      radius: root.scratchpadOpen ? root.dot * 0.35 : 1
      rotation: root.scratchpadOpen ? 0 : 45
      color: root.scratchpadOpen ? Theme.accent : root.foreground
      Behavior on color { ColorAnimation { duration: 160 } }
      opacity: scratch.shown ? 1 : 0

      Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"scratchpad\")")
    }
  }
}
