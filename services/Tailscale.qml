pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale state, read from `tailscale status --json`, and the few actions
// the bar offers: up/down, exit node, account switch, copy an address.
Singleton {
  id: root

  // Polls faster while something is showing the device list.
  property bool watching: false

  property bool available: true
  property string backendState: ""
  readonly property bool running: backendState === "Running"
  readonly property bool needsLogin: backendState === "NeedsLogin"
  property string authUrl: ""
  property string tailnet: ""
  property string selfName: ""
  property string selfIp: ""
  property string selfOs: ""
  // [{ id, name, ip, os, online, shared, owner, exitNode, exitNodeOption, taildrop }], online first.
  property var peers: []
  // [{ id, label, selected }]
  property var accounts: []
  property string error: ""
  // What the last toggle asked for, shown until the daemon catches up.
  property int pending: -1
  readonly property bool active: pending !== -1 ? pending === 1 : running
  readonly property bool busy: action.running

  readonly property var ownPeers: peers.filter(p => !p.shared)
  readonly property var sharedPeers: peers.filter(p => p.shared)

  readonly property var exitNodeOptions: peers.filter(p => p.exitNodeOption)
  readonly property var exitNode: peers.find(p => p.exitNode) ?? null

  readonly property string status: {
    if (!available) return "Not installed"
    if (needsLogin) return "Needs login"
    if (running) return tailnet !== "" ? tailnet : "Connected"
    if (backendState === "Stopped") return "Off"
    return backendState || "Unknown"
  }

  function firstIPv4(ips) {
    return (ips || []).find(ip => ip.indexOf(":") === -1) ?? ""
  }

  function shortName(node) {
    var dns = String(node.DNSName || "").split(".")[0]
    return dns !== "" ? dns : String(node.HostName || "")
  }

  function parse(raw) {
    var data
    try {
      data = JSON.parse(raw)
    } catch (e) {
      backendState = ""
      peers = []
      return
    }
    backendState = String(data.BackendState || "")
    authUrl = String(data.AuthURL || "")
    tailnet = data.CurrentTailnet ? String(data.CurrentTailnet.Name || "") : ""
    selfName = data.Self ? shortName(data.Self) : ""
    selfIp = data.Self ? firstIPv4(data.Self.TailscaleIPs) : ""
    selfOs = data.Self ? String(data.Self.OS || "") : ""
    var selfUser = data.Self ? String(data.Self.UserID) : ""
    var users = data.User || {}

    var list = []
    var all = data.Peer || {}
    for (var key in all) {
      var peer = all[key]
      list.push({
        id: String(peer.ID || key),
        name: shortName(peer),
        ip: firstIPv4(peer.TailscaleIPs),
        online: peer.Online === true,
        exitNode: peer.ExitNode === true,
        exitNodeOption: peer.ExitNodeOption === true,
        os: String(peer.OS || ""),
        // A machine someone else owns and shared in from their own tailnet.
        shared: String(peer.UserID) !== selfUser,
        owner: users[peer.UserID] ? String(users[peer.UserID].LoginName || "") : "",
        // 1 is Tailscale's "can take files right now".
        taildrop: peer.TaildropTarget === 1
      })
    }
    list.sort(function(a, b) {
      if (a.online !== b.online) return a.online ? -1 : 1
      return a.name.localeCompare(b.name)
    })
    peers = running ? list : []

    if (pending !== -1 && running === (pending === 1)) pending = -1
  }

  function parseAccounts(raw) {
    try {
      accounts = JSON.parse(raw).map(a => ({
        id: String(a.id),
        label: String(a.nickname || a.account || a.tailnet || a.id),
        selected: a.selected === true
      }))
    } catch (e) {
      accounts = []
    }
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function run(command) {
    if (action.running) return
    error = ""
    action.command = command
    action.running = true
  }

  function toggle() {
    if (!available || busy) return
    if (needsLogin && authUrl !== "") {
      Quickshell.execDetached(["xdg-open", authUrl])
      return
    }
    pending = active ? 0 : 1
    run(["tailscale", pending === 1 ? "up" : "down"])
  }

  // An empty address clears the exit node.
  function setExitNode(ip) {
    run(["tailscale", "set", "--exit-node=" + ip])
  }

  function switchAccount(id) {
    run(["tailscale", "switch", id])
  }

  // `tailscale up` and friends need root unless this user is the operator.
  readonly property bool needsOperator: error.indexOf("--operator") !== -1 || error.toLowerCase().indexOf("access denied") !== -1
  function authorize() {
    run(["pkexec", "tailscale", "set", "--operator=" + Quickshell.env("USER")])
  }

  // Taildrop: pick a file with the desktop's chooser and send it. The
  // result arrives as a notification.
  function sendFile(peer) {
    if (!peer.taildrop || send.running) return
    send.command = ["sh", "-c", "file=$(roseshell-pick-file --title \"Send to $2\" --folder \"$HOME\") || exit 0; [ -n \"$file\" ] || exit 0; "
      + "if error=$(tailscale file cp --update-interval=0 -- \"$file\" \"$1:\" 2>&1); then notify-send -a Taildrop \"Sent to $2\" \"$(basename \"$file\")\"; "
      + "else notify-send -a Taildrop -u critical \"Could not send to $2\" \"${error:-Taildrop transfer failed}\"; fi", "sh", peer.ip, peer.name]
    send.running = true
  }

  Process {
    id: send
  }

  // Incoming files land in ~/Downloads while Tailscale is up. The
  // script takes its `tailscale file get` down with it when the shell stops.
  Process {
    running: root.running
    command: [Quickshell.shellDir + "/bin/taildrop-receive"]
  }

  function copy(text) {
    Quickshell.execDetached(["wl-copy", "--", text])
  }

  Process {
    id: statusProcess
    command: ["tailscale", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }
    onExited: function(code) {
      // 127 from the shell, or a start failure: the CLI is not there.
      if (code === 127) root.available = false
    }
    onRunningChanged: if (!running && !accountsProcess.running && root.watching) accountsProcess.running = true
  }

  Process {
    id: accountsProcess
    command: ["tailscale", "switch", "--list", "--json"]
    stdout: StdioCollector {
      onStreamFinished: root.parseAccounts(text)
    }
  }

  Process {
    id: action
    stderr: StdioCollector {
      id: actionError
    }
    onExited: function(code) {
      if (code !== 0) {
        root.pending = -1
        var lines = String(actionError.text || "").trim().split("\n")
        root.error = lines[lines.length - 1] || "Tailscale command failed"
      }
      root.refresh()
    }
  }

  Timer {
    interval: root.watching || root.pending !== -1 ? 3000 : 30000
    running: root.available
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onWatchingChanged: if (watching) refresh()
}
