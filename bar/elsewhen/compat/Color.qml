pragma Singleton
import QtQuick
import Quickshell
import qs.theme

// Omarchy's colour roles, answered from the shell's Theme.
Singleton {
  readonly property color foreground: Theme.foreground
  readonly property color background: Theme.background
  readonly property color accent: Theme.accent

  readonly property QtObject popups: QtObject {
    readonly property color background: Theme.background
    readonly property color text: Theme.foreground
    readonly property color border: Theme.accent
  }
  readonly property QtObject tooltip: QtObject {
    readonly property color background: Theme.surface
    readonly property color text: Theme.foreground
    readonly property color border: Theme.separator
  }
}
