.pragma library

// Pure helpers for the Spaces workspace switcher (bar/Spaces.qml). Adapted from Spaces by
// Tornike Gomareli (github.com/tornikegomareli/omarchy-spaces, MIT licence).
// Nothing here touches QML objects beyond plain property reads, so it can be
// checked with node.

// Whether a workspace pill shows its app icons.
//   mode: "all" | "active" | "hover" (active + hovered)
function showsApps(mode, occupied, active, hovered) {
  if (!occupied) return false
  if (mode === "all") return true
  if (mode === "active") return active
  return active || hovered
}

// Hyprland reports addresses with or without the 0x prefix depending on source.
function normalizeAddress(address) {
  return String(address || "").toLowerCase().replace(/^0x/, "")
}

// Workspace ids to draw: 1..persistent always, then every other normal
// workspace Hyprland has, then the focused one even if it is empty.
function workspaceIds(known, focused, persistent) {
  var ids = []
  function add(id) { if (id > 0 && ids.indexOf(id) === -1) ids.push(id) }
  for (var p = 1; p <= persistent; p++) add(p)
  for (var i = 0; i < known.length; i++) add(known[i])
  add(focused)
  ids.sort(function(l, r) { return l - r })
  return ids
}

// Left to right, then top to bottom, the way the windows sit on screen.
// Windows without a known position keep their relative order at the end.
function sortWindows(windows) {
  var indexed = windows.map(function(w, i) { return { w: w, i: i } })
  indexed.sort(function(l, r) {
    var la = l.w.at, ra = r.w.at
    if (la && ra) {
      if (la[0] !== ra[0]) return la[0] - ra[0]
      if (la[1] !== ra[1]) return la[1] - ra[1]
    } else if (la || ra) {
      return la ? -1 : 1
    }
    return l.i - r.i
  })
  return indexed.map(function(x) { return x.w })
}

// Turns windows into icons, one per window or one per app with a count.
// Past maxIcons the rest collapse into an overflow number, but the focused
// window is never the one hidden.
//   windows: [{ address, appId, title, focused }]
function iconItems(windows, groupApps, maxIcons) {
  var items = []
  if (groupApps) {
    var byApp = {}
    for (var i = 0; i < windows.length; i++) {
      var w = windows[i]
      var key = String(w.appId || "").toLowerCase() || w.address
      var item = byApp[key]
      if (!item) {
        item = byApp[key] = { key: key, address: w.address, appId: w.appId, title: w.title, focused: w.focused, count: 1, addresses: [w.address] }
        items.push(item)
      } else {
        item.count++
        item.addresses.push(w.address)
        if (w.focused) {
          item.focused = true
          item.address = w.address
          item.title = w.title
        }
      }
    }
  } else {
    for (var j = 0; j < windows.length; j++) {
      var x = windows[j]
      items.push({ key: x.address, address: x.address, appId: x.appId, title: x.title, focused: x.focused, count: 1, addresses: [x.address] })
    }
  }

  var overflow = Math.max(0, items.length - maxIcons)
  if (overflow > 0) {
    var visible = items.slice(0, maxIcons)
    for (var f = maxIcons; f < items.length; f++)
      if (items[f].focused) visible[visible.length - 1] = items[f]
    items = visible
  }
  return { items: items, overflow: overflow }
}

// Lookup keys for an app id, most specific first. Reverse-DNS ids such as
// "com.mitchellh.ghostty" often ship a desktop file named after the last part.
function appIdCandidates(appId) {
  var id = String(appId || "")
  if (id === "") return []
  var out = [id]
  function add(v) { if (v && out.indexOf(v) === -1) out.push(v) }
  add(id.toLowerCase())
  var dot = id.lastIndexOf(".")
  if (dot > 0 && dot < id.length - 1) {
    add(id.slice(dot + 1))
    add(id.slice(dot + 1).toLowerCase())
  }
  return out
}

// Chromium-family --app windows have classes like
// "chrome-web.whatsapp.com__-Default". Returns the host, or "".
function webAppHost(appId) {
  var m = /^(?:chrome|chromium|brave|msedge|vivaldi|helium|opera)-([^_]+?)(?:__|_).*-(?:Default|Profile_\d+)$/i.exec(String(appId || ""))
  return m ? m[1] : ""
}

// The letter that stands in for an app with no icon. Prefers the tail of a
// reverse-DNS class, so "org.example.tool" reads "T", not "O".
function fallbackLetter(name, appId) {
  var label = String(name || "")
  var id = String(appId || "")
  if (label === "" || label === id) {
    var parts = id.split(".")
    label = parts.length > 1 ? parts[parts.length - 1] : id
  }
  return label.charAt(0).toUpperCase()
}

// Usable area of a monitor in layout coordinates, without what bars reserve.
//   monitor: { x, y, width, height, scale, transform, reserved: [l, t, r, b] }
// width and height are physical pixels, the rest logical.
function monitorArea(monitor) {
  if (!monitor || !monitor.width || !monitor.height) return null
  var scale = monitor.scale > 0 ? monitor.scale : 1
  var r = monitor.reserved && monitor.reserved.length === 4 ? monitor.reserved : [0, 0, 0, 0]
  // Odd transforms are rotations, which swap the mode's axes.
  var rotated = (monitor.transform || 0) % 2 === 1
  var w = (rotated ? monitor.height : monitor.width) / scale
  var h = (rotated ? monitor.width : monitor.height) / scale
  return {
    x: (monitor.x || 0) + r[0],
    y: (monitor.y || 0) + r[1],
    width: Math.max(1, w - r[0] - r[2]),
    height: Math.max(1, h - r[1] - r[3])
  }
}

// Size of the miniature: `extent` on its longest side, the monitor's shape.
function previewSize(area, extent) {
  var ratio = area && area.width > 0 && area.height > 0 ? area.height / area.width : 9 / 16
  return ratio > 1 ? { width: extent / ratio, height: extent } : { width: extent, height: extent * ratio }
}

// Places windows inside a width x height miniature of `area`, where they
// really sit on screen; floating windows last so they draw on top. Without
// positions for all of them, an even grid instead.
//   windows: [{ address, at: [x, y] | null, size: [w, h] | null, floating }]
function previewLayout(windows, area, width, height) {
  var placed = []
  var known = area && windows.length > 0 && windows.every(function(w) { return w.at && w.size })

  if (known) {
    var sx = width / area.width
    var sy = height / area.height
    for (var i = 0; i < windows.length; i++) {
      var w = windows[i]
      var x = (w.at[0] - area.x) * sx
      var y = (w.at[1] - area.y) * sy
      // Windows can hang off the edge; keep them inside.
      var cx = Math.max(0, Math.min(width - 4, x))
      var cy = Math.max(0, Math.min(height - 4, y))
      placed.push({
        address: w.address,
        x: cx, y: cy,
        width: Math.max(4, Math.min(width - cx, w.size[0] * sx - (cx - x))),
        height: Math.max(4, Math.min(height - cy, w.size[1] * sy - (cy - y))),
        floating: !!w.floating
      })
    }
  } else {
    var n = windows.length
    var cols = Math.max(1, Math.ceil(Math.sqrt(n)))
    var rows = Math.max(1, Math.ceil(n / cols))
    var gap = 4
    var cw = (width - gap * (cols - 1)) / cols
    var ch = (height - gap * (rows - 1)) / rows
    for (var j = 0; j < n; j++) {
      placed.push({
        address: windows[j].address,
        x: (j % cols) * (cw + gap), y: Math.floor(j / cols) * (ch + gap),
        width: cw, height: ch,
        floating: false
      })
    }
  }

  placed.sort(function(l, r) { return (l.floating ? 1 : 0) - (r.floating ? 1 : 0) })
  return placed
}

// ---------------------------------------------------------------- agents
// Coding agents (Claude Code and others) report through bin/spaces-agent:
//   agents: { session: { state, pids, address } }
// pids run from the agent up towards init. The nearest ancestor that owns a
// window is the agent's terminal. Ghostty runs every window in one process,
// so one PID can own several windows; `address` pins the agent to one.

var AGENT_RANK = { waiting: 3, working: 2, done: 1 }
var AGENT_STATES = { working: true, waiting: true, done: true, idle: true }
var AGENT_LIVE = { working: true, waiting: true }

function normalizeAgentState(state) {
  var value = String(state || "")
  return AGENT_STATES[value] ? value : ""
}

function parsePids(csv) {
  return String(csv || "").split(",").map(Number).filter(function(n) { return n > 1 })
}

function windowsByPid(windows) {
  var byPid = {}
  for (var i = 0; i < (windows || []).length; i++) {
    var pid = Number(windows[i].pid)
    if (!pid) continue
    if (!byPid[pid]) byPid[pid] = []
    byPid[pid].push(String(windows[i].address))
  }
  return byPid
}

function ownerWindows(pids, byPid) {
  for (var i = 0; i < pids.length; i++) if (byPid[pids[i]]) return byPid[pids[i]]
  return null
}

// address -> the most pressing state of the agents in that window:
// waiting beats working beats done.
//   windows: [{ address, pid }]
function agentWindowStates(agents, windows) {
  var byPid = windowsByPid(windows)
  var out = {}
  for (var session in agents) {
    var agent = agents[session]
    var rank = AGENT_RANK[agent.state] || 0
    if (!rank) continue
    var candidates = ownerWindows(agent.pids, byPid)
    if (!candidates) continue
    if (agent.address && candidates.indexOf(agent.address) !== -1) candidates = [agent.address]
    for (var c = 0; c < candidates.length; c++) {
      var address = candidates[c]
      if (!out[address] || AGENT_RANK[out[address]] < rank) out[address] = agent.state
    }
  }
  return out
}

// The one window to pin an agent to: the only candidate, or else the focused
// window when it is one of them. "" when it cannot tell.
function agentPinAddress(pids, windows, activeAddress) {
  var candidates = ownerWindows(pids, windowsByPid(windows))
  if (!candidates) return ""
  if (candidates.length === 1) return candidates[0]
  return activeAddress && candidates.indexOf(activeAddress) !== -1 ? activeAddress : ""
}

// The agent process of every live session (the first PID of a report), to
// check for crashed reporters that never said "end".
function agentProcessIds(agents) {
  var out = []
  for (var session in agents) {
    var agent = agents[session]
    if (!AGENT_LIVE[agent.state]) continue
    var pid = Number(agent.pids[0])
    if (pid > 1 && out.indexOf(pid) === -1) out.push(pid)
  }
  return out
}

// Drops live sessions whose agent process is gone.
function pruneDeadAgents(agents, alivePids) {
  var alive = {}
  for (var i = 0; i < alivePids.length; i++) alive[Number(alivePids[i])] = true
  var pruned = false
  var out = {}
  for (var session in agents) {
    var agent = agents[session]
    if (AGENT_LIVE[agent.state] && !alive[Number(agent.pids[0])]) {
      pruned = true
      continue
    }
    out[session] = agent
  }
  return pruned ? out : agents
}

// Next workspace when scrolling; wraps around.
function stepWorkspace(ids, current, delta) {
  if (!ids.length) return current
  var idx = ids.indexOf(current)
  if (idx === -1) return ids[0]
  return ids[(idx + (delta > 0 ? 1 : -1) + ids.length) % ids.length]
}

if (typeof module !== "undefined") {
  module.exports = {
    showsApps: showsApps, normalizeAddress: normalizeAddress, workspaceIds: workspaceIds,
    sortWindows: sortWindows, iconItems: iconItems, appIdCandidates: appIdCandidates,
    webAppHost: webAppHost, fallbackLetter: fallbackLetter, monitorArea: monitorArea,
    previewSize: previewSize, previewLayout: previewLayout, normalizeAgentState: normalizeAgentState,
    parsePids: parsePids, agentWindowStates: agentWindowStates, agentPinAddress: agentPinAddress,
    agentProcessIds: agentProcessIds, pruneDeadAgents: pruneDeadAgents, stepWorkspace: stepWorkspace
  }
}
