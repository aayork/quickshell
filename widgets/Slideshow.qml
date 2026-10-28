import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.theme

// The Vista slideshow gadget: photos in a thin frame, crossfading every few
// seconds. The pictures are the current theme's slideshow folder. Hovering
// brings up back / pause / next along the bottom, like Vista's; clicking the
// photo opens it.
Item {
  id: root

  property string folder: Theme.themeDir + "/slideshow"
  property int seconds: 12

  implicitWidth: 172
  implicitHeight: 112

  FolderListModel {
    id: photos
    folder: "file://" + root.folder
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
    showDirs: false
    sortField: FolderListModel.Name
  }

  property int index: 0
  property bool showingA: true
  property bool paused: false

  function advance(step) {
    if (photos.count === 0) return
    index = (index + (step === undefined ? 1 : step) + photos.count) % photos.count
    var url = photos.get(index, "fileUrl")
    if (showingA) b.source = url
    else a.source = url
    showingA = !showingA
  }

  Timer {
    interval: root.seconds * 1000
    running: root.visible && photos.count > 1 && !root.paused && !hover.hovered
    repeat: true
    onTriggered: root.advance(1)
  }

  Connections {
    target: photos
    function onCountChanged() {
      if (photos.count > 0 && a.source.toString() === "") a.source = photos.get(0, "fileUrl")
    }
  }

  // Shadow and frame.
  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 2
    anchors.bottomMargin: -2
    color: Theme.alpha("#000000", 0.45)
    radius: 3
  }
  Rectangle {
    id: frame
    anchors.fill: parent
    radius: 3
    color: "#f4f6f8"
    border.width: 1
    border.color: Theme.alpha("#000000", 0.5)

    Item {
      anchors.fill: parent
      anchors.margins: 4
      clip: true

      Image {
        id: a
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 400
        opacity: root.showingA ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 900 } }
      }
      Image {
        id: b
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 400
        opacity: root.showingA ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 900 } }
      }
      // Glass over the print.
      Rectangle {
        width: parent.width
        height: parent.height * 0.45
        gradient: Gradient {
          GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.28) }
          GradientStop { position: 1; color: Theme.alpha("#ffffff", 0) }
        }
      }
    }
  }

  HoverHandler { id: hover }

  // Click the photo to open it.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: if (photos.count > 0) Quickshell.execDetached(["xdg-open", photos.get(root.index, "filePath")])
  }

  // Controls, shown while the pointer is over the gadget.
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    width: controls.implicitWidth + 16
    height: 24
    radius: 12
    opacity: hover.hovered ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160 } }
    border.width: 1
    border.color: Theme.alpha("#000000", 0.6)
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.alpha("#3a4a58", 0.85) }
      GradientStop { position: 0.5; color: Theme.alpha("#1a242e", 0.85) }
      GradientStop { position: 1; color: Theme.alpha("#0b1218", 0.9) }
    }

    Row {
      id: controls
      anchors.centerIn: parent
      spacing: 14

      GlyphButton { text: String.fromCodePoint(0xF0141); onClicked: root.advance(-1) }
      GlyphButton { text: String.fromCodePoint(root.paused ? 0xF040A : 0xF03E4); onClicked: root.paused = !root.paused }
      GlyphButton { text: String.fromCodePoint(0xF0142); onClicked: root.advance(1) }
    }
  }

}
