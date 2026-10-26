import QtQuick
import QtQuick.Effects
import qs.theme

// A notification's icon. Symbolic icons (names ending in -symbolic) are
// single-colour shapes meant to be recoloured, so they take the theme's text
// colour instead of the dark grey they ship in; pictures stay as they are.
Item {
  id: root

  property string source: ""
  readonly property bool symbolic: /-symbolic(\.svg)?$/.test(source)

  Image {
    id: image
    anchors.fill: parent
    // A symbolic icon sits a little inset, like a glyph, not edge to edge.
    anchors.margins: root.symbolic ? 4 : 0
    source: root.source
    sourceSize.width: 64
    sourceSize.height: 64
    fillMode: root.symbolic ? Image.PreserveAspectFit : Image.PreserveAspectCrop
    asynchronous: true
    visible: !root.symbolic
  }

  MultiEffect {
    anchors.fill: image
    source: image
    visible: root.symbolic && image.status === Image.Ready
    // Lift to white, then tint, so the result is the theme colour itself.
    brightness: 1
    colorization: 1
    colorizationColor: Theme.foreground
  }
}
