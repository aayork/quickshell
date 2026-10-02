import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui
import "Fuzzy.js" as Fuzzy
import "Calc.js" as Calc

// The launcher. Type to find an app or a command, do a sum, or start with a
// keyword and a colon (`vim:`, `def:`) to ask one of the extensions.
//
// An extension is a JSON file naming a keyword and a command; the command
// prints one JSON row per line. Same format Omacast used, so those carry over.
Scope {
  id: root

  property bool open: false
  property string query: ""
  property int cursor: 0
  // Row waiting for a second Enter.
  property string armed: ""

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/aayork-quickshell"
  // Still Omacast's folder; these move with the rest of the config later.
  readonly property string extensionDir: Quickshell.env("HOME") + "/.config/roseshell/omacast/extensions"
  readonly property int maxRows: 60

  // key -> { count, last }
  property var frecency: ({})
  // Extensions whose `when` check passed.
  property var extensions: []
  // Rows the current extension query produced.
  property var extensionRows: []
  property bool extensionBusy: false

  // Keywords answered by the shell itself instead of a script. Listed first,
  // so they win over an extension file with the same keyword.
  readonly property var builtins: [
    { id: "displays", title: "Displays", subtitle: "Resolution and scale", keyword: "displays",
      aliases: ["display", "monitor", "monitors", "resolution", "scale"], glyph: Icons.glyph(0xF0379), minChars: 0, debounceMs: 0, maxRows: 60, provider: displays }
  ]
  readonly property var scopes: builtins.concat(extensions)

  // "keyword: rest" where keyword belongs to a scope.
  readonly property var scoped: {
    var match = query.match(/^\s*([a-z0-9_-]+):\s?(.*)$/i)
    if (!match) return null
    var keyword = match[1].toLowerCase()
    var extension = scopes.find(e => e.keyword === keyword || e.aliases.indexOf(keyword) !== -1)
    return extension ? { extension: extension, text: match[2] } : null
  }

  Displays { id: displays }

  // Things the shell does itself. A command with the same id as an extension
  // keyword steps aside for the extension.
  readonly property var commands: [
    { id: "lock", title: "Lock", glyph: 0xF033E, words: "lock screen", run: () => Session.run("lock") },
    { id: "suspend", title: "Suspend", glyph: 0xF04B2, words: "sleep", run: () => Session.run("suspend") },
    { id: "logout", title: "Log out", glyph: 0xF0343, words: "exit sign out", confirm: true, run: () => Session.run("logout") },
    { id: "reboot", title: "Restart", glyph: 0xF0709, words: "reboot", confirm: true, run: () => Session.run("reboot") },
    { id: "shutdown", title: "Shut down", glyph: 0xF0425, words: "power off poweroff", confirm: true, run: () => Session.run("shutdown") },
    { id: "control-center", title: "Control Center", glyph: 0xF057E, words: "audio sound output input now playing", run: () => PopupState.request("control-center") },
    { id: "tailscale", title: "Tailscale", glyph: 0xF0582, words: "vpn tailnet", run: () => PopupState.request("tailscale") },
    { id: "calendar", title: "Calendar and Weather", glyph: 0xF0599, words: "clock date notifications", run: () => PopupState.request("clock") },
    { id: "colorpicker", title: "Color Picker", glyph: 0xF0349, words: "colour pick hex hyprpicker", run: () => Quickshell.execDetached(["hyprpicker", "-a"]) },
    { id: "reload", title: "Reload Shell", glyph: 0xF0450, words: "restart quickshell", run: () => Quickshell.reload(true) }
  ].filter(c => !scopes.some(s => s.keyword === c.id))

  // What is listed. Each row carries a `header` when it starts a new group.
  readonly property var rows: withHeaders(scoped ? scopedRows() : query.trim() === "" ? emptyRows() : searchRows())
  readonly property var currentRow: rows[cursor] ?? null
  readonly property var currentActions: currentRow && !currentRow.hint ? currentRow.actions : []

  // Second and later things the current row can do (Ctrl+K).
  property bool actionsOpen: false
  property int actionCursor: 0

  function frecencyBonus(key) {
    var entry = frecency[key]
    if (!entry) return 0
    var days = (Date.now() - entry.last) / 86400000
    return Math.min(200, entry.count * 8) + (days < 7 ? 50 : 0)
  }

  function copyAction(title, text) {
    return { title: title, run: () => Quickshell.execDetached(["wl-copy", "--", text]) }
  }

  function appRow(entry, score) {
    var actions = [{ title: "Open", run: () => entry.execute() }]
    var extra = entry.actions || []
    for (var i = 0; i < extra.length; i++) {
      actions.push({ title: extra[i].name, run: (function(action) { return () => action.execute() })(extra[i]) })
    }
    actions.push(copyAction("Copy Name", entry.name))
    return {
      key: "app:" + entry.id,
      title: entry.name,
      subtitle: entry.genericName || entry.comment || "",
      icon: Quickshell.iconPath(entry.icon, "application-x-executable"),
      glyph: "",
      chip: "",
      score: score,
      actions: actions
    }
  }

  function commandRow(command, score) {
    return {
      key: "cmd:" + command.id,
      title: command.title,
      subtitle: "Command",
      icon: "",
      glyph: Icons.glyph(command.glyph),
      chip: "",
      confirm: command.confirm === true,
      score: score,
      actions: [{ title: "Run", run: command.run }]
    }
  }

  // An extension or built-in keyword. Choosing it fills the keyword in.
  function scopeRow(scope, score) {
    return {
      key: "kw:" + scope.id,
      title: scope.title,
      subtitle: scope.subtitle !== scope.title ? scope.subtitle : "",
      icon: "",
      glyph: scope.glyph || Icons.glyph(0xF0349),
      chip: scope.keyword + ":",
      score: score,
      actions: [{ title: "Use Keyword", fill: scope.keyword + ": " }]
    }
  }

  function rowForKey(key) {
    var id = key.slice(key.indexOf(":") + 1)
    if (key.indexOf("app:") === 0) {
      var entry = DesktopEntries.applications.values.find(e => e.id === id)
      return entry && !entry.noDisplay ? appRow(entry, 0) : null
    }
    if (key.indexOf("cmd:") === 0) {
      var command = commands.find(c => c.id === id)
      return command ? commandRow(command, 0) : null
    }
    if (key.indexOf("kw:") === 0) {
      var scope = scopes.find(s => s.id === id)
      return scope ? scopeRow(scope, 0) : null
    }
    return null
  }

  // An empty box: the five things used last, then every command and keyword
  // there is, A to Z, so one nobody has typed yet can still be found by eye.
  function emptyRows() {
    var list = []
    var shown = {}
    var keys = Object.keys(frecency).sort((a, b) => frecency[b].last - frecency[a].last)
    for (var i = 0; i < keys.length && list.length < 5; i++) {
      var row = rowForKey(keys[i])
      if (!row) continue
      row.group = "Recent"
      shown[row.key] = true
      list.push(row)
    }

    var rest = []
    for (var c = 0; c < commands.length; c++) rest.push(commandRow(commands[c], 0))
    for (var s = 0; s < scopes.length; s++) rest.push(scopeRow(scopes[s], 0))
    rest = rest.filter(r => !shown[r.key])
    rest.sort((a, b) => a.title.localeCompare(b.title))
    for (var r = 0; r < rest.length; r++) rest[r].group = "Commands"
    return list.concat(rest)
  }

  function searchRows() {
    var text = query.trim()
    var list = []
    var apps = DesktopEntries.applications.values

    for (var i = 0; i < apps.length; i++) {
      var entry = apps[i]
      if (entry.noDisplay) continue
      var appScore = Fuzzy.best(text, entry.name, [entry.genericName, entry.id].concat(entry.keywords || []))
      if (appScore > 0) list.push(appRow(entry, appScore + frecencyBonus("app:" + entry.id)))
    }

    for (var c = 0; c < commands.length; c++) {
      var command = commands[c]
      var commandScore = Fuzzy.best(text, command.title, command.words.split(" "))
      // Things that end the session never outrank an app on a loose match.
      if (commandScore > 0) list.push(commandRow(command, (commandScore + frecencyBonus("cmd:" + command.id)) * (command.confirm ? 0.7 : 0.95)))
    }

    for (var e = 0; e < scopes.length; e++) {
      var scope = scopes[e]
      var scopeScore = Fuzzy.best(text, scope.keyword, [scope.title].concat(scope.aliases))
      if (scopeScore > 0) list.push(scopeRow(scope, scopeScore * 0.9 + frecencyBonus("kw:" + scope.id)))
    }

    list.sort(function(a, b) { return b.score - a.score || a.title.localeCompare(b.title) })
    list = list.slice(0, maxRows)

    var answer = Calc.evaluate(text)
    if (answer !== null) {
      var exact = String(Math.round(answer * 1e10) / 1e10)
      list.unshift({
        key: "calc",
        title: Calc.format(answer),
        subtitle: "Calculator",
        icon: "",
        glyph: Icons.glyph(0xF00EC),
        chip: "",
        actions: [copyAction("Copy Result", exact), copyAction("Copy Expression", text)]
      })
    }
    return list
  }

  function hintRow(title, scope) {
    return { key: "hint", title: title, subtitle: "", icon: "", glyph: scope.glyph, chip: "", hint: true, actions: [] }
  }

  function scopedRows() {
    var extension = scoped.extension
    if (extension.provider) return extension.provider.rows(scoped.text)
    if (scoped.text.trim().length < extension.minChars) return [hintRow("Keep typing to search " + extension.title, extension)]
    if (extensionRows.length === 0) return [hintRow(extensionBusy ? "Searching…" : "Nothing found", extension)]
    return extensionRows
  }

  function withHeaders(list) {
    var previous = ""
    for (var i = 0; i < list.length; i++) {
      var group = list[i].group || ""
      list[i].header = group !== previous ? group : ""
      previous = group
    }
    return list
  }

  function quote(text) {
    return "'" + String(text).replace(/'/g, "'\\''") + "'"
  }

  function searchExtension() {
    if (!scoped || scoped.text.trim().length < scoped.extension.minChars) {
      extensionRows = []
      extensionBusy = false
      return
    }
    extensionBusy = true
    if (search.running) {
      // Let the old answer go; the exit handler starts the new question.
      search.restart = true
      search.signal(15)
      return
    }
    startSearch()
  }

  function startSearch() {
    if (!scoped) return
    var extension = scoped.extension
    var text = scoped.text
    search.extensionId = extension.id
    search.limit = extension.maxRows
    search.command = ["sh", "-c", extension.search.replace(/\{([a-z0-9_-]+)\}/gi, function(whole, name) {
      return root.quote(name.toLowerCase() === "query" ? text : "")
    })]
    search.running = true
  }

  function parseRows(text, extension, limit) {
    var raw = []
    var trimmed = String(text || "").trim()
    try {
      if (trimmed.charAt(0) === "[") raw = JSON.parse(trimmed)
      else raw = trimmed.split("\n").filter(l => l.trim() !== "").map(l => JSON.parse(l))
    } catch (e) {
      return []
    }
    return raw.slice(0, limit).map(function(row, index) {
      var icon = String(row.icon || "")
      var subtitle = String(row.subtitle || "")
      var keys = Array.isArray(row.keys) ? row.keys : []
      // Scripts list their own actions; a row without any gets its `exec`.
      var actions = (Array.isArray(row.actions) ? row.actions : []).filter(a => a && a.title)
      if (actions.length === 0 && row.exec) actions = [{ title: "Open", exec: String(row.exec), keepOpen: row.keepOpen === true }]
      // A short subtitle is a label and goes on the right. A long one is a
      // sentence and gets its own line. Key chips already say a shortcut.
      var long = subtitle.length > 36
      return {
        key: "ext:" + extension.keyword + ":" + (row.id || index),
        title: String(row.title || ""),
        detail: long ? subtitle : "",
        subtitle: long || keys.length > 0 ? "" : subtitle,
        icon: icon === "" ? "" : icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon, true),
        glyph: String(row.glyph || extension.glyph || ""),
        chip: String(row.accessory || ""),
        group: String(row.group || ""),
        keys: keys,
        actions: actions
      }
    })
  }

  // Enter: the row's first action.
  function activate(index) {
    var row = rows[index]
    if (!row || row.hint || row.actions.length === 0) return
    runAction(row, row.actions[0])
  }

  function runAction(row, action) {
    if (!action) return
    actionsOpen = false
    if (action.fill) {
      remember(row.key)
      query = action.fill
      return
    }
    if (row.confirm && armed !== row.key) {
      armed = row.key
      return
    }
    var stay = action.keepOpen === true || row.keepOpen === true || action.query !== undefined
    if (!stay) remember(row.key)
    if (action.run) action.run()
    else if (action.exec) Quickshell.execDetached(["sh", "-c", String(action.exec)])
    // An action can ask to land on another query instead of closing.
    if (action.query !== undefined) query = String(action.query)
    else if (!stay) hide()
  }

  function move(delta) {
    var count = rows.length
    if (count === 0) return
    cursor = Math.max(0, Math.min(count - 1, cursor + delta))
    armed = ""
  }

  function remember(key) {
    if (key === "calc") return
    var next = Object.assign({}, frecency)
    var entry = next[key] || { count: 0, last: 0 }
    next[key] = { count: entry.count + 1, last: Date.now() }
    frecency = next
    frecencyFile.setText(JSON.stringify(next))
  }

  function show(text) {
    query = text || ""
    cursor = 0
    armed = ""
    actionsOpen = false
    open = true
  }

  function hide() {
    open = false
  }

  onQueryChanged: {
    cursor = 0
    armed = ""
    actionsOpen = false
  }
  onActionsOpenChanged: actionCursor = 0

  // Driven by `scoped` rather than the query: the query's own change handler
  // can run before `scoped` has caught up with it.
  property string lastExtension: ""
  onScopedChanged: {
    var id = scoped ? scoped.extension.id : ""
    var previous = lastExtension
    if (id !== previous) extensionRows = []
    lastExtension = id
    if (scoped && scoped.extension.provider) {
      debounce.stop()
      if (id !== previous) scoped.extension.provider.refresh()
    } else if (scoped) {
      debounce.restart()
    } else {
      debounce.stop()
      extensionBusy = false
    }
  }

  Timer {
    id: debounce
    interval: root.scoped ? root.scoped.extension.debounceMs : 100
    onTriggered: root.searchExtension()
  }

  Process {
    id: search
    property string extensionId: ""
    property int limit: 8
    property bool restart: false

    // The output can finish arriving after the process has exited, so rows
    // are read here and not in onExited.
    stdout: StdioCollector {
      onStreamFinished: {
        if (search.restart) return
        root.extensionBusy = false
        if (root.scoped && root.scoped.extension.id === search.extensionId)
          root.extensionRows = root.parseRows(text, root.scoped.extension, search.limit)
      }
    }
    onExited: function(code) {
      if (!restart) return
      restart = false
      root.startSearch()
    }
  }

  // Reads every extension file and runs its `when` check, printing the ones
  // that pass, one JSON object per line.
  Process {
    id: loadExtensions
    running: true
    command: ["sh", "-c", "for f in \"$1\"/*.json; do case \"$f\" in *.cases.json) continue;; esac; "
      + "[ -f \"$f\" ] || continue; when=$(jq -r '.when // \"\"' \"$f\" 2>/dev/null) || continue; "
      + "if [ -z \"$when\" ] || sh -c \"$when\" >/dev/null 2>&1; then jq -c . \"$f\"; fi; done", "sh", root.extensionDir]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trim() === "") continue
          try {
            var raw = JSON.parse(lines[i])
            if (!raw.id || !raw.search) continue
            list.push({
              id: String(raw.id),
              title: String(raw.title || raw.id),
              keyword: String(raw.keyword || raw.id).toLowerCase(),
              aliases: (raw.aliases || []).map(a => String(a).toLowerCase()),
              glyph: String(raw.glyph || ""),
              subtitle: String(raw.subtitle || raw.title || raw.id),
              search: String(raw.search),
              minChars: raw.minChars === undefined ? 1 : Number(raw.minChars),
              debounceMs: raw.debounceMs === undefined ? 200 : Number(raw.debounceMs),
              maxRows: raw.maxRows === undefined ? 8 : Number(raw.maxRows)
            })
          } catch (e) {}
        }
        root.extensions = list
      }
    }
  }

  FileView {
    id: frecencyFile
    path: root.stateDir + "/frecency.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        root.frecency = JSON.parse(text())
      } catch (e) {}
    }
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void { if (root.open) root.hide(); else root.show("") }
    function open(query: string): void { root.show(query) }
    function close(): void { root.hide() }
  }

  component Chip: Rectangle {
    property alias text: chipLabel.text
    property bool accented: false

    visible: chipLabel.text !== ""
    implicitWidth: chipLabel.implicitWidth + 16
    implicitHeight: 20
    radius: height / 2
    color: accented ? Theme.alpha(Theme.accent, 0.16) : Theme.alpha(Theme.foreground, 0.07)

    Label {
      id: chipLabel
      anchors.centerIn: parent
      color: parent.accented ? Theme.accent : Theme.dim
      font.pixelSize: Theme.fontSmall
      elide: Text.ElideNone
    }
  }

  PanelWindow {
    id: window

    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    visible: root.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.alpha(Theme.background, 0.35)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aayork-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) input.forceActiveFocus()

    MouseArea {
      anchors.fill: parent
      onClicked: root.hide()
    }

    Rectangle {
      id: card
      width: 680
      height: column.implicitHeight + 2 * Theme.borderWidth
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.2)
      color: Theme.background
      border.width: Theme.borderWidth
      border.color: Theme.accent
      radius: Theme.radius

      MouseArea { anchors.fill: parent }

      ColumnLayout {
        id: column
        x: Theme.borderWidth
        y: Theme.borderWidth
        width: parent.width - 2 * Theme.borderWidth
        spacing: 0

        RowLayout {
          Layout.fillWidth: true
          Layout.margins: 12
          spacing: 10

          Label {
            text: Icons.glyph(0xF0349)
            font.pixelSize: Theme.iconLarge
            color: Theme.dim
            elide: Text.ElideNone
          }

          TextInput {
            id: input
            Layout.fillWidth: true
            text: root.query
            color: Theme.foreground
            selectionColor: Theme.selection
            selectedTextColor: Theme.brightForeground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLarge
            clip: true
            onTextEdited: root.query = text

            Label {
              anchors.fill: parent
              visible: input.text === ""
              text: "Search apps, do math, run a command"
              color: Theme.dim
              font.pixelSize: Theme.fontLarge
            }

            Keys.onPressed: function(event) {
              var control = (event.modifiers & Qt.ControlModifier) !== 0
              var enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
              event.accepted = true

              if (control && event.key === Qt.Key_K) {
                if (root.currentActions.length > 0) root.actionsOpen = !root.actionsOpen
              } else if (root.actionsOpen) {
                // While the action list is up, the keys are its.
                var actions = root.currentActions
                if (event.key === Qt.Key_Escape) root.actionsOpen = false
                else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) root.actionCursor = Math.min(actions.length - 1, root.actionCursor + 1)
                else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) root.actionCursor = Math.max(0, root.actionCursor - 1)
                else if (enter) root.runAction(root.currentRow, actions[root.actionCursor])
              } else if (event.key === Qt.Key_Escape) {
                if (root.query !== "") root.query = ""
                else root.hide()
              } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (control && event.key === Qt.Key_N)) {
                root.move(1)
              } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (control && event.key === Qt.Key_P)) {
                root.move(-1)
              } else if (event.key === Qt.Key_PageDown) {
                root.move(9)
              } else if (event.key === Qt.Key_PageUp) {
                root.move(-9)
              } else if (control && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                // Run the nth row without walking to it; the dim numbers down
                // the left are the other half of this.
                var nth = event.key - Qt.Key_1
                if (nth < root.rows.length) {
                  root.cursor = nth
                  root.activate(nth)
                }
              } else if (enter && (event.modifiers & Qt.ShiftModifier)) {
                // The second action, without opening the list.
                var second = root.currentActions[1]
                if (second) root.runAction(root.currentRow, second)
                else root.activate(root.cursor)
              } else if (enter) {
                root.activate(root.cursor)
              } else {
                event.accepted = false
              }
            }
          }

          Chip {
            text: root.scoped ? root.scoped.extension.title : ""
            accented: true
          }
        }

        Separator { Layout.fillWidth: true; visible: list.count > 0 }

        ListView {
          id: list
          Layout.fillWidth: true
          Layout.topMargin: 4
          Layout.bottomMargin: 4
          implicitHeight: Math.min(contentHeight, 9 * 40 + 24)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.rows
          currentIndex: root.cursor
          highlightMoveDuration: 0
          // A new answer starts back at the top.
          onModelChanged: positionViewAtBeginning()
          onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

          delegate: Column {
            id: row
            required property var modelData
            required property int index

            readonly property bool current: root.cursor === index
            readonly property bool armed: root.armed === modelData.key
            readonly property var keys: (modelData.keys || []).slice(0, 6)

            width: list.width

            Item {
              width: parent.width
              height: visible ? 24 : 0
              visible: row.modelData.header !== ""

              SectionHeader {
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: row.modelData.header.toUpperCase()
                font.bold: true
              }
            }

            Item {
              width: parent.width
              height: 40

              Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                radius: Theme.controlRadius
                color: row.armed ? Theme.alpha(Theme.red, 0.2) : row.current && !row.modelData.hint ? Theme.selection : "transparent"
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: if (root.cursor !== row.index) { root.cursor = row.index; root.armed = "" }
                onClicked: root.activate(row.index)
              }

              // Only the first nine have a chord that runs them.
              Label {
                visible: row.index < 9 && !row.modelData.hint
                text: String(row.index + 1)
                color: Theme.muted
                font.pixelSize: Theme.fontSmall
                width: 12
                horizontalAlignment: Text.AlignRight
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideNone
              }

              Item {
                id: icon
                width: 22
                height: 22
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.verticalCenter: parent.verticalCenter

                Image {
                  anchors.fill: parent
                  visible: row.modelData.icon !== ""
                  source: row.modelData.icon
                  sourceSize.width: 44
                  sourceSize.height: 44
                  asynchronous: true
                }
                Label {
                  anchors.centerIn: parent
                  visible: row.modelData.icon === ""
                  text: row.modelData.glyph
                  font.pixelSize: Theme.iconLarge
                  color: row.armed ? Theme.red : row.current ? Theme.foreground : Theme.dim
                  elide: Text.ElideNone
                }
              }

              // Title, with a line of detail under it when there is one.
              Column {
                anchors.left: icon.right
                anchors.leftMargin: 12
                anchors.right: tail.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Label {
                  width: parent.width
                  text: row.armed ? "Enter again to " + row.modelData.title.toLowerCase() : row.modelData.title
                  color: row.armed ? Theme.red : row.modelData.hint ? Theme.dim : row.current ? Theme.brightForeground : Theme.foreground
                  font.pixelSize: Theme.fontSize + 1
                }
                Label {
                  width: parent.width
                  visible: text !== ""
                  text: row.modelData.detail || ""
                  color: Theme.dim
                  font.pixelSize: Theme.fontSmall
                }
              }

              // Right side: key chips or the keyword pill, then what the thing
              // is, hard against the edge so it reads as a column.
              Row {
                id: tail
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Row {
                  visible: row.keys.length > 0
                  spacing: 4
                  anchors.verticalCenter: parent.verticalCenter

                  Repeater {
                    model: row.keys

                    Rectangle {
                      required property string modelData
                      width: keyLabel.implicitWidth + 10
                      height: 20
                      radius: Theme.controlRadius
                      color: Theme.alpha(Theme.foreground, 0.06)
                      border.width: 1
                      border.color: Theme.alpha(Theme.foreground, 0.2)

                      Label {
                        id: keyLabel
                        anchors.centerIn: parent
                        text: parent.modelData
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideNone
                      }
                    }
                  }
                }

                Chip {
                  anchors.verticalCenter: parent.verticalCenter
                  text: row.modelData.chip || ""
                  accented: (row.modelData.key || "").indexOf("kw:") === 0
                }

                Label {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: text !== ""
                  text: row.modelData.subtitle || ""
                  color: Theme.dim
                  font.pixelSize: Theme.fontSmall
                  horizontalAlignment: Text.AlignRight
                  width: Math.min(implicitWidth, list.width * 0.38)
                }
              }
            }
          }
        }

        Separator { Layout.fillWidth: true; visible: footer.visible }

        // What Enter does to the current row, and how to get at the rest.
        RowLayout {
          id: footer
          visible: root.currentActions.length > 0
          Layout.fillWidth: true
          Layout.leftMargin: 14
          Layout.rightMargin: 14
          Layout.topMargin: 6
          Layout.bottomMargin: 6
          spacing: 14

          Label {
            text: "↵  " + (root.currentActions.length > 0 ? root.currentActions[0].title : "")
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            Layout.fillWidth: true
          }
          Label {
            visible: root.currentActions.length > 1
            text: "⇧↵  " + (root.currentActions.length > 1 ? root.currentActions[1].title : "")
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideNone
          }
          Label {
            visible: root.currentActions.length > 1
            text: "Ctrl K  Actions"
            color: root.actionsOpen ? Theme.accent : Theme.dim
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideNone
          }
        }
      }
    }

    // Ctrl+K: everything else the current row can do.
    Rectangle {
      visible: root.actionsOpen && root.currentActions.length > 0
      width: 300
      height: actionColumn.implicitHeight + 12
      anchors.right: card.right
      anchors.top: card.bottom
      anchors.topMargin: 6
      color: Theme.background
      border.width: Theme.borderWidth
      border.color: Theme.accent
      radius: Theme.radius

      MouseArea { anchors.fill: parent }

      Column {
        id: actionColumn
        x: 6
        y: 6
        width: parent.width - 12

        Repeater {
          model: root.actionsOpen ? root.currentActions : []

          Rectangle {
            id: actionRow
            required property var modelData
            required property int index

            width: actionColumn.width
            height: 32
            radius: Theme.controlRadius
            color: root.actionCursor === index ? Theme.selection : "transparent"

            Label {
              anchors.left: parent.left
              anchors.right: hint.left
              anchors.leftMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: actionRow.modelData.title
            }
            Label {
              id: hint
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: actionRow.index === 0 ? "↵" : actionRow.index === 1 ? "⇧↵" : ""
              color: Theme.dim
              font.pixelSize: Theme.fontSmall
              elide: Text.ElideNone
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onPositionChanged: root.actionCursor = actionRow.index
              onClicked: root.runAction(root.currentRow, actionRow.modelData)
            }
          }
        }
      }
    }
  }
}
