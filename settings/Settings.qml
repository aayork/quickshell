import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.ui

// Settings: how things look, how the shell behaves, how windows are drawn,
// and the network and Bluetooth panels.
//
// Theme, background, font, cursor and window style are applied by the
// scripts in bin/ (theme-set and friends), which also recolour the other
// apps. This is the front end for them.
Scope {
  id: root

  property bool open: false
  property string tab: "appearance"

  readonly property var tabs: [
    { id: "appearance", label: "Appearance", glyph: 0xF03D8, about: "Theme, background, font, cursor and icons" },
    { id: "shell", label: "Shell", glyph: 0xF0379, about: "Night light, the bar, the screensaver and the lock" },
    { id: "windows", label: "Windows", glyph: 0xF05AF, about: "How Hyprland draws and spaces windows" },
    { id: "network", label: "Network", glyph: 0xF0928, about: "Wi-Fi networks in range" },
    { id: "bluetooth", label: "Bluetooth", glyph: 0xF00AF, about: "Paired devices and new ones nearby" },
    { id: "calendar", label: "Calendar", glyph: 0xF00ED, about: "Accounts whose events show in the clock popup" },
    { id: "jot", label: "Jot", glyph: 0xF039B, about: "The scratchpad under the bar's note button" }
  ]
  readonly property var currentTab: tabs.find(t => t.id === tab) ?? tabs[0]

  // ---------------------------------------------------------------- state
  property var themes: []
  property string theme: ""
  // Background files on hand, newest first.
  property var available: []
  // What the Background card shows: the ones used last, topped up with the
  // newest files until there are five. Anything else comes from "Choose file".
  readonly property var backgrounds: {
    // Only files the list below vouched for: drawable, and still there.
    var list = Background.recent.filter(p => available.indexOf(p) !== -1)
    for (var i = 0; i < available.length && list.length < Background.recentLimit; i++)
      if (list.indexOf(available[i]) === -1) list.push(available[i])
    return list.slice(0, Background.recentLimit).map(p => ({ path: p }))
  }
  property var fonts: []
  property string font: ""
  property var cursors: []
  property string cursor: ""
  property int cursorSize: 24
  // Sizes this cursor theme has crisp bitmaps for.
  property var cursorSizes: []
  property var iconThemes: []
  property string iconTheme: ""
  // Hex just copied from a swatch, or the swatch under the pointer.
  property string swatchNote: ""

  readonly property string stateDir: Theme.stateDir
  readonly property string bin: Quickshell.shellDir + "/bin/"
  readonly property string iconDirs: "\"$HOME/.local/share/icons\" \"$HOME/.icons\" /usr/share/icons"

  function show(which) {
    if (tabs.some(t => t.id === which)) tab = which
    load()
    open = true
  }

  function hide() {
    open = false
  }

  function load() {
    themeList.running = true
    themeCurrent.running = true
    backgroundList.running = true
    fontList.running = true
    fontCurrent.running = true
    cursorList.running = true
    cursorCurrent.running = true
    iconList.running = true
    iconCurrent.running = true
    matchStyleCurrent.running = true
    videoCount.running = true
    Background.check()
  }

  function pretty(name) {
    return String(name || "").replace(/\.[^.]+$/, "").replace(/^\d+-/, "").replace(/[-_]/g, " ")
      .replace(/\b\w/g, function(c) { return c.toUpperCase() })
  }

  // ---------------------------------------------------------------- appearance
  function applyTheme(name) {
    theme = name
    Quickshell.execDetached([root.bin + "theme-set", name])
    // The script takes about a second and picks the theme's own background.
    settle.restart()
  }

  function applyBackground(path) {
    Quickshell.execDetached([root.bin + "theme-bg-set", path])
    settle.restart()
  }

  // Builds a palette from the current background and applies it as the
  // generated "Wallpaper" theme.
  // How colourful a matched theme is, strongest first: vibrant, balanced,
  // soft, muted or monochrome. theme-from-background remembers the last one.
  property string matchStyle: "balanced"

  function matchTheme(style) {
    if (Background.path === "" || matchProcess.running) return
    if (style) matchStyle = style
    matchProcess.command = [root.bin + "theme-from-background", "--style", matchStyle, Background.path]
    matchProcess.running = true
  }

  // The desktop's own file chooser, opened in Pictures. It floats over this
  // window and closes itself once a file is picked.
  function browseBackground() {
    if (!browseProcess.running) browseProcess.running = true
  }

  // A chosen file is copied into the theme's own backgrounds folder, so it
  // stays selectable even if the original moves.
  readonly property string importScript: "src=$(realpath -- \"$1\") || exit 1; "
    + "theme=$(cat \"$HOME/.local/state/aayork-quickshell/current/theme.name\" 2>/dev/null); "
    + "dir=\"$HOME/.config/aayork-quickshell/backgrounds/$theme\"; "
    + "themedir=$(realpath -m \"$HOME/.local/state/aayork-quickshell/current/theme/backgrounds\"); "
    + "case \"$src\" in \"$dir\"/*|\"$themedir\"/*) dest=$src ;; "
    + "*) mkdir -p \"$dir\" || exit 1; dest=\"$dir/${src##*/}\"; "
    + "if [ -e \"$dest\" ] && ! cmp -s \"$src\" \"$dest\"; then dest=\"$dir/$(date +%s)-${src##*/}\"; fi; "
    + "[ -e \"$dest\" ] || cp -- \"$src\" \"$dest\" || exit 1 ;; esac; "
    + "\"$2theme-bg-set\" \"$dest\""

  function applyFont(name) {
    font = name
    // Restarts the shell at the end, since Qt reads fonts once at startup.
    Quickshell.execDetached([Quickshell.shellDir + "/bin/font-set", name])
  }

  function applyCursor(name, size) {
    cursor = name
    cursorSize = size
    Quickshell.execDetached([root.bin + "cursor-set", name, String(size)])
  }

  function nearestCursorSize(size) {
    var best = cursorSizes[0] || size
    for (var i = 1; i < cursorSizes.length; i++)
      if (Math.abs(cursorSizes[i] - size) < Math.abs(best - size)) best = cursorSizes[i]
    return best
  }

  function applyIconTheme(name) {
    iconTheme = name
    Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", name])
  }

  // ---------------------------------------------------------------- windows
  function applyWindows() {
    var w = Config.windows
    Quickshell.execDetached([root.bin + "window-style", String(w.rounding), String(w.gapsIn), String(w.gapsOut),
      String(w.border), w.shadow ? "on" : "off", w.animations])
  }

  // ---------------------------------------------------------------- probes
  component Lines: Process {
    id: lines
    property var result: []
    stdout: StdioCollector {
      onStreamFinished: lines.result = text.split("\n").filter(l => l !== "")
    }
  }

  Lines { id: themeList; command: [root.bin + "theme-list"]; onResultChanged: root.themes = result }
  Lines { id: themeCurrent; command: [root.bin + "theme-current"]; onResultChanged: root.theme = result[0] || "" }
  Lines {
    id: matchStyleCurrent
    command: ["sh", "-c", "cat \"$HOME/.local/state/aayork-quickshell/match-style\" 2>/dev/null || echo balanced"]
    onResultChanged: root.matchStyle = result[0] || "balanced"
  }
  Lines { id: fontList; command: [root.bin + "font-list"]; onResultChanged: root.fonts = result }
  Lines { id: fontCurrent; command: [root.bin + "font-current"]; onResultChanged: root.font = result[0] || "" }
  Lines {
    id: cursorList
    command: ["sh", "-c", "for d in " + root.iconDirs + "; do [ -d \"$d\" ] && find \"$d\" -mindepth 1 -maxdepth 1; done | while read -r t; do [ -d \"$t/cursors\" ] && basename \"$t\"; done | sort -u"]
    onResultChanged: root.cursors = result
  }
  Lines {
    id: cursorCurrent
    command: ["sh", "-c", "gsettings get org.gnome.desktop.interface cursor-theme | tr -d \"'\"; gsettings get org.gnome.desktop.interface cursor-size"]
    onResultChanged: {
      root.cursor = result[0] || ""
      root.cursorSize = parseInt(result[1], 10) || 24
    }
  }
  Lines {
    id: cursorSizeList
    onResultChanged: root.cursorSizes = result.map(n => parseInt(n, 10)).filter(n => n > 0)
  }
  Lines {
    id: iconList
    command: ["sh", "-c", "for d in " + root.iconDirs + "; do [ -d \"$d\" ] && find \"$d\" -mindepth 1 -maxdepth 1; done | while read -r t; do [ -f \"$t/index.theme\" ] && [ ! -d \"$t/cursors\" -o -d \"$t/apps\" -o -d \"$t/scalable\" -o -d \"$t/48x48\" ] && basename \"$t\"; done | sort -u"]
    onResultChanged: root.iconThemes = result
  }
  Lines {
    id: iconCurrent
    command: ["sh", "-c", "gsettings get org.gnome.desktop.interface icon-theme | tr -d \"'\""]
    onResultChanged: root.iconTheme = result[0] || ""
  }
  // The current theme's backgrounds plus the user's own for it, newest file
  // first. Only used to fill out the recents.
  Lines {
    id: backgroundList
    command: ["sh", "-c", "theme=$(cat \"$HOME/.local/state/aayork-quickshell/current/theme.name\" 2>/dev/null); "
      + "find -L \"$HOME/.config/aayork-quickshell/backgrounds/$theme/\" \"$HOME/.local/state/aayork-quickshell/current/theme/backgrounds/\" -maxdepth 1 -type f "
      + "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \\) -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | cut -f2- "
      // By content, not by name: a HEIF saved as .png cannot be drawn.
      + "| while IFS= read -r f; do case $(file -b --mime-type -- \"$f\") in image/jpeg|image/png|image/webp|image/gif) printf '%s\\n' \"$f\" ;; esac; done"]
    onResultChanged: root.available = result
  }

  // How many videos the screensaver folder holds.
  Lines {
    id: videoCount
    command: ["sh", "-c", "d=\"$1\"; d=\"${d/#\\~/$HOME}\"; find -L \"$d\" -maxdepth 1 -type f \\( -iname '*.mov' -o -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.mkv' -o -iname '*.webm' \\) 2>/dev/null | wc -l", "sh", Config.screensaver.folder]
  }
  Connections {
    target: Config.screensaver
    function onFolderChanged() { videoCount.running = true }
  }

  // The command is set here, not bound: a binding on `cursor` is not
  // guaranteed to have caught up when this handler runs.
  onCursorChanged: {
    if (cursor === "") return
    cursorSizeList.running = false
    cursorSizeList.command = [root.bin + "cursor-set", "--sizes", cursor]
    cursorSizeList.running = true
  }

  Process {
    id: matchProcess
    onExited: root.load()
  }

  Process {
    id: browseProcess
    command: [root.bin + "pick-file", "--images", "--title", "Choose a background", "--folder", Quickshell.env("HOME") + "/Pictures"]
    stdout: StdioCollector {
      onStreamFinished: {
        var path = text.trim()
        if (path !== "") {
          importProcess.command = ["sh", "-c", root.importScript, "sh", path, root.bin]
          importProcess.running = true
        }
      }
    }
  }

  Process {
    id: importProcess
    onExited: settle.restart()
  }

  // Account picture (login screen), via bin/account-picture.
  property int pictureRevision: 0
  Process {
    id: pictureBrowse
    command: [root.bin + "pick-file", "--images", "--title", "Choose a picture", "--folder", Quickshell.env("HOME") + "/Pictures"]
    stdout: StdioCollector {
      onStreamFinished: {
        var path = text.trim()
        if (path !== "") {
          pictureSet.command = [root.bin + "account-picture", path]
          pictureSet.running = true
        }
      }
    }
  }
  Process {
    id: pictureSet
    onExited: root.pictureRevision++
  }

  // After a theme or background change, once the scripts have finished.
  Timer {
    id: settle
    interval: 1300
    onTriggered: {
      themeCurrent.running = true
      backgroundList.running = true
      Background.check()
    }
  }

  // The launcher's Settings command asks through the same channel the bar
  // popups use.
  Connections {
    target: PopupState
    function onRequested(name) {
      // "settings:<tab>" opens on that tab.
      if (name === "settings") root.show("")
      else if (name.indexOf("settings:") === 0) root.show(name.slice(9))
    }
  }

  IpcHandler {
    target: "settings"
    function toggle(): void { if (root.open) root.hide(); else root.show("") }
    function open(tab: string): void { root.show(tab) }
    function close(): void { root.hide() }
  }

  // ---------------------------------------------------------------- pieces
  // A setting: an icon, what it is, and its control on the right.
  component Setting: RowLayout {
    id: setting
    property int glyph: 0
    property alias label: name.text
    property string note: ""
    default property alias control: slot.data

    Layout.fillWidth: true
    spacing: 12

    Label {
      visible: setting.glyph !== 0
      text: setting.glyph !== 0 ? Icons.glyph(setting.glyph) : ""
      color: Theme.accent
      font.pixelSize: Theme.iconLarge
      horizontalAlignment: Text.AlignHCenter
      Layout.preferredWidth: 22
      elide: Text.ElideNone
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      Label { id: name; Layout.fillWidth: true }
      Label {
        visible: text !== ""
        text: setting.note
        color: Theme.dim
        font.pixelSize: Theme.fontSmall
        Layout.fillWidth: true
      }
    }
    RowLayout { id: slot; spacing: 8 }
  }

  // A softly raised group of related settings, under a small heading.
  component Card: ColumnLayout {
    property alias title: heading.text
    default property alias content: body.data

    Layout.fillWidth: true
    spacing: 6

    SectionHeader {
      id: heading
      visible: text !== ""
      Layout.leftMargin: 2
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: body.implicitHeight + 28
      radius: Theme.controlRadius + 4
      color: Theme.alpha(Theme.foreground, 0.035)
      border.width: 1
      border.color: Theme.alpha(Theme.foreground, 0.1)

      ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 14
      }
    }
  }

  component Swatches: Row {
    property var keys: []
    spacing: 4

    Repeater {
      model: parent.keys.filter(k => Theme.colors[k] !== undefined)

      Rectangle {
        required property string modelData
        width: 26
        height: 26
        radius: Theme.controlRadius
        color: Theme.colors[modelData]
        border.width: 1
        border.color: Theme.alpha(Theme.foreground, swatchMouse.containsMouse ? 0.7 : 0.15)

        MouseArea {
          id: swatchMouse
          anchors.fill: parent
          hoverEnabled: true
          onEntered: root.swatchNote = parent.modelData.replace(/_/g, " ") + "  " + Theme.colors[parent.modelData]
          onClicked: {
            Quickshell.execDetached(["wl-copy", "--", Theme.colors[parent.modelData]])
            root.swatchNote = "Copied " + Theme.colors[parent.modelData]
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- window
  // A real window, not a layer over the screen, so the desktop's file chooser
  // can open on top of it. Hyprland floats, centres and dims around it by a
  // rule in hyprland.lua that matches this title.
  FloatingWindow {
    title: "Settings"
    visible: root.open
    implicitWidth: 760
    implicitHeight: 620
    minimumSize: Qt.size(640, 420)
    color: Theme.background

    // Closed from outside (SUPER+W, say).
    onClosed: root.open = false
    onVisibleChanged: if (visible) keys.forceActiveFocus()

    Item {
      id: card
      anchors.fill: parent

      // Clicking empty space takes focus back from a text field.
      MouseArea {
        anchors.fill: parent
        onClicked: keys.forceActiveFocus()
      }

      FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
          var index = root.tabs.findIndex(t => t.id === root.tab)
          event.accepted = true
          if (event.key === Qt.Key_Escape) root.hide()
          else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) root.tab = root.tabs[(index + 1) % root.tabs.length].id
          else if (event.key === Qt.Key_Backtab && (event.modifiers & Qt.ControlModifier)) root.tab = root.tabs[(index + root.tabs.length - 1) % root.tabs.length].id
          else if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.tabs.length) root.tab = root.tabs[event.key - Qt.Key_1].id
          else event.accepted = false
        }

        // Tabs down the left.
        ColumnLayout {
          id: sidebar
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.margins: 10
          width: 150
          spacing: 2

          Label {
            text: "Settings"
            font.bold: true
            font.pixelSize: Theme.fontLarge
            Layout.margins: 8
          }

          Repeater {
            model: root.tabs

            Rectangle {
              id: tabButton
              required property var modelData
              required property int index

              readonly property bool current: root.tab === modelData.id

              Layout.fillWidth: true
              implicitHeight: 30
              radius: Theme.controlRadius
              color: current ? Theme.selection : tabMouse.containsMouse ? Theme.hover : "transparent"

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 10

                Label {
                  text: Icons.glyph(tabButton.modelData.glyph)
                  font.pixelSize: Theme.iconSize
                  color: tabButton.current ? Theme.accent : Theme.dim
                  elide: Text.ElideNone
                }
                Label {
                  text: tabButton.modelData.label
                  color: tabButton.current ? Theme.brightForeground : Theme.foreground
                  Layout.fillWidth: true
                }
                Label {
                  text: "^" + (tabButton.index + 1)
                  color: Theme.muted
                  font.pixelSize: Theme.fontSmall
                  elide: Text.ElideNone
                }
              }

              MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.tab = tabButton.modelData.id
              }
            }
          }

          Item { Layout.fillHeight: true }
        }

        Rectangle {
          id: divider
          anchors.left: sidebar.right
          anchors.leftMargin: 10
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 1
          color: Theme.separator
        }

        Scrollbar {
          flickable: page
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.top: page.top
          anchors.bottom: page.bottom
        }

        Flickable {
          id: page
          anchors.left: divider.right
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.margins: 18
          anchors.rightMargin: 22
          contentHeight: content.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          // A new tab starts at its top.
          Connections {
            target: root
            function onTabChanged() { page.contentY = 0 }
          }

          ColumnLayout {
            id: content
            width: page.width
            spacing: 0

            // What this page is, with its icon on an accent tile.
            RowLayout {
              Layout.fillWidth: true
              Layout.bottomMargin: 16
              spacing: 12

              Rectangle {
                implicitWidth: 36
                implicitHeight: 36
                radius: Theme.controlRadius + 4
                color: Theme.alpha(Theme.accent, 0.16)

                Label {
                  anchors.centerIn: parent
                  text: Icons.glyph(root.currentTab.glyph)
                  color: Theme.accent
                  font.pixelSize: 20
                  elide: Text.ElideNone
                }
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { text: root.currentTab.label; font.bold: true; font.pixelSize: Theme.fontLarge + 2; Layout.fillWidth: true }
                Label { text: root.currentTab.about; color: Theme.dim; font.pixelSize: Theme.fontSmall; Layout.fillWidth: true }
              }
            }

            // ------------------------------------------------ appearance
            ColumnLayout {
              visible: root.tab === "appearance"
              Layout.fillWidth: true
              spacing: 16

              Card {
              title: "THEME"

              Picker {
                Layout.fillWidth: true
                options: root.themes
                current: root.theme
                onPicked: function(value) { root.applyTheme(value) }
              }

              ColumnLayout {
                spacing: 4
                Swatches { keys: ["darker_background", "background", "lighter_background", "selection", "muted", "dark_foreground", "foreground", "bright_foreground", "accent"] }
                Swatches { keys: ["red", "orange", "yellow", "green", "cyan", "blue", "magenta", "brown"] }
                Swatches { keys: ["bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta"] }
                Label {
                  text: root.swatchNote !== "" ? root.swatchNote : "Click a colour to copy it"
                  color: Theme.dim
                  font.pixelSize: Theme.fontSmall
                }
              }

              }

              Card {
              title: "RECENT BACKGROUNDS"

              // The five used most recently.
              RowLayout {
                Layout.fillWidth: true
                spacing: 8
                uniformCellSizes: true
                visible: root.backgrounds.length > 0

                Repeater {
                  model: root.backgrounds

                  Rectangle {
                    id: thumb
                    required property var modelData

                    readonly property bool current: modelData.path === Background.path

                    // A file Qt cannot decode (a HEIF saved as .png, say) would
                    // sit here as a blank tile and make a blank wallpaper.
                    visible: preview.status !== Image.Error
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    color: Theme.surface
                    border.width: current ? 2 : 1
                    border.color: current ? Theme.accent : Theme.alpha(Theme.foreground, thumbMouse.containsMouse ? 0.5 : 0.15)
                    radius: Theme.controlRadius

                    Image {
                      id: preview
                      anchors.fill: parent
                      anchors.margins: thumb.border.width
                      source: "file://" + thumb.modelData.path
                      sourceSize.width: 256
                      sourceSize.height: 160
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                    }

                    MouseArea {
                      id: thumbMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: root.applyBackground(thumb.modelData.path)
                    }
                  }
                }
              }

              Label {
                visible: root.backgrounds.length === 0
                text: "No backgrounds yet. Choose a file to add one."
                color: Theme.dim
              }

              RowLayout {
                spacing: 6
                TextButton { text: browseProcess.running ? "Choosing…" : "Choose file…"; icon: Icons.glyph(0xF024B); enabled: !browseProcess.running; onClicked: root.browseBackground() }
                TextButton {
                  icon: Icons.glyph(0xF0E09)
                  text: matchProcess.running ? "Matching…" : "Match theme to background"
                  enabled: !matchProcess.running
                  onClicked: root.matchTheme()
                }
              }

              // How colourful the matched theme is. Picking one matches again
              // straight away in that style.
              Setting {
                glyph: 0xF03D8
                label: "Match style"
                note: ({ vibrant: "Stronger colour everywhere",
                         balanced: "The image's colour on tinted surfaces",
                         soft: "Gentler colour throughout",
                         muted: "Nearly neutral, with a soft accent",
                         monochrome: "Grey, with only a trace of the image" })[root.matchStyle] || ""
                Segmented {
                  options: [
                    { label: "Vibrant", value: "vibrant" },
                    { label: "Balanced", value: "balanced" },
                    { label: "Soft", value: "soft" },
                    { label: "Muted", value: "muted" },
                    { label: "Mono", value: "monochrome" }
                  ]
                  current: root.matchStyle
                  onPicked: function(value) { root.matchTheme(value) }
                }
              }

              }

              Card {
              title: "STYLE"

              Setting {
                glyph: 0xF06D6
                label: "Font"
                note: "Restarts the shell"
                Picker {
                  Layout.preferredWidth: 300
                  options: root.fonts
                  current: root.font
                  onPicked: function(value) { root.applyFont(value) }
                }
              }

              Setting {
                glyph: 0xF01C0
                label: "Cursor"
                Picker {
                  Layout.preferredWidth: 300
                  options: root.cursors
                  current: root.cursor
                  onPicked: function(value) {
                    root.cursor = value
                    // The old size may fall between this theme's bitmaps.
                    snap.restart()
                  }
                }
              }

              Timer {
                id: snap
                interval: 400
                onTriggered: root.applyCursor(root.cursor, root.nearestCursorSize(root.cursorSize))
              }

              Setting {
                glyph: 0xF0A68
                label: "Cursor size"
                note: "One notch for each size this cursor is drawn at"
                Label {
                  text: root.cursorSize + " px"
                  color: Theme.dim
                  elide: Text.ElideNone
                }
                NotchSlider {
                  Layout.preferredWidth: 260
                  stops: root.cursorSizes
                  value: root.nearestCursorSize(root.cursorSize)
                  onMoved: function(value) { root.applyCursor(root.cursor, value) }
                }
              }

              Setting {
                glyph: 0xF003B
                label: "Icons"
                note: "For apps that follow the system icon theme"
                Picker {
                  Layout.preferredWidth: 300
                  options: root.iconThemes
                  current: root.iconTheme
                  onPicked: function(value) { root.applyIconTheme(value) }
                }
              }
              }

              Card {
              title: "LOGIN SCREEN"

              Setting {
                glyph: 0xF0009
                label: "Picture"
                note: "Shown when you log in"

                Item {
                  implicitWidth: 40
                  implicitHeight: 40

                  Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.alpha(Theme.accent, 0.18)
                    border.width: 1
                    border.color: Theme.accent
                  }
                  Image {
                    id: accountFace
                    anchors.fill: parent
                    anchors.margins: 2
                    // The query string makes the image reload after a change.
                    source: "file:///var/lib/AccountsService/icons/" + Quickshell.env("USER") + "?" + root.pictureRevision
                    sourceSize: Qt.size(80, 80)
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    visible: false
                  }
                  MultiEffect {
                    anchors.fill: accountFace
                    source: accountFace
                    visible: accountFace.status === Image.Ready
                    maskEnabled: true
                    maskSource: accountFaceMask
                  }
                  Item {
                    id: accountFaceMask
                    anchors.fill: accountFace
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: width / 2 }
                  }
                }

                TextButton {
                  text: pictureBrowse.running ? "Choosing…" : pictureSet.running ? "Saving…" : "Choose picture…"
                  icon: Icons.glyph(0xF024B)
                  enabled: !pictureBrowse.running && !pictureSet.running
                  onClicked: pictureBrowse.running = true
                }
              }
              }
            }

            // ------------------------------------------------ shell
            ColumnLayout {
              visible: root.tab === "shell"
              Layout.fillWidth: true
              spacing: 16

              Card {
              title: "NIGHT LIGHT"

              Setting {
                glyph: 0xF0594
                label: "Night light"
                note: NightLight.active ? "On now" : "Off now"
                Toggle {
                  checked: NightLight.active
                  onToggled: NightLight.toggle()
                }
              }

              Setting {
                glyph: 0xF0150
                label: "Schedule"
                note: Config.nightlight.schedule === "off" ? "Only when switched on by hand"
                  : NightLight.windowText !== "" ? NightLight.windowText : ""
                Segmented {
                  options: [
                    { label: "Off", value: "off", icon: Icons.glyph(0xF073A) },
                    { label: "Sunset to sunrise", value: "sunset", icon: Icons.glyph(0xF059B) },
                    { label: "Custom", value: "custom", icon: Icons.glyph(0xF0954) }
                  ]
                  current: Config.nightlight.schedule
                  onPicked: function(value) { Config.nightlight.schedule = value }
                }
              }

              Setting {
                visible: Config.nightlight.schedule === "custom"
                glyph: 0xF051F
                label: "From"
                note: "24-hour, like 20:00"
                Field {
                  Layout.preferredWidth: 80
                  text: Config.nightlight.start
                  onAccepted: if (/^([01]?\d|2[0-3]):[0-5]\d$/.test(text)) Config.nightlight.start = text
                  onCancelled: text = Config.nightlight.start
                }
                Label { text: "to"; color: Theme.dim }
                Field {
                  Layout.preferredWidth: 80
                  text: Config.nightlight.end
                  onAccepted: if (/^([01]?\d|2[0-3]):[0-5]\d$/.test(text)) Config.nightlight.end = text
                  onCancelled: text = Config.nightlight.end
                }
              }

              Setting {
                glyph: 0xF050F
                label: "Warmth"
                note: Config.nightlight.temperature + " K"
                Slider {
                  Layout.preferredWidth: 260
                  // Left is neutral, right is warmest.
                  value: (5500 - Config.nightlight.temperature) / 3000
                  step: 250 / 3000
                  onMoved: function(value) { Config.nightlight.temperature = Math.round((5500 - value * 3000) / 50) * 50 }
                }
              }

              }

              Card {
              title: "BAR"

              Setting {
                glyph: 0xF00B5
                label: "Background effects"
                note: Config.bar.glass ? "Frosted glass, like macOS Sequoia" : "None, the bar is clear"
                Toggle {
                  checked: Config.bar.glass
                  onToggled: Config.bar.glass = !Config.bar.glass
                }
              }

              Setting {
                visible: Config.bar.glass
                glyph: 0xF05CC
                label: "Tint"
                note: Math.round(Config.bar.tint * 100) + "% of the theme background"
                Slider {
                  Layout.preferredWidth: 260
                  value: Config.bar.tint
                  onMoved: function(value) { Config.bar.tint = Math.round(value * 20) / 20 }
                }
              }

              Setting {
                glyph: 0xF0954
                label: "Clock format"
                note: Qt.formatDateTime(new Date(), Config.clock.format)
                Field {
                  Layout.preferredWidth: 220
                  text: Config.clock.format
                  onAccepted: if (text.trim() !== "") Config.clock.format = text.trim()
                  onCancelled: text = Config.clock.format
                }
              }

              }

              Card {
              title: "MEDIA"

              Setting {
                glyph: 0xF0387
                label: "One player at a time"
                note: "Starting playback in one app pauses the others"
                Toggle {
                  checked: Config.media.exclusive
                  onToggled: Config.media.exclusive = !Config.media.exclusive
                }
              }

              }

              Card {
              title: "SCREENSAVER"

              Setting {
                glyph: 0xF1104
                label: "Screensaver"
                note: Config.screensaver.enabled ? "Plays your videos before the screen locks" : "Off: the screen just locks"
                TextButton {
                  text: "Preview"
                  icon: Icons.glyph(0xF040A)
                  onClicked: {
                    root.hide()
                    Quickshell.execDetached([Quickshell.shellDir + "/bin/screensaver", Config.screensaver.folder, Config.screensaver.sound ? "yes" : "no"])
                  }
                }
                Toggle {
                  checked: Config.screensaver.enabled
                  onToggled: Config.screensaver.enabled = !Config.screensaver.enabled
                }
              }

              Setting {
                glyph: 0xF051F
                label: "Start after"
                note: "Held off while something is playing or fullscreen"
                Stepper {
                  value: Math.round(Config.idle.screensaver / 60)
                  from: 1
                  to: 60
                  suffix: " min"
                  onMoved: function(value) {
                    Config.idle.screensaver = value * 60
                    if (Config.idle.lock <= Config.idle.screensaver) Config.idle.lock = Config.idle.screensaver + 60
                  }
                }
              }

              Setting {
                glyph: 0xF024B
                label: "Videos"
                note: videoCount.result.length > 0 ? videoCount.result[0] + " videos, shuffled" : ""
                Field {
                  Layout.preferredWidth: 260
                  text: Config.screensaver.folder
                  onAccepted: if (text.trim() !== "") Config.screensaver.folder = text.trim()
                  onCancelled: text = Config.screensaver.folder
                }
              }

              Setting {
                glyph: 0xF057E
                label: "Sound"
                Toggle {
                  checked: Config.screensaver.sound
                  onToggled: Config.screensaver.sound = !Config.screensaver.sound
                }
              }
              }

              Card {
              title: "LOCK"

              Setting {
                glyph: 0xF033E
                label: "Lock after"
                note: "Counted from the last input, not from the screensaver"
                // In seconds underneath, so half minutes are possible.
                Stepper {
                  value: Config.idle.lock
                  from: Config.idle.screensaver + 30
                  to: 7200
                  step: 30
                  display: (value / 60) + " min"
                  onMoved: function(value) { Config.idle.lock = value }
                }
              }

              Setting {
                glyph: 0xF0D90
                label: "Screen off after"
                note: "Once locked and untouched"
                Stepper {
                  value: Config.idle.blank
                  from: 5
                  to: 300
                  step: 5
                  suffix: " s"
                  onMoved: function(value) { Config.idle.blank = value }
                }
              }
              }
            }

            // ------------------------------------------------ windows
            ColumnLayout {
              visible: root.tab === "windows"
              Layout.fillWidth: true
              spacing: 16

              Card {
              title: "SHAPE"

              Setting {
                glyph: 0xF0607
                label: "Corner radius"
                Stepper {
                  value: Config.windows.rounding
                  to: 30
                  suffix: " px"
                  onMoved: function(value) { Config.windows.rounding = value; root.applyWindows() }
                }
              }
              Setting {
                glyph: 0xF00C7
                label: "Border"
                Stepper {
                  value: Config.windows.border
                  to: 8
                  suffix: " px"
                  onMoved: function(value) { Config.windows.border = value; root.applyWindows() }
                }
              }
              Setting {
                glyph: 0xF0637
                label: "Shadows"
                Toggle {
                  checked: Config.windows.shadow
                  onToggled: { Config.windows.shadow = !Config.windows.shadow; root.applyWindows() }
                }
              }

              }

              Card {
              title: "SPACING"

              Setting {
                glyph: 0xF084E
                label: "Between windows"
                Stepper {
                  value: Config.windows.gapsIn
                  to: 30
                  suffix: " px"
                  onMoved: function(value) { Config.windows.gapsIn = value; root.applyWindows() }
                }
              }
              Setting {
                glyph: 0xF00CE
                label: "Around the screen edge"
                Stepper {
                  value: Config.windows.gapsOut
                  to: 60
                  suffix: " px"
                  onMoved: function(value) { Config.windows.gapsOut = value; root.applyWindows() }
                }
              }

              }

              Card {
              title: "MOTION"

              Setting {
                glyph: 0xF05D8
                label: "Animations"
                note: Config.windows.animations === "minimal" ? "Workspace switches only" : ""
                Segmented {
                  options: [{ label: "Off", value: "off" }, { label: "Minimal", value: "minimal" }, { label: "Full", value: "full" }]
                  current: Config.windows.animations
                  onPicked: function(value) { Config.windows.animations = value; root.applyWindows() }
                }
              }
              }
            }

            // ------------------------------------------------ network
            Card {
              visible: root.tab === "network"
              WifiPanel {
                Layout.fillWidth: true
                active: root.open && root.tab === "network"
                maxRows: 13
              }
            }

            // ------------------------------------------------ calendar
            ColumnLayout {
              visible: root.tab === "calendar"
              Layout.fillWidth: true
              spacing: 16

              Card {
              title: "ACCOUNTS"

              Label {
                visible: !Calendar.connected
                text: "No calendars connected yet."
                color: Theme.dim
              }

              Repeater {
                model: Calendar.accounts

                Setting {
                  id: account
                  required property var modelData
                  glyph: modelData.provider === "icloud" ? 0xF0035 : 0xF046B
                  label: (modelData.provider === "icloud" ? "iCloud" : "Feed") + " · " + modelData.label
                  note: (modelData.calendars || []).map(c => c.displayName).join(", ")
                  TextButton {
                    text: "Remove"
                    enabled: !Calendar.busy
                    onClicked: Calendar.removeAccount(account.modelData.id)
                  }
                }
              }

              RowLayout {
                spacing: 8
                TextButton { icon: Icons.glyph(0xF04E6); text: Calendar.busy ? "Working…" : "Sync now"; enabled: Calendar.connected && !Calendar.busy; onClicked: Calendar.refresh() }
                Label {
                  text: Calendar.status !== "" ? Calendar.status
                    : Calendar.errors.length > 0 ? String(Calendar.errors[0].message || Calendar.errors[0])
                    : Calendar.connected ? Calendar.events.length + " events in the next two weeks" : ""
                  color: Calendar.status !== "" || Calendar.errors.length > 0 ? Theme.yellow : Theme.dim
                  font.pixelSize: Theme.fontSmall
                  Layout.fillWidth: true
                }
              }

              }

              Card {
              title: "ADD ICLOUD"

              Label {
                text: "Use an app-specific password from account.apple.com, not your Apple Account password. It is kept in the keyring."
                color: Theme.dim
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                Layout.fillWidth: true
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Field { id: icloudEmail; Layout.fillWidth: true; placeholder: "Apple Account email"; onAccepted: icloudPassword.focusInput() }
                Field {
                  id: icloudPassword
                  Layout.preferredWidth: 200
                  placeholder: "App-specific password"
                  password: true
                  onAccepted: icloudAdd.clicked()
                }
                TextButton {
                  id: icloudAdd
                  text: "Connect"
                  enabled: !Calendar.busy && icloudEmail.text !== "" && icloudPassword.text !== ""
                  onClicked: {
                    Calendar.addIcloud(icloudEmail.text.trim(), icloudPassword.text)
                    icloudPassword.text = ""
                  }
                }
              }

              }

              Card {
              title: "ADD A FEED"

              Label {
                text: "A read-only .ics address, like the secret iCal link Google and Outlook calendars offer."
                color: Theme.dim
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                Layout.fillWidth: true
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Field { id: feedUrl; Layout.fillWidth: true; placeholder: "https://…/basic.ics"; onAccepted: feedLabel.focusInput() }
                Field { id: feedLabel; Layout.preferredWidth: 140; placeholder: "Name"; onAccepted: feedAdd.clicked() }
                TextButton {
                  id: feedAdd
                  text: "Add"
                  enabled: !Calendar.busy && /^https?:\/\//.test(feedUrl.text.trim())
                  onClicked: {
                    Calendar.addFeed(feedUrl.text.trim(), feedLabel.text.trim())
                    feedUrl.text = ""
                    feedLabel.text = ""
                  }
                }
              }
              }
            }

            // ------------------------------------------------ bluetooth
            Card {
              visible: root.tab === "bluetooth"
              BluetoothPanel {
                Layout.fillWidth: true
                active: root.open && root.tab === "bluetooth"
              }
            }

            // ------------------------------------------------ jot
            ColumnLayout {
              visible: root.tab === "jot"
              Layout.fillWidth: true
              spacing: 16

              Card {
                title: "NOTE"

                Setting {
                  glyph: 0xF004C
                  label: "Size"
                  note: "Width and height of the dropdown"
                  Stepper {
                    value: Config.jot.width
                    from: 280
                    to: 900
                    step: 20
                    suffix: " w"
                    onMoved: function(value) { Config.jot.width = value }
                  }
                  Stepper {
                    value: Config.jot.height
                    from: 220
                    to: 1000
                    step: 20
                    suffix: " h"
                    onMoved: function(value) { Config.jot.height = value }
                  }
                }

                Setting {
                  glyph: 0xF0284
                  label: "Text size"
                  note: "Ctrl+= and Ctrl+- in a note too"
                  Stepper {
                    value: Config.jot.fontSize
                    from: 9
                    to: 28
                    suffix: " px"
                    onMoved: function(value) { Config.jot.fontSize = value }
                  }
                }

                Setting {
                  glyph: 0xF0B78
                  label: "Paper"
                  Segmented {
                    options: [
                      { label: "Plain", value: "none" },
                      { label: "Lined", value: "ruled" },
                      { label: "Grid", value: "lines" },
                      { label: "Dots", value: "dots" }
                    ]
                    current: Config.jot.paper
                    onPicked: function(value) { Config.jot.paper = value }
                  }
                }

                Setting {
                  glyph: 0xF0284
                  label: "Line spacing"
                  Segmented {
                    options: [
                      { label: "Tight", value: 1.35 },
                      { label: "Antinote", value: 1.63 },
                      { label: "Roomy", value: 1.9 }
                    ]
                    current: Config.jot.lineSpacing
                    onPicked: function(value) { Config.jot.lineSpacing = value }
                  }
                }

                Setting {
                  glyph: 0xF0450
                  label: "Position"
                  note: Config.jot.offsetX === 0 && Config.jot.offsetY === 0 ? "Under the bar button; drag its top edge to move it"
                    : "Moved by hand; double-click its top edge to put it back"
                  TextButton {
                    visible: Config.jot.offsetX !== 0 || Config.jot.offsetY !== 0
                    text: "Put back"
                    onClicked: {
                      Config.jot.offsetX = 0
                      Config.jot.offsetY = 0
                    }
                  }
                }

                Setting {
                  glyph: 0xF04E1
                  label: "Opens on"
                  Segmented {
                    options: [
                      { label: "Last note", value: "last" },
                      { label: "Newest note", value: "newest" }
                    ]
                    current: Config.jot.openOn
                    onPicked: function(value) { Config.jot.openOn = value }
                  }
                }

                Setting {
                  glyph: 0xF0741
                  label: "Reverse swipe"
                  note: "Which way a sideways swipe moves between notes"
                  Toggle {
                    checked: Config.jot.swipeInvert
                    onToggled: Config.jot.swipeInvert = !Config.jot.swipeInvert
                  }
                }
              }

              Card {
                title: "KEEPING NOTES"

                Setting {
                  glyph: 0xF0954
                  label: "Delete untouched notes after"
                  note: Config.jot.autoDeleteDays === 0 ? "Notes are kept forever" : "Days without an edit"
                  Stepper {
                    value: Config.jot.autoDeleteDays
                    from: 0
                    to: 365
                    display: value === 0 ? "Never" : value + " d"
                    onMoved: function(value) { Config.jot.autoDeleteDays = value }
                  }
                }

                Setting {
                  glyph: 0xF024B
                  label: "Export folder"
                  note: "Ctrl+S saves the note there as Markdown"
                  Field {
                    Layout.preferredWidth: 200
                    text: Config.jot.exportDir
                    onAccepted: if (text.trim() !== "") Config.jot.exportDir = text.trim()
                    onCancelled: text = Config.jot.exportDir
                  }
                }

                Setting {
                  glyph: 0xF01C1
                  label: "Currency rates"
                  note: "Daily ECB rates for 32 USD to JPY; Jot's only connection"
                  Toggle {
                    checked: Config.jot.currency
                    onToggled: Config.jot.currency = !Config.jot.currency
                  }
                }
              }

              Card {
                title: "KEYWORDS"

                Label {
                  Layout.fillWidth: true
                  text: "A keyword on a note's first line switches its feature on. Several words: separate them with commas."
                  color: Theme.dim
                  font.pixelSize: Theme.fontSmall
                  wrapMode: Text.Wrap
                  elide: Text.ElideNone
                }

                Repeater {
                  model: [
                    { key: "math", about: "Live sums, variables, units" },
                    { key: "list", about: "Checkboxes in the margin" },
                    { key: "sum", about: "Adds up every number" },
                    { key: "avg", about: "Averages every number" },
                    { key: "count", about: "Lines, words and characters" },
                    { key: "timer", about: "timer 5m, on its own line" },
                    { key: "stopwatch", about: "Counts up" },
                    { key: "pomodoro", about: "pomodoro 25/5" }
                  ]

                  Setting {
                    required property var modelData
                    glyph: 0xF030C
                    label: modelData.key
                    note: modelData.about
                    Field {
                      Layout.preferredWidth: 200
                      text: Config.jot.keywords[modelData.key]
                      onAccepted: Config.jot.keywords[modelData.key] = text.trim() !== "" ? text.trim() : modelData.key
                      onCancelled: text = Config.jot.keywords[modelData.key]
                    }
                  }
                }
              }

              Card {
                title: "KEYS"

                Repeater {
                  model: [
                    ["Alt+A", "Open and close Jot"],
                    ["Ctrl+[  Ctrl+]", "Previous and next note (or swipe); past the newest is a new note"],
                    ["Ctrl+Shift+]", "Newest note"],
                    ["Ctrl+N", "New note"],
                    ["Ctrl+K  Ctrl+F", "All notes: type to filter, arrows, Enter"],
                    ["Ctrl+P", "Keep open"],
                    ["Ctrl+Shift+V", "AutoPaste"],
                    ["Ctrl+S", "Export"],
                    ["Ctrl+Shift+C", "Copy the note"],
                    ["Ctrl+Shift+D", "Delete the note"],
                    ["Ctrl+Return", "Tick a list item"],
                    ["Ctrl+click", "Open a link (Ctrl+Alt+click shortens it)"]
                  ]

                  RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Label { text: modelData[1]; Layout.fillWidth: true }
                    Label { text: modelData[0]; color: Theme.dim; elide: Text.ElideNone }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
