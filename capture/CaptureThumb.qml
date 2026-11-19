import QtQuick
import qs.services
import qs.theme
import qs.ui

// A capture's picture for capture/CaptureToast.qml, on the darkest
// background colour with a hairline round it. Click to annotate; drag it
// out to drop the file somewhere.
Rectangle {
  id: thumb
  required property string path
  property bool crop: false
  readonly property bool video: Captures.isVideo(path)
  readonly property bool gif: /\.gif$/i.test(path)
  readonly property real ratio: pic.implicitHeight > 0 ? pic.implicitWidth / pic.implicitHeight : 16 / 9

  color: Theme.darkerBackground
  border.width: 1
  border.color: thumbMouse.containsMouse ? Theme.accent : Theme.separator
  clip: true

  Image {
    id: pic
    anchors.fill: parent
    anchors.margins: 1
    source: "file://" + Captures.thumbOf(thumb.path)
    fillMode: thumb.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
    sourceSize.width: 720
    asynchronous: true
    cache: false
    smooth: true
    mipmap: true
  }

  Rectangle {
    visible: thumb.video
    anchors.centerIn: parent
    width: badge.implicitWidth + 12
    height: badge.implicitHeight + 6
    radius: Theme.controlRadius
    color: Theme.alpha(Theme.background, 0.85)
    Label {
      id: badge
      anchors.centerIn: parent
      text: thumb.gif ? "GIF" : Icons.glyph(0xF040A)
      color: Theme.foreground
      font.pixelSize: Theme.fontSmall
      font.bold: thumb.gif
      elide: Text.ElideNone
    }
  }

  Item {
    id: dragProxy
    Drag.active: thumbMouse.drag.active
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.mimeData: ({ "text/uri-list": "file://" + thumb.path + "\r\n" })
    Drag.imageSource: "file://" + Captures.thumbOf(thumb.path)
    Drag.onDragFinished: function(action) { if (action === Qt.CopyAction) Captures.dismiss(thumb.path) }
  }

  MouseArea {
    id: thumbMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    drag.target: dragProxy
    onClicked: Captures.edit(thumb.path)
  }
}
