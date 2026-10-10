import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services
import qs.theme
import qs.ui
import "../services/SpacesModel.js" as Model

// A live miniature of a workspace, under its pill while the pointer rests on
// it: the windows where they sit on screen, each one a click away. One card
// serves every pill and moves between them. It never takes focus, so it
// cannot close another popup.
PopupWindow {
  id: root

  required property Item anchorItem
  // Address of the window lit in the miniature (an icon or a thumbnail is
  // under the pointer).
  property string highlight: ""

  property int workspaceId: -1
  property Item pill: null
  property bool wanted: false
  readonly property var workspace: Services.Spaces.workspaces[workspaceId] || null
  readonly property bool open: wanted && Services.Config.spaces.previews
    && workspace !== null && workspace.windows.length > 0

  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property int inset: Theme.popupPadding + Theme.borderWidth
  readonly property var mapSize: Model.previewSize(workspace ? workspace.area : null, 380)

  function pillHovered(target, hovered) {
    if (!Services.Config.spaces.previews) return
    if (hovered && !target.active && target.occupied) {
      hideTimer.stop()
      root.pill = target
      if (root.open) {
        // Already showing: follow the pointer straight away.
        root.workspaceId = target.workspaceId
        root.place()
      } else {
        showTimer.restart()
      }
    } else if (!hovered) {
      showTimer.stop()
      hideTimer.restart()
    }
  }

  function hide() {
    showTimer.stop()
    hideTimer.stop()
    peekTimer.stop()
    wanted = false
    highlight = ""
  }

  // Shown from a key rather than the pointer; it goes again on its own
  // unless the pointer moves onto it.
  function peek(target) {
    hideTimer.stop()
    root.pill = target
    root.workspaceId = target.workspaceId
    root.place()
    root.wanted = true
    peekTimer.restart()
  }

  // Centred under the pill, kept inside the screen.
  function place() {
    var window = root.anchorWindow
    if (!window || !root.pill) return
    var point = window.contentItem.mapFromItem(root.pill, root.pill.width / 2, 0)
    var x = point.x - root.implicitWidth / 2
    popupAnchor.rect.x = Math.round(Math.max(Theme.popupGap, Math.min(x, window.width - root.implicitWidth - Theme.popupGap)))
    popupAnchor.rect.y = window.height + Theme.popupGap
    if (root.visible) popupAnchor.updateAnchor()
  }

  Timer {
    id: showTimer
    interval: 380
    onTriggered: {
      if (!root.pill) return
      root.workspaceId = root.pill.workspaceId
      root.place()
      root.wanted = true
    }
  }

  Timer {
    id: hideTimer
    interval: 200
    onTriggered: if (!cardHover.hovered) root.hide()
  }

  Timer {
    id: peekTimer
    interval: 2500
    onTriggered: if (!cardHover.hovered) root.hide()
  }

  visible: open || card.opacity > 0
  color: "transparent"
  implicitWidth: Math.round(mapSize.width) + inset * 2
  implicitHeight: column.implicitHeight + inset * 2
  onImplicitWidthChanged: place()

  anchor {
    id: popupAnchor
    window: root.anchorWindow
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    rect.width: 1
    rect.height: 1
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

    HoverHandler {
      id: cardHover
      onHoveredChanged: {
        if (hovered) {
          hideTimer.stop()
          peekTimer.stop()
        } else {
          hideTimer.restart()
        }
      }
    }

    Column {
      id: column
      anchors.fill: parent
      anchors.margins: root.inset
      spacing: 8

      Item {
        width: parent.width
        height: title.implicitHeight

        Label {
          id: title
          anchors.left: parent.left
          text: "Workspace " + (root.workspaceId === 10 ? "0" : root.workspaceId)
          font.bold: true
        }

        Label {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          readonly property int count: root.workspace ? root.workspace.windows.length : 0
          text: count + (count === 1 ? " WINDOW" : " WINDOWS")
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          font.letterSpacing: 1.2
        }
      }

      Rectangle {
        width: Math.round(root.mapSize.width)
        height: Math.round(root.mapSize.height)
        color: Theme.alpha(Theme.foreground, 0.05)
        border.width: 1
        border.color: Theme.separator

        Loader {
          id: miniature
          anchors.fill: parent
          active: root.visible && root.workspace !== null
          sourceComponent: miniatureComponent
        }

        // Moving to another workspace fades the new one in.
        Connections {
          target: root
          function onWorkspaceIdChanged() { if (root.visible) swap.restart() }
        }

        ParallelAnimation {
          id: swap
          NumberAnimation { target: miniature; property: "opacity"; from: 0.35; to: 1; duration: 220; easing.type: Easing.OutCubic }
          NumberAnimation { target: miniature; property: "scale"; from: 0.97; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }
      }

      Label {
        width: parent.width
        readonly property var hovered: Services.Spaces.windowByAddress(root.highlight)
        text: hovered ? hovered.title : "Click a window to jump to it"
        color: hovered ? Theme.foreground : Theme.dim
        font.pixelSize: Theme.fontSmall
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  Component {
    id: miniatureComponent

    Item {
      id: mini
      readonly property var layout: root.workspace
        ? Model.previewLayout(root.workspace.windows, root.workspace.area, width, height) : []
      readonly property var rects: {
        var map = ({})
        for (var i = 0; i < layout.length; i++) map[layout[i].address] = layout[i]
        return map
      }

      Repeater {
        model: ScriptModel { values: mini.layout.map(function(r) { return r.address }) }

        Item {
          id: thumb
          required property var modelData
          readonly property var rect: mini.rects[modelData] || null
          readonly property var win: Services.Spaces.windowByAddress(modelData)
          readonly property bool lit: root.highlight === modelData || thumbMouse.containsMouse

          x: rect ? rect.x + 2 : 0
          y: rect ? rect.y + 2 : 0
          width: rect ? Math.max(2, rect.width - 4) : 0
          height: rect ? Math.max(2, rect.height - 4) : 0
          z: rect && rect.floating ? 1 : 0

          // Translucent windows (a terminal with background opacity) sit
          // on the theme background, not on whatever is behind the card.
          Rectangle {
            anchors.fill: parent
            color: Theme.background
          }

          ScreencopyView {
            id: capture
            anchors.fill: parent
            captureSource: thumb.win ? thumb.win.toplevel : null
            live: true
            constraintSize: Qt.size(Math.round(thumb.width * 2), Math.round(thumb.height * 2))
            opacity: hasContent ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
          }

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: thumb.lit ? 2 : 1
            border.color: thumb.lit ? Theme.accent : Theme.alpha(Theme.foreground, 0.18)
          }

          // The app in the corner, so small thumbnails stay recognisable.
          Rectangle {
            readonly property var info: thumb.win ? Services.Spaces.appInfo(thumb.win.appId) : null
            visible: info !== null && thumb.width > 28 && thumb.height > 22
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 4
            width: 20
            height: 20
            radius: Theme.controlRadius
            color: Theme.alpha(Theme.background, 0.85)

            Image {
              anchors.centerIn: parent
              width: 14
              height: 14
              source: parent.info ? parent.info.source : ""
              sourceSize.width: 42
              sourceSize.height: 42
              fillMode: Image.PreserveAspectFit
              asynchronous: true
            }
          }

          MouseArea {
            id: thumbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
              if (containsMouse) root.highlight = thumb.modelData
              else if (root.highlight === thumb.modelData) root.highlight = ""
            }
            onClicked: {
              Services.Spaces.focusWindow(thumb.modelData)
              root.hide()
            }
          }
        }
      }
    }
  }
}
