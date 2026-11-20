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
  Behavior on color { ColorAnimation { duration: 90; easing.type: Easing.OutCubic } }
  border.width: selected ? 0 : 1
  border.color: Theme.alpha(Theme.foreground, 0.1)

  // delta.dev buttons: a darker, thicker bottom edge at rest that slides
  // away on hover while a ring fades in just outside the button.
  readonly property bool lit: mouse.containsMouse && enabled

  // delta.dev's inset shadow (0 -2px, inside the border): a flat-topped band
  // whose bottom corners follow the button's, with its ends turned up a
  // touch at the sides. Plain rectangles, so it stays crisp at 1.6x.
  // Hover slides it down and out of the clipped inside.
  readonly property real lip: 2
  readonly property color lipInk: selected ? Theme.alpha("#000000", 0.18)
    : Theme.alpha("#000000", Theme.luminance(Theme.background) > 0.4 ? 0.12 : 0.4)

  Item {
    anchors.fill: parent
    anchors.margins: root.border.width
    clip: true

    Item {
      id: lipShape
      width: parent.width
      height: parent.height
      // Far enough to take the raised ends out too.
      y: root.lit ? root.lip + Math.max(1, root.radius) + 1 : 0
      Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

      readonly property real r: Math.max(1, root.radius - root.border.width)

      // The band: the bottom of a button-shaped fill.
      Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.lip
        clip: true
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: lipShape.height
          radius: lipShape.r
          color: root.lipInk
        }
      }
      // The turned-up ends.
      Repeater {
        model: 2
        Rectangle {
          required property int index
          x: index === 0 ? 0 : lipShape.width - width
          y: lipShape.height - root.lip - lipShape.r
          width: 1
          height: lipShape.r
          color: root.lipInk
        }
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: -3
    radius: root.radius + 3
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.22)
    opacity: root.lit ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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
