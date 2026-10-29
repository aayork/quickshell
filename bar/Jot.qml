import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import qs.theme
import qs.ui

// Jot, a scratchpad that drops from the bar (Antinote-style). Notes have no
// titles; a keyword on the first line switches a feature on (math, list,
// sum, avg, count), "timer 5m" on a line starts a timer, and Ctrl+[ / Ctrl+]
// or a sideways swipe move between notes. The notes, timer and AutoPaste
// live in services/JotStore.qml; the text logic in services/JotEngine.js.
//
// The editor is a plain TextEdit with see-through text, laid over a rich
// text copy of the same characters in the theme's colours; both lay out the
// same, so the colours line up with what is typed.
BarButton {
  id: root

  readonly property alias popup: popup
  readonly property var engine: JotStore.engine()

  property bool pinned: false
  property bool loading: false
  // Set by an undo, so the result the user just took back is not put back.
  property bool holdEngine: false
  property string html: ""
  property var checks: []
  property var names: []
  property string stats: ""
  property var completion: null
  property bool searching: false
  property string query: ""
  property real swipe: 0
  property bool swipeLocked: false
  property string toastText: ""
  property bool caretOn: true
  // Own undo history, [{ text, cursor }]: the editor's is lost whenever its
  // text is set again (see setPlain).
  property var history: []
  property int historyAt: 0
  // A link under the pointer, for the tooltip: { url, short, x, y } or null.
  property var hoverLink: null

  // Antinote's measurements (its 360x412 note): text 47 px in from the left,
  // 46 from the right, the first line's baseline 50 px down.
  readonly property int gutter: 47
  readonly property int padTop: Math.round(50 - rowMetrics.ascent)
  readonly property int padBottom: 40
  readonly property int padRight: 46

  // Antinote's font is SF Mono; Geist Mono is the closest one here.
  readonly property string fontFamily: "GeistMono Nerd Font Mono"

  // Antinote's default look, sampled from its own screenshots. The note is
  // the same whatever the desktop theme.
  readonly property var pal: ({
    bg: "#fdfdfd", fg: "#36312e", dim: "#9a9a9a", accent: "#1e7e7a",
    caret: "#113b51", selection: "#cfe3f5",
    keyword: "#103345", listKeyword: "#b353e2",
    variable: "#1e7e7a", colon: "#9848bc", reference: "#3f9aa3", result: "#449921",
    link: "#004a8a", check: "#4f4c4b", checkDone: "#dab3ec", done: "#ababab", doneMark: "#d6d6d6",
    timer: "#9a9a9a", railOn: "#9848bc", railOff: "#e2e2e2",
    toastBg: "#302d26", toastFg: "#ffffff", badgeBg: "#2c2c2c", edge: "#fde9cc",
    clip: "#5cb85c", icon: "#8a8a8a", border: "#1a000000"
  })
  readonly property string paper: Config.jot.paper
  // The keyword takes its feature's colour, as in Antinote: navy for math,
  // purple for lists.
  readonly property var colors: ({
    keyword: pal.keyword, colon: pal.colon, variable: pal.variable, reference: pal.reference,
    result: pal.result, link: pal.link, done: pal.done, doneMark: pal.doneMark
  })
  function colorsFor(mode) {
    return mode === "list" ? Object.assign({}, colors, { keyword: pal.listKeyword }) : colors
  }
  onColorsChanged: if (popup.open) refresh()
  property bool picking: false

  text: Icons.glyph(0xF039B)
  active: popup.open
  onClicked: function(button) {
    if (button === Qt.RightButton) PopupState.request("settings:jot")
    else popup.toggle()
  }

  // ------------------------------------------------------------ the editor's text
  //
  // The editor is rich text only so its lines can be spaced out (QML's plain
  // TextEdit has no line height). The whole note is one paragraph with line
  // breaks (U+2028) between lines, so empty lines survive; text only ever
  // goes in through these helpers, as escaped plain text.

  readonly property string lineBreak: String.fromCharCode(0x2028)
  readonly property string paragraphBreak: String.fromCharCode(0x2029)
  // Line spacing is a multiple of the font size (Antinote's is about 1.63);
  // Qt's percentage is of the font's own line height, hence the conversion.
  readonly property string blockStyle: "margin:0; white-space:pre-wrap; line-height:"
    + Math.round(Config.jot.lineSpacing * Config.jot.fontSize / Math.max(1, rowMetrics.height) * 100) + "%"
  onBlockStyleChanged: if (popup.open) setPlain(plain(), editor.cursorPosition, false)

  function escapeHtml(t) {
    return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\n/g, "<br>")
  }

  // The note as typed, with "\n" between lines.
  function plain() {
    return editor.getText(0, editor.length).split(lineBreak).join("\n").split(paragraphBreak).join("\n")
  }

  // Replace everything (keeps the line spacing; clears Qt's undo history,
  // which is why Jot keeps its own).
  function setPlain(text, cursor, asEdit) {
    loading = true
    editor.text = "<p style=\"" + blockStyle + "\">" + escapeHtml(text) + "</p>"
    editor.cursorPosition = Math.max(0, Math.min(cursor, editor.length))
    loading = false
    if (asEdit) edited()
  }

  // Inserting at the very start makes Qt drop the paragraph's line spacing,
  // so there the whole text is set again instead.
  function insertAt(pos, text) {
    if (pos <= 0) {
      var all = plain()
      setPlain(text + all, text.length, true)
      return
    }
    editor.insert(pos, "<span style=\"white-space:pre-wrap\">" + escapeHtml(text) + "</span>")
  }

  function removeRange(from, to) {
    if (to > from) editor.remove(from, to)
  }

  function replaceRange(from, to, text) {
    if (from <= 0) {
      var all = plain()
      setPlain(text + all.slice(to), text.length, true)
      return
    }
    removeRange(from, to)
    if (text !== "") insertAt(from, text)
  }

  function insertAtCursor(text) {
    if (editor.selectedText !== "") {
      var from = editor.selectionStart
      replaceRange(from, editor.selectionEnd, text)
      editor.cursorPosition = from + text.length
    } else {
      var at = editor.cursorPosition
      insertAt(at, text)
      editor.cursorPosition = at + text.length
    }
  }

  function selectedPlain() {
    return editor.selectedText.split(lineBreak).join("\n").split(paragraphBreak).join("\n")
  }

  // ------------------------------------------------------------ notes

  function loadNote(direction) {
    var n = JotStore.note
    if (!n) return
    setPlain(n.text, n.text.length, false)
    history = [{ text: n.text, cursor: n.text.length }]
    historyAt = 0
    completion = null
    hoverLink = null
    refresh()
    if (direction) flash(direction)
  }

  function edited() {
    if (loading) return
    // Something cost the paragraph its spacing: put it back, just after.
    if (editor.text.indexOf("line-height") === -1) Qt.callLater(root.repairSpacing)
    JotStore.setText(JotStore.current, plain())
    snapshot.restart()
    Qt.callLater(root.refresh)
  }

  function repairSpacing() {
    if (editor.text.indexOf("line-height") === -1) setPlain(plain(), editor.cursorPosition, false)
  }

  // A pause in typing ends an undo step.
  function commitHistory() {
    snapshot.stop()
    var text = plain()
    if (history.length && history[historyAt].text === text) return
    var list = history.slice(0, historyAt + 1)
    list.push({ text: text, cursor: editor.cursorPosition })
    if (list.length > 200) list.shift()
    history = list
    historyAt = list.length - 1
  }

  Timer {
    id: snapshot
    interval: 700
    onTriggered: root.commitHistory()
  }

  // Start of each line, from the editor's text.
  function lineStarts(lines) {
    var starts = [], at = 0
    for (var i = 0; i < lines.length; i++) { starts.push(at); at += lines[i].length + 1 }
    return starts
  }

  function lineAt(starts, pos) {
    var i = starts.length - 1
    while (i > 0 && starts[i] > pos) i--
    return i
  }

  function refresh() {
    if (!engine || !popup.open) return
    var text = plain()
    var lines = text.split("\n")
    var mode = engine.modeOf(text)
    if (mode === "math") {
      var res = engine.analyse(lines)
      if (!holdEngine && res.infos.some(i => i.newText !== null)) {
        applyResults(lines, res.infos)
        text = plain()
        lines = text.split("\n")
        res = engine.analyse(lines)
      }
      names = engine.variableNames(lines, res.infos)
    } else {
      names = []
    }
    holdEngine = false
    html = engine.highlight(text, colorsFor(mode), blockStyle)
    var starts = lineStarts(lines)
    var list = []
    if (mode === "list")
      for (var i = 1; i < lines.length; i++)
        if (lines[i].trim() !== "") list.push({ line: i, pos: starts[i], done: engine.isDone(lines[i]) })
    checks = list
    stats = engine.stats(text)
    updateCompletion()
  }

  // Write the math engine's results after each "=", keeping the cursor.
  function applyResults(lines, infos) {
    var starts = lineStarts(lines)
    var cursorLine = lineAt(starts, editor.cursorPosition)
    var cursorCol = editor.cursorPosition - starts[cursorLine]
    var toEnd = false
    for (var i = infos.length - 1; i >= 0; i--) {
      var next = infos[i].newText
      if (next === null) continue
      var old = lines[i], n = 0
      while (n < old.length && n < next.length && old[n] === next[n]) n++
      replaceRange(starts[i] + n, starts[i] + old.length, next.slice(n))
      if (i === cursorLine && cursorCol >= n) toEnd = true
    }
    if (toEnd) {
      var now = plain().split("\n")
      editor.cursorPosition = lineStarts(now)[cursorLine] + now[cursorLine].length
    }
  }

  function replaceLine(index, text) {
    var lines = plain().split("\n")
    var start = lineStarts(lines)[index]
    var cursor = editor.cursorPosition
    replaceRange(start, start + lines[index].length, text)
    editor.cursorPosition = Math.min(cursor, editor.length)
  }

  function cursorLine() {
    var lines = plain().split("\n")
    var starts = lineStarts(lines)
    var i = lineAt(starts, editor.cursorPosition)
    return { index: i, start: starts[i], text: lines[i] }
  }

  function toggleDone(index) {
    var line = plain().split("\n")[index]
    if (index > 0 && line.trim() !== "") replaceLine(index, engine.toggleDone(line))
  }

  // "timer 5m", "stopwatch", "pomodoro", "timer stop" on its own line.
  function maybeTimer() {
    var line = cursorLine()
    var cmd = engine.parseTimer(line.text)
    if (!cmd) return false
    var msg
    if (cmd.kind === "stop") {
      msg = JotStore.timerKind !== "" ? "Timer stopped" : "No timer running"
      JotStore.stopTimer()
    } else {
      JotStore.startTimer(cmd)
      msg = cmd.kind === "stopwatch" ? "Stopwatch started"
        : cmd.kind === "countdown" ? engine.formatSeconds(cmd.seconds) + " timer started"
        : cmd.work + "/" + cmd.rest + " Pomodoro started"
    }
    replaceRange(line.start, line.start + line.text.length, "")
    showToast(msg)
    return true
  }

  function updateCompletion() {
    completion = editor.selectedText === "" ? engine.completion(plain(), editor.cursorPosition, names) : null
  }

  // ------------------------------------------------------------ links, paste

  function makeToken(url) {
    var links = Object.assign({}, JotStore.note.links)
    var base = engine.shortenUrl(url), token = base, n = 2
    while (links[token] !== undefined && links[token] !== url) token = base.slice(0, -1) + (n++) + "+"
    links[token] = url
    JotStore.setLinks(JotStore.current, links)
    return token
  }

  function insertPlain(text) {
    var clean = engine.cleanPaste(text)
    var bare = clean.trim()
    if (/^https?:\/\/\S+$/.test(bare) && bare.length > 40) clean = makeToken(bare)
    insertAtCursor(clean)
  }

  function paste() {
    var text = Quickshell.clipboardText
    if (text !== "") {
      insertPlain(text)
    } else {
      showToast("Reading text…")
      ocr.running = true
    }
  }

  // The link under a point in the editor: { start, end, text } or null.
  function linkAt(x, y) {
    var pos = editor.positionAt(x, y)
    // positionAt finds the nearest character even past a line's end.
    var r = editor.positionToRectangle(pos)
    if (Math.abs(r.x - x) > editor.font.pixelSize || y < r.y - 2 || y > r.y + r.height + 2) return null
    var lines = plain().split("\n")
    var starts = lineStarts(lines)
    var i = lineAt(starts, pos)
    var col = pos - starts[i]
    var span = engine.linkSpans(lines[i]).find(s => col >= s[0] && col < s[1])
    if (!span) return null
    return { start: starts[i] + span[0], end: starts[i] + span[1], text: lines[i].slice(span[0], span[1]) }
  }

  function openLink(x, y) {
    var link = linkAt(x, y)
    if (!link) return
    var links = JotStore.note.links || {}
    Qt.openUrlExternally(links[link.text] !== undefined ? links[link.text] : link.text)
    if (!pinned) popup.close()
  }

  // Ctrl+Alt+click: a long link to its short token, or back.
  function toggleLinkForm(x, y) {
    var link = linkAt(x, y)
    if (!link) return
    var links = Object.assign({}, JotStore.note.links)
    var replacement
    if (links[link.text] !== undefined) {
      replacement = links[link.text]
      delete links[link.text]
      JotStore.setLinks(JotStore.current, links)
    } else {
      replacement = makeToken(link.text)
    }
    replaceRange(link.start, link.end, replacement)
  }

  // ------------------------------------------------------------ actions

  function expandedText() {
    return engine.expandLinks(plain(), JotStore.note ? JotStore.note.links : {})
  }

  function copyNote() {
    Quickshell.clipboardText = expandedText()
    showToast("Note copied")
  }

  function exportNote() {
    var text = expandedText()
    if (text.trim() === "") { showToast("Nothing to export"); return }
    var home = Quickshell.env("HOME")
    var dir = Config.jot.exportDir.replace(/^~(?=\/|$)/, home)
    var file = dir + "/" + engine.exportName(text) + " " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HHmm") + ".md"
    Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s\\n' \"$2\" > \"$3\"", "sh", dir, text.replace(/\n+$/, ""), file])
    showToast("Saved to " + file.replace(home, "~"))
  }

  function undo(redo) {
    commitHistory()
    var to = historyAt + (redo ? 1 : -1)
    if (to < 0 || to >= history.length) return
    historyAt = to
    // The result the user just took back is not put straight back.
    holdEngine = true
    setPlain(history[to].text, history[to].cursor, true)
  }

  // Shows a link's full address while the pointer rests on it.
  function hoverAt(x, y) {
    var link = linkAt(x, y)
    if (!link) { hoverLink = null; return }
    var links = JotStore.note ? JotStore.note.links : {}
    var url = links[link.text] !== undefined ? links[link.text] : link.text
    hoverLink = { url: url, short: links[link.text] !== undefined, x: x, y: y }
  }

  // Files or text dropped on the note: text files and dropped text go in as
  // they are, images through tesseract.
  function dropped(drop) {
    var p = editor.mapFromItem(body, drop.x, drop.y)
    editor.cursorPosition = editor.positionAt(p.x, p.y)
    if (drop.hasUrls) {
      var paths = drop.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).filter(p => p.indexOf("/") === 0)
      if (paths.length) {
        showToast("Reading…")
        reader.command = ["sh", "-c", "for f; do case $(file -b --mime-type \"$f\") in "
          + "text/*|application/json|application/xml) head -c 200000 \"$f\"; echo;; "
          + "image/*) tesseract \"$f\" - 2>/dev/null;; esac; done", "sh"].concat(paths)
        reader.running = true
        drop.accept()
        return
      }
    }
    if (drop.hasText) {
      insertPlain(drop.text)
      drop.accept()
    }
  }

  function zoom(step) {
    Config.jot.fontSize = step === 0 ? 14 : Math.max(9, Math.min(28, Config.jot.fontSize + step))
  }

  function showToast(text) {
    toastText = text
    toastTimer.restart()
  }

  function flash(direction) {
    edge.x = direction > 0 ? body.width - edge.width : 0
    edgeFade.restart()
  }

  // The notes list (Ctrl+F, Ctrl+K or the list button): every note, newest
  // first, filtered by what is typed; arrows move, Enter opens.
  function openSearch() {
    picking = false
    query = ""
    searching = true
    selected = Math.max(0, results.findIndex(r => r.current))
    Qt.callLater(function() {
      searchInput.forceActiveFocus()
      noteList.positionViewAtIndex(root.selected, ListView.Contain)
    })
  }

  function moveSelection(step) {
    if (results.length === 0) return
    selected = Math.max(0, Math.min(results.length - 1, selected + step))
    noteList.positionViewAtIndex(selected, ListView.Contain)
  }

  function ago(seconds) {
    var d = Date.now() / 1000 - seconds
    if (d < 60) return "now"
    if (d < 3600) return Math.floor(d / 60) + "m"
    if (d < 86400) return Math.floor(d / 3600) + "h"
    if (d < 86400 * 7) return Math.floor(d / 86400) + "d"
    return Qt.formatDate(new Date(seconds * 1000), "MMM d")
  }

  function closeSearch() {
    if (!searching) return
    searching = false
    editor.forceActiveFocus()
  }

  function openFromSearch(id) {
    var from = JotStore.index
    closeSearch()
    if (id === JotStore.current) return
    var to = JotStore.notes.findIndex(n => n.id === id)
    JotStore.leaveNote()
    JotStore.open(id, to > from ? 1 : -1)
  }

  property int selected: 0
  onQueryChanged: selected = 0
  readonly property var results: {
    if (!searching) return []
    var q = query.trim().toLowerCase()
    var list = JotStore.notes.slice().reverse()
    if (q !== "") list = list.filter(n => n.text.toLowerCase().indexOf(q) !== -1)
    return list.map(function(n) {
      var lines = n.text.split("\n").filter(l => l.trim() !== "")
      // A keyword line is shown as the tag; the title is what follows it.
      var head = lines.length ? engine.header(lines[0]) : null
      if (head) {
        var named = head.colon >= 0 ? lines[0].slice(head.colon + 1).trim() : ""
        lines = named !== "" ? [named].concat(lines.slice(1)) : lines.slice(1)
      }
      var snippet = ""
      if (q !== "") {
        var at = n.text.toLowerCase().indexOf(q)
        var from = Math.max(0, at - 20)
        if (from > 0) {
          var space = n.text.indexOf(" ", from)
          from = space !== -1 && space < at ? space + 1 : at
        }
        snippet = n.text.slice(from, at + 50).replace(/\n/g, " · ").trim()
      } else if (lines.length > 1) {
        snippet = lines[1].trim()
      }
      return {
        id: n.id, title: lines.length ? lines[0].trim() : "Empty note", snippet: snippet,
        mode: engine.modeOf(n.text), ago: root.ago(n.modified), current: n.id === JotStore.current
      }
    })
  }

  function key(event) {
    var ctrl = event.modifiers & Qt.ControlModifier
    var shift = event.modifiers & Qt.ShiftModifier
    var alt = event.modifiers & Qt.AltModifier
    var k = event.key
    if (k === Qt.Key_Escape) {
      if (picking) picking = false
      else if (searching) closeSearch()
      else popup.close()
      event.accepted = true
      return
    }
    if (ctrl && !alt) {
      if (k === Qt.Key_BracketLeft) JotStore.go(-1)
      else if (k === Qt.Key_BracketRight && !shift) JotStore.go(1)
      else if (k === Qt.Key_BraceRight || (k === Qt.Key_BracketRight && shift)) JotStore.goFront(false)
      else if (k === Qt.Key_BraceLeft) JotStore.goOldest()
      else if (k === Qt.Key_N) JotStore.newNote("")
      else if (k === Qt.Key_Z) undo(shift)
      else if (k === Qt.Key_Y) undo(true)
      else if (k === Qt.Key_S) exportNote()
      else if (k === Qt.Key_C && shift) copyNote()
      else if (k === Qt.Key_P) pinned = !pinned
      else if (k === Qt.Key_V && shift) JotStore.toggleAutoPaste()
      else if (k === Qt.Key_V) paste()
      // Copy and cut as plain text: the editor's own would carry its
      // see-through colour into whatever the text is pasted into.
      else if (k === Qt.Key_C && editor.selectedText !== "") Quickshell.clipboardText = selectedPlain()
      else if (k === Qt.Key_X && editor.selectedText !== "") {
        Quickshell.clipboardText = selectedPlain()
        replaceRange(editor.selectionStart, editor.selectionEnd, "")
      }
      else if (k === Qt.Key_C || k === Qt.Key_X) {}
      else if (k === Qt.Key_F || k === Qt.Key_K) openSearch()
      else if (k === Qt.Key_D && shift) JotStore.deleteNote()
      else if (k === Qt.Key_Return || k === Qt.Key_Enter) toggleDone(cursorLine().index)
      else if (k === Qt.Key_Comma) PopupState.request("settings:jot")
      else if (k === Qt.Key_Equal || k === Qt.Key_Plus) zoom(1)
      else if (k === Qt.Key_Minus) zoom(-1)
      else if (k === Qt.Key_0) zoom(0)
      else return
      event.accepted = true
      return
    }
    // Enter is a line break in the one paragraph, never a new paragraph.
    if ((k === Qt.Key_Return || k === Qt.Key_Enter) && !alt) {
      if (shift || !maybeTimer()) insertAtCursor("\n")
      event.accepted = true
      return
    }
    if (k === Qt.Key_Insert && shift) {
      paste()
      event.accepted = true
      return
    }
    if (k === Qt.Key_Tab && !shift && completion) {
      insertAtCursor(completion.insert)
      event.accepted = true
    }
  }

  Connections {
    target: JotStore
    function onSwitched(direction) { if (popup.open) root.loadNote(direction) }
    function onTextReplaced(id) { if (popup.open && id === JotStore.current) root.loadNote(0) }
    function onToast(text) { if (popup.open) root.showToast(text) }
    function onEngineVersionChanged() { if (popup.open) root.refresh() }
    // `qs ipc call jot newNote`: open on the focused monitor only.
    function onOpenRequested() {
      var window = root.QsWindow.window
      if (!popup.open && window && Hyprland.monitorFor(window.screen) === Hyprland.focusedMonitor) popup.open = true
    }
  }

  Process {
    id: reader
    stdout: StdioCollector {
      onStreamFinished: {
        var found = text.replace(/\f/g, "").replace(/\n{3,}/g, "\n\n").replace(/\n+$/, "")
        if (found.trim() !== "") root.insertPlain(found + "\n")
        else root.showToast("Nothing to add from that")
      }
    }
  }

  // Image on the clipboard: its text, through tesseract.
  Process {
    id: ocr
    command: ["sh", "-c", "wl-paste --list-types 2>/dev/null | grep -q '^image/' || exit 0; "
      + "t=$(mktemp --suffix .png); wl-paste --type image/png > \"$t\" 2>/dev/null && tesseract \"$t\" - 2>/dev/null; rm -f \"$t\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var found = text.replace(/\f/g, "").replace(/\n{3,}/g, "\n\n").trim()
        if (found !== "") {
          root.insertPlain(found)
          root.showToast("Text from image added")
        } else {
          root.showToast("Nothing to paste")
        }
      }
    }
  }

  FloatingPopup {
    id: popup
    anchorItem: root
    contentWidth: Config.jot.width
    contentHeight: Config.jot.height
    keepOpen: root.pinned
    inset: 0
    cardColor: root.pal.bg
    borderColor: root.pal.border
    borderWidth: 1
    cornerRadius: 12
    shadow: true
    // Dragged by its top strip, as Antinote's window is; remembered.
    offsetX: chromeDrag.pressed ? chromeDrag.liveX : Config.jot.offsetX
    offsetY: chromeDrag.pressed ? chromeDrag.liveY : Config.jot.offsetY

    onOpenChanged: {
      if (open) {
        if (Config.jot.openOn === "newest") JotStore.goFront(true)
        root.loadNote(0)
        Qt.callLater(() => editor.forceActiveFocus())
      } else {
        root.searching = false
        root.picking = false
        if (JotStore.leaveNote()) JotStore.open(JotStore.notes[JotStore.notes.length - 1].id, 0)
        JotStore.flush()
      }
    }

    Binding {
      target: JotStore
      property: "editorFocused"
      value: popup.grabbing
      when: popup.open
    }

    Item {
      id: content
      objectName: "jotContent"
      anchors.fill: parent

      // As in Antinote, the note's buttons stay out of sight until the
      // pointer comes to the top edge (or a panel of theirs is open).
      readonly property bool chromeShown: (topHover.hovered && topHover.point.position.y < root.padTop + 6)
        || chromeHover.hovered || chromeDrag.pressed || root.picking || root.searching
      HoverHandler { id: topHover }

      Item {
        id: body
        anchors.fill: parent
        clip: true

        // Paper: drawn behind the text and moved with its scrolling, cut to
        // the note's round corners.
        Canvas {
          id: paperCanvas
          anchors.fill: parent
          visible: root.paper === "lines" || root.paper === "dots" || root.paper === "ruled"
          readonly property var look: [root.paper, width, height, pitchProbe.pitch, rowMetrics.ascent, root.gutter, flick.contentY]
          onLookChanged: requestPaint()
          // The paper is laid out from the text, as Antinote's is: letters
          // stand on it. Grid squares are half a line tall with a line on
          // every baseline (so capitals fill a square); dots sit on the
          // baseline, a line apart both ways; rules run along the baseline.
          // All start from the text's left edge.
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (!visible) return
            ctx.beginPath()
            ctx.roundedRect(0, 0, width, height, 11, 11)
            ctx.clip()
            var pitch = pitchProbe.pitch
            var baseline = root.padTop + rowMetrics.ascent - flick.contentY
            var left = root.gutter
            // First position at or before 0 on a lattice through `at`.
            function from(at, step) { return at - Math.ceil(at / step) * step }
            if (root.paper === "ruled") {
              ctx.fillStyle = Theme.alpha(root.pal.fg, 0.1)
              for (var ry = from(baseline, pitch); ry < height; ry += pitch) ctx.fillRect(0, Math.round(ry), width, 1)
            } else if (root.paper === "lines") {
              var cell = pitch / 2
              ctx.fillStyle = Theme.alpha(root.pal.fg, 0.07)
              for (var gy = from(baseline, cell); gy < height; gy += cell) ctx.fillRect(0, Math.round(gy), width, 1)
              for (var gx = from(left, cell); gx < width; gx += cell) ctx.fillRect(Math.round(gx), 0, 1, height)
            } else {
              ctx.fillStyle = Theme.alpha(root.pal.fg, 0.16)
              for (var dy = from(baseline, pitch); dy < height; dy += pitch)
                for (var dx = from(left, pitch); dx < width; dx += pitch) ctx.fillRect(Math.round(dx) - 1, Math.round(dy) - 1, 2, 2)
            }
          }
        }

        Flickable {
          id: flick
          anchors.fill: parent
          contentWidth: width
          contentHeight: Math.max(height, editor.contentHeight + root.padTop + root.padBottom)
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick

          function ensureVisible(r) {
            var top = r.y + root.padTop, bottom = top + r.height
            if (top < contentY) contentY = top - 4
            else if (bottom > contentY + height) contentY = Math.min(contentHeight - height, bottom - height + 8)
          }

          FontMetrics {
            id: rowMetrics
            font: editor.font
          }

          // Two lines in the editor's style, to measure how far apart lines are.
          TextEdit {
            id: pitchProbe
            visible: false
            width: 400
            textFormat: TextEdit.RichText
            font: editor.font
            text: "<p style=\"" + root.blockStyle + "\">a<br>b</p>"
            readonly property real pitch: {
              text; font.pixelSize
              if (length < 3) return rowMetrics.lineSpacing
              var d = positionToRectangle(2).y - positionToRectangle(0).y
              return d > 0 ? d : rowMetrics.lineSpacing
            }
          }

          // The coloured copy, under the see-through editor.
          Text {
            x: root.gutter
            y: root.padTop
            width: editor.width
            textFormat: Text.RichText
            wrapMode: Text.Wrap
            color: root.pal.fg
            font: editor.font
            text: root.html
          }


          TextEdit {
            id: editor
            objectName: "jotEditor"
            x: root.gutter
            y: root.padTop
            width: flick.width - root.gutter - root.padRight
            height: Math.max(implicitHeight, flick.height - root.padTop - root.padBottom)
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.Wrap
            color: "transparent"
            selectedTextColor: "transparent"
            selectionColor: Theme.alpha(root.pal.selection, 0.75)
            selectByMouse: true
            persistentSelection: false
            font.family: root.fontFamily
            font.pixelSize: Config.jot.fontSize

            onTextChanged: root.edited()
            onCursorPositionChanged: {
              blink.restart()
              root.caretOn = true
              if (!root.loading) Qt.callLater(root.updateCompletion)
            }
            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            Keys.onPressed: function(event) { root.key(event) }

            // Qt sizes the delegate to the font's whole box, which is taller
            // than the letters look. Antinote's caret (measured on its clip)
            // runs from a third of a capital above the caps to a third below
            // the baseline, about 1.6 capitals tall.
            cursorDelegate: Item {
              width: 2
              visible: root.caretOn && editor.activeFocus
              Rectangle {
                width: 2
                y: Math.round(rowMetrics.ascent - 1.32 * rowMetrics.capitalHeight)
                height: Math.round(1.62 * rowMetrics.capitalHeight)
                color: root.pal.caret
              }
            }
            Timer {
              id: blink
              interval: 530
              repeat: true
              running: editor.activeFocus
              onTriggered: root.caretOn = !root.caretOn
            }

            // Over a link: a hand, and its full address after a moment.
            HoverHandler {
              id: linkHover
              cursorShape: root.hoverLink ? Qt.PointingHandCursor : Qt.IBeamCursor
              onPointChanged: hoverDelay.restart()
              onHoveredChanged: if (!hovered) { hoverDelay.stop(); root.hoverLink = null }
            }
            Timer {
              id: hoverDelay
              interval: 120
              onTriggered: root.hoverAt(linkHover.point.position.x, linkHover.point.position.y)
            }

            // Ctrl+click opens a link; Ctrl+Alt+click shortens or expands it.
            TapHandler {
              acceptedModifiers: Qt.ControlModifier
              onTapped: function(point) { root.openLink(point.position.x, point.position.y) }
            }
            TapHandler {
              acceptedModifiers: Qt.ControlModifier | Qt.AltModifier
              onTapped: function(point) { root.toggleLinkForm(point.position.x, point.position.y) }
            }
          }

          // AutoPaste is filling this note: a clipboard by its first line.
          JotLabel {
            visible: JotStore.autoPaste && JotStore.autoPasteTarget === JotStore.current
            readonly property rect first: { editor.contentHeight; root.html; return editor.positionToRectangle(0) }
            x: root.gutter - width - 9
            y: root.padTop + first.y + (first.height - height) / 2
            text: Icons.glyph(0xF0147)
            color: root.pal.clip
            font.pixelSize: Theme.fontSmall + 1
            elide: Text.ElideNone
          }

          // List notes: a box in the margin of each item; click to tick.
          Repeater {
            model: root.checks

            Rectangle {
              id: box
              required property var modelData
              readonly property rect line: {
                editor.contentHeight; editor.width; root.html
                // A note switch can leave a box for a moment past the new text's end.
                return modelData.pos <= editor.length ? editor.positionToRectangle(modelData.pos) : Qt.rect(0, -100, 0, 0)
              }
              // Antinote's: 13 px, 11 px left of the text, sitting on the
              // letters' baseline; ticked ones go pale purple.
              x: root.gutter - width - 11
              y: root.padTop + line.y + rowMetrics.ascent - height + 1
              width: 13
              height: 13
              radius: 2.5
              color: tick.containsMouse ? Theme.alpha(root.pal.fg, 0.06) : "transparent"
              border.width: 1.2
              border.color: modelData.done ? root.pal.checkDone : root.pal.check

              Canvas {
                anchors.fill: parent
                visible: box.modelData.done
                onPaint: {
                  var c = getContext("2d")
                  c.reset()
                  c.strokeStyle = root.pal.checkDone
                  c.lineWidth = 1.3
                  c.lineCap = "round"
                  c.lineJoin = "round"
                  c.beginPath()
                  c.moveTo(3.6, 6.8)
                  c.lineTo(5.8, 9)
                  c.lineTo(9.6, 4.2)
                  c.stroke()
                }
              }
              MouseArea {
                id: tick
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                onClicked: root.toggleDone(box.modelData.line)
              }
            }
          }
        }


        // The running timer, in the left margin: digits and a rail of dots.
        // Click to pause, right-click to stop.
        Item {
          visible: JotStore.timerKind !== ""
          x: 0
          width: root.gutter - 4
          height: parent.height

          readonly property color digits: Theme.alpha(root.pal.timer, JotStore.timerPaused ? 0.5 : 1)
          readonly property bool fromBottom: JotStore.timerKind === "stopwatch"

          Column {
            id: timerDigits
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.fromBottom ? parent.height - height - 6 : root.padTop
            Repeater {
              model: JotStore.timerLines
              JotLabel {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData
                color: timerDigits.parent.digits
                font.pixelSize: Theme.fontSmall
              }
            }
          }

          JotLabel {
            visible: parent.fromBottom
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.padTop
            text: "60s"
            color: root.pal.dim
            font.pixelSize: Theme.fontSmall - 1
          }

          Column {
            id: rail
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.fromBottom ? root.padTop + 20 : timerDigits.y + timerDigits.height + 8
            spacing: 4
            readonly property int count: Math.max(0, Math.floor(((parent.fromBottom ? timerDigits.y - 8 : parent.height - 6) - y) / 6))
            readonly property int lit: Math.round(JotStore.progress * count)
            Repeater {
              model: rail.count
              Rectangle {
                required property int index
                width: 2
                height: 2
                readonly property bool on: rail.parent.fromBottom ? rail.count - 1 - index < rail.lit : index < rail.lit
                color: on ? Theme.alpha(root.pal.railOn, JotStore.timerPaused ? 0.5 : 1) : root.pal.railOff
              }
            }
          }

          MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            y: timerDigits.y - 4
            height: timerDigits.height + 8
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(event) {
              if (event.button === Qt.RightButton) {
                JotStore.stopTimer()
                root.showToast("Timer stopped")
              } else {
                JotStore.togglePause()
                root.showToast(JotStore.timerPaused ? "Paused" : "Resumed")
              }
            }
          }
        }

        // Tab completes a variable's name in a math note.
        Rectangle {
          visible: root.completion !== null && editor.activeFocus
          x: Math.max(4, Math.min(root.gutter + editor.cursorRectangle.x - 10, body.width - width - 4))
          y: root.padTop + editor.cursorRectangle.y + editor.cursorRectangle.height - flick.contentY + 4
          width: hint.implicitWidth + 14
          height: hint.implicitHeight + 6
          radius: Theme.controlRadius
          color: root.pal.toastBg
          border.width: 1
          border.color: "transparent"
          JotLabel {
            id: hint
            anchors.centerIn: parent
            text: root.completion ? "tab  " + root.completion.name : ""
            color: root.pal.toastFg
            font.pixelSize: Theme.fontSmall
          }
        }

        // sum / avg / count notes.
        Rectangle {
          visible: root.stats !== ""
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: 6
          width: statsLabel.implicitWidth + 16
          height: statsLabel.implicitHeight + 6
          radius: Theme.controlRadius
          color: Theme.alpha(root.pal.fg, 0.07)
          JotLabel {
            id: statsLabel
            anchors.centerIn: parent
            text: root.stats
            color: root.pal.dim
            font.pixelSize: Theme.fontSmall
          }
        }

        // Which way the notes moved.
        Rectangle {
          id: edge
          y: 0
          width: 5
          height: parent.height
          color: root.pal.edge
          opacity: 0
          NumberAnimation on opacity { id: edgeFade; running: false; from: 1; to: 0; duration: 420; easing.type: Easing.OutCubic }
        }

        // An empty note goes away when you leave it; Antinote marks it so.
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 8
          visible: editor.length === 0 && JotStore.notes.length > 1 && !toastTimer.running && !root.searching
          width: 30
          height: 22
          radius: 6
          color: root.pal.badgeBg
          JotLabel {
            anchors.centerIn: parent
            text: Icons.glyph(0xF0B5C)
            color: root.pal.toastFg
            font.pixelSize: Theme.fontSize
            elide: Text.ElideNone
          }
        }

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 8
          visible: toastTimer.running
          width: toastLabel.implicitWidth + 24
          height: toastLabel.implicitHeight + 8
          radius: height / 2
          color: root.pal.toastBg
          JotLabel {
            id: toastLabel
            anchors.centerIn: parent
            text: root.toastText
            color: root.pal.toastFg
            font.pixelSize: Theme.fontSmall
          }
        }
        Timer { id: toastTimer; interval: 1800 }

        // A link's full address, under the pointer.
        Rectangle {
          id: linkTip
          visible: root.hoverLink !== null && tipDelay.done
          readonly property point at: root.hoverLink ? editor.mapToItem(body, root.hoverLink.x, root.hoverLink.y) : Qt.point(0, 0)
          x: Math.max(4, Math.min(at.x - 12, body.width - width - 4))
          y: at.y + 18 + height > body.height ? at.y - height - 10 : at.y + 18
          width: Math.min(body.width - 8, tipColumn.implicitWidth + 16)
          height: tipColumn.implicitHeight + 10
          radius: Theme.controlRadius
          color: root.pal.toastBg
          border.width: 1
          border.color: Theme.alpha(root.pal.fg, 0.15)

          // Shown only once the pointer has rested, not while passing over.
          Timer {
            id: tipDelay
            property bool done: false
            interval: 450
            running: root.hoverLink !== null
            onRunningChanged: if (running) done = false
            onTriggered: done = true
          }

          ColumnLayout {
            id: tipColumn
            anchors.centerIn: parent
            width: Math.min(implicitWidth, body.width - 24)
            spacing: 2
            JotLabel {
              text: root.hoverLink ? root.hoverLink.url : ""
              elide: Text.ElideMiddle
              Layout.maximumWidth: body.width - 24
              font.pixelSize: Theme.fontSmall
            }
            JotLabel {
              text: root.hoverLink && root.hoverLink.short ? "Ctrl+click to open · Ctrl+Alt+click to expand"
                : "Ctrl+click to open · Ctrl+Alt+click to shorten"
              color: root.pal.dim
              font.pixelSize: Theme.fontSmall - 1
              Layout.maximumWidth: body.width - 24
            }
          }
        }

        // Files and text dragged onto the note.
        DropArea {
          anchors.fill: parent
          onEntered: function(drag) {
            if (drag.hasUrls || drag.hasText) drag.accept(Qt.CopyAction)
          }
          onDropped: function(drop) { root.dropped(drop) }
        }

        // The notes list.
        Rectangle {
          visible: root.searching
          anchors.fill: parent
          anchors.margins: 8
          anchors.topMargin: root.padTop - 4
          radius: 8
          color: root.pal.bg
          border.width: 1
          border.color: Theme.alpha(root.pal.fg, 0.15)

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            // The filter. Arrows, Enter and Escape drive the list from here.
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: Theme.rowHeight
              radius: Theme.controlRadius
              color: Theme.alpha(root.pal.fg, 0.04)
              border.width: 1
              border.color: searchInput.activeFocus ? root.pal.accent : Theme.alpha(root.pal.fg, 0.25)

              JotLabel {
                anchors.fill: searchInput
                visible: searchInput.text === ""
                text: JotStore.notes.length + (JotStore.notes.length === 1 ? " note" : " notes") + " · type to filter"
                color: root.pal.dim
              }
              TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: root.pal.fg
                selectionColor: root.pal.selection
                font.family: root.fontFamily
                font.pixelSize: Theme.fontSize
                onTextChanged: root.query = text
                Keys.onPressed: function(event) {
                  var k = event.key
                  if (k === Qt.Key_Escape) root.closeSearch()
                  else if (k === Qt.Key_Down || (k === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) root.moveSelection(1)
                  else if (k === Qt.Key_Up || (k === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) root.moveSelection(-1)
                  else if (k === Qt.Key_PageDown) root.moveSelection(5)
                  else if (k === Qt.Key_PageUp) root.moveSelection(-5)
                  else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                    if (root.results.length) root.openFromSearch(root.results[root.selected].id)
                  }
                  else if (k === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                    if (root.results.length) JotStore.deleteById(root.results[root.selected].id)
                    root.selected = Math.min(root.selected, Math.max(0, root.results.length - 1))
                  }
                  else return
                  event.accepted = true
                }
                text: ""
                Connections {
                  target: root
                  function onSearchingChanged() { if (root.searching) searchInput.text = "" }
                }
              }
            }

            ListView {
              id: noteList
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              spacing: 2
              boundsBehavior: Flickable.StopAtBounds
              model: root.results

              delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool chosen: index === root.selected
                width: noteList.width
                height: rowColumn.implicitHeight + 10
                radius: Theme.controlRadius
                color: chosen ? root.pal.selection : rowHover.hovered ? Theme.alpha(root.pal.fg, 0.06) : "transparent"

                HoverHandler { id: rowHover }
                MouseArea {
                  anchors.fill: parent
                  onClicked: root.openFromSearch(row.modelData.id)
                }

                ColumnLayout {
                  id: rowColumn
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  spacing: 1

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    // The note being shown.
                    Rectangle {
                      visible: row.modelData.current
                      implicitWidth: 5
                      implicitHeight: 5
                      radius: 2.5
                      color: root.pal.accent
                    }
                    JotLabel {
                      text: row.modelData.title
                      color: row.chosen ? root.pal.fg : root.pal.fg
                      Layout.fillWidth: true
                    }
                    JotLabel {
                      visible: row.modelData.mode !== ""
                      text: row.modelData.mode
                      color: root.pal.accent
                      font.pixelSize: Theme.fontSmall
                    }
                    JotLabel {
                      visible: !trash.visible
                      text: row.modelData.ago
                      color: root.pal.dim
                      font.pixelSize: Theme.fontSmall
                    }
                    IconButton {
                      id: trash
                      visible: rowHover.hovered
                      implicitWidth: 20
                      implicitHeight: 18
                      size: Theme.fontSmall
                      icon: Icons.glyph(0xF0A7A)
                      foreground: root.pal.dim
                      onClicked: JotStore.deleteById(row.modelData.id)
                    }
                  }
                  JotLabel {
                    visible: text !== ""
                    text: row.modelData.snippet
                    color: root.pal.dim
                    font.pixelSize: Theme.fontSmall
                    Layout.fillWidth: true
                  }
                }
              }
            }

            JotLabel {
              Layout.fillWidth: true
              text: "↑↓ choose · Enter open · Shift+Del delete · Esc back"
              color: root.pal.dim
              font.pixelSize: Theme.fontSmall - 1
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }

        // Over everything: a press takes the keyboard back while pinned, and
        // a sideways swipe moves between notes. Both pass the event on.
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
          onPressed: function(mouse) {
            popup.regrab()
            // A middle click would paste the selection as rich text: eat it.
            mouse.accepted = mouse.button === Qt.MiddleButton
          }
          onWheel: function(wheel) {
            var dx = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.angleDelta.x / 3
            var dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 3
            if (dx === 0 || Math.abs(dx) <= Math.abs(dy)) {
              wheel.accepted = false
              return
            }
            root.swipe += dx
            if (!root.swipeLocked && Math.abs(root.swipe) > 70) {
              // Content moving left (fingers swiping left) goes to the next note.
              var step = root.swipe < 0 ? 1 : -1
              if (Config.jot.swipeInvert) step = -step
              root.swipeLocked = true
              swipeReset.restart()
              JotStore.go(step)
            }
          }
        }
        Timer {
          id: swipeReset
          interval: 450
          onTriggered: {
            root.swipe = 0
            root.swipeLocked = false
          }
        }
      }

      // The buttons, over the top of the note, on a strip of the note's own
      // background so the text under them does not show through.
      Rectangle {
        id: chrome
        objectName: "jotChrome"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        radius: 11
        height: root.padTop - 6
        color: root.pal.bg
        opacity: content.chromeShown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        HoverHandler { id: chromeHover }

        // Drag the strip to move the note; double-click to put it back
        // under the bar button. Pointer positions are taken in screen
        // coordinates, so the card moving under the pointer does not feed
        // back into the drag.
        MouseArea {
          id: chromeDrag
          anchors.fill: parent
          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
          property point start
          property real startX: 0
          property real startY: 0
          property real liveX: 0
          property real liveY: 0
          onPressed: function(mouse) {
            popup.regrab()
            start = mapToGlobal(mouse.x, mouse.y)
            startX = liveX = Config.jot.offsetX
            startY = liveY = Config.jot.offsetY
          }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            var p = mapToGlobal(mouse.x, mouse.y)
            liveX = startX + p.x - start.x
            liveY = Math.max(0, startY + p.y - start.y)
          }
          onReleased: {
            Config.jot.offsetX = Math.round(liveX)
            Config.jot.offsetY = Math.round(liveY)
          }
          onDoubleClicked: {
            Config.jot.offsetX = 0
            Config.jot.offsetY = 0
            root.showToast("Back under the button")
          }
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          spacing: 6

          // As Antinote: settings and search on the left, a new note and
          // the pin on the right, drawn to match its icons (ui/JotIcon.qml).
          JotIcon {
            kind: "settings"
            color: root.pal.icon
            onClicked: PopupState.request("settings:jot")
          }
          JotIcon {
            kind: "search"
            color: root.searching ? root.pal.accent : root.pal.icon
            onClicked: root.searching ? root.closeSearch() : root.openSearch()
          }
          Item { Layout.fillWidth: true }
          JotIcon {
            kind: "compose"
            color: root.pal.icon
            onClicked: JotStore.newNote("")
          }
          JotIcon {
            kind: root.pinned ? "pinned" : "pin"
            color: root.pinned ? root.pal.accent : root.pal.icon
            onClicked: root.pinned = !root.pinned
          }
        }
      }
    }
  }
}
