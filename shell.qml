//@ pragma IconTheme Numix-Square
import QtQuick
import Quickshell
import qs.theme
import qs.background
import qs.bar
import qs.capture
import qs.idle
import qs.launcher
import qs.lock
import qs.services
import qs.notifications
import qs.osd
import qs.polkit
import qs.session
import qs.settings
import qs.weather

ShellRoot {
  // The night light is a service; naming it here is what starts it.
  readonly property bool nightLight: NightLight.active
  // Likewise the clipboard history, which has to be recording from the start.
  readonly property int clipboardEntries: Clipboard.entries.length

  // Popups, toasts and overlays share the window corner radius. Bound here
  // because services already import the theme, so Theme cannot import Config.
  Binding {
    target: Theme
    property: "radius"
    value: Math.max(0, Number(Config.windows.rounding) || 0)
  }

  Wallpaper {}
  Bar {}
  Toasts {}
  Osd {}
  Launcher {}
  Lock {}
  Idle {}
  Polkit {}
  AreaPicker {}
  Pins {}
  Editor {}
  CaptureMenu {}
  SessionOverlay {}
  Settings {}
  WeatherApp {}
}

