import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.theme

// A card that drops from a bar button. Clicking anywhere else, or Escape,
// closes it.
PopupWindow {
  id: root

  required property Item anchorItem
  property bool open: false
  property int contentWidth: 320
  property int contentHeight: 100
  // Distance kept from the screen edges.
  property int margin: Theme.popupGap
  default property alias content: holder.data

  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property int inset: Theme.popupPadding + Theme.borderWidth

  function toggle() { open = !open }
  function close() { open = false }

  visible: open || card.opacity > 0
  color: "transparent"
  implicitWidth: contentWidth + inset * 2
  implicitHeight: contentHeight + inset * 2

  onOpenChanged: {
    if (open) {
      PopupState.opened(root)
      holder.forceActiveFocus()
      grabDelay.restart()
    } else {
      PopupState.closed(root)
      grabDelay.stop()
      grabbing = false
    }
  }

  // The grab starts a beat after the popup maps. Started in the same frame,
  // a popup still settling on its size loses the grab straight away and
  // closes itself.
  property bool grabbing: false
  Timer {
    id: grabDelay
    interval: 60
    onTriggered: root.grabbing = root.open
  }

  HyprlandFocusGrab {
    active: root.grabbing
    windows: root.anchorWindow ? [root, root.anchorWindow] : [root]
    onCleared: root.close()
  }

  anchor {
    id: popupAnchor
    window: root.anchorWindow
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    rect.width: 1
    rect.height: 1

    // Centred under the button, then pulled back inside the screen.
    onAnchoring: {
      var window = root.anchorWindow
      if (!window || !root.anchorItem) return
      var point = window.contentItem.mapFromItem(root.anchorItem,
        root.anchorItem.width / 2 - root.implicitWidth / 2, 0)
      var x = Math.max(root.margin, Math.min(point.x, window.width - root.implicitWidth - root.margin))
      popupAnchor.rect.x = Math.round(x)
      popupAnchor.rect.y = window.height + root.margin
    }
  }

  Rectangle {
    id: card
    anchors.fill: parent
    color: Theme.background
    border.width: Theme.borderWidth
    border.color: Theme.accent
    radius: Theme.radius
    opacity: root.open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    FocusScope {
      id: holder
      anchors.fill: parent
      anchors.margins: root.inset
      focus: true
      Keys.onEscapePressed: root.close()
    }
  }
}
