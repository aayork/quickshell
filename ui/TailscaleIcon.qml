import QtQuick
import qs.theme

// The Tailscale mark: a 3x3 grid of dots with the T lit. Drawn rather than
// loaded, so it stays crisp at bar size and takes the bar's colour.
//
// It moves a little: a ripple runs out from the centre dot on hover (`hovered`)
// and keeps running while Tailscale switches on or off (`busy`), and the T
// lights up or fades out from the centre outwards when `off` changes.
Item {
  id: root

  property real size: 13
  property color color: Theme.foreground
  // Tailscale is off: every dot dimmed.
  property bool off: false
  property bool hovered: false
  property bool busy: false

  readonly property real dot: Math.max(2, size * 0.24)
  readonly property real mid: (size - dot) / 2
  readonly property real end: size - dot

  // Where the ripple is: 0 at the centre dot, 1 at the edges, 2 at the
  // corners; it runs a little past 2 so the corners settle before it stops.
  property real wave: -1

  implicitWidth: size
  implicitHeight: size

  onHoveredChanged: if (hovered && !ripple.running) ripple.start()
  onBusyChanged: if (busy && !ripple.running) ripple.start()

  SequentialAnimation {
    id: ripple
    NumberAnimation { target: root; property: "wave"; from: -0.6; to: 2.8; duration: 620; easing.type: Easing.InOutSine }
    ScriptAction { script: root.wave = -1 }
    // Again while still switching, with a short rest between ripples.
    PauseAnimation { duration: root.busy ? 160 : 0 }
    ScriptAction { script: if (root.busy) ripple.restart() }
  }

  component Dot: Rectangle {
    id: dot
    property int row: 0
    property int column: 0
    property bool lit: false
    // 0 centre, 1 edge, 2 corner.
    readonly property int ring: Math.abs(row - 1) + Math.abs(column - 1)
    // How close the ripple is to this dot, 0 to 1.
    readonly property real swell: Math.max(0, 1 - Math.abs(root.wave - ring) * 1.4)

    x: column * root.mid
    y: row * root.mid
    width: root.dot
    height: root.dot
    radius: width / 2
    color: root.color
    scale: 1 + 0.3 * swell
    opacity: Math.min(1, (lit && !root.off ? 1 : 0.3) + 0.5 * swell)

    // On and off spread from the centre: inner dots change first.
    Behavior on opacity {
      enabled: root.wave < 0
      SequentialAnimation {
        PauseAnimation { duration: dot.ring * 70 }
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }
    }
  }

  Dot { row: 0; column: 0 }
  Dot { row: 0; column: 1 }
  Dot { row: 0; column: 2 }
  Dot { row: 1; column: 0; lit: true }
  Dot { row: 1; column: 1; lit: true }
  Dot { row: 1; column: 2; lit: true }
  Dot { row: 2; column: 0 }
  Dot { row: 2; column: 1; lit: true }
  Dot { row: 2; column: 2 }
}
