import QtQuick
import QtQuick.Effects
import qs.theme

// A round account picture: the AccountsService icon when there is one,
// otherwise the first letter of the name on an accent disc.
Item {
  id: root

  property var user: null
  property int size: 76
  property bool current: true
  signal clicked()

  implicitWidth: size
  implicitHeight: size

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: Theme.alpha(Theme.accent, 0.18)
    border.width: root.current ? Theme.borderWidth : 1
    border.color: root.current ? Theme.accent : Theme.alpha(Theme.foreground, 0.3)
  }

  Label {
    anchors.centerIn: parent
    visible: face.status !== Image.Ready
    text: root.user ? root.user.display.charAt(0).toUpperCase() : ""
    color: Theme.brightForeground
    font.pixelSize: Math.round(root.size * 0.4)
    elide: Text.ElideNone
  }

  Image {
    id: face
    anchors.fill: parent
    anchors.margins: (root.current ? Theme.borderWidth : 1) + 2
    source: root.user ? Theme.face(root.user.name) : ""
    sourceSize: Qt.size(root.size * 2, root.size * 2)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false
    visible: false
  }

  MultiEffect {
    anchors.fill: face
    source: face
    visible: face.status === Image.Ready
    maskEnabled: true
    maskSource: mask
  }

  Item {
    id: mask
    anchors.fill: face
    layer.enabled: true
    visible: false
    Rectangle { anchors.fill: parent; radius: width / 2 }
  }

  MouseArea {
    anchors.fill: parent
    enabled: !root.current
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.clicked()
  }
}
