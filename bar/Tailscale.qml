import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme
import qs.ui

// Tailscale: on/off, the machines on the tailnet (click one to copy its
// address, or send it a file), and the exit node.
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

  function osGlyph(os) {
    var name = String(os || "").toLowerCase()
    if (name === "macos") return Icons.glyph(0xF0322)
    if (name === "ios" || name === "android") return Icons.glyph(0xF011C)
    if (name === "tvos") return Icons.glyph(0xF0502)
    if (name === "windows") return Icons.glyph(0xF05B3)
    if (name === "linux") return Icons.glyph(0xF033D)
    return Icons.glyph(0xF07C0)
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
    property string os: ""
    // Who owns it, for a machine shared in from someone else's tailnet.
    property string owner: ""
    property string note: ""
    // The peer, when files can be sent to it.
    property var sendTo: null

    Layout.fillWidth: true
    implicitHeight: owner !== "" ? Theme.rowHeight + 10 : Theme.rowHeight
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
        text: root.osGlyph(machine.os)
        color: machine.online ? Theme.foreground : Theme.dim
        font.pixelSize: Theme.iconSize
        horizontalAlignment: Text.AlignHCenter
        Layout.preferredWidth: 16
        elide: Text.ElideNone
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Label {
          text: machine.name
          color: machine.online ? Theme.foreground : Theme.dim
          Layout.fillWidth: true
        }
        Label {
          visible: machine.owner !== ""
          text: machine.owner
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          Layout.fillWidth: true
        }
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

      // Taildrop, offered on hover to machines that can take a file.
      Label {
        id: sendLabel
        visible: machine.sendTo !== null && mouse.containsMouse
        text: "Send file"
        color: Theme.accent
        font.pixelSize: Theme.fontSmall
        elide: Text.ElideNone
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: function(event) {
        // The right end of the row is the send button while it shows.
        if (sendLabel.visible && event.x >= sendLabel.mapToItem(machine, 0, 0).x - 6) {
          popup.close()
          Tailscale.sendFile(machine.sendTo)
        } else {
          root.copy(machine.ip)
        }
      }
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 340
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
        implicitHeight: Math.min(machines.implicitHeight, Theme.rowHeight * 12)
        contentHeight: machines.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: machines
          width: list.width
          spacing: 0

          SectionHeader { text: "MY DEVICES"; Layout.leftMargin: 6; Layout.topMargin: 2; Layout.bottomMargin: 2 }

          Machine {
            name: Tailscale.selfName
            ip: Tailscale.selfIp
            os: Tailscale.selfOs
            note: "This device"
          }

          Repeater {
            model: Tailscale.ownPeers

            Machine {
              required property var modelData
              name: modelData.name
              ip: modelData.ip
              os: modelData.os
              online: modelData.online
              note: modelData.exitNode ? "Exit node" : ""
              sendTo: modelData.taildrop ? modelData : null
            }
          }

          // Machines other people own and shared in. They are reachable, but
          // they are not on this tailnet, and Taildrop does not cross accounts.
          SectionHeader {
            visible: Tailscale.sharedPeers.length > 0
            text: "SHARED WITH ME · OTHER TAILNETS"
            Layout.leftMargin: 6
            Layout.topMargin: 10
            Layout.bottomMargin: 2
          }

          Repeater {
            model: Tailscale.sharedPeers

            Machine {
              required property var modelData
              name: modelData.name
              ip: modelData.ip
              os: modelData.os
              online: modelData.online
              owner: modelData.owner !== "" ? modelData.owner : "Someone else's machine"
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
