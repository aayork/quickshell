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
    color: Theme.alpha(root.foreground, root.active ? 0.16 : mouse.containsMouse ? 0.08 : 0)
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

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: function(event) { root.clicked(event.button) }
    onWheel: function(event) { root.scrolled(event.angleDelta.y) }
  }
}
