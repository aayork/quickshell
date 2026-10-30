import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import "Squircle.js" as Squircle

// A bar popup that can be dragged anywhere (Jot). A popup surface has to ask
// the compositor for every move, which lags behind the pointer; this is a
// see-through layer over the whole screen instead, with the card moved
// inside it, so a drag is as quick as anything drawn in QML.
//
// Same interface as Popup: open, toggle(), close(), contentWidth and
// contentHeight, plus offsetX/offsetY (where it was dragged to from its place
// under the button) and keepOpen (pinned).
PanelWindow {
  id: root

  required property Item anchorItem
  property bool open: false
  property int contentWidth: 320
  property int contentHeight: 100
  property int margin: Theme.popupGap
  // Pinned: stays open, and the rest of the screen stays usable around it.
  property bool keepOpen: false
  property real offsetX: 0
  property real offsetY: 0
  default property alias content: holder.data

  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  // The card's look. The defaults are the shell's; Jot gives its own.
  property color cardColor: Theme.background
  property color borderColor: Theme.accent
  property int borderWidth: Theme.borderWidth
  property int cornerRadius: Theme.radius
  property bool shadow: false
  // Above 0, macOS-style smooth corners (0.6 is Apple's) instead of round ones.
  property real cornerSmoothing: 0
  property int inset: Theme.popupPadding + Theme.borderWidth
  // Jot has the keyboard (while pinned it only gets it when clicked).
  readonly property bool grabbing: open && !keepOpen
  // The card, for dragging code that wants its position.
  readonly property alias card: card

  function toggle() { open = !open }
  function close() { open = false }
  // Kept for callers written against Popup; nothing to do here.
  function regrab() {}

  Connections {
    target: Session
    function onScreensaverChanged() { if (Session.screensaver) root.close() }
  }

  onOpenChanged: {
    if (open) {
      PopupState.opened(root)
      holder.forceActiveFocus()
    } else {
      PopupState.closed(root)
    }
  }

  screen: anchorWindow ? anchorWindow.screen : null
  visible: open || card.opacity > 0
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "aayork-jot"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: root.keepOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
  // Pinned, only the card takes the pointer; otherwise a click anywhere
  // else closes it, like the other bar popups.
  mask: root.keepOpen ? cardRegion : null
  Region { id: cardRegion; item: card }

  MouseArea {
    anchors.fill: parent
    enabled: !root.keepOpen
    onClicked: root.close()
  }

  // Centred under the button, moved by the drag offset, kept on screen.
  readonly property real homeX: {
    var w = anchorWindow
    if (!w || !anchorItem) return margin
    return w.contentItem.mapFromItem(anchorItem, anchorItem.width / 2, 0).x - card.width / 2
  }

  // Offsets that keep the card on screen. Dragging code clamps with these
  // so pushing past an edge does not pile up offset that has to be dragged
  // back before the card moves again.
  function clampOffsetX(v) {
    return Math.max(-homeX, Math.min(v, width - card.width - homeX))
  }
  function clampOffsetY(v) {
    return Math.max(-margin, Math.min(v, height - card.height - Theme.barHeight - margin))
  }

  // A soft shadow under the card, like a macOS window.
  RectangularShadow {
    visible: root.shadow
    anchors.fill: card
    radius: card.radius
    offset.y: 10
    blur: 36
    spread: -2
    color: Theme.alpha("#000000", 0.28)
    opacity: card.opacity
  }

  Rectangle {
    id: card
    // Dragged, it can sit flush against the screen edges and the bar, never past.
    x: Math.round(Math.max(0, Math.min(root.homeX + root.offsetX, root.width - width)))
    y: Math.round(Math.max(Theme.barHeight,
      Math.min(Theme.barHeight + root.margin + root.offsetY, root.height - height)))
    width: root.contentWidth + root.inset * 2
    height: root.contentHeight + root.inset * 2
    readonly property bool smooth: root.cornerSmoothing > 0
    color: smooth ? "transparent" : root.cardColor
    border.width: smooth ? 0 : root.borderWidth
    border.color: root.borderColor
    radius: root.cornerRadius
    opacity: root.open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Shape {
      anchors.fill: parent
      visible: card.smooth
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: root.cardColor
        strokeColor: root.borderWidth > 0 ? root.borderColor : "transparent"
        strokeWidth: root.borderWidth
        PathPolyline {
          path: card.smooth ? Squircle.polyline(card.width, card.height, root.cornerRadius,
            root.cornerSmoothing, root.borderWidth / 2) : []
        }
      }
    }

    // Clicks on the card stay on the card.
    MouseArea { anchors.fill: parent }

    FocusScope {
      id: holder
      anchors.fill: parent
      anchors.margins: root.inset
      focus: true
      Keys.onEscapePressed: root.close()
    }
  }
}
