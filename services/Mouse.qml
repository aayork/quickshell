pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Razer mouse: DPI and polling rate through OpenRazer, acceleration and
// sensitivity through Hyprland. bin/mouse does the talking; this keeps its
// last answer and queues changes the same way the Bose service does.
Singleton {
  id: root

  // Refreshes faster while the popup is showing.
  property bool watching: false

  readonly property string helper: Quickshell.shellDir + "/bin/mouse"

  // Last answer; null while no Razer mouse is around.
  property var state: null
  property string error: ""
  readonly property bool busy: statusProcess.running || actionProcess.running

  readonly property bool present: state !== null
  // The mouse itself answering, not just its dongle being plugged in; from
  // the watcher, which reads the mouse every half second.
  property bool online: false
  readonly property bool connected: present && online
  readonly property string name: state ? state.name : ""
  readonly property int battery: state && state.battery !== undefined ? state.battery : -1
  readonly property bool charging: state ? state.charging === true : false
  readonly property int dpi: state ? state.dpi : 0
  readonly property int maxDpi: state ? state.maxDpi : 0
  // What the DPI button cycles through.
  readonly property var stages: state && state.stages ? state.stages : []
  readonly property int poll: state ? state.poll : 0
  readonly property var pollRates: state ? state.pollRates : []
  readonly property bool flat: state ? state.accel === "flat" : false
  readonly property real sensitivity: state ? state.sensitivity : 0

  // Newest value per kind only, so dragging a slider sends where it ended up.
  property var queued: ({})

  function refresh() {
    if (busy) return
    statusProcess.running = true
  }

  // Shown right away; the next status read confirms it.
  function send(kind, value, patch) {
    if (state) state = Object.assign({}, state, patch)
    var next = Object.assign({}, queued)
    next[kind] = [kind, String(value)]
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
    actionProcess.command = [helper].concat(args)
    actionProcess.running = true
  }

  function setDpi(value) { send("dpi", value, { dpi: value }) }
  function setPoll(value) { send("poll", value, { poll: value }) }
  function setFlat(on) { send("accel", on ? "flat" : "adaptive", { accel: on ? "flat" : "adaptive" }) }
  function setSensitivity(value) {
    value = Math.round(value * 20) / 20
    send("sensitivity", value, { sensitivity: value })
  }

  function lastLine(text) {
    var lines = String(text || "").trim().split("\n")
    return lines[lines.length - 1]
  }

  onWatchingChanged: if (watching) refresh()

  Timer {
    interval: root.watching ? 10000 : 60000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    command: [root.helper, "status"]
    stdout: StdioCollector { id: statusOut }
    onExited: function(code) {
      if (code === 0) {
        try {
          root.state = JSON.parse(statusOut.text)
        } catch (e) {
          root.state = null
        }
      } else {
        root.state = null
      }
      root.drain()
    }
  }

  Process {
    id: actionProcess
    stderr: StdioCollector { id: actionError }
    onExited: function(code) {
      if (code !== 0) root.error = root.lastLine(actionError.text) || "The mouse refused that"
      if (Object.keys(root.queued).length > 0) root.drain()
      else root.refresh()
    }
  }

  // Runs with the shell: reports DPI button presses straight away, saves
  // them, and puts the saved DPI back after the mouse or daemon resets.
  Process {
    id: watchProcess
    running: true
    command: [root.helper, "watch"]
    stdout: SplitParser {
      onRead: function(line) {
        var parts = line.split(" ")
        if (parts[0] === "online" || parts[0] === "offline") {
          root.online = parts[0] === "online"
          // Fresh battery and settings as it comes back.
          if (root.online) root.refresh()
          return
        }
        if (parts[0] !== "dpi" || !root.state) return
        var value = parseInt(parts[1])
        if (value > 0 && value !== root.state.dpi && !root.queued.dpi)
          root.state = Object.assign({}, root.state, { dpi: value })
      }
    }
    onExited: {
      root.online = false
      watchRestart.start()
    }
  }

  Timer {
    id: watchRestart
    interval: 10000
    onTriggered: watchProcess.running = true
  }

  Component.onCompleted: refresh()
}
