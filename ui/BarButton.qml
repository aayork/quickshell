import QtQuick
import qs.theme

// A slot on the bar: one glyph or a short piece of text.
Item {
  id: root

  property string text: ""
  property string fontFamily: Theme.fontFamily
  property int fontSize: Theme.iconSize
  property color foreground: Theme.foreground
  // Held down while the popup it owns is open.
  property bool active: false
  property int minimumWidth: Theme.barIconSlot
  readonly property bool hovered: mouse.containsMouse

  signal clicked(int button)
  signal scrolled(real delta)

  implicitWidth: Math.max(minimumWidth, label.implicitWidth + Theme.barPadding * 2)
  implicitHeight: Theme.barHeight

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 3
    anchors.bottomMargin: 3
    radius: Theme.controlRadius
    color: Theme.alpha(root.foreground, root.active || root.moving ? 0.16 : mouse.containsMouse ? 0.08 : 0)
  }

  Label {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    elide: Text.ElideNone
  }

  // Drag sideways to move the button along the bar (when `movable`). The
  // drag starts once the pointer has gone a few pixels, and a drag never
  // counts as a click.
  property bool movable: false
  property bool moving: false
  signal moveStarted()
  signal moved(real dx)
  signal moveEnded()

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    // In window coordinates, since the button itself moves while dragged.
    property real pressX: 0
    property bool dragged: false

    onPressed: function(event) {
      dragged = false
      pressX = mapToItem(null, event.x, 0).x
    }
    onPositionChanged: function(event) {
      if (!root.movable || !(pressedButtons & Qt.LeftButton)) return
      var dx = mapToItem(null, event.x, 0).x - pressX
      if (!root.moving && Math.abs(dx) < 6) return
      if (!root.moving) {
        dragged = true
        root.moving = true
        root.moveStarted()
      }
      root.moved(dx)
    }
    onReleased: finishMove()
    onCanceled: finishMove()
    function finishMove() {
      if (!root.moving) return
      root.moving = false
      root.moveEnded()
    }
    onClicked: function(event) { if (!dragged) root.clicked(event.button) }
    onWheel: function(event) { root.scrolled(event.angleDelta.y) }
  }
}
