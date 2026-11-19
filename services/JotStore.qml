pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import "JotEngine.js" as Engine

// Jot's notes, timer, AutoPaste and currency rates. Each note is a Markdown
// file in Config.jot.notesDir (~/Notes), named for when it was started, so
// any editor, grep or git can use them; bin/jot-notes reads and writes the
// folder. Notes in memory: { id (the file name), text, links, created,
// modified, dirty }, times in seconds. The order, the open note and the
// shortened links are kept in ~/.local/share/jot/state.json. Files changed
// or added outside Jot are picked up whenever the dropdown opens. The
// dropdown itself is bar/Jot.qml.
Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string dataDir: home + "/.local/share/jot"
  readonly property string cacheDir: home + "/.cache/jot"
  readonly property string notesDir: String(Config.jot.notesDir || "~/Notes").replace(/^~(?=\/|$)/, home)
  readonly property string helper: Quickshell.shellDir + "/bin/jot-notes"

  // The note's colours: the shell theme's own ("shell", the default), or
  // any of the desktop themes in themes/ (Settings › Jot › Colours, Ctrl+T),
  // the paper a step lighter than the shell's popups, the syntax in the
  // theme's terminal colours.
  readonly property string themesDir: Quickshell.shellDir + "/themes"
  // [{ name, colors }] for every desktop theme, read once at start.
  property var themes: []
  readonly property string themeName: themes.some(t => t.name === Config.jot.theme) ? Config.jot.theme : "shell"
  readonly property var themeColors: {
    var t = themes.find(t => t.name === themeName)
    return t ? t.colors : Theme.colors
  }

  // A palette from a colors.toml map, falling back to the shell theme.
  function palette(c) {
    c = c || {}
    function k(name, fallback) { return c[name] !== undefined ? c[name] : fallback }
    var fg = k("foreground", Theme.foreground), muted = k("muted", Theme.muted), accent = k("accent", Theme.accent)
    var magenta = k("magenta", accent), cyan = k("cyan", accent), blue = k("blue", accent)
    return {
      bg: k("lighter_background", Theme.surface), fg: fg, dim: k("dark_foreground", Theme.dim), accent: accent,
      caret: accent, selection: k("selection", Theme.selection),
      keyword: accent, listKeyword: magenta, variable: cyan, colon: magenta, reference: blue,
      result: k("green", Theme.green), link: blue, check: k("dark_foreground", Theme.dim), checkDone: magenta,
      done: muted, doneMark: Theme.alpha(muted, 0.7),
      timer: k("dark_foreground", Theme.dim), railOn: accent, railOff: Theme.alpha(fg, 0.1),
      toastBg: k("background", Theme.background), toastFg: fg, badgeBg: k("background", Theme.background),
      edge: accent, clip: k("green", Theme.green), icon: k("dark_foreground", Theme.dim), border: accent,
      hover: Theme.alpha(fg, 0.08), margin: k("red", Theme.red), rule: blue
    }
  }
  readonly property var pal: palette(themeColors)

  // The next (or previous) choice, "shell" first, for Ctrl+T.
  function cycleTheme(step) {
    var names = ["shell"].concat(themes.map(t => t.name))
    var at = Math.max(0, names.indexOf(themeName))
    Config.jot.theme = names[(at + step + names.length) % names.length]
    return Config.jot.theme === "shell" ? "Shell theme" : Config.jot.theme
  }

  Process {
    running: true
    command: ["sh", "-c", "for f in \"$1\"/*/colors.toml; do printf '== %s\\n' \"$(basename \"$(dirname \"$f\")\")\"; cat \"$f\"; echo; done", "sh", root.themesDir]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = [], cur = null
        text.split("\n").forEach(function(line) {
          var head = line.match(/^== (.+)$/)
          if (head) { cur = { name: head[1], colors: {} }; list.push(cur); return }
          var m = cur && line.match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["'](#[0-9A-Fa-f]{6})["']/)
          if (m) cur.colors[m[1]] = m[2]
        })
        root.themes = list
      }
    }
  }

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
  // The note's text colour, for ui/JotLabel.qml.
  readonly property color ink: pal.fg

  readonly property string welcome: "Hi, this is Jot.\n\n"
    + "Jot is for the scraps: numbers, links, lists, half-thoughts. No titles, no folders. "
    + "Notes nobody touches for a month quietly go away.\n\n"
    + "Ctrl+[ or a sideways swipe goes back a note, Ctrl+] forward, Ctrl+N starts a new one.\n\n"
    + "Try a keyword on the first line: math, list, sum, count. Or type \"timer 5m\" on a line and press Enter.\n\n"
    + "Right-click the note button for settings.\n"

  // A new note, named for now: 2026-11-19-141502.md.
  function makeNote(text) {
    var now = new Date()
    var base = Qt.formatDateTime(now, "yyyy-MM-dd-HHmmss"), id = base + ".md"
    for (var n = 2; find(id) || trash.indexOf(id) >= 0; n++) id = base + "-" + n + ".md"
    return { id: id, text: text || "", links: {}, created: now / 1000, modified: now / 1000, dirty: ++editSeq }
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
  // ------------------------------------------------------------ notes

  // The engine, shared with the dropdown so both see the same keywords and rates.
  function engine() { return Engine }

  function find(id) { return notes.find(n => n.id === id) || null }

  function setText(id, text) {
    var n = find(id)
    if (!n || n.text === text) return
    n.text = text
    n.modified = Date.now() / 1000
    n.dirty = ++editSeq
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
    discard([n.id])
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

  // Antinote's Promote: this note moves to the front and becomes the newest.
  function promote() {
    var n = note
    if (!n) return
    if (index === notes.length - 1) { toast("Already the newest note"); return }
    n.modified = Date.now() / 1000
    notes = notes.filter(x => x !== n).concat([n])
    save()
    toast("Moved to the front")
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
    discard([notes[at].id])
    var rest = notes.filter((x, i) => i !== at)
    if (rest.length === 0) rest = [makeNote("")]
    notes = rest
    open(rest[Math.min(at, rest.length - 1)].id, -1)
    toast("Note deleted")
  }

  // Delete any note, from the notes list.
  function deleteById(id) {
    if (id === current) { deleteNote(); return }
    discard([id])
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
    discard(notes.filter(n => keep.indexOf(n) < 0).map(n => n.id))
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
  //
  // Edits are written a moment later by bin/jot-notes. Each edit gets a
  // number (editSeq); a note stays dirty until a sync that included its
  // latest edit has finished, so nothing typed during a sync is lost.
  // Deleted notes go to the desktop trash.

  property int editSeq: 0
  property var trash: []
  // The edit number the running sync covers.
  property int syncSeq: 0
  property bool syncAgain: false

  function discard(ids) {
    trash = trash.concat(ids)
    save()
  }

  function save() { if (loaded) saveTimer.restart() }

  function snapshot(withText) {
    return JSON.stringify({
      current: current,
      notes: notes.map(n => ({ id: n.id, created: n.created, modified: n.modified, links: n.links,
        dirty: !!n.dirty, text: n.dirty || withText ? n.text : "" })),
      trash: trash
    })
  }

  function flush() {
    if (!loaded) return
    saveTimer.stop()
    if (syncProc.running) { syncAgain = true; return }
    syncSeq = editSeq
    syncProc.sentTrash = trash.slice()
    snapshotFile.setText(snapshot(false))
  }

  Timer {
    id: saveTimer
    interval: 500
    onTriggered: root.flush()
  }

  FileView {
    id: snapshotFile
    path: root.dataDir + "/sync.json"
    atomicWrites: true
    printErrors: false
    onSaved: syncProc.running = true
    onSaveFailed: console.warn("jot: could not write", path)
  }

  Process {
    id: syncProc
    property var sentTrash: []
    command: [root.helper, "sync", root.notesDir, root.dataDir + "/state.json", root.dataDir + "/sync.json"]
    stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.warn("jot-notes:", text.trim()) }
    onExited: function(code) {
      if (code === 0) {
        for (var i = 0; i < root.notes.length; i++)
          if (root.notes[i].dirty && root.notes[i].dirty <= root.syncSeq) root.notes[i].dirty = 0
        var sent = sentTrash
        root.trash = root.trash.filter(id => sent.indexOf(id) < 0)
      }
      if (root.syncAgain) {
        root.syncAgain = false
        root.flush()
      } else if (root.notes.some(n => n.dirty) || root.trash.length) {
        // Failed, or edited while it ran: try again shortly.
        root.save()
      }
    }
  }

  // The folder may have changed since (edited in another editor, notes
  // copied in or deleted): read it again, keeping anything not yet written.
  function rescan() {
    if (!loaded || loadProc.running) return
    if (saveTimer.running || syncProc.running || notes.some(n => n.dirty) || trash.length) {
      flush()
      rescanTimer.restart()
      return
    }
    loadProc.running = true
  }

  Timer {
    id: rescanTimer
    interval: 300
    onTriggered: root.rescan()
  }

  // A different folder: read the notes from there instead. Files are not
  // moved; that is left to whoever changed it.
  onNotesDirChanged: {
    if (!loaded) return
    loaded = false
    notes = []
    trash = []
    loadProc.running = true
  }

  function apply(raw) {
    var data
    try {
      data = JSON.parse(raw)
    } catch (e) {
      console.warn("jot: could not read the notes folder:", e)
      if (!loaded) { notes = [makeNote("")]; current = notes[0].id; loaded = true; switched(0) }
      return
    }
    var disk = (data.notes || []).map(n => ({
      id: String(n.id), text: String(n.text || ""), links: n.links || {},
      created: Number(n.created) || Date.now() / 1000, modified: Number(n.modified) || Date.now() / 1000, dirty: 0
    }))
    if (!loaded) {
      var first = disk.length === 0 && !data.current
      var list = disk.length ? disk : [makeNote(first ? welcome : "")]
      notes = list
      current = list.some(n => n.id === data.current) ? data.current : list[list.length - 1].id
      loaded = true
      expire()
      switched(0)
      return
    }
    // A rescan: the disk wins for notes Jot has no unsaved edits to.
    var byId = {}, changed = false, shownChanged = false
    disk.forEach(n => byId[n.id] = n)
    var merged = []
    notes.forEach(function(n) {
      var d = byId[n.id]
      delete byId[n.id]
      if (!d) {
        // Gone from the folder: deleted outside Jot. Blank notes never had a file.
        if (n.dirty || n.text.trim() === "") merged.push(n)
        else changed = true
        return
      }
      if (!n.dirty && d.text !== n.text) {
        n.text = d.text
        n.modified = d.modified
        changed = true
        if (n.id === current) shownChanged = true
      }
      merged.push(n)
    })
    disk.forEach(function(d) { if (byId[d.id]) { merged.push(d); changed = true } })
    if (!changed) return
    if (merged.length === 0) merged = [makeNote("")]
    notes = merged
    if (!find(current)) open(notes[notes.length - 1].id, 0)
    else if (shownChanged) textReplaced(current)
  }

  Process {
    id: loadProc
    command: [root.helper, "load", root.notesDir, root.dataDir + "/state.json", root.dataDir + "/notes.json"]
    stdout: StdioCollector { onStreamFinished: root.apply(text) }
    stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.warn("jot-notes:", text.trim()) }
  }

  Component.onCompleted: {
    Engine.setKeywords(keywordConfig)
    loadRates()
    loadProc.running = true
  }

  // On the way out (a shell reload) there is no waiting for a Process, so
  // anything unwritten goes straight to the helper.
  Component.onDestruction: {
    if (!loaded || (!notes.some(n => n.dirty) && trash.length === 0 && !saveTimer.running)) return
    Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2.tmp\" && mv -f \"$2.tmp\" \"$2\" && exec \"$3\" sync \"$4\" \"$5\" \"$2\"",
      "sh", snapshot(false), dataDir + "/sync.json", helper, notesDir, dataDir + "/state.json"])
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

}
