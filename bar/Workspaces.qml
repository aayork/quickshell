import QtQuick
import Quickshell.Hyprland
import qs.services
import qs.theme

// Every workspace is its number on a small square tile (no border, a
// barely-there rounding). Empty ones are a faint tile with a dim number, ones holding
// windows a stronger tile with a dot per window under it (up to three), and the
// focused one the strongest. While a special workspace is open, the
// workspace underneath fades back.
// Clicking any number closes it.
Row {
  id: root

  property color foreground: Theme.foreground

  readonly property int box: 16
  // Settings › Shell › Bar › Kanji numerals.
  readonly property var kanji: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
  readonly property int gap: 4

  // 1-3 always show. Anything past that shows only while Hyprland has it, and
  // Hyprland drops an empty workspace the moment it is left.
  readonly property var ids: {
    var list = [1, 2, 3]
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

        Text {
          id: label
          anchors.centerIn: parent
          // CJK faces carry a tall ascent/descent, so centring the text box
          // leaves the strokes off. Ideographs are drawn in a square em box
          // whose middle is 0.38em above the baseline in Noto CJK: centre that.
          // (TextMetrics' tight box is wrong for 一, it runs down to the baseline.)
          // 13px glyphs in the 16px tile land on x = 1.5, which Qt rounds
          // down, leaving them half a pixel left of centre.
          anchors.horizontalCenterOffset: Config.bar.kanji ? 0.5 : 0
          anchors.verticalCenterOffset: Config.bar.kanji ? height / 2 - (baselineOffset - 0.38 * font.pixelSize) : 0
          // 一 二 三 are bare strokes, so the kanji are drawn larger than the
          // digits, and in one CJK face so every numeral has the same weight.
          text: Config.bar.kanji ? root.kanji[slot.modelData - 1] : slot.modelData
          font.family: Config.bar.kanji ? "Noto Sans CJK JP" : Theme.fontFamily
          font.pixelSize: Config.bar.kanji ? Theme.fontSmall + 2 : Theme.fontSmall
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

      // One dot per window under the tile, up to three.
      Row {
        anchors.top: frame.bottom
        anchors.topMargin: 1.5
        anchors.horizontalCenter: frame.horizontalCenter
        spacing: 2
        opacity: frame.opacity

        Repeater {
          model: Math.min(slot.windows, 3)
          Rectangle {
            width: 2
            height: 2
            radius: 1
            color: root.foreground
            opacity: 0.9
          }
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
