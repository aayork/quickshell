pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Calendar events from iCloud (CalDAV) and plain ICS feeds. The talking to
// servers is done by calendar/calendar_helper.py; passwords live in the
// keyring, never in a file.
Singleton {
  id: root

  readonly property string helper: Quickshell.shellDir + "/calendar/calendar_helper.py"
  readonly property string eventsFile: Theme.stateDir + "/calendar/events.json"

  // [{ id, type, provider, label, calendars: [{ displayName, color, enabled }] }]
  property var accounts: []
  // The next two weeks: [{ uid, title, location, start, end, allDay, calendar, color }]
  property var events: []
  property var errors: []
  property string status: ""
  readonly property bool busy: sync.running || action.running
  readonly property bool connected: accounts.length > 0

  function dayKey(date) {
    return Qt.formatDate(date, "yyyy-MM-dd")
  }

  function eventsOn(date) {
    var key = dayKey(date)
    return events.filter(e => e.start.slice(0, 10) <= key && (e.allDay ? e.end.slice(0, 10) > key || e.start.slice(0, 10) === key : e.end.slice(0, 10) >= key))
  }

  function hasEvents(date) {
    return eventsOn(date).length > 0
  }

  function timeText(event) {
    if (event.allDay) return "All day"
    return Qt.formatTime(new Date(event.start), "h:mm AP")
  }

  function refresh() {
    if (connected && !sync.running) sync.running = true
  }

  function run(args, input, doing) {
    if (action.running) return
    status = doing
    action.input = input || ""
    action.command = ["python3", helper].concat(args)
    action.running = true
  }

  // An app-specific password from appleid.apple.com, not the account's own.
  function addIcloud(email, password) {
    run(["add-icloud", email], password + "\n", "Connecting to iCloud…")
  }

  function addFeed(url, label) {
    run(["add-ics", url, "--label", label || "Calendar", "--provider", "ics"], "", "Adding the feed…")
  }

  function removeAccount(id) {
    run(["remove-account", id], "", "Removing…")
  }

  Process {
    id: listAccounts
    running: true
    command: ["python3", root.helper, "list-accounts"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.accounts = JSON.parse(text).accounts || []
        } catch (e) {
          root.accounts = []
        }
        root.refresh()
      }
    }
  }

  // Writes the cache file, which is read below.
  Process {
    id: sync
    command: ["python3", root.helper, "sync"]
  }

  Process {
    id: action
    property string input: ""
    stdinEnabled: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var result = JSON.parse(text)
          root.status = result.ok ? "" : String(result.error || "That didn't work")
        } catch (e) {
          root.status = "That didn't work"
        }
        listAccounts.running = true
      }
    }
    onStarted: {
      if (input !== "") write(input)
      input = ""
    }
  }

  FileView {
    path: root.eventsFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var data = JSON.parse(text())
        root.events = data.events || []
        root.errors = data.errors || []
      } catch (e) {}
    }
  }

  Timer {
    interval: 5 * 60 * 1000
    running: root.connected
    repeat: true
    onTriggered: root.refresh()
  }
}
