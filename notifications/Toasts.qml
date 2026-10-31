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

      // The slot holds the card's place in the stack; the card itself
      // slides sideways inside it when swiped.
      Item {
        id: slot
        required property var modelData

        Layout.fillWidth: true
        implicitHeight: card.implicitHeight
        clip: false

        Rectangle {
          id: card
          readonly property var modelData: slot.modelData

          readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
          // Seconds on screen. Critical ones stay until dealt with.
          readonly property real lifetime: critical ? 0 : modelData.expireTimeout > 0 ? modelData.expireTimeout : 6
          readonly property string icon: Notifs.iconFor(modelData)
          readonly property var defaultAction: modelData.actions.find(a => a.identifier === "default") ?? null
          // How far a swipe has to go before letting go throws the card away.
          readonly property real throwDistance: width * 0.3
          property bool leaving: false
          property bool swiping: false

          width: slot.width
          implicitHeight: body.implicitHeight + 24
          opacity: 1 - Math.min(0.8, Math.abs(x) / width)
          color: Theme.background
          border.width: Theme.borderWidth
          border.color: critical ? Theme.red : Theme.accent
          radius: Theme.radius

          Behavior on x {
            enabled: !card.swiping
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
          }

          // Ends a swipe: far enough (or flicked) goes away, otherwise it
          // springs back.
          function settle(velocity) {
            swiping = false
            if (Math.abs(x) > throwDistance || Math.abs(velocity) > 1.2) throwAway(x !== 0 ? x : velocity)
            else x = 0
          }

          function throwAway(direction) {
            if (leaving) return
            leaving = true
            x = direction < 0 ? -width : width
            gone.start()
          }

          Timer {
            id: gone
            interval: 180
            onTriggered: card.modelData.dismiss()
          }

          Timer {
            interval: card.lifetime * 1000
            running: card.lifetime > 0 && !hover.hovered && !card.swiping && !card.leaving
            onTriggered: card.modelData.expire()
          }

          // Two-finger touchpad swipes come in as horizontal scrolling; the
          // card settles once the fingers stop.
          Timer {
            id: wheelSettle
            interval: 160
            onTriggered: card.settle(0)
          }

          HoverHandler { id: hover }

          MouseArea {
            id: mouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
            drag.target: card.leaving ? null : card
            drag.axis: Drag.XAxis
            drag.minimumX: -card.width
            drag.maximumX: card.width
            drag.threshold: 6

            property real lastX: 0
            property real lastTime: 0
            property real velocity: 0
            property bool dragged: false

            onPressed: function(event) {
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
            onReleased: {
              if (dragged) card.settle(velocity)
            }
            onClicked: function(event) {
              if (dragged || card.leaving) return
              // Middle click puts it away; left click opens whatever the app
              // made the default and leaves the toast alone otherwise.
              if (event.button === Qt.MiddleButton) card.throwAway(1)
              else if (card.defaultAction) card.defaultAction.invoke()
            }
            onWheel: function(wheel) {
              var dx = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.angleDelta.x / 4
              if (dx === 0 || Math.abs(wheel.angleDelta.y) > Math.abs(wheel.angleDelta.x) || card.leaving) {
                wheel.accepted = false
                return
              }
              if (wheel.inverted) dx = -dx
              card.swiping = true
              card.x = Math.max(-card.width, Math.min(card.width, card.x - dx))
              wheelSettle.restart()
            }
          }

          // Close button, top right, shown while the pointer is over the card.
          Rectangle {
            id: closeButton
            z: 2
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            width: 20
            height: 20
            visible: opacity > 0
            opacity: hover.hovered && !card.swiping ? 1 : 0
            color: "transparent"

            Behavior on opacity { NumberAnimation { duration: 120 } }

            Label {
              anchors.centerIn: parent
              text: Icons.close
              color: closeMouse.containsMouse ? Theme.foreground : Theme.dim
              font.pixelSize: 13
              elide: Text.ElideNone
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: card.throwAway(1)
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
                Layout.rightMargin: 22
                color: Theme.dim
                font.pixelSize: Theme.fontSmall
                Layout.fillWidth: true
              }
              Label {
                text: Notifs.plain(card.modelData.summary)
                Layout.rightMargin: card.modelData.appName === "" ? 22 : 0
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
}
