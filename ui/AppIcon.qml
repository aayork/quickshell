import QtQuick
import QtQuick.Effects
import qs.theme

// An app icon set on a glossy tile, the way iOS 6 glossed every app icon and
// the Wii framed its channels: a pearly rounded square, the icon inside, and
// a curved gloss over the top half. Everything is masked to the tile's shape,
// so the gloss never spills past its corners.
Item {
  id: root

  property string source: ""
  // Share of the tile left around the icon.
  property real inset: 0.14

  readonly property real corner: width * 0.24

  // Drop shadow under the tile.
  Rectangle {
    width: parent.width
    height: parent.height
    y: Math.max(1, parent.height * 0.05)
    radius: root.corner
    color: Theme.alpha("#0b2540", 0.22)
  }

  Item {
    id: tile
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: shape
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: "#ffffff" }
        GradientStop { position: 0.55; color: "#eef5fb" }
        GradientStop { position: 1; color: "#cfe0ee" }
      }
    }

    Image {
      anchors.fill: parent
      anchors.margins: parent.width * root.inset
      source: root.source
      sourceSize.width: 64
      sourceSize.height: 64
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
      mipmap: true
    }

    // The gloss: the bottom of a big ellipse, curving down over the top half.
    Rectangle {
      width: parent.width * 1.7
      height: parent.height * 1.15
      radius: width / 2
      x: (parent.width - width) / 2
      y: parent.height * 0.52 - height
      gradient: Gradient {
        GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.0) }
        GradientStop { position: 0.6; color: Theme.alpha("#ffffff", 0.18) }
        GradientStop { position: 1; color: Theme.alpha("#ffffff", 0.55) }
      }
    }
  }

  // The tile's outline, drawn over the mask.
  Rectangle {
    anchors.fill: parent
    radius: root.corner
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha("#0b2540", 0.25)
  }

  Item {
    id: shape
    anchors.fill: parent
    visible: false
    layer.enabled: true
    Rectangle {
      anchors.fill: parent
      radius: root.corner
    }
  }
}
