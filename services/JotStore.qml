pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "JotEngine.js" as Engine

// Jot's notes, timer, AutoPaste and currency rates. The notes live in
// ~/.local/share/jot/notes.json, the same file the old GTK Jot used:
// { version, current, notes: [{ id, text, links, created, modified }] },
// times in seconds. The dropdown itself is bar/Jot.qml.
Singleton {
  id: root

  readonly property string dataDir: Quickshell.env("HOME") + "/.local/share/jot"
  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/jot"

  property var notes: []
  property string current: ""
  property bool loaded: false
  readonly property int index: notes.findIndex(n => n.id === current)
  readonly property var note: index >= 0 ? notes[index] : null

  // The editor shows another note: reload it. direction is -1, 0 or 1.
  signal switched(int direction)
  // A note's text changed from outside the editor (AutoPaste, a new note
  // from IPC): reload it if it is showing.
  signal textReplaced(string id)
  signal toast(string text)
  // Something asked for the dropdown to open (IPC `jot newNote`).
  signal openRequested()

  // Set by the dropdown while it has the keyboard, so AutoPaste leaves
  // copies made inside Jot alone.
  property bool editorFocused: false
  // The note's text colour in the current theme, for ui/JotLabel.qml.
  property color ink: "#36312e"

  readonly property string welcome: "Hi, this is Jot.\n\n"
    + "Jot is for the scraps: numbers, links, lists, half-thoughts. No titles, no folders. "
    + "Notes nobody touches for a month quietly go away.\n\n"
    + "Ctrl+[ or a sideways swipe goes back a note, Ctrl+] forward, Ctrl+N starts a new one.\n\n"
    + "Try a keyword on the first line: math, list, sum, count. Or type \"timer 5m\" on a line and press Enter.\n\n"
    + "Right-click the note button for settings.\n"

  function makeNote(text) {
    var now = Date.now() / 1000
    return { id: Math.random().toString(16).slice(2, 14).padEnd(12, "0"), text: text || "", links: {}, created: now, modified: now }
  }

  // ------------------------------------------------------------ keywords

  readonly property var keywordConfig: ({
    math: Config.jot.keywords.math, list: Config.jot.keywords.list, sum: Config.jot.keywords.sum,
    avg: Config.jot.keywords.avg, count: Config.jot.keywords.count, timer: Config.jot.keywords.timer,
    stopwatch: Config.jot.keywords.stopwatch, pomodoro: Config.jot.keywords.pomodoro
  })
  // Bumped whenever the engine's keywords or rates change, so text that
  // depends on them is worked out again.
  property int engineVersion: 0
  onKeywordConfigChanged: {
    Engine.setKeywords(keywordConfig)
    engineVersion++
  }
  Component.onCompleted: {
    Engine.setKeywords(keywordConfig)
    loadRates()
  }

  // ------------------------------------------------------------ notes

  // The engine, shared with the dropdown so both see the same keywords and rates.
  function engine() { return Engine }

  function find(id) { return notes.find(n => n.id === id) || null }

  function setText(id, text) {
    var n = find(id)
    if (!n || n.text === text) return
    n.text = text
    n.modified = Date.now() / 1000
    save()
  }

  function setLinks(id, links) {
    var n = find(id)
    if (!n) return
    n.links = links
    save()
  }

  function open(id, direction) {
    if (!find(id)) return
    current = id
    switched(direction || 0)
    save()
  }

  // Drop the current note if it is empty (never the last one). True if dropped.
  function leaveNote() {
    var n = note
    if (!n || n.text.trim() !== "" || notes.length <= 1) return false
    notes = notes.filter(x => x !== n)
    return true
  }

  function go(step) {
    var target = index + step
    // Past the newest note is a fresh one, as in Antinote.
    if (step > 0 && target >= notes.length) {
      if (note && note.text.trim() !== "") newNote("")
      return
    }
    if (target < 0) {
      toast("Oldest note")
      return
    }
    var id = notes[target].id
    if (leaveNote()) toast("Empty note deleted")
    open(id, step)
  }

  function goFront(quiet) {
    if (notes.length === 0 || current === notes[notes.length - 1].id) return
    var id = notes[notes.length - 1].id
    if (leaveNote() && !quiet) toast("Empty note deleted")
    open(id, quiet ? 0 : 1)
  }

  function goOldest() {
    if (notes.length === 0 || current === notes[0].id) return
    var id = notes[0].id
    leaveNote()
    open(id, -1)
  }

  function newNote(text) {
    if (note && note.text.trim() === "" && !text) {
      if (current !== notes[notes.length - 1].id) goFront()
      else toast("Already blank")
      return
    }
    leaveNote()
    var n = makeNote(text)
    notes = notes.concat([n])
    open(n.id, 1)
  }

  function deleteNote() {
    var at = index
    var rest = notes.filter((x, i) => i !== at)
    if (rest.length === 0) rest = [makeNote("")]
    notes = rest
    open(rest[Math.min(at, rest.length - 1)].id, -1)
    toast("Note deleted")
  }

  // Delete any note, from the notes list.
  function deleteById(id) {
    if (id === current) { deleteNote(); return }
    notes = notes.filter(n => n.id !== id)
    save()
    toast("Note deleted")
  }

  // A new note holding `text`, e.g. from `qs ipc call jot add "..."`.
  function addText(text) {
    if (!text) return
    leaveNote()
    var n = makeNote(text)
    notes = notes.concat([n])
    open(n.id, 1)
  }

  function expire() {
    var days = Config.jot.autoDeleteDays
    if (!loaded || !days || days <= 0) return
    var cutoff = Date.now() / 1000 - days * 86400
    var keep = notes.filter(n => n.modified >= cutoff || n.id === current)
    if (keep.length === notes.length) return
    notes = keep.length ? keep : [makeNote("")]
    if (!find(current)) open(notes[notes.length - 1].id, 0)
    save()
  }

  Timer {
    interval: 3600 * 1000
    running: root.loaded
    repeat: true
    onTriggered: root.expire()
  }

  // ------------------------------------------------------------ disk

  function save() { if (loaded) saveTimer.restart() }

  function flush() {
    if (!loaded) return
    saveTimer.stop()
    notesFile.setText(JSON.stringify({ version: 1, current: current, notes: notes }, null, 1))
  }

  Timer {
    id: saveTimer
    interval: 500
    onTriggered: root.flush()
  }

  function load(raw) {
    var list = [], cur = ""
    if (raw !== null) {
      try {
        var data = JSON.parse(raw)
        list = (data.notes || []).map(n => ({
          id: String(n.id), text: String(n.text || ""), links: n.links || {},
          created: Number(n.created) || Date.now() / 1000, modified: Number(n.modified) || Date.now() / 1000
        }))
        cur = data.current || ""
      } catch (e) {
        // Unreadable: keep it aside rather than overwrite it.
        backup.running = true
        console.warn("jot: notes file unreadable, moved to notes.broken.json:", e)
      }
    } else {
      list = [makeNote(welcome)]
    }
    if (list.length === 0) list = [makeNote("")]
    notes = list
    current = list.some(n => n.id === cur) ? cur : list[list.length - 1].id
    loaded = true
    expire()
    switched(0)
  }

  FileView {
    id: notesFile
    path: root.dataDir + "/notes.json"
    atomicWrites: true
    printErrors: false
    onLoaded: if (!root.loaded) root.load(text())
    onLoadFailed: if (!root.loaded) root.load(null)
  }

  Process {
    id: backup
    command: ["mv", "-f", root.dataDir + "/notes.json", root.dataDir + "/notes.broken.json"]
  }

  // ------------------------------------------------------------ IPC

  IpcHandler {
    target: "jot"
    // A fresh note, with the dropdown opened on it.
    function newNote(): void {
      root.newNote("")
      root.openRequested()
    }
    // Save text as a new note without opening anything.
    function add(text: string): void { root.addText(text) }
  }

  // ------------------------------------------------------------ timer

  // "", "stopwatch", "countdown" or "pomodoro". One at a time.
  property string timerKind: ""
  property real timerStarted: 0     // ms
  property real timerPausedAt: 0    // ms; 0 while running
  property int timerDuration: 0     // s
  property int pomodoroWork: 25 * 60
  property int pomodoroRest: 5 * 60
  property string pomodoroPhase: "work"
  property int pomodoroRounds: 0
  property real now: Date.now()
  readonly property bool timerPaused: timerPausedAt !== 0

  readonly property real elapsed: timerKind === "" ? 0 : Math.max(0, ((timerPaused ? timerPausedAt : now) - timerStarted) / 1000)
  readonly property real remaining: Math.max(0, timerDuration - elapsed)
  // 0 to 1: how far through the countdown, or through the current minute.
  readonly property real progress: timerKind === "countdown" || timerKind === "pomodoro"
    ? (timerDuration ? Math.min(1, elapsed / timerDuration) : 0)
    : (elapsed % 60) / 60
  // The digits stacked in the note's margin: [mm, ss] or [hh, mm].
  readonly property var timerLines: {
    var secs = timerKind === "stopwatch" ? Math.floor(elapsed) : Math.ceil(remaining)
    var h = Math.floor(secs / 3600), m = Math.floor(secs % 3600 / 60), s = secs % 60
    var pad = v => String(v).padStart(2, "0")
    var out = h ? [pad(h), pad(m)] : [pad(m), pad(s)]
    if (timerKind === "pomodoro") out.unshift(pomodoroRounds + "x")
    return out
  }

  function startTimer(cmd) {
    timerPausedAt = 0
    pomodoroPhase = "work"
    pomodoroRounds = 0
    now = Date.now()
    timerStarted = now
    if (cmd.kind === "stopwatch") {
      timerDuration = 0
    } else if (cmd.kind === "countdown") {
      timerDuration = cmd.seconds
    } else {
      pomodoroWork = cmd.work * 60
      pomodoroRest = cmd.rest * 60
      timerDuration = pomodoroWork
    }
    timerKind = cmd.kind
  }

  function stopTimer() { timerKind = "" }

  function togglePause() {
    if (timerKind === "") return
    if (timerPaused) {
      timerStarted += Date.now() - timerPausedAt
      timerPausedAt = 0
    } else {
      timerPausedAt = Date.now()
    }
  }

  function alarm(title, body) {
    Quickshell.execDetached(["notify-send", "-a", "Jot", "-i", "alarm-symbolic", title, body])
    Quickshell.execDetached(["sh", "-c", "command -v canberra-gtk-play >/dev/null && canberra-gtk-play -i alarm-clock-elapsed"])
    toast(body)
  }

  Timer {
    interval: 250
    running: root.timerKind !== ""
    repeat: true
    onTriggered: {
      root.now = Date.now()
      if (root.timerPaused || root.timerKind === "stopwatch" || root.remaining > 0) return
      if (root.timerKind === "countdown") {
        root.timerKind = ""
        root.alarm("Timer done", "Countdown finished")
      } else {
        if (root.pomodoroPhase === "work") {
          root.pomodoroRounds++
          root.pomodoroPhase = "rest"
          root.timerDuration = root.pomodoroRest
          root.alarm("Pomodoro", "Break time · " + root.pomodoroRest / 60 + " min")
        } else {
          root.pomodoroPhase = "work"
          root.timerDuration = root.pomodoroWork
          root.alarm("Pomodoro", "Back to work · " + root.pomodoroWork / 60 + " min")
        }
        root.timerStarted = Date.now()
      }
    }
  }

  // ------------------------------------------------------------ AutoPaste

  // While on, everything copied elsewhere is added to the end of the note
  // that was showing when it was switched on.
  property bool autoPaste: false
  property string autoPasteTarget: ""
  property bool autoPasteSkip: true

  function toggleAutoPaste() {
    autoPaste = !autoPaste
    if (autoPaste) {
      autoPasteTarget = current
      autoPasteSkip = true
    }
    toast(autoPaste ? "AutoPasting clipboard…" : "AutoPaste off")
  }

  function appendTo(id, text) {
    var n = find(id) || note
    if (!n) return
    var clean = Engine.cleanPaste(text).replace(/^\n+|\n+$/g, "")
    if (clean.trim() === "") return
    var body = n.text
    if (body !== "" && !body.endsWith("\n")) body += "\n"
    setText(n.id, body + clean + "\n")
    textReplaced(n.id)
  }

  Process {
    running: root.autoPaste
    // One record per clipboard change, ended by an ASCII record separator.
    command: ["wl-paste", "--type", "text", "--watch", "sh", "-c", "cat; printf '\\036'"]
    stdout: SplitParser {
      splitMarker: "\u001e"
      onRead: function(data) {
        // The first record is what was on the clipboard already.
        if (root.autoPasteSkip) { root.autoPasteSkip = false; return }
        if (root.editorFocused) return
        root.appendTo(root.autoPasteTarget, data)
      }
    }
  }

  // ------------------------------------------------------------ currency

  readonly property bool currencyOn: Config.jot.currency
  onCurrencyOnChanged: loadRates()

  function loadRates() {
    if (!currencyOn) {
      Engine.setRates({})
      engineVersion++
      return
    }
    ratesFile.reload()
  }

  function useRates(raw) {
    var fetched = 0
    try {
      var data = JSON.parse(raw)
      Engine.setRates(data.rates || {})
      fetched = Number(data.fetched) || 0
      engineVersion++
    } catch (e) {}
    if (Date.now() / 1000 - fetched > 20 * 3600) fetchRates.running = true
  }

  FileView {
    id: ratesFile
    path: root.cacheDir + "/rates.json"
    blockLoading: false
    printErrors: false
    preload: false
    onLoaded: if (root.currencyOn) root.useRates(text())
    onLoadFailed: if (root.currencyOn) fetchRates.running = true
  }

  Process {
    id: fetchRates
    command: ["curl", "-fsS", "--max-time", "15", "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml"]
    stdout: StdioCollector {
      onStreamFinished: {
        var rates = { eur: 1 }, re = /currency='(\w+)' rate='([\d.]+)'/g, m, found = false
        while ((m = re.exec(text)) !== null) { rates[m[1].toLowerCase()] = Number(m[2]); found = true }
        if (!found || !root.currencyOn) return
        Engine.setRates(rates)
        root.engineVersion++
        writeRates.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/rates.json\"", "sh",
          root.cacheDir, JSON.stringify({ fetched: Date.now() / 1000, rates: rates })]
        writeRates.running = true
      }
    }
  }

  Process { id: writeRates }

  Timer {
    interval: 6 * 3600 * 1000
    running: root.currencyOn
    repeat: true
    onTriggered: root.loadRates()
  }

  Component.onDestruction: flush()
}
