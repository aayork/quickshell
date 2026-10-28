import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui

// The session menu on SUPER+Escape: a row of cards in the middle of the
// screen. Arrows or Tab to move, a number to pick, Enter to run. Anything
// that ends the session asks for a second press within a few seconds.
Scope {
  id: root

  property bool open: false
  Connections {
    target: Session
    function onScreensaverChanged() { if (Session.screensaver) root.open = false }
  }
  property int cursor: 0
  // Index of the card waiting for its second press, or -1.
  property int confirming: -1
  // 1 down to 0 while the confirmation window runs out.
  property real confirmLeft: 1
  property string uptime: ""

  readonly property int confirmSeconds: 3
  readonly property int cardSize: 96
  readonly property var actions: Session.actions

  function show() {
    cursor = 0
    cancelConfirm()
    uptimeProcess.running = true
    open = true
  }

  function hide() {
    cancelConfirm()
    open = false
  }

  function cancelConfirm() {
    countdown.stop()
    confirming = -1
    confirmLeft = 1
  }

  function trigger(index) {
    var action = actions[index]
    if (!action) return
    cursor = index
    if (action.confirm && confirming !== index) {
      confirming = index
      confirmLeft = 1
      countdown.restart()
      return
    }
    hide()
    Session.run(action.id)
  }

  NumberAnimation {
    id: countdown
    target: root
    property: "confirmLeft"
    from: 1
    to: 0
    duration: root.confirmSeconds * 1000
    onFinished: root.cancelConfirm()
  }

  Process {
    id: uptimeProcess
    command: ["cat", "/proc/uptime"]
    stdout: StdioCollector {
      onStreamFinished: {
        var seconds = Math.floor(Number(text.split(" ")[0]) || 0)
        var days = Math.floor(seconds / 86400)
        var hours = Math.floor(seconds % 86400 / 3600)
        var minutes = Math.floor(seconds % 3600 / 60)
        root.uptime = (days > 0 ? days + "d " : "") + (hours > 0 || days > 0 ? hours + "h " : "") + minutes + "m"
      }
    }
  }

  IpcHandler {
    target: "session"
    function toggle(): void { if (root.open) root.hide(); else root.show() }
  }

  PanelWindow {
    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    visible: root.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.alpha(Theme.background, 0.35)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aayork-session"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    MouseArea {
      anchors.fill: parent
      onClicked: root.hide()
    }

    Rectangle {
      width: column.implicitWidth + 24
      height: column.implicitHeight + 22
      anchors.centerIn: parent
      color: Theme.background
      border.width: Theme.borderWidth
      border.color: Theme.accent
      radius: Theme.radius

      MouseArea { anchors.fill: parent }

      Item {
        id: keys
        focus: true
        Keys.onPressed: function(event) {
          var count = root.actions.length
          event.accepted = true
          if (event.key === Qt.Key_Escape) {
            if (root.confirming >= 0) root.cancelConfirm()
            else root.hide()
          } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
            root.cancelConfirm()
            root.cursor = (root.cursor + 1) % count
          } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab) {
            root.cancelConfirm()
            root.cursor = (root.cursor + count - 1) % count
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.trigger(root.confirming >= 0 ? root.confirming : root.cursor)
          } else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + count) {
            root.trigger(event.key - Qt.Key_1)
          } else {
            event.accepted = false
          }
        }
      }

      ColumnLayout {
        id: column
        anchors.centerIn: parent
        spacing: 10

        Label {
          Layout.alignment: Qt.AlignHCenter
          text: Icons.glyph(0xF0379) + "  " + Quickshell.env("USER") + "  •  up " + root.uptime
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }

        RowLayout {
          spacing: 10

          Repeater {
            model: root.actions

            Rectangle {
              id: card
              required property var modelData
              required property int index

              readonly property bool selected: root.cursor === index
              readonly property bool confirming: root.confirming === index
              // Shut down stands out, as the one you least want by accident.
              readonly property bool loud: modelData.id === "shutdown"
              readonly property color ink: confirming || loud ? Theme.background : Theme.foreground

              implicitWidth: root.cardSize
              implicitHeight: root.cardSize
              radius: Theme.controlRadius + 4
              color: confirming || loud ? Theme.red : Theme.alpha(Theme.foreground, mouse.containsMouse ? 0.1 : 0.05)
              border.width: selected ? 2 : 1
              border.color: selected ? (confirming || loud ? Theme.brightForeground : Theme.accent) : Theme.alpha(Theme.foreground, 0.1)

              // Number to press, or Enter while confirming.
              Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                width: Math.max(16, badge.implicitWidth + 8)
                height: 16
                radius: 4
                color: Theme.alpha(card.confirming || card.loud ? Theme.background : Theme.foreground, 0.16)

                Label {
                  id: badge
                  anchors.centerIn: parent
                  text: card.confirming ? "↵" : String(card.index + 1)
                  color: card.ink
                  font.pixelSize: 10
                  font.bold: true
                  elide: Text.ElideNone
                }
              }

              Column {
                anchors.centerIn: parent
                spacing: 8

                Label {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Icons.glyph(card.modelData.icon)
                  color: card.ink
                  font.pixelSize: 26
                  elide: Text.ElideNone
                }
                Label {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: card.confirming ? "Confirm (" + Math.max(1, Math.ceil(root.confirmLeft * root.confirmSeconds)) + "s)" : card.modelData.label
                  color: card.ink
                  font.pixelSize: Theme.fontSmall
                  elide: Text.ElideNone
                }
              }

              // Time left to confirm.
              Rectangle {
                visible: card.confirming
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                width: parent.width - 24
                height: 3
                radius: 2
                color: Theme.alpha(Theme.background, 0.25)

                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1, root.confirmLeft))
                  height: parent.height
                  radius: parent.radius
                  color: Theme.background
                }
              }

              MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                  if (root.cursor !== card.index) root.cancelConfirm()
                  root.cursor = card.index
                }
                onClicked: root.trigger(card.index)
              }
            }
          }
        }
      }
    }
  }
}
