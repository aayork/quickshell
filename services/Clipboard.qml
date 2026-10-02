pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history. Two `wl-paste --watch` processes hand every copy to
// bin/clipboard-store, which writes the history file read here.
Singleton {
  id: root

  readonly property string dir: Quickshell.env("HOME") + "/.local/state/aayork-quickshell/clipboard"
  readonly property string store: Quickshell.shellDir + "/bin/clipboard-store"

  // [{ id, kind: "text" | "image", text?, path?, time, size }], newest first.
  property var entries: []

  function copy(entry) {
    if (entry.kind === "image") Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\"", "sh", entry.path])
    else Quickshell.execDetached(["wl-copy", "--", entry.text])
  }

  function write(list) {
    entries = list
    file.setText(JSON.stringify(list))
  }

  function remove(entry) {
    if (entry.path) Quickshell.execDetached(["rm", "-f", "--", entry.path])
    write(entries.filter(e => e.id !== entry.id))
  }

  function clear() {
    Quickshell.execDetached(["sh", "-c", "rm -f -- \"$1\"/images/*.png", "sh", dir])
    write([])
  }

  Process {
    running: true
    command: ["wl-paste", "--type", "text", "--watch", root.store, "text"]
  }

  Process {
    running: true
    command: ["wl-paste", "--type", "image/png", "--watch", root.store, "image"]
  }

  FileView {
    id: file
    path: root.dir + "/history.json"
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onFileChanged: reload()
    onLoaded: {
      try {
        var list = JSON.parse(text())
        if (Array.isArray(list)) root.entries = list
      } catch (e) {}
    }
  }

  Process {
    running: true
    command: ["mkdir", "-p", root.dir]
  }
}
