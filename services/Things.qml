pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Things 3, through Things Cloud. bin/things wraps an unofficial CLI and
// supplies the login from the keyring; this keeps Today and the Inbox and
// queues the changes.
Singleton {
  id: root

  readonly property string bin: Quickshell.shellDir + "/bin/things"

  // Refreshes faster while the popup is showing.
  property bool watching: false

  // "ready", "no-cli", "no-login", or "" before the first check.
  property string setup: ""
  readonly property bool ready: setup === "ready"

  // [{ uuid, title, note, isProject, deadlineDate, parentIds }]
  property var today: []
  property var inbox: []
  // uuid -> title, for showing which project a to-do belongs to.
  property var projects: ({})
  property string error: ""
  property bool loaded: false
  readonly property bool busy: lists.running || action.running

  function project(task) {
    var ids = task.parentIds || []
    return ids.length > 0 && projects[ids[0]] ? projects[ids[0]] : ""
  }

  function check() {
    if (!status.running) status.running = true
  }

  function refresh() {
    if (ready && !lists.running) lists.running = true
  }

  // Changes run one at a time, oldest first.
  property var queue: []
  function run(args) {
    queue = queue.concat([args])
    drain()
  }
  function drain() {
    if (action.running || queue.length === 0) return
    action.command = [bin].concat(queue[0])
    queue = queue.slice(1)
    action.running = true
  }

  // where: "today" or "inbox".
  function add(title, where) {
    if (title.trim() === "") return
    var placeholder = { uuid: "pending-" + Date.now(), title: title.trim(), pending: true }
    if (where === "inbox") inbox = inbox.concat([placeholder])
    else today = today.concat([placeholder])
    run(["create", title.trim(), "--when", where])
  }

  function complete(task) {
    if (task.pending) return
    today = today.filter(t => t.uuid !== task.uuid)
    inbox = inbox.filter(t => t.uuid !== task.uuid)
    run(["complete", task.uuid])
  }

  function moveToToday(task) {
    if (task.pending) return
    inbox = inbox.filter(t => t.uuid !== task.uuid)
    today = today.concat([task])
    run(["move-to-today", task.uuid])
  }

  // The password goes to the wrapper on stdin and from there to the keyring.
  function login(email, password) {
    error = ""
    loginProcess.secret = password + "\n"
    loginProcess.command = [bin, "login", email]
    loginProcess.running = true
  }

  function logout() {
    Quickshell.execDetached([bin, "logout"])
    setup = "no-login"
    today = []
    inbox = []
    loaded = false
  }

  function lastLine(text) {
    var lines = String(text || "").trim().split("\n")
    return lines[lines.length - 1]
  }

  onSetupChanged: if (ready) refresh()
  onWatchingChanged: {
    if (!watching) return
    if (ready) refresh()
    else check()
  }

  Process {
    id: status
    running: true
    command: [root.bin, "status"]
    stdout: StdioCollector {
      onStreamFinished: root.setup = text.trim()
    }
  }

  // Today, the inbox and the project names in one go, as three JSON lines.
  Process {
    id: lists
    command: ["sh", "-c", "for list in today inbox projects; do \"$1\" \"$list\" | jq -c . || exit 1; done", "sh", root.bin]
    stdout: StdioCollector {
      id: listsOut
    }
    stderr: StdioCollector {
      id: listsError
    }
    onExited: function(code) {
      if (code !== 0) {
        var message = root.lastLine(listsError.text)
        // A login the server does not know comes back as a bare HTTP status.
        root.error = /^login:.*(401|403|404|unauthorized)/i.test(message)
          ? "Things Cloud didn't accept that email and password. Sign out and try again."
          : message || "Could not reach Things Cloud"
        return
      }
      try {
        var parts = listsOut.text.trim().split("\n").map(l => JSON.parse(l) || [])
        var open = t => !t.inTrash && t.status === 0 && !t.isProject
        var names = {}
        for (var i = 0; i < parts[2].length; i++) names[parts[2][i].uuid] = parts[2][i].title
        root.projects = names
        // Changes still on their way would be undone by an older answer.
        if (root.queue.length === 0 && !action.running) {
          root.today = parts[0].filter(open)
          root.inbox = parts[1].filter(open)
        }
        root.loaded = true
        root.error = ""
      } catch (e) {
        root.error = "Unreadable answer from Things Cloud"
      }
    }
  }

  Process {
    id: action
    stderr: StdioCollector {
      id: actionError
    }
    onExited: function(code) {
      if (code !== 0) root.error = root.lastLine(actionError.text) || "Things Cloud refused that"
      if (root.queue.length > 0) root.drain()
      else root.refresh()
    }
  }

  Process {
    id: loginProcess
    property string secret: ""
    stdinEnabled: true
    onStarted: {
      write(secret)
      secret = ""
      stdinEnabled = false
    }
    onExited: function(code) {
      stdinEnabled = true
      if (code !== 0) root.error = "Could not store the login"
      root.check()
    }
  }

  Timer {
    interval: root.watching ? 60000 : 10 * 60000
    running: root.ready
    repeat: true
    onTriggered: root.refresh()
  }
}
