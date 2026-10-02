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

  function refresh() {
    if (!resolve.running) resolve.running = true
  }

  Process {
    id: resolve
    command: ["readlink", "-f", root.link]
    stdout: StdioCollector {
      onStreamFinished: {
        var next = String(text || "").trim()
        if (next === root.path) root.reloads += 1
        else root.path = next
      }
    }
  }

  IpcHandler {
    target: "wallpaper"
    function refresh(): void { root.refresh() }
  }

  Component.onCompleted: refresh()
}
