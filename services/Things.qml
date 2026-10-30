pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Things 3, through Things Cloud. bin/things wraps an unofficial CLI and
// supplies the login from the keyring. A sync has the CLI bring its local
// copy of the whole database up to date; the lists here are worked out from
// that copy, the way Things itself does (so a to-do scheduled for an earlier
// day still counts as Today until it is done).
Singleton {
  id: root

  readonly property string bin: Quickshell.shellDir + "/bin/things"
  readonly property string cache: Quickshell.env("HOME") + "/.cache/aayork-quickshell/things-state.json"

  // Refreshes faster while the popup is showing.
  property bool watching: false

  // "ready", "no-cli", "no-login", or "" before the first check.
  property string setup: ""
  readonly property bool enabled: Config.features.things
  readonly property bool ready: enabled && setup === "ready"

  // The synced copy: uuid -> task / checklist item / area, as the CLI keeps them.
  property var tasks: ({})
  property var checklistItems: ({})
  property var areas: ({})
  // Changes made here that the server has not confirmed yet: uuid -> fields.
  property var overrides: ({})
  // To-dos added here and not yet synced back: [{ uuid, title, view }]
  property var pending: []

  property string error: ""
  property bool loaded: false
  readonly property bool busy: sync.running || action.running

  readonly property string todayKey: Qt.formatDate(clock.date, "yyyy-MM-dd")
  SystemClock { id: clock; precision: SystemClock.Hours }

  readonly property var views: [
    { id: "today", label: "Today" },
    { id: "inbox", label: "Inbox" },
    { id: "upcoming", label: "Upcoming" },
    { id: "anytime", label: "Anytime" },
    { id: "someday", label: "Someday" }
  ]

  // Every open to-do, with local changes applied, as plain rows.
  readonly property var open: {
    var list = []
    for (var uuid in tasks) {
      var raw = tasks[uuid]
      if (!raw) continue
      var task = overrides[uuid] ? Object.assign({}, raw, overrides[uuid]) : raw
      // Type 0 is a to-do (1 project, 2 heading); Status 0 is open.
      if (task.Type !== 0 || task.Status !== 0 || task.InTrash) continue
      list.push({
        uuid: uuid,
        title: task.Title || "",
        note: plainNote(task.Note),
        schedule: task.Schedule,
        date: task.ScheduledDate ? String(task.ScheduledDate).slice(0, 10) : "",
        deadline: task.DeadlineDate ? String(task.DeadlineDate).slice(0, 10) : "",
        context: contextOf(task),
        order: task.Index || 0,
        todayOrder: task.TodayIndex || 0
      })
    }
    return list
  }

  readonly property var lists: {
    var out = { today: [], inbox: [], upcoming: [], anytime: [], someday: [] }
    for (var i = 0; i < open.length; i++) out[viewOf(open[i])].push(open[i])
    out.today.sort((a, b) => a.todayOrder - b.todayOrder || a.order - b.order)
    out.upcoming.sort((a, b) => a.date.localeCompare(b.date) || a.order - b.order)
    var plain = ["inbox", "anytime", "someday"]
    for (var p = 0; p < plain.length; p++) out[plain[p]].sort((a, b) => a.order - b.order)
    for (var n = 0; n < pending.length; n++)
      out[pending[n].view].push({ uuid: pending[n].uuid, title: pending[n].title, note: "", date: "", deadline: "", context: "", pending: true })
    return out
  }
  readonly property int todayCount: lists.today.length

  // Which list a to-do sits in. Schedule: 0 inbox, 1 anytime, 2 someday; a
  // date on or before today makes it Today, a later one Upcoming.
  function viewOf(task) {
    if (task.date !== "") return task.date <= todayKey ? "today" : "upcoming"
    if (task.schedule === 0) return "inbox"
    return task.schedule === 2 ? "someday" : "anytime"
  }

  function contextOf(task) {
    var parent = (task.ParentTaskIDs || [])[0]
    if (parent && tasks[parent]) return tasks[parent].Title || ""
    var area = (task.AreaIDs || [])[0]
    return area && areas[area] ? areas[area].Title || "" : ""
  }

  // Notes arrive either as plain text or wrapped in a little XML.
  function plainNote(note) {
    return String(note || "").replace(/<[^>]+>/g, "").trim()
  }

  // [{ title, done }] in the order Things shows them.
  function checklist(uuid) {
    var list = []
    for (var id in checklistItems) {
      var item = checklistItems[id]
      if (item && (item.TaskIDs || []).indexOf(uuid) !== -1) list.push({ title: item.Title || "", done: item.Status === 3, order: item.Index || 0 })
    }
    return list.sort((a, b) => a.order - b.order)
  }

  function check() {
    if (enabled && !status.running) status.running = true
  }

  function refresh() {
    if (ready && !sync.running) sync.running = true
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

  function override(uuid, fields) {
    var next = Object.assign({}, overrides)
    next[uuid] = Object.assign({}, next[uuid] || {}, fields)
    overrides = next
  }

  function dateKey(daysFromToday) {
    var day = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate() + daysFromToday)
    return Qt.formatDate(day, "yyyy-MM-dd")
  }

  // view: one of the list ids. Upcoming means tomorrow.
  function add(title, view) {
    var text = title.trim()
    if (text === "") return
    pending = pending.concat([{ uuid: "pending-" + Date.now(), title: text, view: view }])
    if (view === "upcoming") run(["create", text, "--scheduled", dateKey(1)])
    else run(["create", text, "--when", view])
  }

  function complete(task) {
    if (task.pending) return
    override(task.uuid, { Status: 3 })
    run(["complete", task.uuid])
  }

  function trash(task) {
    if (task.pending) return
    override(task.uuid, { InTrash: true })
    run(["trash", task.uuid])
  }

  // where: "today", "tomorrow", "anytime", "someday" or "inbox".
  function move(task, where) {
    if (task.pending) return
    if (where === "today") {
      override(task.uuid, { Schedule: 1, ScheduledDate: dateKey(0) })
      run(["move-to-today", task.uuid])
    } else if (where === "tomorrow") {
      override(task.uuid, { ScheduledDate: dateKey(1) })
      run(["edit", task.uuid, "--scheduled", dateKey(1)])
    } else {
      override(task.uuid, { Schedule: where === "inbox" ? 0 : where === "someday" ? 2 : 1, ScheduledDate: null })
      run(["edit", task.uuid, "--when", where])
    }
  }

  function rename(task, title) {
    if (task.pending || title.trim() === "" || title.trim() === task.title) return
    override(task.uuid, { Title: title.trim() })
    run(["edit", task.uuid, "--title", title.trim()])
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
    tasks = ({})
    checklistItems = ({})
    overrides = ({})
    pending = []
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
    running: root.enabled
    command: [root.bin, "status"]
    stdout: StdioCollector {
      onStreamFinished: root.setup = text.trim()
    }
  }

  // Any read command brings the CLI's local copy up to date; `areas` is the
  // one with the least to print. The copy itself is read below.
  Process {
    id: sync
    command: [root.bin, "areas"]
    stderr: StdioCollector {
      id: syncError
    }
    onExited: function(code) {
      if (code !== 0) {
        var message = root.lastLine(syncError.text)
        // A login the server does not know comes back as a bare HTTP status.
        root.error = /^login:.*(401|403|404|unauthorized)/i.test(message)
          ? "Things Cloud didn't accept that email and password. Sign out and try again."
          : message || "Could not reach Things Cloud"
        return
      }
      root.error = ""
      copy.reload()
    }
  }

  FileView {
    id: copy
    path: root.cache
    printErrors: false
    onLoaded: {
      try {
        var state = JSON.parse(text()).state || {}
        root.tasks = state.Tasks || {}
        root.checklistItems = state.CheckListItems || {}
        root.areas = state.Areas || {}
        // What was changed here is in the synced copy now, unless more
        // changes are still on their way.
        if (root.queue.length === 0 && !action.running) {
          root.overrides = ({})
          root.pending = []
        }
        root.loaded = true
      } catch (e) {
        root.error = "Could not read the synced Things data"
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
