pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screenshots after they are taken. bin/screenshot hands each one over; it
// joins the quick-access stack in the corner and the history on disk, and
// from there it can be copied, saved, edited or pinned.
Singleton {
  id: root

  // Every capture is kept here until it is deleted or ages out.
  readonly property string dir: Quickshell.env("HOME") + "/.local/state/aayork-quickshell/captures"
  readonly property string saveDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
  readonly property int historyLimit: 100

  // Paths on show in the quick-access stack, newest first.
  property var stack: []
  // [{ path, time }] for everything in `dir`, newest first.
  property var history: []
  // [{ id, path }] pinned to the screen.
  property var pins: []
  // A scrolling capture is running.
  property bool scrolling: false

  signal editRequested(string path)
  signal menuRequested()
  // bin/screenshot froze the screen into `frozen` and wants an area picked
  // from it (capture/AreaPicker.qml), the result going to `out`.
  signal pickRequested(string mode, string monitor, string frozen, string out)
  // The picker is up; a second press of the shortcut cancels it.
  property bool picking: false
  signal pickCancelled()

  function add(path) {
    stack = [path].concat(stack.filter(p => p !== path)).slice(0, 5)
    refresh()
  }

  function dismiss(path) {
    stack = stack.filter(p => p !== path)
  }

  function dismissAll() {
    stack = []
  }

  function copy(path) {
    Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\"", "sh", path])
  }

  // Into ~/Pictures/Screenshots under a dated name; says where it went.
  function save(path) {
    Quickshell.execDetached(["sh", "-c",
      "mkdir -p \"$2\" && dest=\"$2/Screenshot $(date '+%Y-%m-%d %H-%M-%S').png\" && cp -- \"$1\" \"$dest\" && "
      + "notify-send -a Screenshot -i \"$dest\" 'Screenshot saved' \"$(basename \"$dest\")\"", "sh", path, saveDir])
  }

  // Anywhere, under any name, through the desktop's save dialog.
  function saveAs(path) {
    if (saveAsProcess.running) return
    saveAsProcess.source = path
    saveAsProcess.command = [Quickshell.shellDir + "/bin/pick-file", "--save",
      "Screenshot " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss") + ".png",
      "--folder", saveDir, "--title", "Save Screenshot"]
    saveAsProcess.running = true
  }

  Process {
    id: saveAsProcess
    property string source: ""
    stdout: StdioCollector {
      onStreamFinished: {
        var dest = text.trim()
        if (dest === "") return
        Quickshell.execDetached(["sh", "-c", "cp -- \"$1\" \"$2\" && notify-send -a Screenshot -i \"$2\" 'Screenshot saved' \"$(basename \"$2\")\"",
          "sh", saveAsProcess.source, dest])
        root.dismiss(saveAsProcess.source)
      }
    }
  }

  function remove(path) {
    dismiss(path)
    pins = pins.filter(p => p.path !== path)
    Quickshell.execDetached(["rm", "-f", "--", path])
    history = history.filter(h => h.path !== path)
  }

  function edit(path) {
    editRequested(path)
  }

  function pin(path) {
    dismiss(path)
    pins = pins.concat([{ id: Date.now(), path: path }])
  }

  function unpin(id) {
    pins = pins.filter(p => p.id !== id)
  }

  // A fresh file name in the captures folder, for the editor to write to.
  function newPath() {
    return dir + "/capture-" + Date.now() + ".png"
  }

  function refresh() {
    if (!list.running) list.running = true
  }

  // Lists the folder newest first and deletes what is past the limit.
  Process {
    id: list
    running: true
    command: ["sh", "-c", "mkdir -p \"$1\" && cd \"$1\" && ls -t -- *.png 2>/dev/null | tail -n +\"$(( $2 + 1 ))\" | xargs -r -d '\\n' rm -f --; "
      + "find \"$1\" -maxdepth 1 -name '*.png' -printf '%T@\\t%p\\n' | sort -rn", "sh", root.dir, String(root.historyLimit)]
    stdout: StdioCollector {
      onStreamFinished: {
        root.history = text.split("\n").filter(l => l !== "").map(function(line) {
          var tab = line.indexOf("\t")
          return { time: Math.round(Number(line.slice(0, tab)) * 1000), path: line.slice(tab + 1) }
        })
      }
    }
  }

  IpcHandler {
    target: "capture"
    function add(path: string): void { root.add(path) }
    function edit(path: string): void { root.edit(path) }
    function pin(path: string): void { root.pin(path) }
    function menu(): void { root.menuRequested() }
    function pick(mode: string, monitor: string, frozen: string, out: string): void {
      // A second press while picking cancels; its own fresh still goes.
      if (root.picking) {
        Quickshell.execDetached(["rm", "-f", "--", frozen])
        root.pickCancelled()
      } else root.pickRequested(mode, monitor, frozen, out)
    }
    function dismissAll(): void { root.dismissAll() }
    function scrolling(on: bool): void { root.scrolling = on }
  }
}
