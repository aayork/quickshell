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

  // Calendars an event can be added to: iCloud ones, minus Reminders lists.
  readonly property var writable: {
    var list = []
    for (var a = 0; a < accounts.length; a++) {
      var account = accounts[a]
      if (account.type !== "caldav") continue
      var calendars = account.calendars || []
      for (var c = 0; c < calendars.length; c++) {
        if (calendars[c].enabled === false || /reminders/i.test(calendars[c].displayName)) continue
        list.push({ accountId: account.id, url: calendars[c].url, name: calendars[c].displayName.replace(/[^\x20-\x7E]/g, "").trim(), color: calendars[c].color })
      }
    }
    return list
  }

  // "9am", "9:30", "14:00", "3pm-4:30pm". Returns { start, end } in minutes
  // after midnight, null for all day (empty text), or undefined if unreadable.
  function parseTimes(text) {
    var clean = String(text || "").trim().toLowerCase()
    if (clean === "") return null
    var parts = clean.split(/\s*(?:-|–|to)\s*/)
    function minutes(word, hint) {
      var match = word.match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm|a|p)?$/)
      if (!match) return -1
      var hour = Number(match[1])
      var suffix = match[3] ? match[3].charAt(0) : hint
      if (hour > 23 || Number(match[2] || 0) > 59) return -1
      if (suffix === "p" && hour < 12) hour += 12
      if (suffix === "a" && hour === 12) hour = 0
      return hour * 60 + Number(match[2] || 0)
    }
    var endHint = parts.length > 1 ? (parts[1].match(/(am|pm|a|p)$/) || [""])[0].charAt(0) : ""
    var start = minutes(parts[0], endHint)
    if (start < 0) return undefined
    var end = parts.length > 1 ? minutes(parts[1], "") : start + 60
    if (end < 0) return undefined
    if (end <= start) end = start + 60
    return { start: start, end: end }
  }

  // times: what parseTimes returned (null for all day).
  function createEvent(calendar, day, title, times) {
    var start = new Date(day.getFullYear(), day.getMonth(), day.getDate())
    var end = new Date(start)
    if (times) {
      start.setMinutes(times.start)
      end.setMinutes(times.end)
    } else {
      end.setDate(end.getDate() + 1)
    }
    function local(date) { return Qt.formatDateTime(date, "yyyy-MM-ddTHH:mm:ss") }
    run(["create-event"], JSON.stringify({
      accountId: calendar.accountId, calendarUrl: calendar.url, title: title,
      start: times ? start.toISOString() : local(start), end: times ? end.toISOString() : local(end), allDay: !times
    }), "Adding the event…")
  }

  function canDelete(event) {
    return accounts.some(a => a.id === event.accountId && a.type === "caldav")
  }

  function deleteEvent(event) {
    var account = accounts.find(a => a.id === event.accountId)
    var calendar = account ? (account.calendars || []).find(c => c.displayName === event.calendar) : null
    if (!calendar) return
    run(["delete-event"], JSON.stringify({ accountId: event.accountId, calendarUrl: calendar.url, uid: event.uid }), "Deleting…")
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
      // The helper reads its input to the end, so it has to be told it ended.
      stdinEnabled = false
    }
    onExited: stdinEnabled = true
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
