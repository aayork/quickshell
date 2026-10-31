import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// What happens when nobody is there: the screensaver, then the lock, then
// the screen off. Any input during the screensaver calls the whole thing off.
Scope {
  id: root

  // Seconds without input, from the config file.
  readonly property int screensaverSeconds: Math.max(10, Config.idle.screensaver)
  readonly property int lockSeconds: Math.max(screensaverSeconds + 1, Config.idle.lock)
  // Seconds the lock screen sits untouched before the panel turns off.
  readonly property int blankSeconds: Math.max(5, Config.idle.blank)

  // Off while "stay awake" is on.
  property bool enabled: true
  // Screensaver is up (or about to be) and the lock is counting down.
  property bool cycling: false
  property string inhibitedBy: ""
  property bool blanked: false
  // Addresses of screensaver windows currently open.
  property var saverWindows: ({})
  readonly property int saverCount: Object.keys(saverWindows).length
  // Set the moment the screensaver is asked for, so the shell's popups and
  // overlays are gone before mpv maps; one closing over mpv would put the
  // pointer on it, which mpv takes as movement and quits.
  property bool saverStarting: false
  onSaverCountChanged: {
    if (saverCount > 0) {
      saverStarting = false
      reveal.restart()
    } else {
      // mpv quit: drop the veil at once so the desktop is right there.
      reveal.stop()
      veilInstant = true
      veiled = false
      veilInstant = false
    }
  }

  // A black layer over every screen. The desktop fades into it, mpv starts
  // underneath (hiding its first unfullscreened frame), then it fades away to
  // show the video.
  readonly property int fadeInMs: 800
  readonly property int fadeOutMs: 1200
  property bool veiled: false
  property bool veilInstant: false

  readonly property bool cursorHidden: veiled || saverCount > 0
  onCursorHiddenChanged: setCursorHidden(cursorHidden)
  // Hide the pointer while the screensaver is up. Reset on start in case the
  // shell restarted with it hidden.
  function setCursorHidden(hidden) {
    Quickshell.execDetached(["hyprctl", "eval", "hl.config({ cursor = { invisible = " + hidden + " } })"])
  }
  Component.onCompleted: setCursorHidden(false)
  Binding {
    target: Session
    property: "screensaver"
    value: root.saverStarting || root.saverCount > 0
  }

  readonly property string saverClass: "org.aayork.screensaver"

  // Browsers ask to keep the screen awake over D-Bus, which nothing here
  // answers, so the idle monitor never hears about it. Check for playing
  // media or a fullscreen window on a visible workspace before idling.
  readonly property string inhibitCheck: "playerctl -a status 2>/dev/null | grep -qx Playing && { echo media; exit; }; "
    + "active=$(hyprctl -j monitors 2>/dev/null | jq -c '[.[].activeWorkspace.id]'); "
    + "hyprctl -j clients 2>/dev/null | jq -e --argjson active \"${active:-[]}\" "
    + "'any(.[]; .fullscreen > 0 and .class != \"" + saverClass + "\" and (.workspace.id as $w | $active | index($w)))' >/dev/null && echo fullscreen"

  function launchScreensaver() {
    saverStarting = true
    veiled = true
    saverLaunch.restart()
    saverGiveUp.restart()
  }

  // Input while the screen is still fading to black: back out before mpv runs.
  function abortLaunch() {
    saverLaunch.stop()
    saverGiveUp.stop()
    saverStarting = false
    veiled = false
  }

  // mpv starts once the screen is black.
  Timer {
    id: saverLaunch
    interval: root.fadeInMs
    onTriggered: Quickshell.execDetached([Quickshell.shellDir + "/bin/screensaver", Config.screensaver.folder, Config.screensaver.sound ? "yes" : "no"])
  }
  // No window came up (no videos, mpv failed): let the shell show again.
  Timer {
    id: saverGiveUp
    interval: 6000
    onTriggered: {
      root.saverStarting = false
      if (root.saverCount === 0) root.veiled = false
    }
  }
  // Time for mpv to go fullscreen and show a frame before the veil lifts.
  Timer {
    id: reveal
    interval: 700
    onTriggered: root.veiled = false
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.veiled || veil.opacity > 0
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}
      WlrLayershell.namespace: "aayork-screensaver-veil"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Rectangle {
        id: veil
        anchors.fill: parent
        color: "black"
        opacity: root.veiled ? 1 : 0
        Behavior on opacity {
          enabled: !root.veilInstant
          NumberAnimation {
            duration: root.veiled ? root.fadeInMs : root.fadeOutMs
            easing.type: Easing.InOutQuad
          }
        }
      }
    }
  }

  function start() {
    if (cycling) return
    cycling = true
    saverWindows = ({})
    if (Config.screensaver.enabled) {
      console.log("idle: screensaver")
      launchScreensaver()
      grace.restart()
    } else {
      console.log("idle: waiting to lock")
    }
    lockTimer.restart()
  }

  function cancel(reason) {
    if (!cycling) return
    console.log("idle: cancelled, " + reason)
    cycling = false
    lockTimer.stop()
    grace.stop()
  }

  function stopScreensaver() {
    Quickshell.execDetached(["pkill", "-f", "--", "--wayland-app-id=" + saverClass])
  }

  function setBlanked(off) {
    if (blanked === off) return
    blanked = off
    Hyprland.dispatch("hl.dsp.dpms({ action = \"" + (off ? "disable" : "enable") + "\" })")
  }

  IdleMonitor {
    id: monitor
    enabled: root.enabled && !Session.locked
    timeout: root.screensaverSeconds
    respectInhibitors: true

    onIsIdleChanged: {
      if (isIdle) {
        if (!root.cycling && !check.running) check.running = true
        return
      }
      recheck.stop()
      root.inhibitedBy = ""
      if (saverLaunch.running) {
        root.abortLaunch()
        root.cancel("activity")
        return
      }
      // The screensaver appearing can itself read as activity. Once it is up
      // (or still starting), only its window closing ends the cycle.
      if (root.cycling && root.saverCount === 0 && !grace.running) root.cancel("activity")
    }
  }

  Process {
    id: check
    command: ["bash", "-c", root.inhibitCheck]
    stdout: StdioCollector {
      onStreamFinished: {
        if (!monitor.isIdle || !root.enabled || Session.locked) return
        root.inhibitedBy = text.trim()
        // Held off: look again after another full timeout, so the screensaver
        // still waits its usual time once the video or game ends.
        if (root.inhibitedBy !== "") recheck.restart()
        else root.start()
      }
    }
  }

  Timer {
    id: recheck
    interval: root.screensaverSeconds * 1000
    onTriggered: if (monitor.isIdle && !root.cycling && !check.running) check.running = true
  }

  // Time for mpv to put its window up before a missing one means anything.
  Timer {
    id: grace
    interval: 3400
    onTriggered: if (root.cycling && root.saverCount === 0 && !monitor.isIdle) root.cancel("screensaver did not start")
  }

  Timer {
    id: lockTimer
    interval: Math.max(1, root.lockSeconds - root.screensaverSeconds) * 1000
    onTriggered: {
      if (!root.cycling) return
      console.log("idle: lock")
      root.cycling = false
      Session.run("lock")
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "openwindow") {
        var opened = event.parse(4)
        if (opened[2] !== root.saverClass) return
        var withNew = Object.assign({}, root.saverWindows)
        withNew[opened[0]] = true
        root.saverWindows = withNew
      } else if (event.name === "closewindow") {
        var address = event.parse(1)[0]
        if (!root.saverWindows[address]) return
        var without = Object.assign({}, root.saverWindows)
        delete without[address]
        root.saverWindows = without
        // Someone moved the mouse: mpv quit, and the lock stands down.
        if (root.saverCount === 0 && !Session.locked) root.cancel("screensaver dismissed")
      }
    }
  }

  // Locked: the screensaver goes, and an untouched lock screen turns the
  // panel off. Any input brings it back.
  Connections {
    target: Session
    function onLockedChanged() {
      if (Session.locked) {
        root.cancel("locked")
        root.stopScreensaver()
      } else {
        root.setBlanked(false)
      }
    }
  }

  IdleMonitor {
    enabled: Session.locked
    timeout: root.blankSeconds
    respectInhibitors: false
    onIsIdleChanged: root.setBlanked(isIdle && Session.locked)
  }

  IpcHandler {
    target: "idle"
    function status(): string {
      return JSON.stringify({ enabled: root.enabled, idle: monitor.isIdle, cycling: root.cycling,
        inhibitedBy: root.inhibitedBy, locked: Session.locked, blanked: root.blanked })
    }
    function toggle(): void { root.enabled = !root.enabled }
    function screensaver(): void { root.launchScreensaver() }
  }
}
