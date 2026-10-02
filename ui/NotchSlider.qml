import QtQuick
import qs.theme

// A slider that only rests on given values, each marked with a notch.
// The notches are evenly spaced whatever the values are.
Item {
  id: root

  // The values it can take, in order.
  property var stops: []
  property var value: null
  signal moved(var value)

  readonly property int index: Math.max(0, stops.indexOf(value))
  readonly property real span: Math.max(1, stops.length - 1)

  implicitHeight: Theme.rowHeight
  opacity: enabled && stops.length > 1 ? 1 : 0.4

  function pick(x) {
    if (stops.length === 0) return
    var nearest = Math.max(0, Math.min(stops.length - 1, Math.round(x / width * span)))
    if (stops[nearest] !== value) moved(stops[nearest])
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 4
    radius: Theme.controlRadius
    color: Theme.track

    Rectangle {
      width: parent.width * root.index / root.span
      height: parent.height
      radius: parent.radius
      color: Theme.accent
    }
  }

  Repeater {
    model: root.stops.length

    Rectangle {
      required property int index
      anchors.verticalCenter: parent.verticalCenter
      x: Math.round((root.width - width) * index / root.span)
      width: 2
      height: 8
      color: index <= root.index ? Theme.accent : Theme.alpha(Theme.foreground, 0.35)
    }
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    x: Math.round((parent.width - width) * root.index / root.span)
    width: 4
    height: 14
    radius: Theme.controlRadius
    color: Theme.foreground
  }

  MouseArea {
    anchors.fill: parent
    onPressed: function(event) { root.pick(event.x) }
    onPositionChanged: function(event) { if (pressed) root.pick(event.x) }
    onWheel: function(event) {
      var next = Math.max(0, Math.min(root.stops.length - 1, root.index + (event.angleDelta.y > 0 ? 1 : -1)))
      if (root.stops.length > 0 && next !== root.index) root.moved(root.stops[next])
    }
  }
}
