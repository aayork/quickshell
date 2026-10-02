//@ pragma IconTheme Colloid
import Quickshell
import qs.background
import qs.bar
import qs.idle
import qs.launcher
import qs.lock
import qs.services
import qs.notifications
import qs.osd
import qs.polkit
import qs.session
import qs.settings

ShellRoot {
  // The night light is a service; naming it here is what starts it.
  readonly property bool nightLight: NightLight.active

  Wallpaper {}
  Bar {}
  Toasts {}
  Osd {}
  Launcher {}
  Lock {}
  Idle {}
  Polkit {}
  SessionOverlay {}
  Settings {}
}
