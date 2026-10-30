import QtQuick
import QtQuick.Effects
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
// prints one JSON row per line. The bundled ones are in launcher/extensions,
// with their scripts in launcher/scripts.
Scope {
  id: root

  property bool open: false
  property string query: ""
  property int cursor: 0
  // Row waiting for a second Enter.
  property string armed: ""

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/aayork-quickshell"
  // Extension definitions: the ones that ship here, then the user's own,
  // which win when both define the same id.
  readonly property var extensionDirs: [Quickshell.shellDir + "/launcher/extensions", Quickshell.env("HOME") + "/.config/aayork-quickshell/extensions"]
  // Every extension command runs with the shell's own scripts on its PATH.
  readonly property string scriptPath: "PATH=" + quote(Quickshell.shellDir + "/bin:" + Quickshell.shellDir + "/launcher/scripts") + ":\"$PATH\"; "
  readonly property int maxRows: 60
  readonly property int rowHeight: 32
  // Corners follow the window rounding set in Settings › Windows, so the
  // launcher matches the windows around it; rows and popovers scale with it.
  readonly property int corner: Math.max(0, Number(Config.windows.rounding) || 0)
  readonly property int smallCorner: Math.min(8, Math.round(corner * 0.6))

  // key -> { count, last }
  property var frecency: ({})
  // Keys of the rows pinned to the top of the empty launcher, in order.
  property var favorites: []
  // Extensions whose `when` check passed.
  property var extensions: []
  // Rows the current extension query produced.
  property var extensionRows: []
  property bool extensionBusy: false

  // Keywords answered by the shell itself instead of a script. Listed first,
  // so they win over an extension file with the same keyword.
  readonly property var builtins: [
    { id: "displays", title: "Displays", subtitle: "Resolution and scale", keyword: "displays",
      aliases: ["display", "monitor", "monitors", "resolution", "scale"], glyph: Icons.glyph(0xF0379), minChars: 0, debounceMs: 0, maxRows: 60, provider: displays },
    { id: "clipboard", title: "Clipboard History", subtitle: "What you copied", keyword: "ch",
      aliases: ["clipboard", "clip", "paste", "copied", "history"], glyph: Icons.glyph(0xF014D), minChars: 0, debounceMs: 0, maxRows: 100, provider: clipboard },
    { id: "shots", title: "Capture History", subtitle: "Screenshots you took", keyword: "shots",
      aliases: ["screenshots", "screenshot", "captures", "capture"], glyph: Icons.glyph(0xF02E9), minChars: 0, debounceMs: 0, maxRows: 100, provider: shots },
    // Shows the mouse settings panel in place of a list.
    { id: "mouse", title: "Mouse", subtitle: "Razer DPI, polling and speed", keyword: "mouse",
      aliases: ["razer", "dpi", "pointer", "sensitivity", "acceleration"], glyph: Icons.glyph(0xF037D), minChars: 0, debounceMs: 0, maxRows: 1, panel: "mouse" }
  ]
  readonly property var scopes: builtins.filter(b => b.id !== "mouse" || Config.features.mouse).concat(extensions)

  // "keyword: rest" where keyword belongs to a scope.
  readonly property var scoped: {
    var match = query.match(/^\s*([a-z0-9_-]+):\s?(.*)$/i)
    if (!match) return null
    var keyword = match[1].toLowerCase()
    var extension = scopes.find(e => e.keyword === keyword || e.aliases.indexOf(keyword) !== -1)
    return extension ? { extension: extension, text: match[2] } : null
  }

  Displays { id: displays }
  ClipboardSource { id: clipboard }
  ShotsSource { id: shots }

  // Things the shell does itself. A command with the same id as an extension
  // keyword steps aside for the extension.
  readonly property var commands: [
    { id: "lock", title: "Lock", glyph: 0xF033E, words: "lock screen", run: () => Session.run("lock") },
    { id: "suspend", title: "Suspend", glyph: 0xF04B2, words: "sleep", run: () => Session.run("suspend") },
    { id: "logout", title: "Log out", glyph: 0xF0343, words: "exit sign out", confirm: true, run: () => Session.run("logout") },
    { id: "reboot", title: "Restart", glyph: 0xF0709, words: "reboot", confirm: true, run: () => Session.run("reboot") },
    { id: "shutdown", title: "Shut down", glyph: 0xF0425, words: "power off poweroff", confirm: true, run: () => Session.run("shutdown") },
    { id: "control-center", title: "Control Center", glyph: 0xF057E, words: "audio sound output input now playing", run: () => PopupState.request("control-center") },
    { id: "tailscale", title: "Tailscale", glyph: 0xF0582, mark: "tailscale", words: "vpn tailnet", run: () => PopupState.request("tailscale") },
    { id: "calendar", title: "Calendar and Weather", glyph: 0xF0599, words: "clock date notifications", run: () => PopupState.request("clock") },
    { id: "settings", title: "Settings", glyph: 0xF0493, words: "preferences theme background font cursor night light windows", run: () => PopupState.request("settings") },
    { id: "capture", title: "Take a Screenshot", glyph: 0xF0E51, words: "screenshot capture region area window fullscreen scroll", run: () => Captures.menuRequested() },
    { id: "colorpicker", title: "Color Picker", glyph: 0xF0349, words: "colour pick hex hyprpicker", run: () => Quickshell.execDetached(["hyprpicker", "-a"]) },
    { id: "reload", title: "Reload Shell", glyph: 0xF0450, words: "restart quickshell", run: () => Quickshell.reload(true) }
  ].concat(windowCommands).filter(c => !scopes.some(s => s.keyword === c.id))

  // Raycast-style window management, for the window that had focus before
  // the launcher opened (bin/window-arrange).
  function arrange(preset) {
    Quickshell.execDetached([Quickshell.shellDir + "/bin/window-arrange", preset, String(Theme.barHeight)])
  }
  readonly property var windowCommands: [
    { id: "win-left", title: "Left Half", glyph: 0xF10AA, words: "window snap tile side", kind: "Window", run: () => arrange("left-half") },
    { id: "win-right", title: "Right Half", glyph: 0xF10AB, words: "window snap tile side", kind: "Window", run: () => arrange("right-half") },
    { id: "win-top", title: "Top Half", glyph: 0xF1513, words: "window snap upper", kind: "Window", run: () => arrange("top-half") },
    { id: "win-bottom", title: "Bottom Half", glyph: 0xF10A9, words: "window snap lower", kind: "Window", run: () => arrange("bottom-half") },
    { id: "win-center", title: "Center", glyph: 0xF02F1, words: "window middle centre float", kind: "Window", run: () => arrange("center") },
    { id: "win-almost", title: "Almost Maximize", glyph: 0xF004C, words: "window big large", kind: "Window", run: () => arrange("almost-maximize") },
    { id: "win-maximize", title: "Maximize", glyph: 0xF05AF, words: "window full zoom", kind: "Window", run: () => arrange("maximize") },
    { id: "win-fullscreen", title: "Toggle Fullscreen", glyph: 0xF0293, words: "window full screen", kind: "Window", run: () => arrange("fullscreen") },
    { id: "win-float", title: "Toggle Floating", glyph: 0xF0E59, words: "window float tile", kind: "Window", run: () => arrange("float") },
    { id: "win-tile", title: "Tile Window", glyph: 0xF0A1D, words: "window tiling layout restore", kind: "Window", run: () => arrange("tile") },
    { id: "win-pin", title: "Pin to All Workspaces", glyph: 0xF0403, words: "window sticky every workspace", kind: "Window", run: () => arrange("pin") }
  ]

  // What is listed. Each row carries a `header` when it starts a new group.
  readonly property var rows: withHeaders(scoped ? scopedRows() : query.trim() === "" ? emptyRows() : searchRows())
  readonly property var currentRow: rows[cursor] ?? null
  // Rows that carry a preview get a pane beside the list.
  readonly property bool split: rows.some(r => r.preview !== undefined)
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

  function isFavorite(key) { return favorites.indexOf(key) !== -1 }

  function toggleFavorite(key) {
    var next = favorites.filter(k => k !== key)
    if (next.length === favorites.length) next.push(key)
    setFavorites(next)
  }

  function moveFavorite(key, step) {
    var next = favorites.slice()
    var at = next.indexOf(key)
    var to = at + step
    if (at < 0 || to < 0 || to >= next.length) return
    next.splice(at, 1)
    next.splice(to, 0, key)
    setFavorites(next)
  }

  function setFavorites(next) {
    favorites = next
    favoritesFile.setText(JSON.stringify(next))
  }

  // Ctrl+K entries every app, command and keyword gets.
  function favoriteActions(key) {
    if (!isFavorite(key)) return [{ title: "Add to Favorites", keepOpen: true, shortcut: ["Ctrl", "⇧", "F"], run: () => toggleFavorite(key) }]
    var list = [{ title: "Remove from Favorites", keepOpen: true, shortcut: ["Ctrl", "⇧", "F"], run: () => toggleFavorite(key) }]
    var at = favorites.indexOf(key)
    if (at > 0) list.push({ title: "Move Up in Favorites", keepOpen: true, run: () => moveFavorite(key, -1) })
    if (at < favorites.length - 1) list.push({ title: "Move Down in Favorites", keepOpen: true, run: () => moveFavorite(key, 1) })
    return list
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
    actions = actions.concat(favoriteActions("app:" + entry.id))
    return {
      key: "app:" + entry.id,
      favorite: isFavorite("app:" + entry.id),
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
      favorite: isFavorite("cmd:" + command.id),
      title: command.title,
      subtitle: command.kind || "Command",
      icon: "",
      glyph: Icons.glyph(command.glyph),
      // A drawn logo to show in place of the glyph.
      mark: command.mark || "",
      chip: "",
      confirm: command.confirm === true,
      score: score,
      actions: [{ title: command.kind === "Window" ? "Arrange Window" : "Run", run: command.run }].concat(favoriteActions("cmd:" + command.id))
    }
  }

  // An extension or built-in keyword. Choosing it fills the keyword in.
  function scopeRow(scope, score) {
    return {
      key: "kw:" + scope.id,
      favorite: isFavorite("kw:" + scope.id),
      title: scope.title,
      subtitle: scope.subtitle !== scope.title ? scope.subtitle : "",
      icon: "",
      glyph: scope.glyph || Icons.glyph(0xF0349),
      chip: scope.keyword + ":",
      score: score,
      actions: [{ title: "Use Keyword", fill: scope.keyword + ": " }].concat(favoriteActions("kw:" + scope.id))
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
    for (var f = 0; f < favorites.length; f++) {
      var favorite = rowForKey(favorites[f])
      if (!favorite) continue
      favorite.group = "Favorites"
      shown[favorite.key] = true
      list.push(favorite)
    }
    var recentCount = 0
    var keys = Object.keys(frecency).sort((a, b) => frecency[b].last - frecency[a].last)
    for (var i = 0; i < keys.length && recentCount < 5; i++) {
      if (shown[keys[i]]) continue
      var row = rowForKey(keys[i])
      if (!row) continue
      row.group = "Recent"
      shown[row.key] = true
      list.push(row)
      recentCount++
    }

    var rest = []
    var windows = []
    for (var c = 0; c < commands.length; c++) {
      var commandEntry = commandRow(commands[c], 0)
      if (commands[c].kind === "Window") windows.push(commandEntry)
      else rest.push(commandEntry)
    }
    for (var s = 0; s < scopes.length; s++) rest.push(scopeRow(scopes[s], 0))
    rest = rest.filter(r => !shown[r.key])
    rest.sort((a, b) => a.title.localeCompare(b.title))
    for (var r = 0; r < rest.length; r++) rest[r].group = "Commands"
    windows = windows.filter(r => !shown[r.key])
    for (var w = 0; w < windows.length; w++) windows[w].group = "Window Management"
    return list.concat(rest).concat(windows)
  }

  function searchRows() {
    var text = query.trim()
    var list = []
    var apps = DesktopEntries.applications.values

    for (var i = 0; i < apps.length; i++) {
      var entry = apps[i]
      if (entry.noDisplay) continue
      var appScore = Fuzzy.best(text, entry.name, [entry.genericName, entry.id].concat(entry.keywords || []))
      if (appScore > 0) list.push(appRow(entry, appScore + frecencyBonus("app:" + entry.id) + (isFavorite("app:" + entry.id) ? 60 : 0)))
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
    for (var g = 0; g < list.length; g++) list[g].group = "Results"

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
        group: "Calculator",
        actions: [copyAction("Copy Result", exact), copyAction("Copy Expression", text)]
      })
    }
    return list.concat(fallbackRows(text))
  }

  // Raycast's fallback commands: what to do with the text when the list has
  // nothing better, always offered at the bottom.
  function fallbackRows(text) {
    var group = "Use \u201c" + (text.length > 24 ? text.slice(0, 24) + "\u2026" : text) + "\u201d with"
    var list = [{
      key: "fallback:web",
      title: "Search the Web",
      subtitle: "DuckDuckGo",
      icon: "",
      glyph: Icons.glyph(0xF059F),
      chip: "",
      group: group,
      actions: [{ title: "Search the Web", run: () => Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(text)]) }]
    }]
    var more = [["files", "Search Files"], ["define", "Define Word"], ["ch", "Search Clipboard History"], ["emoji", "Search Emoji"]]
    for (var i = 0; i < more.length; i++) {
      var scope = scopes.find(s => s.keyword === more[i][0])
      if (!scope) continue
      list.push({
        key: "fallback:" + scope.id,
        title: more[i][1],
        subtitle: scope.keyword + ":",
        icon: "",
        glyph: scope.glyph || Icons.glyph(0xF0349),
        chip: "",
        group: group,
        actions: [{ title: more[i][1], fill: scope.keyword + ": " + text }]
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
    if (extension.panel === "mouse") {
      if (Mouse.connected) return []
      return [hintRow(Mouse.present ? "The mouse is asleep. Move it to wake it" : "No Razer mouse found", extension)]
    }
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
    search.command = ["sh", "-c", scriptPath + extension.search.replace(/\{([a-z0-9_-]+)\}/gi, function(whole, name) {
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
      var isLong = subtitle.length > 36
      return {
        key: "ext:" + extension.keyword + ":" + (row.id || index),
        title: String(row.title || ""),
        detail: isLong ? subtitle : "",
        subtitle: isLong || keys.length > 0 ? "" : subtitle,
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
    else if (action.exec) Quickshell.execDetached(["sh", "-c", scriptPath + String(action.exec)])
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
    if (key === "calc" || key.indexOf("fallback:") === 0) return
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

  // Like Raycast, it goes away when you move to another workspace.
  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() { if (root.open) root.hide() }
  }

  Connections {
    target: Session
    function onScreensaverChanged() { if (Session.screensaver) root.hide() }
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
    command: ["sh", "-c", root.scriptPath + "for d in \"$@\"; do for f in \"$d\"/*.json; do case \"$f\" in *.cases.json) continue;; esac; "
      + "[ -f \"$f\" ] || continue; when=$(jq -r '.when // \"\"' \"$f\" 2>/dev/null) || continue; "
      + "if [ -z \"$when\" ] || sh -c \"$when\" >/dev/null 2>&1; then jq -c . \"$f\"; fi; done; done", "sh"].concat(root.extensionDirs)
    stdout: StdioCollector {
      onStreamFinished: {
        var list = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trim() === "") continue
          try {
            var raw = JSON.parse(lines[i])
            if (!raw.id || !raw.search) continue
            list = list.filter(e => e.id !== String(raw.id))
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
    id: favoritesFile
    path: root.stateDir + "/favorites.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        var saved = JSON.parse(text())
        if (Array.isArray(saved)) root.favorites = saved
      } catch (e) {}
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

  // Other parts of the shell can ask for one of the built-in views.
  Connections {
    target: PopupState
    function onRequested(name) { if (name === "shots") root.show("shots: ") }
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void { if (root.open) root.hide(); else root.show("") }
    function open(query: string): void { root.show(query) }
    function close(): void { root.hide() }
  }

  // A key, drawn like one.
  component Keycap: Rectangle {
    property alias text: capLabel.text

    implicitWidth: Math.max(20, capLabel.implicitWidth + 10)
    implicitHeight: 20
    radius: 5
    color: Theme.alpha(Theme.foreground, 0.06)
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.22)

    // The darker lower edge that makes it read as a raised key.
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: 4
      anchors.rightMargin: 4
      height: 1
      color: Theme.alpha(Theme.foreground, 0.28)
    }

    Label {
      id: capLabel
      anchors.centerIn: parent
      color: Theme.foreground
      font.pixelSize: Theme.fontSmall
      elide: Text.ElideNone
    }
  }

  component Chip: Rectangle {
    property alias text: chipLabel.text
    property bool accented: false

    visible: chipLabel.text !== ""
    implicitWidth: chipLabel.implicitWidth + 16
    implicitHeight: 18
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
    // Real pixels per point. Screen.devicePixelRatio rounds 1.6 up to 2, but
    // the window itself is drawn at the monitor's fractional scale.
    readonly property real pixelScale: Hyprland.focusedMonitor?.scale ?? Screen.devicePixelRatio
    visible: root.open
    anchors { top: true; bottom: true; left: true; right: true }
    // No dimming: like Raycast, it floats over whatever is there.
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aayork-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) {
      input.forceActiveFocus()
      appear.restart()
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.hide()
    }

    // A soft shadow under the card, so it floats.
    RectangularShadow {
      anchors.fill: card
      radius: card.radius
      offset.y: 14
      blur: 48
      spread: -4
      color: Theme.alpha("#000000", 0.5)
      opacity: card.opacity
    }

    // Opens with a quick fade and settle, like Raycast.
    ParallelAnimation {
      id: appear
      NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
      NumberAnimation { target: card; property: "scale"; from: 0.975; to: 1; duration: 160; easing.type: Easing.OutCubic }
    }

    Rectangle {
      id: card
      width: 720
      height: column.implicitHeight
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.2)
      // Translucent: Hyprland blurs what is behind it (a layer rule for
      // aayork-launcher in hyprland.lua).
      color: Theme.alpha(Theme.background, 0.8)
      border.width: 1
      border.color: Theme.alpha(Theme.foreground, 0.14)
      radius: root.corner
      clip: true

      MouseArea { anchors.fill: parent }

      ColumnLayout {
        id: column
        width: parent.width
        spacing: 0

        // The magnifier sits in the rows' icon column and the text starts
        // where the row titles do, so the search lines up with the list.
        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: 34
          Layout.rightMargin: 14
          Layout.topMargin: 12
          Layout.bottomMargin: 12
          spacing: 10

          Label {
            text: Icons.glyph(0xF0349)
            font.pixelSize: Theme.iconLarge
            color: Theme.dim
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: 20
            elide: Text.ElideNone
          }

          TextInput {
            id: input
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            verticalAlignment: TextInput.AlignVCenter
            text: root.query
            color: Theme.brightForeground
            selectionColor: Theme.selection
            selectedTextColor: Theme.brightForeground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLarge + 3
            clip: true
            onTextEdited: root.query = text

            Label {
              anchors.fill: parent
              visible: input.text === ""
              text: "Search apps and commands"
              color: Theme.dim
              font.pixelSize: Theme.fontLarge + 3
            }

            Keys.onPressed: function(event) {
              var control = (event.modifiers & Qt.ControlModifier) !== 0
              var enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
              event.accepted = true

              if (control && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_F) {
                var current = root.currentRow
                if (current && /^(app|cmd|kw):/.test(current.key)) root.toggleFavorite(current.key)
              } else if (control && event.key === Qt.Key_K) {
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
                root.move(12)
              } else if (event.key === Qt.Key_PageUp) {
                root.move(-12)
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

        Separator { Layout.fillWidth: true; visible: list.count > 0 || mousePanel.visible }

        // The `mouse:` keyword's panel, the same one the bar used to open.
        MouseSettings {
          id: mousePanel
          visible: root.open && root.scoped !== null && root.scoped.extension.panel === "mouse" && Mouse.connected
          Layout.fillWidth: true
          Layout.margins: 14
          onVisibleChanged: Mouse.watching = visible
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 0

        ListView {
          id: list
          Layout.fillWidth: !root.split
          Layout.preferredWidth: root.split ? 290 : -1
          Layout.alignment: Qt.AlignTop
          Layout.topMargin: 4
          Layout.bottomMargin: 4
          // About twelve rows before it scrolls.
          // A split view keeps its full height so the preview has room.
          implicitHeight: root.split ? 12 * root.rowHeight + 22 : Math.min(contentHeight, 12 * root.rowHeight + 22)
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
              height: visible ? 22 : 0
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
              // A row with a second line needs a little more room.
              height: row.modelData.detail ? root.rowHeight + 6 : root.rowHeight

              Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                radius: root.smallCorner
                color: row.armed ? Theme.alpha(Theme.red, 0.2) : row.current && !row.modelData.hint ? Theme.alpha(Theme.foreground, 0.09) : "transparent"
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
                width: 20
                height: 20
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.verticalCenter: parent.verticalCenter

                // Asked for at exactly the pixels it is drawn at (the monitor's
                // fractional scale), so nothing gets rescaled and it stays sharp.
                Image {
                  anchors.fill: parent
                  visible: row.modelData.icon !== ""
                  source: row.modelData.icon
                  sourceSize.width: Math.ceil(parent.width * window.pixelScale)
                  sourceSize.height: Math.ceil(parent.height * window.pixelScale)
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                }
                TailscaleIcon {
                  anchors.centerIn: parent
                  visible: row.modelData.mark === "tailscale"
                  size: 14
                  color: row.current ? Theme.foreground : Theme.dim
                }
                Label {
                  anchors.centerIn: parent
                  visible: row.modelData.icon === "" && !row.modelData.mark
                  text: row.modelData.glyph
                  font.pixelSize: Theme.iconSize
                  color: row.armed ? Theme.red : row.current ? Theme.foreground : Theme.dim
                  elide: Text.ElideNone
                }
              }

              // Title, with a line of detail under it when there is one.
              Column {
                anchors.left: icon.right
                anchors.leftMargin: 10
                anchors.right: tail.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Label {
                  width: parent.width
                  text: row.armed ? "Enter again to " + row.modelData.title.toLowerCase() : row.modelData.title
                  color: row.armed ? Theme.red : row.modelData.hint ? Theme.dim : row.current ? Theme.brightForeground : Theme.foreground
                  font.pixelSize: Theme.fontSize
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
                      height: 18
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

                Label {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: row.modelData.favorite === true
                  text: Icons.glyph(0xF04CE)
                  color: Theme.yellow
                  font.pixelSize: Theme.fontSmall
                  elide: Text.ElideNone
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

          Rectangle {
            visible: root.split
            Layout.fillHeight: true
            implicitWidth: 1
            color: Theme.separator
          }

          // What the current row is: its text or picture, and a few facts
          // about it underneath.
          ColumnLayout {
            id: pane
            visible: root.split
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 12
            spacing: 10

            readonly property var preview: root.currentRow && root.currentRow.preview ? root.currentRow.preview : null

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true

              Image {
                anchors.fill: parent
                visible: pane.preview !== null && pane.preview.image !== ""
                source: visible ? pane.preview.image : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 800
                sourceSize.height: 800
              }

              Rectangle {
                anchors.centerIn: parent
                visible: pane.preview !== null && pane.preview.colour !== ""
                width: 96
                height: 96
                radius: Theme.controlRadius + 4
                color: visible ? pane.preview.colour : "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.foreground, 0.2)
              }

              Label {
                anchors.fill: parent
                visible: pane.preview !== null && pane.preview.image === "" && pane.preview.colour === ""
                text: pane.preview ? pane.preview.text : ""
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                verticalAlignment: Text.AlignTop
                font.pixelSize: Theme.fontSmall
              }
            }

            Separator { Layout.fillWidth: true }
            SectionHeader { text: "INFORMATION" }

            Repeater {
              model: pane.preview ? pane.preview.info : []

              RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Label { text: modelData[0]; color: Theme.dim; font.pixelSize: Theme.fontSmall; Layout.fillWidth: true }
                Label { text: modelData[1]; font.pixelSize: Theme.fontSmall; elide: Text.ElideNone }
              }
            }
          }
        }

        // The footer, as in Raycast: where you are on the left; what Enter
        // does and the way into the other actions on the right.
        Rectangle {
          id: footer
          visible: root.currentActions.length > 0 || root.scoped !== null
          Layout.fillWidth: true
          implicitHeight: 40
          color: Theme.alpha(Theme.foreground, 0.035)

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.alpha(Theme.foreground, 0.1)
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 6

            Label {
              text: root.scoped ? (root.scoped.extension.glyph || Icons.glyph(0xF0349)) : Icons.glyph(0xF0349)
              color: Theme.dim
              font.pixelSize: Theme.iconSize
              elide: Text.ElideNone
            }
            Label {
              text: root.scoped ? root.scoped.extension.title : "Search"
              color: Theme.dim
              font.pixelSize: Theme.fontSmall
              Layout.maximumWidth: 200
            }

            Item { Layout.fillWidth: true }

            Label {
              visible: root.currentActions.length > 0
              text: root.currentActions.length > 0 ? root.currentActions[0].title : ""
              color: Theme.foreground
              font.pixelSize: Theme.fontSmall
              font.bold: true
              Layout.maximumWidth: 220
            }
            Keycap { visible: root.currentActions.length > 0; text: "↵" }

            Rectangle {
              visible: root.currentActions.length > 1
              Layout.leftMargin: 6
              Layout.rightMargin: 6
              implicitWidth: 1
              implicitHeight: 16
              color: Theme.alpha(Theme.foreground, 0.15)
            }

            Label {
              visible: root.currentActions.length > 1
              text: "Actions"
              color: root.actionsOpen ? Theme.accent : Theme.dim
              font.pixelSize: Theme.fontSmall
              elide: Text.ElideNone
            }
            Keycap { visible: root.currentActions.length > 1; text: "Ctrl" }
            Keycap { visible: root.currentActions.length > 1; text: "K" }
          }
        }
      }
    }

    // Ctrl+K: everything else the current row can do.
    // A popover just above the footer's right end, the way Raycast's opens.
    RectangularShadow {
      anchors.fill: actionPanel
      visible: actionPanel.visible
      radius: actionPanel.radius
      offset.y: 10
      blur: 36
      spread: -4
      color: Theme.alpha("#000000", 0.5)
    }

    Rectangle {
      id: actionPanel
      visible: root.actionsOpen && root.currentActions.length > 0
      width: 320
      height: actionColumn.implicitHeight + 14
      anchors.right: card.right
      anchors.rightMargin: 10
      anchors.bottom: card.bottom
      anchors.bottomMargin: 46
      color: Theme.alpha(Theme.background, 0.86)
      border.width: 1
      border.color: Theme.alpha(Theme.foreground, 0.16)
      radius: root.corner

      MouseArea { anchors.fill: parent }

      Column {
        id: actionColumn
        x: 7
        y: 7
        width: parent.width - 14

        Label {
          width: parent.width
          leftPadding: 10
          topPadding: 2
          bottomPadding: 6
          text: root.currentRow ? root.currentRow.title : "Actions"
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
        }

        Repeater {
          model: root.actionsOpen ? root.currentActions : []

          Rectangle {
            id: actionRow
            required property var modelData
            required property int index

            width: actionColumn.width
            height: 30
            radius: root.smallCorner
            color: root.actionCursor === index ? Theme.alpha(Theme.foreground, 0.09) : "transparent"

            Label {
              anchors.left: parent.left
              anchors.right: hint.left
              anchors.leftMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: actionRow.modelData.title
            }
            Row {
              id: hint
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              spacing: 4
              Keycap { visible: actionRow.index === 1; text: "⇧" }
              Keycap { visible: actionRow.index < 2; text: "↵" }
              Repeater {
                model: actionRow.index >= 2 ? (actionRow.modelData.shortcut || []) : []
                Keycap { required property string modelData; text: modelData }
              }
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
