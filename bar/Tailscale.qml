import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme
import qs.ui

// Tailscale: on/off, the machines on the tailnet (click one to copy its
// address), and the exit node.
BarButton {
  id: root

  readonly property alias popup: popup
  // Address that was just copied, for a moment of feedback.
  property string copied: ""

  function copy(ip) {
    if (ip === "") return
    Tailscale.copy(ip)
    copied = ip
    copiedTimer.restart()
  }

  visible: Tailscale.available
  active: popup.open
  onClicked: function(button) {
    if (button === Qt.RightButton) Tailscale.toggle()
    else popup.toggle()
  }

  Timer {
    id: copiedTimer
    interval: 1200
    onTriggered: root.copied = ""
  }

  TailscaleIcon {
    anchors.centerIn: parent
    color: root.foreground
    off: !Tailscale.active
  }

  component Machine: Rectangle {
    id: machine
    property string name: ""
    property string ip: ""
    property bool online: true
    property string note: ""

    Layout.fillWidth: true
    implicitHeight: Theme.rowHeight
    radius: Theme.controlRadius
    color: mouse.containsMouse ? Theme.hover : "transparent"

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 6
      anchors.rightMargin: 6
      spacing: Theme.spacing

      Rectangle {
        implicitWidth: 6
        implicitHeight: 6
        radius: 3
        color: machine.online ? Theme.green : "transparent"
        border.width: machine.online ? 0 : 1
        border.color: Theme.dim
      }

      Label {
        text: machine.name
        color: machine.online ? Theme.foreground : Theme.dim
        Layout.fillWidth: true
      }

      Label {
        visible: machine.note !== ""
        text: machine.note
        color: Theme.accent
        font.pixelSize: Theme.fontSmall
        elide: Text.ElideNone
      }

      Label {
        text: root.copied === machine.ip && machine.ip !== "" ? "Copied" : machine.ip
        color: Theme.dim
        font.pixelSize: Theme.fontSmall
        elide: Text.ElideNone
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: root.copy(machine.ip)
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 320
    contentHeight: column.implicitHeight

    onOpenChanged: Tailscale.watching = open

    ColumnLayout {
      id: column
      width: parent.width
      spacing: Theme.spacing

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing

        Label { text: "Tailscale"; font.bold: true }
        Label { text: Tailscale.status; color: Theme.dim; Layout.fillWidth: true }
        Toggle {
          checked: Tailscale.active
          enabled: !Tailscale.busy
          onToggled: Tailscale.toggle()
        }
      }

      Label {
        visible: Tailscale.needsLogin
        text: "Flip the switch to log in from the browser."
        color: Theme.dim
        Layout.fillWidth: true
      }

      Label {
        visible: Tailscale.error !== ""
        text: Tailscale.error
        color: Theme.red
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
      }

      Rectangle {
        visible: Tailscale.needsOperator
        Layout.fillWidth: true
        implicitHeight: Theme.rowHeight
        radius: Theme.controlRadius
        color: authorizeMouse.containsMouse ? Theme.pressed : Theme.hover

        Label {
          anchors.centerIn: parent
          text: "Let this user control Tailscale"
        }

        MouseArea {
          id: authorizeMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: Tailscale.authorize()
        }
      }

      Separator { Layout.fillWidth: true; visible: Tailscale.running }

      Flickable {
        id: list
        visible: Tailscale.running
        Layout.fillWidth: true
        implicitHeight: Math.min(machines.implicitHeight, Theme.rowHeight * 10)
        contentHeight: machines.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: machines
          width: list.width
          spacing: 0

          Machine {
            name: Tailscale.selfName
            ip: Tailscale.selfIp
            note: "This device"
          }

          Repeater {
            model: Tailscale.peers

            Machine {
              required property var modelData
              name: modelData.name
              ip: modelData.ip
              online: modelData.online
              note: modelData.exitNode ? "Exit node" : ""
            }
          }
        }
      }

      SectionHeader {
        visible: exitNode.visible
        text: "EXIT NODE"
      }

      Select {
        id: exitNode
        visible: Tailscale.running && Tailscale.exitNodeOptions.length > 0
        Layout.fillWidth: true
        options: [{ label: "None", value: "" }].concat(Tailscale.exitNodeOptions.map(p => ({ label: p.name, value: p.ip })))
        current: Tailscale.exitNode ? Tailscale.exitNode.ip : ""
        onPicked: function(value) { Tailscale.setExitNode(value) }
      }

      SectionHeader {
        visible: account.visible
        text: "ACCOUNT"
      }

      Select {
        id: account
        visible: Tailscale.accounts.length > 1
        Layout.fillWidth: true
        options: Tailscale.accounts.map(a => ({ label: a.label, value: a.id }))
        current: (Tailscale.accounts.find(a => a.selected) ?? { id: "" }).id
        onPicked: function(value) { Tailscale.switchAccount(value) }
      }
    }
  }
}
