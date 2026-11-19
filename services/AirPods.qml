pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// AirPods over Apple's AAP control channel. airpods/bridge.py holds the
// connection while they are connected and prints their state as it changes:
// battery per pod and case, ear detection, listening mode, conversational
// awareness.
Singleton {
  id: root

  readonly property string bridge: Quickshell.shellDir + "/airpods/bridge.py"

  // Paired AirPods: [{ address, name, model, product, adaptive }].
  property var devices: []
  readonly property var info: {
    var paired = Bluetooth.devices.values
    for (var i = 0; i < devices.length; i++)
      if (paired.find(d => d.address.toUpperCase() === devices[i].address && d.connected)) return devices[i]
    return devices.length > 0 ? devices[0] : null
  }
  readonly property var bluetoothDevice: info
    ? (Bluetooth.devices.values.find(d => d.address.toUpperCase() === info.address) ?? null)
    : null
  readonly property bool present: info !== null
  readonly property bool connected: bluetoothDevice !== null && bluetoothDevice.connected
  readonly property string name: info ? info.name : ""
  readonly property string model: info ? info.model : ""

  // Last state from the bridge; null until the channel is open.
  property var state: null
  property string error: ""

  readonly property var battery: state && state.battery ? state.battery : ({})
  // [primary, secondary]: "ear", "out" or "case".
  readonly property var ear: state && state.ear ? state.ear : []
  readonly property int inEar: ear.filter(e => e === "ear").length
  // 1 off, 2 noise cancellation, 3 transparency, 4 adaptive; 0 if not reported.
  readonly property int noise: state && state.noise ? state.noise : 0
  readonly property bool hasNoiseControl: noise > 0
  readonly property var noiseModes: {
    var modes = [{ id: 1, label: "Off" }, { id: 3, label: "Transparency" }]
    if (info && info.adaptive !== false || noise === 4) modes.push({ id: 4, label: "Adaptive" })
    modes.push({ id: 2, label: "Noise Cancellation" })
    return modes
  }
  readonly property bool hasConversationalAwareness: state !== null && state.ca !== undefined
  readonly property bool conversationalAwareness: state !== null && state.ca === true

  function setNoise(id) {
    if (!watchProcess.running || id === noise) return
    watchProcess.write("noise " + id + "\n")
  }

  function setConversationalAwareness(on) {
    if (!watchProcess.running) return
    watchProcess.write("ca " + (on ? 1 : 0) + "\n")
  }

  function scan() {
    scanProcess.running = true
  }

  function lastLine(text) {
    var lines = String(text || "").trim().split("\n")
    return lines[lines.length - 1]
  }

  onConnectedChanged: {
    if (connected) {
      error = ""
      // The channel is not ready the instant audio connects.
      settle.restart()
    } else {
      settle.stop()
      watchProcess.running = false
      state = null
    }
  }

  Timer {
    id: settle
    interval: 2000
    onTriggered: if (root.connected) watchProcess.running = true
  }

  Process {
    id: watchProcess
    command: root.info ? ["/usr/bin/python3", "-I", root.bridge, "watch", root.info.address] : ["true"]
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          root.state = JSON.parse(line)
          root.error = ""
        } catch (e) {}
      }
    }
    stderr: StdioCollector { id: watchError }
    onExited: function(code) {
      root.state = null
      if (code !== 0) root.error = root.lastLine(watchError.text) || "Lost the AirPods control channel"
      // Try again while they stay connected.
      if (root.connected) retry.restart()
    }
  }

  Timer {
    id: retry
    interval: 10000
    onTriggered: if (root.connected && !watchProcess.running) watchProcess.running = true
  }

  // Pairing or removing a device changes what a scan would find.
  Connections {
    target: Bluetooth.devices
    function onValuesChanged() { rescan.restart() }
  }

  Timer {
    id: rescan
    interval: 1000
    onTriggered: root.scan()
  }

  Process {
    id: scanProcess
    command: ["/usr/bin/python3", "-I", root.bridge, "scan"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.devices = JSON.parse(text).devices || []
        } catch (e) {
          root.devices = []
        }
      }
    }
  }

  Component.onCompleted: scan()
}
