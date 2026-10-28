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

  // A pill of white glass behind the hovered or open slot.
  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 3
    anchors.bottomMargin: 3
    radius: height / 2
    opacity: root.active ? 1 : mouse.containsMouse ? 0.6 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    border.width: 1
    border.color: Theme.alpha("#ffffff", 0.7)
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.55) }
      GradientStop { position: 0.5; color: Theme.alpha("#ffffff", 0.25) }
      GradientStop { position: 1; color: Theme.alpha("#ffffff", 0.12) }
    }
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
