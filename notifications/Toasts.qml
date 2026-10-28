import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui

// Notifications as they arrive, stacked under the bar's right end on the
// monitor that has focus.
PanelWindow {
  id: root

  readonly property int cardWidth: 360

  screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
  visible: Notifs.toasts.length > 0 && !Session.screensaver
  anchors { top: true; right: true }
  margins { top: Theme.popupGap; right: Theme.popupGap }
  implicitWidth: cardWidth
  implicitHeight: Math.max(1, stack.implicitHeight)
  color: "transparent"
  exclusionMode: ExclusionMode.Normal
  WlrLayershell.namespace: "aayork-notifications"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  ColumnLayout {
    id: stack
    width: parent.width
    spacing: 6

    Repeater {
      model: Notifs.toasts

      Rectangle {
        id: card
        required property var modelData

        readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
        // Seconds on screen. Critical ones stay until dealt with.
        readonly property real lifetime: critical ? 0 : modelData.expireTimeout > 0 ? modelData.expireTimeout : 6
        readonly property string icon: Notifs.iconFor(modelData)

        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 24
        color: Theme.background
        border.width: Theme.borderWidth
        border.color: critical ? Theme.red : Theme.accent
        radius: Theme.radius

        Timer {
          interval: card.lifetime * 1000
          running: card.lifetime > 0 && !hover.hovered
          onTriggered: card.modelData.expire()
        }

        HoverHandler { id: hover }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: function(event) {
            // Left click opens whatever the app made the default; either
            // button puts the toast away.
            if (event.button === Qt.LeftButton) {
              var action = card.modelData.actions.find(a => a.identifier === "default")
              if (action) action.invoke()
            }
            card.modelData.dismiss()
          }
        }

        RowLayout {
          id: body
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 12
          spacing: 10

          NotificationIcon {
            visible: card.icon !== ""
            source: card.icon
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignTop
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
              visible: text !== ""
              text: card.modelData.appName
              color: Theme.dim
              font.pixelSize: Theme.fontSmall
              Layout.fillWidth: true
            }
            Label {
              text: Notifs.plain(card.modelData.summary)
              font.bold: true
              wrapMode: Text.Wrap
              maximumLineCount: 2
              Layout.fillWidth: true
            }
            Label {
              visible: text !== ""
              text: Notifs.plain(card.modelData.body)
              wrapMode: Text.Wrap
              maximumLineCount: 5
              Layout.fillWidth: true
            }

            Flow {
              visible: actions.count > 0
              Layout.fillWidth: true
              Layout.topMargin: 6
              spacing: 6

              Repeater {
                id: actions
                model: card.modelData.actions.filter(a => a.identifier !== "default")

                TextButton {
                  required property var modelData
                  text: modelData.text
                  onClicked: modelData.invoke()
                }
              }
            }
          }
        }
      }
    }
  }
}
