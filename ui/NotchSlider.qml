import QtQuick
import qs.theme

// A slider that only rests on given values, marked with notches.
// The values are evenly spaced whatever they are. With many stops, notchEvery
// marks only the numeric values that are a multiple of it (a ruler), while
// the slider still rests on every stop.
Item {
  id: root

  // The values it can take, in order.
  property var stops: []
  property var value: null
  // 0: a notch on every stop; N: only on stops whose value is a multiple of N.
  property int notchEvery: 0
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
      visible: root.notchEvery <= 0 || root.stops[index] % root.notchEvery === 0
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
