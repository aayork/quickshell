import QtQuick
import QtQuick.Shapes
import qs.theme

// The equalizer as a graph: a smooth curve through one handle per band,
// shaded down to the 0 line. Drag a handle up or down, or scroll over it.
Item {
  id: graph

  property var bands: []
  // Values being dragged, shown before the headphones confirm them.
  property var held: ({})
  signal changed(string id, int value)

  readonly property real pad: 12
  readonly property real plotHeight: height - labels.height - 6
  readonly property var points: {
    var out = []
    for (var i = 0; i < bands.length; i++) {
      var b = bands[i]
      var v = held[b.id] !== undefined ? held[b.id] : b.value
      out.push({ id: b.id, label: b.label, min: b.minimum, max: b.maximum, value: v,
                 x: xAt(i), y: yAt(v, b.minimum, b.maximum) })
    }
    return out
  }

  function xAt(i) { return width * (i + 0.5) / Math.max(1, bands.length) }
  function yAt(v, min, max) { return pad + (plotHeight - 2 * pad) * (max - v) / (max - min) }
  function valueAt(y, min, max) {
    var f = (y - pad) / Math.max(1, plotHeight - 2 * pad)
    return Math.max(min, Math.min(max, Math.round(max - f * (max - min))))
  }

  // Flat out to both edges, then a cubic between each pair of handles with
  // level tangents, so the curve never overshoots a handle.
  function curve(closed) {
    var p = points
    if (p.length === 0) return ""
    var d = "M 0 " + p[0].y + " L " + p[0].x + " " + p[0].y
    for (var i = 1; i < p.length; i++) {
      var mx = (p[i - 1].x + p[i].x) / 2
      d += " C " + mx + " " + p[i - 1].y + " " + mx + " " + p[i].y + " " + p[i].x + " " + p[i].y
    }
    d += " L " + width + " " + p[p.length - 1].y
    if (closed) {
      var zero = yAt(0, p[0].min, p[0].max)
      d += " L " + width + " " + zero + " L 0 " + zero + " Z"
    }
    return d
  }

  onBandsChanged: held = ({})
  implicitHeight: 132

  // Grid: the 0 line solid, the halfway lines faint.
  Repeater {
    model: [-1, -0.5, 0, 0.5, 1]
    Rectangle {
      required property real modelData
      x: 0
      width: graph.width
      height: 1
      y: Math.round(graph.pad + (graph.plotHeight - 2 * graph.pad) * (1 - modelData) / 2)
      color: Theme.alpha(Theme.foreground, modelData === 0 ? 0.28 : 0.07)
    }
  }
  Repeater {
    model: graph.points
    Rectangle {
      required property var modelData
      x: Math.round(modelData.x)
      y: graph.pad
      width: 1
      height: graph.plotHeight - 2 * graph.pad
      color: Theme.alpha(Theme.foreground, 0.05)
    }
  }

  Label {
    x: 2
    y: graph.pad - height / 2
    text: "+" + (graph.points.length ? graph.points[0].max : 10)
    color: Theme.alpha(Theme.foreground, 0.35)
    font.pixelSize: 9
  }
  Label {
    x: 2
    y: graph.plotHeight - graph.pad - height / 2
    text: "−" + (graph.points.length ? -graph.points[0].min : 10)
    color: Theme.alpha(Theme.foreground, 0.35)
    font.pixelSize: 9
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: -1
      fillGradient: LinearGradient {
        x1: 0; y1: graph.pad
        x2: 0; y2: graph.plotHeight - graph.pad
        GradientStop { position: 0; color: Theme.alpha(Theme.accent, 0.30) }
        GradientStop { position: 0.5; color: Theme.alpha(Theme.accent, 0.06) }
        GradientStop { position: 1; color: Theme.alpha(Theme.accent, 0.30) }
      }
      PathSvg { path: graph.curve(true) }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: Theme.accent
      strokeWidth: 2
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: graph.curve(false) }
    }
  }

  // A handle per band, with a tall invisible strip to grab.
  Repeater {
    model: graph.points

    Item {
      id: handle
      required property var modelData
      x: modelData.x - width / 2
      y: 0
      width: graph.width / Math.max(1, graph.points.length)
      height: graph.plotHeight

      function set(y) {
        var v = graph.valueAt(y, modelData.min, modelData.max)
        if (v === modelData.value) return
        var next = Object.assign({}, graph.held)
        next[modelData.id] = v
        graph.held = next
        graph.changed(modelData.id, v)
      }

      Rectangle {
        readonly property real size: grab.pressed || grab.containsMouse ? 14 : 11
        x: handle.width / 2 - size / 2
        y: handle.modelData.y - size / 2
        width: size
        height: size
        radius: size / 2
        color: Theme.background
        border.width: 2
        border.color: Theme.accent
        Behavior on width { NumberAnimation { duration: 100 } }
        Behavior on height { NumberAnimation { duration: 100 } }
      }

      MouseArea {
        id: grab
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SizeVerCursor
        onPressed: function(event) { handle.set(event.y) }
        onPositionChanged: function(event) { if (pressed) handle.set(event.y) }
        onWheel: function(event) {
          var m = handle.modelData
          var v = Math.max(m.min, Math.min(m.max, m.value + (event.angleDelta.y > 0 ? 1 : -1)))
          if (v === m.value) return
          var next = Object.assign({}, graph.held)
          next[m.id] = v
          graph.held = next
          graph.changed(m.id, v)
        }
      }
    }
  }

  // Band names and values under their handles.
  Item {
    id: labels
    anchors.bottom: parent.bottom
    width: parent.width
    height: 16

    Repeater {
      model: graph.points
      Row {
        required property var modelData
        x: modelData.x - width / 2
        spacing: 5
        Label {
          text: parent.modelData.label
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
        Label {
          text: (parent.modelData.value > 0 ? "+" : "") + parent.modelData.value
          color: parent.modelData.value === 0 ? Theme.dim : Theme.foreground
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
      }
    }
  }
}
