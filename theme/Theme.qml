pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Palette and metrics for the whole shell. Colours come from the current
// theme's colors.toml; everything else is fixed here.
Singleton {
  id: root

  // Written by bin/theme-set and bin/theme-bg-set.
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/aayork-quickshell"
  readonly property string themeDir: stateDir + "/current/theme"

  property var colors: ({})

  function pick(name, fallback) {
    var value = colors[name]
    return value !== undefined ? value : fallback
  }

  function alpha(color, a) {
    return Qt.rgba(color.r, color.g, color.b, a)
  }

  readonly property color background: pick("background", "#141c1f")
  readonly property color surface: pick("lighter_background", "#1e2a2e")
  readonly property color darkerBackground: pick("darker_background", "#0a0e0f")
  readonly property color foreground: pick("foreground", "#c3d0d5")
  readonly property color brightForeground: pick("bright_foreground", "#e6edf0")
  readonly property color dim: pick("dark_foreground", "#7c949c")
  readonly property color muted: pick("muted", "#415a62")
  readonly property color accent: pick("accent", "#7dbdd4")
  readonly property color selection: pick("selection", "#2b3b41")
  readonly property color red: pick("red", "#da6c75")
  readonly property color yellow: pick("yellow", "#dab96c")
  readonly property color green: pick("green", "#7eda6c")

  // Text on the bar while it is see-through. Set by the wallpaper layer from
  // the brightness of what sits behind the bar.
  property color barForeground: brightForeground
  // Average colour of the wallpaper behind the bar, set by the same layer.
  property color wallpaperTop: background
  // The same strip in sections, left to right.
  property var wallpaperStrip: []
  // The solid bar when glass is off, the way macOS did it before Tahoe: the
  // wallpaper right behind each part of it, smoothed and darkened a little.
  // Measured off macOS screenshots: every channel at about 78%.
  readonly property real barDarken: 0.78
  readonly property color barSolid: barShade(wallpaperTop)

  function barShade(color) {
    return Qt.rgba(color.r * barDarken, color.g * barDarken, color.b * barDarken, 1)
  }
  // Whichever of the theme's dark and light text reads better on it.
  readonly property color barSolidForeground: contrast(background, barSolid) > contrast(brightForeground, barSolid)
    ? background : brightForeground

  // WCAG relative luminance and contrast ratio of sRGB colours.
  function luminance(c) {
    function linear(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
  }

  function contrast(a, b) {
    var la = luminance(a), lb = luminance(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
  }

  readonly property color hover: alpha(foreground, 0.08)
  readonly property color pressed: alpha(foreground, 0.16)
  readonly property color track: alpha(foreground, 0.15)
  readonly property color separator: alpha(foreground, 0.12)

  // Resolved by fontconfig, so the system font setting carries over.
  readonly property string fontFamily: "monospace"
  readonly property int fontSmall: 11
  readonly property int fontSize: 12
  readonly property int fontLarge: 14
  readonly property int iconSize: 14
  readonly property int iconLarge: 18

  readonly property int barHeight: 26
  readonly property int barPadding: 6
  readonly property int barIconSlot: 27

  readonly property int radius: 0
  readonly property int controlRadius: 2
  readonly property int borderWidth: 2
  readonly property int popupPadding: 14
  readonly property int popupGap: 4
  readonly property int rowHeight: 28
  readonly property int spacing: 8

  function load(raw) {
    var parsed = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["'](#[0-9A-Fa-f]{6})["']/)
      if (match) parsed[match[1]] = match[2]
    }
    colors = parsed
  }

  FileView {
    id: colorsFile
    path: root.themeDir + "/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.load(text())
  }

  // A theme switch replaces the whole theme directory, which the watch on
  // colors.toml does not survive. The name file next to it is rewritten in
  // place every time, so it is the reliable signal.
  signal themeChanged()
  FileView {
    path: root.stateDir + "/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: {
      colorsFile.reload()
      root.themeChanged()
    }
  }
}
