import QtQuick
import qs.services
import qs.theme
import qs.ui

// While a screen recording runs: a red dot and the time so far, as
// CleanShot shows in the menu bar. Click to stop. Shows "Converting…" while
// a GIF is being made.
BarButton {
  id: root

  property double now: Date.now()
  readonly property int seconds: Math.max(0, Math.floor((now - Captures.recordStart) / 1000))

  visible: Captures.recording || Captures.converting
  minimumWidth: 0
  text: Captures.converting ? "Converting…"
    : Icons.glyph(0xF0765) + " " + Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0")
  fontSize: Theme.fontSize
  // A fixed deep red rather than the theme's red, which is pale in most
  // themes: white on a solid pill so it reads over any wallpaper.
  readonly property color recordRed: "#d4111e"
  foreground: Captures.converting ? Theme.brightForeground : "#ffffff"
  onClicked: if (Captures.recording) Captures.stopRecording()

  Rectangle {
    z: -1
    visible: Captures.recording
    anchors.fill: parent
    anchors.topMargin: 4
    anchors.bottomMargin: 4
    radius: Theme.controlRadius
    color: root.hovered ? Qt.darker(root.recordRed, 1.15) : root.recordRed
  }

  Timer {
    interval: 500
    repeat: true
    running: Captures.recording
    onTriggered: root.now = Date.now()
  }
}
