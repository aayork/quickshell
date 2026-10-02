import QtQuick
import qs.theme

// The Tailscale mark: a 3x3 grid of dots with the T lit. Drawn rather than
// loaded, so it stays crisp at bar size and takes the bar's colour.
Item {
  id: root

  property real size: 13
  property color color: Theme.foreground
  // Tailscale is off: every dot dimmed.
  property bool off: false

  readonly property real dot: Math.max(2, size * 0.24)
  readonly property real mid: (size - dot) / 2
  readonly property real end: size - dot

  implicitWidth: size
  implicitHeight: size

  component Dot: Rectangle {
    property bool lit: false
    width: root.dot
    height: root.dot
    radius: width / 2
    color: root.color
    opacity: lit && !root.off ? 1 : 0.3
  }

  Dot { x: 0; y: 0 }
  Dot { x: root.mid; y: 0 }
  Dot { x: root.end; y: 0 }
  Dot { x: 0; y: root.mid; lit: true }
  Dot { x: root.mid; y: root.mid; lit: true }
  Dot { x: root.end; y: root.mid; lit: true }
  Dot { x: 0; y: root.end }
  Dot { x: root.mid; y: root.end; lit: true }
  Dot { x: root.end; y: root.end }
}
