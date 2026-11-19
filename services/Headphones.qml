pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire

// Everything headphones, for the launcher's Headphones panel: paired
// Bluetooth headphones (connect, battery, music or call mode), wired jacks
// (bin/headphones turns a card on when headphones go into one), and which
// output is playing.
Singleton {
  id: root

  // Polls while the panel is showing.
  property bool watching: false

  readonly property string helper: Quickshell.shellDir + "/bin/headphones"

  // From bin/headphones: { jacks: [...], bluetooth: [...] }.
  property var status: ({ jacks: [], bluetooth: [] })
  property string error: ""
  readonly property bool busy: actionProcess.running

  // Paired Bluetooth devices that are headphones or headsets.
  readonly property var bluetoothDevices: Bluetooth.devices.values
    .filter(d => (d.paired || d.connected) && /^audio-(headphones|headset)/.test(d.icon || ""))
    .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))

  // Jacks with headphones in them (or that cannot tell).
  readonly property var jacks: status.jacks.filter(j => j.plugged)

  function bluetoothCard(device) {
    if (!device) return null
    var address = device.address.toUpperCase()
    return status.bluetooth.find(c => c.address === address) ?? null
  }

  // The output node a Bluetooth device plays through, if connected.
  function bluetoothSink(device) {
    if (!device) return null
    var tag = device.address.toUpperCase().replace(/:/g, "_")
    return Audio.sinks.find(n => (n.name || "").indexOf("bluez_output." + tag) === 0) ?? null
  }

  function isDefault(node) {
    return node !== null && Audio.sink !== null && node.id === Audio.sink.id
  }

  // What kind of output a sink is, for its icon: "bluetooth", "usb", "hdmi",
  // "headphones" (a jack) or "speakers".
  function kind(node) {
    if (!node) return "speakers"
    var p = node.properties || {}
    var name = node.name || ""
    if (p["device.api"] === "bluez5" || name.indexOf("bluez_output.") === 0) return "bluetooth"
    if (/hdmi|iec958/i.test(name) || /HDMI|DisplayPort/i.test(node.description || "")) return "hdmi"
    if (status.jacks.some(j => j.active && j.sink === name)) return "headphones"
    if (p["device.bus"] === "usb" || name.indexOf("alsa_output.usb-") === 0) return "usb"
    return "speakers"
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function run(args) {
    if (actionProcess.running) return
    error = ""
    actionProcess.command = [helper].concat(args)
    actionProcess.running = true
  }

  function useJack(jack) {
    run(["use-jack", jack.card, jack.port])
  }

  function setCallMode(card, on) {
    run(["bt-mode", card.card, on ? "call" : "music"])
  }

  function lastLine(text) {
    var lines = String(text || "").trim().split("\n")
    return lines[lines.length - 1]
  }

  onWatchingChanged: if (watching) refresh()

  Timer {
    interval: 3000
    running: root.watching
    repeat: true
    onTriggered: root.refresh()
  }

  // A device or profile change shows up as nodes coming and going.
  Connections {
    target: Pipewire.nodes
    function onValuesChanged() { if (root.watching) changed.restart() }
  }

  Timer {
    id: changed
    interval: 300
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    command: [root.helper, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          if (parsed && parsed.jacks && parsed.bluetooth) root.status = parsed
        } catch (e) {}
      }
    }
  }

  Process {
    id: actionProcess
    stderr: StdioCollector { id: actionError }
    onExited: function(code) {
      if (code !== 0) root.error = root.lastLine(actionError.text) || "That did not work"
      root.refresh()
    }
  }
}
