import QtQuick
import qs.theme

// Horizontal 0..1 slider. Drag, click or scroll.
Item {
  id: root

  property real value: 0
  property real step: 0.05
  signal moved(real value)

  implicitHeight: Theme.rowHeight
  opacity: enabled ? 1 : 0.4

  function fromX(x) {
    return Math.max(0, Math.min(1, x / width))
  }

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 4
    radius: Theme.controlRadius
    color: Theme.track

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, root.value))
      height: parent.height
      radius: parent.radius
      color: Theme.accent
    }
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    x: Math.round((parent.width - width) * Math.max(0, Math.min(1, root.value)))
    width: 4
    height: 14
    radius: Theme.controlRadius
    color: Theme.foreground
  }

  MouseArea {
    anchors.fill: parent
    onPressed: function(event) { root.moved(root.fromX(event.x)) }
    onPositionChanged: function(event) { if (pressed) root.moved(root.fromX(event.x)) }
    onWheel: function(event) { root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? root.step : -root.step)))) }
  }
}
