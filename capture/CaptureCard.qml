import QtQuick
import QtQuick.Effects
import qs.services
import qs.theme
import qs.ui

// One fresh capture in the corner stack, after CleanShot X's Quick Access
// Overlay: the picture filling a rounded card with a soft shadow, sliding in
// from the side. On hover it dims and offers Copy and Save in the middle;
// close top left, pin top right, annotate bottom left, Save As bottom right
// (where CleanShot has its cloud upload). Right click for the rest, Move to
// Trash among them. Click it to annotate; drag it into another app to drop
// the file there.
Item {
  id: card

  required property string path
  property int cardWidth: 220

  readonly property int radius: 10
  readonly property bool hovered: hover.hovered

  // Every card is the same size, whatever the capture's shape, as in
  // CleanShot X; the picture fits inside it.
  implicitWidth: cardWidth
  implicitHeight: Math.round(cardWidth * 0.625)

  // Slides in from the left edge when it arrives.
  property real slide: 1
  Component.onCompleted: enter.start()
  NumberAnimation { id: enter; target: card; property: "slide"; from: 1; to: 0; duration: 280; easing.type: Easing.OutCubic }
  transform: Translate { x: -card.slide * (card.width + 30) }
  opacity: 1 - card.slide * 0.7

  RectangularShadow {
    anchors.fill: frame
    radius: card.radius
    offset.y: 8
    blur: 30
    spread: -2
    color: Theme.alpha("#000000", 0.55)
  }

  // The picture, with rounded corners.
  Item {
    id: frame
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: shape
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }

    Rectangle { anchors.fill: parent; color: "#111111" }

    // Zoomed in to fill the card, as CleanShot does: no bars at the sides.
    Image {
      id: pic
      anchors.fill: parent
      source: "file://" + card.path
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: card.cardWidth * 2
      asynchronous: true
      cache: false
      smooth: true
      mipmap: true
    }

    // Dims under the pointer so the buttons read.
    Rectangle {
      anchors.fill: parent
      color: Theme.alpha("#000000", card.hovered ? 0.5 : 0)
      Behavior on color { ColorAnimation { duration: 140 } }
    }
  }

  Item {
    id: shape
    anchors.fill: parent
    visible: false
    layer.enabled: true
    Rectangle { anchors.fill: parent; radius: card.radius }
  }

  // A hairline edge, so a dark picture still has a shape against a dark
  // desktop.
  Rectangle {
    anchors.fill: parent
    radius: card.radius
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha("#ffffff", card.hovered ? 0.3 : 0.16)
  }

  HoverHandler { id: hover }

  // Drag the card out to drop the file into another app.
  Item {
    id: dragProxy
    Drag.active: dragArea.drag.active
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.mimeData: ({ "text/uri-list": "file://" + card.path + "\r\n" })
    Drag.imageSource: "file://" + card.path
    Drag.onDragFinished: function(action) { if (action === Qt.CopyAction) Captures.dismiss(card.path) }
  }

  MouseArea {
    id: dragArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    drag.target: dragProxy
    onClicked: Captures.edit(card.path)
  }

  // Hover controls, where CleanShot puts them.
  Item {
    anchors.fill: parent
    opacity: card.hovered && !menu.visible ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Column {
      anchors.centerIn: parent
      spacing: 8

      PillButton {
        text: "Copy"
        onClicked: {
          Captures.copy(card.path)
          Captures.dismiss(card.path)
        }
      }
      PillButton {
        text: "Save"
        onClicked: {
          Captures.save(card.path)
          Captures.dismiss(card.path)
        }
      }
    }

    CornerButton {
      anchors { top: parent.top; left: parent.left; margins: 7 }
      glyph: 0xF0156
      onClicked: Captures.dismiss(card.path)
    }
    CornerButton {
      anchors { top: parent.top; right: parent.right; margins: 7 }
      glyph: 0xF0403
      onClicked: Captures.pin(card.path)
    }
    CornerButton {
      anchors { bottom: parent.bottom; left: parent.left; margins: 7 }
      glyph: 0xF03EB
      onClicked: Captures.edit(card.path)
    }
    CornerButton {
      anchors { bottom: parent.bottom; right: parent.right; margins: 7 }
      glyph: 0xF0193
      onClicked: Captures.saveAs(card.path)
    }
  }

  // Right click: everything, as a small menu over the card.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    onClicked: menu.visible = true
  }

  CaptureMenuList {
    id: menu
    visible: false
    anchors.centerIn: parent
    path: card.path
    onDone: visible = false
  }

  // A menu left open goes away with the pointer.
  onHoveredChanged: if (!hovered) menu.visible = false
}
