import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
// Qualified: this widget shares its name with the service.
import qs.services as Services
import qs.theme
import qs.ui
import "../services/SpacesModel.js" as Model

// Workspace switcher that shows the apps open on each workspace, after Spaces
// by Tornike Gomareli (github.com/tornikegomareli/omarchy-spaces, MIT).
//
// Each workspace is a pill. The active one (and the hovered one, or all of
// them, per Config.spaces.showApps) slides open to show the icons of its
// windows, the focused window lit. Click a pill to go there, an icon to focus
// that window, scroll to step through. Hovering another workspace shows a live
// miniature of it; click a window in it to jump there. Terminals running a
// coding agent get a badge: a spinner while it works, a pulsing "!" when it
// needs you, a check when it is done.
Item {
  id: root

  property color foreground: Theme.foreground

  readonly property var cfg: Services.Config.spaces
  readonly property var spaces: Services.Spaces

  readonly property int pillHeight: Theme.barHeight - 6
  readonly property int iconPx: 14
  readonly property int pillRadius: Theme.controlRadius + 2
  readonly property int dur: 240
  readonly property int fastDur: 140

  readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

  readonly property var ids: {
    var known = Object.keys(spaces.workspaces).map(Number)
    return Model.workspaceIds(known, focusedId, cfg.persistent)
  }

  function scrollBy(delta) {
    if (!cfg.scrollSwitch || delta === 0) return
    var next = Model.stepWorkspace(ids, focusedId, delta < 0 ? 1 : -1)
    if (next !== focusedId) spaces.focusWorkspace(next)
  }

  function activate(item) {
    // A grouped icon that is already focused steps through its windows.
    if (item.focused && item.addresses.length > 1) {
      var idx = item.addresses.indexOf(item.address)
      spaces.focusWindow(item.addresses[(idx + 1) % item.addresses.length])
    } else {
      spaces.focusWindow(item.address)
    }
  }

  implicitWidth: pills.implicitWidth
  implicitHeight: Theme.barHeight
  height: Theme.barHeight

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: function(wheel) { root.scrollBy(wheel.angleDelta.y || wheel.angleDelta.x) }
  }

  Row {
    id: pills
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    Repeater {
      id: pillRepeater
      model: ScriptModel { values: root.ids }

      Item {
        id: pill

        required property var modelData
        readonly property int workspaceId: Number(modelData)
        readonly property var workspace: root.spaces.workspaces[workspaceId] || ({ id: workspaceId, windows: [] })
        readonly property bool active: workspaceId === root.focusedId
        readonly property bool occupied: workspace.windows.length > 0
        readonly property bool hovered: pillHover.hovered
        readonly property bool showApps: Model.showsApps(root.cfg.showApps, occupied, active, hovered)
        readonly property var addresses: workspace.windows.map(function(w) { return w.address })
        readonly property bool urgent: {
          if (active) return false
          if (root.cfg.agentStatus && root.spaces.agentStateFor(addresses) === "waiting") return true
          for (var i = 0; i < addresses.length; i++) if (root.spaces.urgent[addresses[i]]) return true
          return false
        }
        readonly property var iconData: Model.iconItems(workspace.windows, root.cfg.groupApps, root.cfg.maxIcons)
        readonly property var itemMap: {
          var map = ({})
          for (var i = 0; i < iconData.items.length; i++) map[iconData.items[i].key] = iconData.items[i]
          return map
        }
        readonly property var itemKeys: iconData.items.map(function(item) { return item.key })

        onHoveredChanged: preview.pillHovered(pill, hovered)

        width: content.implicitWidth + 14
        height: root.pillHeight
        Behavior on width { NumberAnimation { duration: root.dur; easing.type: Easing.OutCubic } }

        // Attention pulse, under the regular fill. Stepped, so the bar
        // repaints a couple of times a second instead of every frame.
        Rectangle {
          id: glow
          anchors.fill: parent
          radius: root.pillRadius
          color: Theme.red
          opacity: 0
          visible: pill.urgent
          Timer {
            running: pill.urgent
            interval: 700
            repeat: true
            triggeredOnStart: true
            onTriggered: glow.opacity = glow.opacity > 0.3 ? 0.15 : 0.55
            onRunningChanged: if (!running) glow.opacity = 0
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: root.pillRadius
          color: pill.active ? Theme.alpha(root.foreground, 0.2)
            : pill.hovered ? Theme.alpha(root.foreground, 0.12)
            : pill.occupied ? Theme.alpha(root.foreground, 0.06)
            : "transparent"
          Behavior on color { ColorAnimation { duration: root.fastDur } }
        }

        HoverHandler { id: pillHover }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            preview.hide()
            if (!pill.active) root.spaces.focusWorkspace(pill.workspaceId)
          }
        }

        Row {
          id: content
          anchors.centerIn: parent
          spacing: iconClip.width > 0 ? 6 : 0

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.workspaceId === 10 ? "0" : String(pill.workspaceId)
            color: root.foreground
            opacity: pill.occupied || pill.active ? 1 : 0.5
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: pill.active
          }

          // Clipped, with its width animating, so the icons slide out of the
          // pill rather than pop in.
          Item {
            id: iconClip
            anchors.verticalCenter: parent.verticalCenter
            width: pill.showApps ? icons.implicitWidth : 0
            height: icons.implicitHeight
            clip: true
            opacity: pill.showApps ? 1 : 0
            Behavior on width { NumberAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: root.dur } }

            Row {
              id: icons
              spacing: 1

              move: Transition { NumberAnimation { properties: "x"; duration: root.dur; easing.type: Easing.OutCubic } }

              Repeater {
                model: ScriptModel { values: pill.itemKeys }

                Item {
                  id: appIcon

                  required property var modelData
                  readonly property var item: pill.itemMap[modelData] || null
                  readonly property var info: item ? root.spaces.appInfo(item.appId) : ({ source: "", name: "" })
                  readonly property bool focusedHere: item !== null && item.focused && pill.active
                  readonly property bool hovered: iconMouse.containsMouse
                  readonly property string agentState: item && root.cfg.agentStatus ? root.spaces.agentStateFor(item.addresses) : ""
                  readonly property bool attention: item !== null && item.addresses.some(function(a) { return root.spaces.urgent[a] === true })

                  width: root.iconPx + 6
                  height: root.iconPx + 4

                  Rectangle {
                    anchors.fill: parent
                    radius: Theme.controlRadius + 1
                    color: (appIcon.focusedHere && pill.itemKeys.length > 1) || appIcon.hovered
                      ? Theme.alpha(root.foreground, 0.2) : "transparent"
                    Behavior on color { ColorAnimation { duration: root.fastDur } }
                  }

                  Item {
                    anchors.centerIn: parent
                    width: root.iconPx
                    height: root.iconPx
                    // Other windows on the active workspace sit back a little.
                    opacity: pill.active && !appIcon.focusedHere && !appIcon.hovered ? 0.55 : 1
                    Behavior on opacity { NumberAnimation { duration: root.fastDur } }

                    Image {
                      id: iconImage
                      anchors.fill: parent
                      source: appIcon.info.source
                      sourceSize.width: root.iconPx * 3
                      sourceSize.height: root.iconPx * 3
                      fillMode: Image.PreserveAspectFit
                      smooth: true
                      asynchronous: true
                      visible: status === Image.Ready
                    }

                    // A letter when no icon could be found.
                    Rectangle {
                      anchors.fill: parent
                      visible: iconImage.status !== Image.Ready
                      radius: Theme.controlRadius
                      color: Theme.alpha(root.foreground, 0.2)
                      Text {
                        anchors.centerIn: parent
                        text: Model.fallbackLetter(appIcon.info.name, appIcon.item ? appIcon.item.appId : "")
                        color: root.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(root.iconPx * 0.65)
                        font.bold: true
                      }
                    }
                  }

                  // A window asking for attention.
                  Rectangle {
                    visible: appIcon.agentState === "" && appIcon.attention
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.red
                  }

                  // Agent badge.
                  Item {
                    id: badge
                    visible: appIcon.agentState !== "" && appIcon.agentState !== "idle"
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 9
                    height: 9

                    Rectangle {
                      anchors.fill: parent
                      radius: width / 2
                      color: appIcon.agentState === "done" ? Theme.green
                        : appIcon.agentState === "waiting" ? Theme.yellow
                        : Theme.background
                    }

                    // Stepped rather than a RotationAnimator: an endless
                    // animation would repaint the bar every frame while an
                    // agent works. Eight steps a second reads the same.
                    Canvas {
                      id: spinner
                      anchors.fill: parent
                      anchors.margins: 1
                      visible: appIcon.agentState === "working"
                      onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.lineWidth = 1.5
                        ctx.lineCap = "round"
                        ctx.strokeStyle = Theme.accent
                        ctx.beginPath()
                        ctx.arc(width / 2, height / 2, width / 2 - 1, 0, Math.PI * 1.4)
                        ctx.stroke()
                      }
                      Timer {
                        running: spinner.visible
                        interval: 125
                        repeat: true
                        onTriggered: spinner.rotation = (spinner.rotation + 45) % 360
                      }
                    }

                    Text {
                      anchors.centerIn: parent
                      visible: appIcon.agentState === "done" || appIcon.agentState === "waiting"
                      text: appIcon.agentState === "done" ? Icons.check : "!"
                      color: Theme.background
                      font.family: Theme.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Timer {
                      running: appIcon.agentState === "waiting"
                      interval: 520
                      repeat: true
                      onTriggered: badge.scale = badge.scale > 1 ? 1 : 1.3
                      onRunningChanged: if (!running) badge.scale = 1
                    }
                  }

                  // Window count for a grouped app.
                  Rectangle {
                    visible: appIcon.item !== null && appIcon.item.count > 1
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -2
                    width: Math.max(height, countText.implicitWidth + 3)
                    height: 9
                    radius: height / 2
                    color: root.foreground
                    Text {
                      id: countText
                      anchors.centerIn: parent
                      text: appIcon.item ? String(appIcon.item.count) : ""
                      color: Theme.background
                      font.family: Theme.fontFamily
                      font.pixelSize: 7
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: iconMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: root.cfg.middleClickClose ? (Qt.LeftButton | Qt.MiddleButton) : Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                      if (!appIcon.item) return
                      preview.hide()
                      if (mouse.button === Qt.MiddleButton) root.spaces.closeWindow(appIcon.item.address)
                      else root.activate(appIcon.item)
                    }
                    onContainsMouseChanged: preview.highlight = containsMouse && appIcon.item ? appIcon.item.address : ""
                  }
                }
              }

              // The windows past maxIcons.
              Text {
                visible: pill.iconData.overflow > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "+" + pill.iconData.overflow
                color: root.foreground
                opacity: 0.8
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                font.bold: true
              }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- preview

  Connections {
    target: Services.Spaces
    function onPeekRequested(id) {
      // Only the bar on the focused monitor answers a key.
      var window = root.QsWindow.window
      if (!window || Hyprland.monitorFor(window.screen) !== Hyprland.focusedMonitor) return
      var idx = root.ids.indexOf(id)
      var pill = idx >= 0 ? pillRepeater.itemAt(idx) : null
      if (pill && pill.occupied) preview.peek(pill)
    }
  }

  onFocusedIdChanged: if (focusedId === preview.workspaceId) preview.hide()

  SpacesPreview {
    id: preview
    anchorItem: root
  }
}
