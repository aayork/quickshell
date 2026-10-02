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
    { id: "displays", title: "Displays", keyword: "displays", aliases: ["display", "monitor", "monitors", "resolution", "scale"],
      glyph: Icons.glyph(0xF0379), minChars: 0, debounceMs: 0, maxRows: 60, provider: displays }
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

  readonly property var commands: [
    { id: "lock", title: "Lock", glyph: 0xF033E, words: "lock screen", run: () => Session.run("lock") },
    { id: "suspend", title: "Suspend", glyph: 0xF04B2, words: "sleep", run: () => Session.run("suspend") },
    { id: "logout", title: "Log out", glyph: 0xF0343, words: "exit sign out", confirm: true, run: () => Session.run("logout") },
    { id: "reboot", title: "Restart", glyph: 0xF0709, words: "reboot", confirm: true, run: () => Session.run("reboot") },
    { id: "shutdown", title: "Shut down", glyph: 0xF0425, words: "power off poweroff", confirm: true, run: () => Session.run("shutdown") },
    { id: "wifi", title: "Wi-Fi", glyph: 0xF0928, words: "network internet", run: () => PopupState.request("network") },
    { id: "audio", title: "Control Center", glyph: 0xF057E, words: "audio volume sound bluetooth output input", run: () => PopupState.request("control-center") },
    { id: "tailscale", title: "Tailscale", glyph: 0xF0582, words: "vpn tailnet", run: () => PopupState.request("tailscale") },
    { id: "bose", title: "Bose", glyph: 0xF02CB, words: "headphones noise cancelling equalizer", run: () => PopupState.request("bose") },
    { id: "calendar", title: "Calendar and Weather", glyph: 0xF0599, words: "clock date notifications", run: () => PopupState.request("clock") },
    { id: "colorpicker", title: "Color Picker", glyph: 0xF0349, words: "colour pick hex hyprpicker", run: () => Quickshell.execDetached(["hyprpicker", "-a"]) },
    { id: "reload", title: "Reload Shell", glyph: 0xF0450, words: "restart quickshell", run: () => Quickshell.reload(true) }
  ]

  readonly property var rows: scoped ? scopedRows() : rootRows()

  function frecencyBonus(key) {
    var entry = frecency[key]
    if (!entry) return 0
    var days = (Date.now() - entry.last) / 86400000
    return Math.min(200, entry.count * 8) + (days < 7 ? 50 : 0)
  }

  function appRow(entry, score) {
    return {
      key: "app:" + entry.id,
      title: entry.name,
      subtitle: entry.genericName || entry.comment || "",
      icon: Quickshell.iconPath(entry.icon, "application-x-executable"),
      glyph: "",
      accessory: "",
      score: score,
      run: () => entry.execute()
    }
  }

  function commandRow(command, score) {
    return {
      key: "cmd:" + command.id,
      title: command.title,
      subtitle: "Command",
      icon: "",
      glyph: Icons.glyph(command.glyph),
      accessory: "",
      confirm: command.confirm === true,
      score: score,
      run: command.run
    }
  }

  function rootRows() {
    var text = query.trim()
    var list = []
    var apps = DesktopEntries.applications.values

    for (var i = 0; i < apps.length; i++) {
      var entry = apps[i]
      if (entry.noDisplay) continue
      var appScore = text === "" ? 0 : Fuzzy.best(text, entry.name, [entry.genericName, entry.id].concat(entry.keywords || []))
      if (text !== "" && appScore === 0) continue
      var appBonus = frecencyBonus("app:" + entry.id)
      if (text === "" && appBonus === 0) continue
      list.push(appRow(entry, appScore + appBonus))
    }

    for (var c = 0; c < commands.length; c++) {
      var command = commands[c]
      var commandScore = text === "" ? 0 : Fuzzy.best(text, command.title, command.words.split(" "))
      if (text !== "" && commandScore === 0) continue
      var commandBonus = frecencyBonus("cmd:" + command.id)
      if (text === "" && commandBonus === 0) continue
      // Things that end the session never outrank an app on a loose match.
      list.push(commandRow(command, (commandScore + commandBonus) * (command.confirm ? 0.7 : 0.95)))
    }

    // Extensions show up by name; choosing one fills in its keyword.
    if (text !== "") {
      for (var e = 0; e < scopes.length; e++) {
        var extension = scopes[e]
        var extensionScore = Fuzzy.best(text, extension.keyword, [extension.title].concat(extension.aliases))
        if (extensionScore === 0) continue
        list.push({
          key: "kw:" + extension.id,
          title: extension.title,
          subtitle: extension.keyword + ":",
          icon: "",
          glyph: extension.glyph || Icons.glyph(0xF0349),
          accessory: "",
          score: extensionScore * 0.8,
          fill: extension.keyword + ": "
        })
      }
    }

    list.sort(function(a, b) { return b.score - a.score || a.title.localeCompare(b.title) })
    list = list.slice(0, text === "" ? 9 : maxRows)

    var answer = Calc.evaluate(text)
    if (answer !== null) {
      var shown = Calc.format(answer)
      list.unshift({
        key: "calc",
        title: shown,
        subtitle: "Copy result",
        icon: "",
        glyph: Icons.glyph(0xF00EC),
        accessory: "",
        score: 9999,
        run: () => Quickshell.execDetached(["wl-copy", "--", String(Math.round(answer * 1e10) / 1e10)])
      })
    }
    return list
  }

  function scopedRows() {
    var extension = scoped.extension
    if (extension.provider) return extension.provider.rows(scoped.text)
    if (scoped.text.trim().length < extension.minChars) {
      return [{ key: "hint", title: extension.title, subtitle: "Keep typing to search", icon: "", glyph: extension.glyph, accessory: "", hint: true }]
    }
    if (extensionRows.length === 0) {
      return [{ key: "hint", title: extensionBusy ? "Searching…" : "Nothing found", subtitle: extension.title, icon: "", glyph: extension.glyph, accessory: "", hint: true }]
    }
    return extensionRows
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
      return {
        key: "ext:" + extension.keyword + ":" + (row.id || index),
        title: String(row.title || ""),
        subtitle: String(row.subtitle || ""),
        icon: icon === "" ? "" : icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon, true),
        glyph: String(row.glyph || extension.glyph || ""),
        accessory: String(row.accessory || ""),
        group: String(row.group || ""),
        keys: Array.isArray(row.keys) ? row.keys : [],
        exec: String(row.exec || ""),
        keepOpen: row.keepOpen === true
      }
    })
  }

  function activate(index) {
    var row = rows[index]
    if (!row || row.hint) return
    if (row.fill) {
      query = row.fill
      return
    }
    if (row.confirm && armed !== row.key) {
      armed = row.key
      return
    }
    if (!row.keepOpen) remember(row.key)
    if (row.run) row.run()
    else if (row.exec) Quickshell.execDetached(["sh", "-c", row.exec])
    if (!row.keepOpen) hide()
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
    open = true
  }

  function hide() {
    open = false
  }

  onQueryChanged: {
    cursor = 0
    armed = ""
  }

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
      width: 640
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
              text: "Search apps and commands"
              color: Theme.dim
              font.pixelSize: Theme.fontLarge
            }

            Keys.onPressed: function(event) {
              var count = root.rows.length
              var control = event.modifiers & Qt.ControlModifier
              if (event.key === Qt.Key_Escape) {
                if (root.query !== "") root.query = ""
                else root.hide()
              } else if (event.key === Qt.Key_Down || (control && (event.key === Qt.Key_N || event.key === Qt.Key_J))) {
                if (count > 0) root.cursor = (root.cursor + 1) % count
                root.armed = ""
              } else if (event.key === Qt.Key_Up || (control && (event.key === Qt.Key_P || event.key === Qt.Key_K))) {
                if (count > 0) root.cursor = (root.cursor + count - 1) % count
                root.armed = ""
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activate(root.cursor)
              } else if (event.key === Qt.Key_Tab) {
                var row = root.rows[root.cursor]
                if (row && row.fill) root.query = row.fill
              } else {
                return
              }
              event.accepted = true
            }
          }

          Label {
            visible: root.scoped !== null
            text: root.scoped ? root.scoped.extension.title : ""
            color: Theme.accent
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideNone
          }
        }

        Separator { Layout.fillWidth: true; visible: list.count > 0 }

        ListView {
          id: list
          Layout.fillWidth: true
          Layout.margins: 6
          implicitHeight: Math.min(contentHeight, 9 * 40)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.rows
          currentIndex: root.cursor
          highlightMoveDuration: 0
          // A new answer starts back at the top.
          onModelChanged: positionViewAtBeginning()
          onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

          delegate: Rectangle {
            id: row
            required property var modelData
            required property int index

            readonly property bool current: root.cursor === index
            readonly property bool armed: root.armed === modelData.key

            width: list.width
            height: 40
            radius: Theme.controlRadius
            color: armed ? Theme.alpha(Theme.red, 0.2) : current && !modelData.hint ? Theme.selection : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 12

              Item {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24

                Image {
                  anchors.fill: parent
                  visible: row.modelData.icon !== ""
                  source: row.modelData.icon
                  sourceSize.width: 48
                  sourceSize.height: 48
                  asynchronous: true
                }
                Label {
                  anchors.centerIn: parent
                  visible: row.modelData.icon === ""
                  text: row.modelData.glyph
                  font.pixelSize: Theme.iconLarge
                  color: row.armed ? Theme.red : Theme.dim
                  elide: Text.ElideNone
                }
              }

              Label {
                text: row.armed ? "Enter again to " + row.modelData.title.toLowerCase() : row.modelData.title
                color: row.armed ? Theme.red : row.modelData.hint ? Theme.dim : Theme.foreground
                font.pixelSize: Theme.fontSize + 1
                Layout.maximumWidth: 380
              }

              // Shortcut rows say the same thing in their key chips.
              Label {
                text: (row.modelData.keys || []).length > 0 ? "" : row.modelData.subtitle
                color: Theme.dim
                font.pixelSize: Theme.fontSmall
                Layout.fillWidth: true
              }

              // Key chips for shortcut rows.
              Row {
                visible: (row.modelData.keys || []).length > 0
                spacing: 4

                Repeater {
                  model: (row.modelData.keys || []).slice(0, 6)

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

              Label {
                visible: text !== ""
                text: row.modelData.accessory || row.modelData.group || ""
                color: Theme.dim
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideNone
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onPositionChanged: if (root.cursor !== row.index) { root.cursor = row.index; root.armed = "" }
              onClicked: root.activate(row.index)
            }
          }
        }
      }
    }
  }
}
