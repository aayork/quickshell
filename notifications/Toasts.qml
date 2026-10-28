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

      Glass {
        id: card
        required property var modelData

        readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
        // Seconds on screen. Critical ones stay until dealt with.
        readonly property real lifetime: critical ? 0 : modelData.expireTimeout > 0 ? modelData.expireTimeout : 6
        readonly property string icon: Notifs.iconFor(modelData)
        // The sending app's own icon, for the caption.
        readonly property string appIcon: {
          var name = Notifs.appIconName(modelData)
          return name === "" ? "" : name.charAt(0) === "/" ? "file://" + name : Quickshell.iconPath(name, true)
        }

        Layout.fillWidth: true
        implicitHeight: caption.height + body.implicitHeight + 22 + (card.lifetime > 0 ? 8 : 0)
        border.color: critical ? Theme.red : Theme.glassBorder
        shineHeight: 0.25

        // Time left, 1 to 0, shown by the progress bar along the bottom. It
        // stands still while the pointer is on the toast.
        property real timeLeft: 1
        NumberAnimation on timeLeft {
          from: 1
          to: 0
          duration: card.lifetime * 1000
          running: card.lifetime > 0
          paused: running && hover.hovered
          onFinished: card.modelData.expire()
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

        // Caption strip, like a little Windows 7 title bar: app icon and
        // name, and a Vista close button.
        Item {
          id: caption
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 1
          height: 26

          Rectangle {
            anchors.fill: parent
            radius: Theme.radius - 1
            gradient: Gradient {
              GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.14) }
              GradientStop { position: 0.5; color: Theme.alpha("#ffffff", 0.05) }
              GradientStop { position: 0.51; color: Theme.alpha("#000000", 0.08) }
              GradientStop { position: 1; color: Theme.alpha("#000000", 0.02) }
            }
          }
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.alpha("#000000", 0.3)
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 4
            spacing: 6

            AppIcon {
              visible: card.appIcon !== ""
              source: card.appIcon
              Layout.preferredWidth: 14
              Layout.preferredHeight: 14
            }
            Label {
              text: card.modelData.appName || "Notification"
              color: Theme.foreground
              font.pixelSize: Theme.fontSmall
              font.bold: true
              style: Text.Raised
              styleColor: Theme.alpha("#000000", 0.4)
              Layout.fillWidth: true
            }

            // Vista close button: glass at rest, red gel under the pointer.
            Item {
              Layout.preferredWidth: 30
              Layout.preferredHeight: 18
              VistaFace {
                anchors.fill: parent
                visible: !closeMouse.containsMouse
                opacity: hover.hovered ? 1 : 0.6
              }
              Gel {
                anchors.fill: parent
                radius: 3
                base: "#d23a2e"
                visible: closeMouse.containsMouse
              }
              Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(0xF0156)
                color: "#ffffff"
                font.family: Theme.iconFamily
                font.pixelSize: 11
                style: Text.Raised
                styleColor: Theme.alpha("#000000", 0.4)
              }
              MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.modelData.dismiss()
              }
            }
          }
        }

        RowLayout {
          id: body
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: caption.bottom
          anchors.margins: 12
          spacing: 12

          // The picture stands free with a shadow, like a Vista icon.
          AppIcon {
            visible: card.icon !== ""
            source: card.icon
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignTop
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
              text: Notifs.plain(card.modelData.summary)
              font.bold: true
              font.pixelSize: Theme.fontLarge
              color: Theme.brightForeground
              style: Text.Raised
              styleColor: Theme.alpha("#000000", 0.4)
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

        // A Vista progress bar: time left before the toast goes.
        Rectangle {
          visible: card.lifetime > 0
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: 10
          anchors.bottomMargin: 8
          height: 5
          radius: 2.5
          color: Theme.alpha("#000000", 0.35)
          border.width: 1
          border.color: Theme.alpha("#000000", 0.4)
          Gel {
            height: parent.height
            width: Math.max(height, parent.width * card.timeLeft)
            base: card.critical ? Theme.red : Theme.green
          }
        }
      }
    }
  }
}
