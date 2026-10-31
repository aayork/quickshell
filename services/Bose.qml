pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Bose headphones over their BMAP control channel. The talking is done by
// bose/bridge.py (from omarchy-bose, on top of bosectl); this keeps its
// answers and queues the changes.
Singleton {
  id: root

  // Refreshes faster while the popup is showing.
  property bool watching: false

  readonly property string bridge: Quickshell.shellDir + "/bose/bridge.py"

  // Paired Bose devices the bridge knows how to talk to.
  property var devices: []
  readonly property var info: {
    if (devices.length === 0) return null
    var paired = Bluetooth.devices.values
    for (var i = 0; i < devices.length; i++) {
      var match = paired.find(d => d.address.toUpperCase() === devices[i].address && d.connected)
      if (match) return devices[i]
    }
    return devices[0]
  }
  readonly property var bluetoothDevice: info
    ? (Bluetooth.devices.values.find(d => d.address.toUpperCase() === info.address) ?? null)
    : null
  readonly property bool present: info !== null
  readonly property bool enabled: Config.features.bose
  readonly property bool connected: enabled && bluetoothDevice !== null && bluetoothDevice.connected
  readonly property string name: info ? info.name : ""

  // Last answer from the headphones; null until one arrives.
  property var state: null
  property string error: ""
  readonly property bool busy: statusProcess.running || actionProcess.running

  readonly property int battery: state && state.battery ? state.battery.level : -1
  readonly property var modes: state && state.mode ? state.mode.options : []
  // A mode just picked shows as current until the headphones confirm it:
  // some apply the switch a moment after acknowledging it.
  property string pendingMode: ""
  readonly property string mode: pendingMode !== "" ? pendingMode : state && state.mode ? state.mode.currentId : ""
  // Name of a custom mode the presets do not cover.
  readonly property string modeLabel: state && state.mode ? state.mode.currentLabel : ""
  readonly property bool hasNoiseControl: state !== null && state.noiseControl.available
  readonly property int noiseLevel: hasNoiseControl ? state.noiseControl.level : 0
  readonly property int noiseMaximum: hasNoiseControl ? state.noiseControl.maximum : 0
  // False where the level is fixed by the current mode.
  readonly property bool noiseEditable: hasNoiseControl && state.noiseControl.editable !== false
  readonly property var bands: state && state.equalizer.available ? state.equalizer.bands : []
  readonly property bool multipoint: state !== null && !!state.multipoint && state.multipoint.available && state.multipoint.enabled

  // Changes wait here while another command is on the wire. Only the newest
  // value per kind is kept, so dragging a slider sends where it ended up.
  property var queued: ({})

  function bridgeCommand(args) {
    return ["/usr/bin/python3", "-I", bridge, "--mac", info.address].concat(args)
  }

  function scan() {
    if (enabled && !scanProcess.running) scanProcess.running = true
  }

  function refresh() {
    if (!connected) {
      state = null
      return
    }
    if (busy) return
    statusProcess.command = bridgeCommand(["status"])
    statusProcess.running = true
  }

  function send(kind, args) {
    if (!connected) return
    var next = Object.assign({}, queued)
    next[kind] = args
    queued = next
    drain()
  }

  function drain() {
    if (busy) return
    var kinds = Object.keys(queued)
    if (kinds.length === 0) return
    var next = Object.assign({}, queued)
    var args = next[kinds[0]]
    delete next[kinds[0]]
    queued = next
    error = ""
    actionProcess.kind = kinds[0]
    actionProcess.command = bridgeCommand(args)
    actionProcess.running = true
  }

  function setMode(id) {
    if (id === mode) return
    pendingMode = id
    pendingExpiry.restart()
    send("mode", ["mode", id])
  }

  function setNoiseLevel(level) {
    send("cnc", ["cnc", String(Math.round(level))])
  }

  // values: { bass, mid, treble }
  function setEqualizer(values) {
    send("eq", ["eq", String(values.bass), String(values.mid), String(values.treble)])
  }

  function lastLine(text) {
    var lines = String(text || "").trim().split("\n")
    return lines[lines.length - 1]
  }

  onConnectedChanged: {
    if (connected) settle.restart()
    else {
      state = null
      pendingMode = ""
    }
  }

  // Gives up on a mode the headphones never reported.
  Timer {
    id: pendingExpiry
    interval: 6000
    onTriggered: {
      root.pendingMode = ""
      root.refresh()
    }
  }

  // Reads the mode back once a switch has had time to land.
  Timer {
    id: modeSettle
    interval: 1200
    onTriggered: root.refresh()
  }
  onWatchingChanged: if (watching) refresh()

  // The control channel is not ready the instant audio connects.
  Timer {
    id: settle
    interval: 2500
    onTriggered: root.refresh()
  }

  Timer {
    interval: root.watching ? 15000 : 120000
    running: root.connected
    repeat: true
    onTriggered: root.refresh()
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

  Process {
    id: statusProcess
    stdout: StdioCollector {
      id: statusOut
    }
    stderr: StdioCollector {
      id: statusError
    }
    onExited: function(code) {
      if (code === 0) {
        try {
          root.state = JSON.parse(statusOut.text)
          root.error = ""
          if (root.pendingMode !== "" && root.state.mode && root.state.mode.currentId === root.pendingMode) {
            root.pendingMode = ""
            pendingExpiry.stop()
          } else if (root.pendingMode !== "") {
            modeSettle.restart()
          }
        } catch (e) {
          root.error = "Unreadable answer from the headphones"
        }
      } else {
        root.error = root.lastLine(statusError.text) || "Could not reach the headphones"
      }
      root.drain()
    }
  }

  Process {
    id: actionProcess
    property string kind: ""
    stderr: StdioCollector {
      id: actionError
    }
    onExited: function(code) {
      if (code !== 0) {
        root.error = root.lastLine(actionError.text) || "The headphones refused that"
        if (kind === "mode") root.pendingMode = ""
      }
      if (Object.keys(root.queued).length > 0) root.drain()
      else if (kind === "mode" && code === 0) modeSettle.restart()
      else root.refresh()
    }
  }

  onEnabledChanged: if (enabled) scan(); else devices = []
  Component.onCompleted: scan()
}
