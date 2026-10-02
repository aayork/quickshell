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

  // The backgrounds used most recently, newest first.
  property var recent: []
  readonly property int recentLimit: 5

  onPathChanged: {
    if (path === "" || !recentLoaded) return
    recent = [path].concat(recent.filter(p => p !== path)).slice(0, recentLimit)
    recentFile.setText(JSON.stringify(recent))
  }

  property bool recentLoaded: false
  FileView {
    id: recentFile
    path: Quickshell.env("HOME") + "/.local/state/aayork-quickshell/backgrounds.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        var saved = JSON.parse(text())
        if (Array.isArray(saved)) root.recent = saved
      } catch (e) {}
      root.recentLoaded = true
      root.pathChanged()
    }
    onLoadFailed: {
      root.recentLoaded = true
      root.pathChanged()
    }
  }

  // Looks for a new path without reloading an unchanged one.
  function check() {
    if (!resolve.running) resolve.running = true
  }

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
