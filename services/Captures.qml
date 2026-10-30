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
  // Recordings, and the stills their cards show, live apart from captures.
  readonly property string recordDir: Quickshell.env("HOME") + "/.local/state/aayork-quickshell/recordings"
  readonly property string videoSaveDir: Quickshell.env("HOME") + "/Videos/Recordings"
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

  function isVideo(path) { return /\.(mp4|gif)$/i.test(path) }
  // The still a recording's card shows.
  function thumbOf(path) { return isVideo(path) ? path + ".thumb.png" : path }

  function copy(path) {
    // A recording goes on the clipboard as a file, for pasting into a chat
    // or a folder; a picture as the picture itself.
    if (isVideo(path)) Quickshell.execDetached(["sh", "-c", "printf 'file://%s\\r\\n' \"$1\" | wl-copy --type text/uri-list", "sh", path])
    else Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\"", "sh", path])
  }

  // Into ~/Pictures/Screenshots under a dated name; says where it went.
  function save(path) {
    if (isVideo(path)) {
      Quickshell.execDetached(["sh", "-c",
        "mkdir -p \"$2\" && dest=\"$2/Recording $(date '+%Y-%m-%d %H-%M-%S').${1##*.}\" && cp -- \"$1\" \"$dest\" && "
        + "notify-send -a Recording 'Recording saved' \"$(basename \"$dest\")\"", "sh", path, videoSaveDir])
      return
    }
    Quickshell.execDetached(["sh", "-c",
      "mkdir -p \"$2\" && dest=\"$2/Screenshot $(date '+%Y-%m-%d %H-%M-%S').png\" && cp -- \"$1\" \"$dest\" && "
      + "notify-send -a Screenshot -i \"$dest\" 'Screenshot saved' \"$(basename \"$dest\")\"", "sh", path, saveDir])
  }

  // Anywhere, under any name, through the desktop's save dialog.
  function saveAs(path) {
    if (saveAsProcess.running) return
    saveAsProcess.source = path
    var video = isVideo(path)
    saveAsProcess.command = [Quickshell.shellDir + "/bin/pick-file", "--save",
      (video ? "Recording " : "Screenshot ") + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss") + "." + path.replace(/^.*\./, ""),
      "--folder", video ? videoSaveDir : saveDir, "--title", video ? "Save Recording" : "Save Screenshot"]
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
    if (isVideo(path)) Quickshell.execDetached(["rm", "-f", "--", path + ".thumb.png"])
    dismiss(path)
    pins = pins.filter(p => p.path !== path)
    Quickshell.execDetached(["rm", "-f", "--", path])
    history = history.filter(h => h.path !== path)
  }

  function edit(path) {
    // A recording opens in the video player; a picture in the editor.
    if (isVideo(path)) Quickshell.execDetached(["xdg-open", path])
    else editRequested(path)
  }

  // ------------------------------------------------------------ all in one
  // The last area picked in the All-In-One bar, in that monitor's points,
  // so the next one starts there (as CleanShot's does).
  property var lastSelection: null
  function rememberSelection(monitor, rect) {
    lastSelection = { monitor: monitor, x: rect.x, y: rect.y, w: rect.w, h: rect.h }
    lastSelectionFile.setText(JSON.stringify(lastSelection))
  }
  FileView {
    id: lastSelectionFile
    path: Quickshell.env("HOME") + "/.local/state/aayork-quickshell/last-selection.json"
    printErrors: false
    atomicWrites: true
    onLoaded: { try { root.lastSelection = JSON.parse(text()) } catch (e) {} }
  }

  // ------------------------------------------------------------ self-timer
  // Counts down on screen, then takes `geo` ("X,Y WxH", layout points).
  property int countdown: 0
  property string countdownGeo: ""
  function timedCapture(geo, seconds) {
    countdownGeo = geo
    countdown = seconds
    countdownTick.restart()
  }
  Timer {
    id: countdownTick
    interval: 1000
    repeat: true
    onTriggered: {
      root.countdown -= 1
      if (root.countdown <= 0) {
        stop()
        // Give the countdown a moment to leave the screen first.
        countdownShot.restart()
      }
    }
  }
  Timer {
    id: countdownShot
    interval: 250
    onTriggered: {
      var file = root.newPath()
      timedGrab.file = file
      timedGrab.command = ["grim", "-l", "1", "-g", root.countdownGeo, file]
      timedGrab.running = true
    }
  }
  Process {
    id: timedGrab
    property string file: ""
    onExited: function(code) { if (code === 0) root.add(file) }
  }

  // ------------------------------------------------------------ text (OCR)
  // Reads a QR code if there is one, else the text, onto the clipboard.
  // QR codes need zbar, text needs tesseract; says what to install if not.
  function recognize(image) {
    Quickshell.execDetached(["sh", "-c",
      "img=\"$1\"; "
      + "if command -v zbarimg >/dev/null && t=$(zbarimg -q --raw \"$img\" 2>/dev/null) && [ -n \"$t\" ]; then "
      + "  printf '%s' \"$t\" | wl-copy; notify-send -a 'Capture Text' 'QR code copied' \"$(printf '%s' \"$t\" | head -c 160)\"; "
      + "elif command -v tesseract >/dev/null; then "
      + "  t=$(tesseract \"$img\" - 2>/dev/null | sed -e 's/[[:space:]]*$//'); "
      + "  if [ -n \"$t\" ]; then printf '%s' \"$t\" | wl-copy; notify-send -a 'Capture Text' 'Text copied' \"$(printf '%s' \"$t\" | head -c 160)\"; "
      + "  else notify-send -a 'Capture Text' 'No text found'; fi; "
      + "else notify-send -a 'Capture Text' 'Text recognition needs tesseract' 'Install it with: sudo pacman -S tesseract tesseract-data-eng'; fi; "
      + "rm -f -- \"$img\"", "sh", image])
  }

  // ------------------------------------------------------------ recording
  property bool recording: false
  property bool converting: false
  property double recordStart: 0
  property string recordFile: ""
  property string recordFormat: "mp4"
  property bool dndBefore: false

  // `geo` is "WxH+X+Y" in layout points. Audio: the speakers, the
  // microphone, both or neither.
  function startRecording(geo, format, systemAudio, microphone, cursor) {
    if (recording || converting) return
    Quickshell.execDetached(["mkdir", "-p", recordDir])
    recordFormat = format
    var stamp = Date.now()
    recordFile = recordDir + "/recording-" + stamp + ".mp4"
    var command = ["gpu-screen-recorder", "-w", "region", "-region", geo, "-f", "60", "-q", "very_high",
      "-cursor", cursor ? "yes" : "no", "-o", recordFile]
    var sources = []
    if (systemAudio) sources.push("default_output")
    if (microphone) sources.push("default_input")
    if (sources.length > 0) command.push("-a", sources.join("|"))
    recorder.command = command
    recorder.running = true
    // Do Not Disturb while recording, so no toast ends up in the video.
    dndBefore = Notifs.dnd
    Notifs.dnd = true
    recordStart = Date.now()
    recording = true
  }

  function stopRecording() {
    if (recording) recorder.signal(2)
  }

  Process {
    id: recorder
    onExited: function(code) {
      root.recording = false
      Notifs.dnd = root.dndBefore
      var file = root.recordFile
      if (root.recordFormat === "gif") {
        root.converting = true
        var gif = file.replace(/\.mp4$/, ".gif")
        convert.target = gif
        convert.command = ["sh", "-c",
          "ffmpeg -v error -y -i \"$1\" -vf 'fps=15,scale=min(iw\\,960):-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse' \"$2\" && rm -f -- \"$1\"",
          "sh", file, gif]
        convert.running = true
      } else {
        root.finishRecording(file)
      }
    }
  }
  Process {
    id: convert
    property string target: ""
    onExited: function(code) {
      root.converting = false
      if (code === 0) root.finishRecording(target)
    }
  }
  // A still for the card, then into the stack.
  function finishRecording(file) {
    thumb.file = file
    thumb.command = ["sh", "-c", "ffmpeg -v error -y -ss 0.5 -i \"$1\" -frames:v 1 \"$1.thumb.png\" || ffmpeg -v error -y -i \"$1\" -frames:v 1 \"$1.thumb.png\"", "sh", file]
    thumb.running = true
  }
  Process {
    id: thumb
    property string file: ""
    onExited: root.add(file)
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
    function stopRecording(): void { root.stopRecording() }
    function pick(mode: string, monitor: string, frozen: string, out: string): void {
      // While recording, the capture shortcut stops it instead.
      if (root.recording) {
        Quickshell.execDetached(["rm", "-f", "--", frozen])
        root.stopRecording()
        return
      }
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
