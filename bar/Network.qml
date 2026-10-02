import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme
import qs.ui

// Wi-Fi at a glance: a switch and the networks in range. Click one to join
// it; a network that needs a password asks for it right there.
BarButton {
  id: root

  readonly property alias popup: popup

  // Name of the network currently asking for a password.
  property string prompting: ""
  // Name of the network whose last attempt failed.
  property string failed: ""

  function join(net) {
    failed = ""
    if (net.connected) return
    if (net.known || !Net.isSecure(net)) {
      prompting = ""
      net.connect()
    } else {
      prompting = net.name
    }
  }

  text: Net.icon
  active: popup.open
  onClicked: popup.toggle()

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 300
    contentHeight: column.implicitHeight

    onOpenChanged: {
      Net.setScanning(open)
      if (!open) {
        root.prompting = ""
        root.failed = ""
      }
    }

    ColumnLayout {
      id: column
      width: parent.width
      spacing: Theme.spacing

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing

        Label { text: "Wi-Fi"; font.bold: true }
        Label { text: Net.status; color: Theme.dim; Layout.fillWidth: true }
        Toggle {
          visible: Net.wifiDevice !== null
          checked: Net.wifiEnabled
          onToggled: Net.setWifiEnabled(!Net.wifiEnabled)
        }
      }

      RowLayout {
        visible: Net.wiredDevice !== null
        Layout.fillWidth: true
        spacing: Theme.spacing

        Label { text: Icons.ethernet; font.pixelSize: Theme.iconSize; color: Theme.accent }
        Label { text: "Ethernet"; Layout.fillWidth: true }
        Label { text: "Connected"; color: Theme.dim }
      }

      Separator { Layout.fillWidth: true; visible: Net.wifiEnabled }

      Label {
        visible: Net.wifiEnabled && Net.networks.length === 0
        text: "Looking for networks…"
        color: Theme.dim
      }

      // A plain column in a flickable rather than a ListView: its height is
      // known before the popup shows, so the popup opens at its final size.
      Flickable {
        id: list
        visible: Net.networks.length > 0
        Layout.fillWidth: true
        implicitHeight: Math.min(rows.implicitHeight, Theme.rowHeight * 9)
        contentHeight: rows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: rows
          width: list.width
          spacing: 0

          Repeater {
            model: Net.networks

        ColumnLayout {
          id: entry
          required property var modelData

          readonly property bool prompting: root.prompting === modelData.name
          readonly property bool failed: root.failed === modelData.name

          Layout.fillWidth: true
          spacing: 4

          onPromptingChanged: if (prompting) password.focusInput()

          Connections {
            target: entry.modelData
            function onConnectionFailed(reason) {
              root.failed = entry.modelData.name
              // A saved password that stopped working needs typing again.
              if (Net.isSecure(entry.modelData)) root.prompting = entry.modelData.name
            }
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.rowHeight
            radius: Theme.controlRadius
            color: hover.hovered ? Theme.hover : "transparent"

            HoverHandler { id: hover }

            MouseArea {
              anchors.fill: parent
              onClicked: root.join(entry.modelData)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: Theme.spacing

              Label {
                text: Icons.wifi(entry.modelData.signalStrength)
                font.pixelSize: Theme.iconSize
                color: entry.modelData.connected ? Theme.accent : Theme.foreground
                elide: Text.ElideNone
              }

              Label {
                text: entry.modelData.name
                color: entry.modelData.connected ? Theme.accent : Theme.foreground
                Layout.fillWidth: true
              }

              // Resting state on the right; the action takes its place on hover.
              Label {
                visible: !action.visible
                elide: Text.ElideNone
                color: entry.failed ? Theme.red : Theme.dim
                font.pixelSize: text === Icons.lock ? Theme.iconSize : Theme.fontSmall
                text: entry.modelData.stateChanging ? "Connecting…"
                  : entry.failed ? "Failed"
                  : entry.modelData.connected ? "Connected"
                  : entry.modelData.known ? "Saved"
                  : Net.isSecure(entry.modelData) ? Icons.lock : ""
              }

              Label {
                id: action
                visible: hover.hovered && !entry.modelData.stateChanging && (entry.modelData.connected || entry.modelData.known)
                elide: Text.ElideNone
                color: actionMouse.containsMouse ? Theme.brightForeground : Theme.dim
                font.pixelSize: Theme.fontSmall
                text: entry.modelData.connected ? "Disconnect" : "Forget"

                MouseArea {
                  id: actionMouse
                  anchors.fill: parent
                  anchors.margins: -6
                  hoverEnabled: true
                  onClicked: {
                    if (entry.modelData.connected) entry.modelData.disconnect()
                    else entry.modelData.forget()
                  }
                }
              }
            }
          }

          Field {
            id: password
            visible: entry.prompting
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            placeholder: entry.failed ? "Try the password again" : "Password"
            password: true
            onAccepted: {
              if (text.length === 0) return
              root.failed = ""
              root.prompting = ""
              entry.modelData.connectWithPsk(text)
              text = ""
            }
            onCancelled: {
              text = ""
              root.prompting = ""
            }
          }
        }
          }
        }
      }
    }
  }
}
