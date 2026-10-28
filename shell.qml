//@ pragma IconTheme oxygen
import Quickshell
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
import qs.widgets

ShellRoot {
  // The night light is a service; naming it here is what starts it.
  readonly property bool nightLight: NightLight.active
  // Likewise the clipboard history, which has to be recording from the start.
  readonly property int clipboardEntries: Clipboard.entries.length

  Wallpaper {}
  // Frutiger Aero: Vista-style desktop gadgets.
  Sidebar {}
  Bar {}
  Toasts {}
  Osd {}
  Launcher {}
  Lock {}
  Idle {}
  Polkit {}
  QuickAccess {}
  Pins {}
  Editor {}
  CaptureMenu {}
  SessionOverlay {}
  Settings {}
}

