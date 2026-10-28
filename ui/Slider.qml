import QtQuick
import qs.theme

// Horizontal 0..1 slider. Drag, click or scroll. A sunken groove filled with
// blue gel, and a glossy orb to drag.
Item {
  id: root

  property real value: 0
  property real step: 0.05
  signal moved(real value)

  readonly property real clamped: Math.max(0, Math.min(1, value))

  implicitHeight: Theme.rowHeight
  opacity: enabled ? 1 : 0.4

  function fromX(x) {
    return Math.max(0, Math.min(1, x / width))
  }

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 6
    radius: height / 2
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.22)
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.alpha(Theme.foreground, 0.18) }
      GradientStop { position: 1; color: Theme.alpha(Theme.foreground, 0.06) }
    }

    Gel {
      width: Math.max(height, parent.width * root.clamped)
      height: parent.height
      visible: root.clamped > 0
    }
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: 14
    height: 14
    radius: 7
    x: Math.round((parent.width - width) * root.clamped)
    border.width: 1
    border.color: Theme.gelBorder
    gradient: Gradient {
      GradientStop { position: 0; color: "#ffffff" }
      GradientStop { position: 0.5; color: "#eef6fc" }
      GradientStop { position: 1; color: "#c9def0" }
    }
    Rectangle {
      anchors.centerIn: parent
      width: 4
      height: 4
      radius: 2
      color: Theme.accent
    }
  }

  MouseArea {
    anchors.fill: parent
    onPressed: function(event) { root.moved(root.fromX(event.x)) }
    onPositionChanged: function(event) { if (pressed) root.moved(root.fromX(event.x)) }
    onWheel: function(event) { root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? root.step : -root.step)))) }
  }
}
