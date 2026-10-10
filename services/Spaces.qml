pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "SpacesModel.js" as Model

// What the Spaces switcher on every bar shares: the windows on each
// workspace, their app icons, windows asking for attention, and the coding
// agents running in terminals.
//
// Agents report through bin/spaces-agent (a Claude Code hook):
//   qs -p <shell> ipc call spaces agent <session> <working|waiting|done|end> <pids>
// A preview can be opened from a key: `qs ipc call spaces peek 3`.
Singleton {
  id: root

  // Bumped once Hyprland has re-read window positions after a move.
  property int revision: 0

  function appIdOf(toplevel) {
    if (toplevel.wayland && toplevel.wayland.appId) return toplevel.wayland.appId
    var ipc = toplevel.lastIpcObject
    return ipc && ipc["class"] ? ipc["class"] : ""
  }

  // { [id]: { id, monitor, area, windows: [{ address, appId, title, focused,
  //   at, size, floating, pid, toplevel }] } } for every normal workspace.
  readonly property var workspaces: {
    root.revision
    var values = Hyprland.workspaces.values
    var active = Hyprland.activeToplevel
    var map = ({})
    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (ws.id <= 0) continue
      var windows = []
      var toplevels = ws.toplevels.values
      for (var j = 0; j < toplevels.length; j++) {
        var tl = toplevels[j]
        var ipc = tl.lastIpcObject || {}
        windows.push({
          address: Model.normalizeAddress(tl.address),
          appId: root.appIdOf(tl),
          title: String(tl.title || ""),
          focused: active ? tl === active : false,
          at: ipc.at && ipc.at.length === 2 ? [ipc.at[0], ipc.at[1]] : null,
          size: ipc.size && ipc.size.length === 2 ? [ipc.size[0], ipc.size[1]] : null,
          floating: ipc.floating === true,
          pid: ipc.pid || 0,
          toplevel: tl.wayland
        })
      }
      var mon = ws.monitor
      var area = mon ? Model.monitorArea({
        x: mon.x, y: mon.y, width: mon.width, height: mon.height, scale: mon.scale,
        transform: mon.lastIpcObject ? mon.lastIpcObject.transform : 0,
        reserved: mon.lastIpcObject ? mon.lastIpcObject.reserved : null
      }) : null
      map[ws.id] = { id: ws.id, monitor: mon, area: area, windows: Model.sortWindows(windows) }
    }
    return map
  }

  readonly property var allWindows: {
    var list = []
    for (var id in root.workspaces) list = list.concat(root.workspaces[id].windows)
    return list
  }

  function windowByAddress(address) {
    var key = Model.normalizeAddress(address)
    for (var i = 0; i < root.allWindows.length; i++)
      if (root.allWindows[i].address === key) return root.allWindows[i]
    return null
  }

  readonly property string activeAddress: Hyprland.activeToplevel ? String(Hyprland.activeToplevel.address || "").toLowerCase().replace(/^0x/, "") : ""

  // ---------------------------------------------------------------- actions
  // Hyprland runs a Lua config here, so dispatchers are Lua calls.

  function focusWorkspace(id) {
    Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
  }

  function focusWindow(address) {
    Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + Model.normalizeAddress(address) + "\" })")
  }

  function closeWindow(address) {
    Hyprland.dispatch("hl.dsp.window.close({ window = \"address:0x" + Model.normalizeAddress(address) + "\" })")
  }

  // ---------------------------------------------------------------- attention
  // Windows that asked to be looked at and have not been focused since.
  property var urgent: ({})

  function setUrgent(address, on) {
    var key = Model.normalizeAddress(address)
    if (key === "" || (!!root.urgent[key]) === on) return
    var next = ({})
    for (var k in root.urgent) if (k !== key) next[k] = true
    if (on) next[key] = true
    root.urgent = next
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      switch (event.name) {
      case "urgent":
        root.setUrgent(event.data, true)
        break
      case "activewindowv2":
      case "closewindow":
        root.setUrgent(event.data.split(",")[0], false)
        refresh.restart()
        break
      case "openwindow":
      case "movewindow":
      case "movewindowv2":
      case "changefloatingmode":
      case "windowtitlev2":
      case "resizewindow":
        refresh.restart()
        break
      }
    }
    function onActiveToplevelChanged() { Qt.callLater(root.acknowledgeAgents) }
  }

  // Positions and PIDs come from Hyprland's IPC objects, which only refresh
  // when asked; the re-read lands a moment later.
  Timer {
    id: refresh
    interval: 120
    onTriggered: {
      Hyprland.refreshToplevels()
      bump.restart()
    }
  }

  Timer {
    id: bump
    interval: 80
    onTriggered: root.revision++
  }

  // Tiled windows move whenever a neighbour opens, closes or resizes, and
  // not every such move raises an event; a slow re-read catches the rest.
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: refresh.restart()
  }

  // ---------------------------------------------------------------- icons

  property var iconCache: ({})
  property int iconRevision: 0

  function desktopEntryFor(appId) {
    if (!appId) return null
    var candidates = Model.appIdCandidates(appId)
    for (var c = 0; c < candidates.length; c++) {
      var byId = DesktopEntries.byId(candidates[c])
      if (byId) return byId
    }
    var entry = DesktopEntries.heuristicLookup(appId)
    if (entry) return entry
    var host = Model.webAppHost(appId)
    if (host === "") return null
    var apps = DesktopEntries.applications.values
    for (var i = 0; i < apps.length; i++)
      if (String(apps[i].execString || "").indexOf("//" + host) !== -1) return apps[i]
    return null
  }

  function iconUrl(name) {
    var value = String(name || "")
    if (value === "") return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return "file://" + value
    return Quickshell.iconPath(value, true)
  }

  // { source, name } for an app id.
  function appInfo(appId) {
    root.iconRevision
    var key = String(appId || "").toLowerCase()
    var cached = root.iconCache[key]
    if (cached) return cached
    var entry = root.desktopEntryFor(appId)
    var source = root.iconUrl(entry && entry.icon ? entry.icon : appId)
    if (source === "" && key !== appId) source = root.iconUrl(key)
    var info = { source: source, name: entry && entry.name ? String(entry.name) : String(appId || "") }
    root.iconCache[key] = info
    return info
  }

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() { iconDebounce.restart() }
  }

  Timer {
    id: iconDebounce
    interval: 1500
    onTriggered: {
      root.iconCache = ({})
      root.iconRevision++
    }
  }

  Component.onCompleted: {
    // Touching the list starts Quickshell's desktop-entry scan.
    DesktopEntries.applications.values
    Hyprland.refreshToplevels()
  }

  // ---------------------------------------------------------------- agents
  // { [session]: { state, pids, address } }
  property var agents: ({})

  readonly property var agentByAddress: Model.agentWindowStates(root.agents, root.allWindows)

  function agentStateFor(addresses) {
    var best = ""
    var rank = { waiting: 3, working: 2, done: 1 }
    for (var i = 0; i < addresses.length; i++) {
      var state = root.agentByAddress[addresses[i]] || ""
      if (state && (!best || rank[state] > rank[best])) best = state
    }
    return best
  }

  // Whether an agent's window is the one in focus.
  function agentInFocus(agent) {
    if (agent.address) return agent.address === root.activeAddress
    var focused = root.windowByAddress(root.activeAddress)
    return focused !== null && agent.pids.indexOf(focused.pid) !== -1
  }

  function report(session, state, pidsCsv) {
    var next = ({})
    for (var k in root.agents) if (k !== session) next[k] = root.agents[k]
    if (state === "end") {
      root.agents = next
      return
    }
    var reported = Model.normalizeAgentState(state)
    if (!reported) return
    var pids = Model.parsePids(pidsCsv)
    // Keep the window this agent was pinned to while that window lives.
    var prev = root.agents[session]
    var address = prev && prev.address && root.windowByAddress(prev.address) ? prev.address : ""
    if (!address) address = Model.agentPinAddress(pids, root.allWindows, root.activeAddress)
    var agent = { state: reported, pids: pids, address: address }
    // Finishing in the window you are looking at needs no check mark.
    if (reported === "done" && root.agentInFocus(agent)) agent.state = "idle"
    next[session] = agent
    root.agents = next
  }

  // Looking at a finished agent's window clears its check mark.
  function acknowledgeAgents() {
    if (root.activeAddress === "") return
    var changed = false
    var next = ({})
    for (var k in root.agents) {
      var agent = root.agents[k]
      if (agent.state === "done" && root.agentInFocus(agent)) {
        agent = { state: "idle", pids: agent.pids, address: agent.address }
        changed = true
      }
      next[k] = agent
    }
    if (changed) root.agents = next
  }

  // A crashed reporter never says "end"; once a minute, drop working or
  // waiting sessions whose agent process has gone.
  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: {
      var pids = Model.agentProcessIds(root.agents)
      if (pids.length === 0 || probe.running) return
      probe.command = ["sh", "-c", "echo ok; for p in " + pids.join(" ")
        + "; do [ -d /proc/$p ] && ! grep -q '^State:.Z' /proc/$p/status 2>/dev/null && echo $p; done"]
      probe.running = true
    }
  }

  Process {
    id: probe
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n")
        // No "ok" means the check itself failed; never reap on that.
        if (lines[0] !== "ok") return
        root.agents = Model.pruneDeadAgents(root.agents, lines.slice(1))
      }
    }
  }

  signal peekRequested(int id)

  IpcHandler {
    target: "spaces"
    function agent(session: string, state: string, pids: string): void { root.report(session, state, pids) }
    function peek(workspace: string): void { root.peekRequested(Number(workspace)) }
    function agents(): string { return JSON.stringify(root.agents) }
  }
}
