import QtQuick
import QtQuick.Effects
import qs.theme

// An app icon the Vista way: the icon stands free, no tile, with a soft drop
// shadow under it so it sits on the glass like an object.
Item {
  id: root

  property string source: ""

  Image {
    id: image
    anchors.fill: parent
    source: root.source
    sourceSize.width: 64
    sourceSize.height: 64
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    mipmap: true
    visible: false
  }

  MultiEffect {
    anchors.fill: image
    source: image
    visible: image.status === Image.Ready
    shadowEnabled: true
    shadowColor: Theme.alpha("#000000", 0.55)
    shadowBlur: 0.45
    shadowVerticalOffset: Math.max(1, root.height * 0.06)
    shadowHorizontalOffset: 0
  }
}
