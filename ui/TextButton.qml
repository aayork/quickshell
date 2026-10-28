import QtQuick
import qs.theme

// A labelled button inside a popup, optionally led by a glyph, drawn as a
// Windows Vista button. `selected` marks the current choice in a group.
Item {
  id: root

  property string text: ""
  property string icon: ""
  property bool selected: false
  // The glyph is accent-coloured unless dimmed.
  property bool dimIcon: false
  property real radius: 3
  signal clicked()

  readonly property color ink: face.ink

  implicitWidth: content.implicitWidth + 20
  implicitHeight: Theme.rowHeight
  opacity: enabled ? 1 : 0.45

  VistaFace {
    id: face
    anchors.fill: parent
    radius: root.radius
    hovered: mouse.containsMouse
    pressed: mouse.pressed
    lit: root.selected
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 6

    Label {
      visible: root.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: Theme.dark ? (root.dimIcon ? "#9aa8b4" : root.selected ? "#ffffff" : "#7cc0f5")
        : (root.dimIcon ? "#5a6670" : root.selected ? "#0b4f86" : "#1f6fb2")
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
