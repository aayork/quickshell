import QtQuick
import qs.theme

// A labelled button inside a popup, optionally led by a glyph. `selected`
// marks the current choice in a group.
Rectangle {
  id: root

  property string text: ""
  property string icon: ""
  property bool selected: false
  // Unselected, the glyph is accent-coloured unless dimmed.
  property bool dimIcon: false
  signal clicked()

  readonly property color ink: selected ? Theme.background : Theme.foreground

  implicitWidth: content.implicitWidth + 20
  implicitHeight: Theme.rowHeight
  radius: Theme.controlRadius
  opacity: enabled ? 1 : 0.4
  transform: Translate { y: mouse.pressed ? 1 : 0 }
  scale: mouse.pressed ? 0.99 : 1
  color: selected ? Theme.accent : mouse.pressed ? Theme.pressed : mouse.containsMouse ? Theme.alpha(Theme.foreground, 0.07) : Theme.alpha(Theme.foreground, 0.05)
  Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
  border.width: selected ? 0 : 1
  border.color: Theme.alpha(Theme.foreground, 0.1)

  // delta.dev buttons: a darker, thicker bottom edge at rest that slides
  // away on hover while a ring fades in just outside the button.
  readonly property bool lit: mouse.containsMouse && enabled

  // delta.dev's inset shadow (0 -2px, inside the border): the button's inner
  // shape minus the same shape raised by the lip height. The ends bend up
  // along the rounded corners. Hover shrinks it away.
  // Drawn once; hover only fades it back, so nothing is repainted mid-fade.
  readonly property real lip: 2

  Canvas {
    id: lipCanvas
    anchors.fill: parent
    anchors.margins: root.border.width
    opacity: root.lit ? 0.3 : 1
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    readonly property color ink: root.selected ? Theme.alpha("#000000", 0.18)
      : Theme.alpha("#000000", Theme.luminance(Theme.background) > 0.4 ? 0.12 : 0.55)
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      if (root.lip <= 0) return
      var w = width, h = height, r = Math.max(1, root.radius)
      function shape(y) {
        ctx.beginPath()
        ctx.moveTo(r, y)
        ctx.lineTo(w - r, y)
        ctx.arcTo(w, y, w, y + r, r)
        ctx.lineTo(w, y + h - r)
        ctx.arcTo(w, y + h, w - r, y + h, r)
        ctx.lineTo(r, y + h)
        ctx.arcTo(0, y + h, 0, y + h - r, r)
        ctx.lineTo(0, y + r)
        ctx.arcTo(0, y, r, y, r)
        ctx.closePath()
      }
      ctx.fillStyle = ink
      shape(0)
      ctx.fill()
      ctx.globalCompositeOperation = "destination-out"
      shape(-root.lip)
      ctx.fill()
    }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: -3
    radius: root.radius + 2
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.18)
    opacity: root.lit ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 6

    Label {
      visible: root.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.selected ? root.ink : root.dimIcon ? Theme.dim : Theme.accent
      font.pixelSize: Theme.iconSize
      elide: Text.ElideNone
    }
    Label {
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: root.ink
      elide: Text.ElideNone
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.clicked()
  }
}
