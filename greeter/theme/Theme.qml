pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// Palette and metrics for the login screen. Under greetd everything comes
// from the copy bin/greeter-sync keeps in /var/lib/aayork-greeter, since the
// greeter user cannot read the desktop user's home. Run by hand (preview), it
// reads the live theme instead.
Singleton {
  id: root

  // Run by hand, it reads the live theme, unless AAYORK_GREETER_DATA points
  // at a synced copy (greeter/start sets it; handy for testing the copy).
  readonly property bool preview: !Greetd.available && !Quickshell.env("AAYORK_GREETER_DATA")
  readonly property string liveState: Quickshell.env("HOME") + "/.local/state/aayork-quickshell/current"
  readonly property string dataDir: Quickshell.env("AAYORK_GREETER_DATA") || "/var/lib/aayork-greeter"

  readonly property string colorsPath: preview ? liveState + "/theme/colors.toml" : dataDir + "/colors.toml"
  property string backgroundName: ""
  readonly property url wallpaper: preview ? "file://" + liveState + "/background"
    : backgroundName ? "file://" + dataDir + "/" + backgroundName : ""
  // Account pictures are the AccountsService icons, which every user can
  // read; Settings › Appearance sets yours through accounts-daemon.
  function face(user) { return "file:///var/lib/AccountsService/icons/" + user }

  property var colors: ({})
  function pick(name, fallback) {
    var value = colors[name]
    return value !== undefined ? value : fallback
  }
  // Takes a color or a "#rrggbb" string.
  function alpha(color, a) {
    var c = Qt.tint(color, "transparent")
    return Qt.rgba(c.r, c.g, c.b, a)
  }

  readonly property color base: pick("background", "#141c1f")
  readonly property color surface: pick("lighter_background", "#1e2a2e")
  readonly property color foreground: pick("foreground", "#c3d0d5")
  readonly property color brightForeground: pick("bright_foreground", "#e6edf0")
  readonly property color dim: pick("dark_foreground", "#7c949c")
  readonly property color accent: pick("accent", "#7dbdd4")
  readonly property color selection: pick("selection", "#2b3b41")
  readonly property color red: pick("red", "#da6c75")

  readonly property color hover: alpha(foreground, 0.08)
  readonly property color pressed: alpha(foreground, 0.16)
  readonly property color separator: alpha(foreground, 0.12)

  // Frutiger Aero: a humanist sans, with icons from the Nerd Font.
  property string fontFamily: "Open Sans"
  // The desktop's font (a Nerd Font), synced by bin/greeter-sync.
  property string iconFamily: "monospace"
  function familyFor(text) {
    return /[\uE000-\uF8FF]|[\uDB80-\uDBFF]/.test(String(text)) ? iconFamily : fontFamily
  }
  readonly property int fontSmall: 11
  readonly property int fontSize: 12
  readonly property int fontLarge: 14
  readonly property int iconSize: 14
  readonly property int iconLarge: 18
  readonly property int radius: 12
  readonly property int controlRadius: 6
  readonly property int borderWidth: 2

  // Aero glass, from the palette: pale on a light theme, Vista's smoked
  // glass on a dark one.
  readonly property bool dark: (0.2126 * base.r + 0.7152 * base.g + 0.0722 * base.b) < 0.35
  readonly property color glassTop: dark ? alpha(Qt.tint(base, alpha("#ffffff", 0.1)), 0.55)
    : alpha(Qt.tint(base, alpha("#ffffff", 0.6)), 0.55)
  readonly property color glassBottom: dark ? alpha(base, 0.62) : alpha(Qt.tint(base, alpha(accent, 0.18)), 0.42)
  readonly property color glassBorder: dark ? alpha("#000000", 0.5) : alpha("#ffffff", 0.55)
  readonly property color gloss: alpha("#ffffff", dark ? 0.22 : 0.55)
  readonly property int rowHeight: 28
  readonly property int spacing: 8

  FileView {
    path: root.colorsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var parsed = {}
      var lines = text().split("\n")
      for (var i = 0; i < lines.length; i++) {
        var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["'](#[0-9A-Fa-f]{6})["']/)
        if (match) parsed[match[1]] = match[2]
      }
      root.colors = parsed
    }
  }

  FileView {
    path: root.preview ? "" : root.dataDir + "/background.name"
    printErrors: false
    onLoaded: root.backgroundName = text().trim()
  }

  FileView {
    path: root.preview ? "" : root.dataDir + "/font"
    printErrors: false
    // The desktop font is a monospace Nerd Font: icons only, Open Sans for text.
    onLoaded: if (text().trim()) root.iconFamily = text().trim()
  }
}
