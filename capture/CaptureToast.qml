import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme
import qs.ui

// A fresh capture, in the notification column (notifications/Toasts.qml),
// drawn like a notification but kept until dealt with: no timeout. The
// newest shows the picture with Copy / Save / Edit / Pin under it; older
// ones fold down to a row. Click the picture to annotate, drag it into
// another app to drop the file there, swipe it sideways or middle-click to
// put it away, right-click for everything else.
Item {
  id: slot

  required property string path
  property bool compact: false

  readonly property bool video: Captures.isVideo(path)
  readonly property bool gif: /\.gif$/i.test(path)
  // capture-<ms>.png: when it was taken.
  readonly property string taken: {
    var m = path.match(/-(\d{13})\.\w+$/)
    return m ? Qt.formatTime(new Date(Number(m[1])), "HH:mm") : ""
  }
  readonly property string kind: gif ? "GIF" : video ? "Recording" : "Screenshot"

  implicitHeight: card.implicitHeight

  Rectangle {
    id: card

    readonly property real throwDistance: width * 0.3
    property bool leaving: false
    property bool swiping: false

    width: slot.width
    implicitHeight: slot.compact ? 56 : full.implicitHeight + 24
    opacity: 1 - Math.min(0.8, Math.abs(x) / width)
    color: Theme.background
    // The same thin edge as a notification.
    border.width: 0.625
    border.color: hover.hovered ? Theme.alpha(Theme.accent, 0.6) : Theme.alpha("#9a9a9a", 0.35)
    radius: Theme.radius

    Behavior on x {
      enabled: !card.swiping
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    function throwAway(direction) {
      if (leaving) return
      leaving = true
      x = direction < 0 ? -width : width
      gone.start()
    }

    function settle(velocity) {
      swiping = false
      if (Math.abs(x) > throwDistance || Math.abs(velocity) > 1.2) throwAway(x !== 0 ? x : velocity)
      else x = 0
    }

    Timer {
      id: gone
      interval: 180
      onTriggered: Captures.dismiss(slot.path)
    }

    HoverHandler { id: hover }

    // Swipe away, middle click away, right click for the menu. Clicks on
    // the picture and the buttons are taken by them first.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      drag.target: card.leaving ? null : card
      drag.axis: Drag.XAxis
      drag.minimumX: -card.width
      drag.maximumX: card.width
      drag.threshold: 6

      property real lastX: 0
      property real lastTime: 0
      property real velocity: 0
      property bool dragged: false

      onPressed: {
        dragged = false
        velocity = 0
        lastX = card.x
        lastTime = Date.now()
      }
      onPositionChanged: {
        if (!drag.active) return
        dragged = true
        card.swiping = true
        var now = Date.now()
        if (now > lastTime) velocity = (card.x - lastX) / (now - lastTime)
        lastX = card.x
        lastTime = now
      }
      onReleased: if (dragged) card.settle(velocity)
      onClicked: function(event) {
        if (dragged || card.leaving) return
        if (event.button === Qt.MiddleButton) card.throwAway(1)
        else if (event.button === Qt.RightButton) menu.visible = true
        else Captures.edit(slot.path)
      }
    }

    // ---- close, top right, while hovered
    IconButton {
      z: 3
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: 4
      implicitWidth: 24
      implicitHeight: 24
      icon: Icons.close
      size: 13
      foreground: Theme.dim
      opacity: hover.hovered && !card.swiping ? 1 : 0
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: 120 } }
      onClicked: card.throwAway(1)
    }

    // ---- the newest: header, picture, buttons
    ColumnLayout {
      id: full
      visible: !slot.compact
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 12
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: 22
        spacing: 6
        Label {
          text: Icons.glyph(slot.video ? 0xF0567 : 0xF0EF6)
          color: Theme.accent
          font.pixelSize: Theme.iconSize
          elide: Text.ElideNone
        }
        Label {
          Layout.fillWidth: true
          text: slot.kind + (slot.taken ? "  ·  " + slot.taken : "")
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
        }
      }

      CaptureThumb {
        path: slot.path
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(Math.min(190, Math.max(90, width / Math.max(0.3, ratio))))
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        TextButton {
          text: "Copy"
          icon: Icons.glyph(0xF018F)
          onClicked: { Captures.copy(slot.path); card.throwAway(1) }
        }
        TextButton {
          text: "Save"
          icon: Icons.glyph(0xF0193)
          onClicked: { Captures.save(slot.path); card.throwAway(1) }
        }
        TextButton {
          text: slot.video ? "Play" : "Edit"
          icon: Icons.glyph(slot.video ? 0xF040A : 0xF03EB)
          onClicked: Captures.edit(slot.path)
        }
        Item { Layout.fillWidth: true }
        IconButton {
          visible: !slot.video
          icon: Icons.glyph(0xF0403)
          foreground: Theme.dim
          onClicked: Captures.pin(slot.path)
        }
        IconButton {
          icon: Icons.glyph(0xF01D8)
          foreground: Theme.dim
          onClicked: menu.visible = !menu.visible
        }
      }
    }

    // ---- older ones: one row
    RowLayout {
      visible: slot.compact
      anchors.fill: parent
      anchors.margins: 8
      anchors.rightMargin: 12
      spacing: 10

      CaptureThumb {
        path: slot.path
        Layout.preferredWidth: 64
        Layout.fillHeight: true
        crop: true
      }
      Label {
        Layout.fillWidth: true
        text: slot.kind + (slot.taken ? "  ·  " + slot.taken : "")
        color: Theme.dim
        font.pixelSize: Theme.fontSmall
      }
      Row {
        spacing: 2
        opacity: hover.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        IconButton { icon: Icons.glyph(0xF018F); foreground: Theme.dim; onClicked: { Captures.copy(slot.path); card.throwAway(1) } }
        IconButton { icon: Icons.glyph(0xF0193); foreground: Theme.dim; onClicked: { Captures.save(slot.path); card.throwAway(1) } }
        IconButton { icon: Icons.glyph(slot.video ? 0xF040A : 0xF03EB); foreground: Theme.dim; onClicked: Captures.edit(slot.path) }
        // Leaves room for the close button.
        Item { width: 18; height: 1 }
      }
    }

    CaptureMenuList {
      id: menu
      z: 4
      visible: false
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.bottom: parent.bottom
      anchors.bottomMargin: slot.compact ? 4 : 40
      path: slot.path
      onDone: visible = false
    }

    // A menu left open goes away with the pointer.
    Connections {
      target: hover
      function onHoveredChanged() { if (!hover.hovered) menu.visible = false }
    }
  }
}
