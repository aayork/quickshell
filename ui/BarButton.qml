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

  // Lit glass behind the hovered or open slot: a soft blue glow, a white
  // glass bead over it and a glint along the top.
  Item {
    anchors.fill: parent
    anchors.topMargin: 4
    anchors.bottomMargin: 4
    anchors.leftMargin: 1
    anchors.rightMargin: 1
    opacity: root.active ? 1 : mouse.containsMouse ? 0.75 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -1.5
      radius: height / 2
      color: Theme.alpha(Theme.accent, root.active ? 0.35 : 0.2)
    }
    Rectangle {
      anchors.fill: parent
      radius: height / 2
      border.width: 1
      border.color: Theme.alpha("#ffffff", 0.85)
      gradient: Gradient {
        GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.7) }
        GradientStop { position: 0.5; color: Theme.alpha("#ffffff", 0.3) }
        GradientStop { position: 0.51; color: Theme.alpha(Theme.accent, 0.18) }
        GradientStop { position: 1; color: Theme.alpha("#ffffff", 0.4) }
      }
    }
  }

  Label {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.foreground
    font.family: root.fontFamily === Theme.fontFamily ? Theme.familyFor(root.text) : root.fontFamily
    font.pixelSize: root.fontSize
    elide: Text.ElideNone
    // Embossed, as if pressed into the glass.
    style: Text.Raised
    styleColor: Theme.luminance(root.foreground) < 0.4 ? Theme.alpha("#ffffff", 0.55) : Theme.alpha("#000000", 0.3)
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
