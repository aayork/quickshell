pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Which image is the wallpaper. The theme scripts keep a `background`
// symlink; this follows it.
Singleton {
  id: root

  readonly property string link: Theme.stateDir + "/current/background"
  property string path: ""
  // Bumped when the file behind an unchanged path is replaced.
  property int reloads: 0
  readonly property url source: path ? "file://" + path + (reloads ? "?" + reloads : "") : ""

  // An asked-for refresh reloads the image even when the path is unchanged.
  property bool forced: false
  function refresh() {
    forced = true
    if (!resolve.running) resolve.running = true
  }

  Process {
    id: resolve
    command: ["readlink", "-f", root.link]
    stdout: StdioCollector {
      onStreamFinished: {
        var next = String(text || "").trim()
        if (next !== root.path) root.path = next
        else if (root.forced) root.reloads += 1
        root.forced = false
      }
    }
  }

  // The theme scripts repoint the symlink without telling this shell, and a
  // symlink cannot be watched for retargeting. Checked on a theme change and
  // every few seconds; a readlink costs nothing.
  Connections {
    target: Theme
    function onThemeChanged() { root.refresh() }
  }

  Timer {
    interval: 4000
    running: true
    repeat: true
    onTriggered: if (!resolve.running) resolve.running = true
  }

  IpcHandler {
    target: "wallpaper"
    function refresh(): void { root.refresh() }
  }

  Component.onCompleted: refresh()
}
