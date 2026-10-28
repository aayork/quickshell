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
    size: 11
    color: root.foreground
    off: !Tailscale.active
  }

  // One machine: its kind in a tile with an online dot, name over address,
  // and copy / send buttons while the pointer is on it.
  component Machine: Rectangle {
    id: machine
    property string name: ""
    property string ip: ""
    property bool online: true
    property string os: ""
    // Who owns it, for a machine shared in from someone else's tailnet.
    property string owner: ""
    property string note: ""
    property bool self: false
    // The peer, when files can be sent to it.
    property var sendTo: null

    readonly property bool hovered: mouse.containsMouse || copyMouse.containsMouse || sendMouse.containsMouse

    Layout.fillWidth: true
    implicitHeight: 42
    radius: Theme.controlRadius + 3
    color: machine.self ? Theme.alpha(Theme.accent, hovered ? 0.16 : 0.1) : hovered ? Theme.hover : "transparent"

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: root.copy(machine.ip)
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 6
      anchors.rightMargin: 8
      spacing: 10

      // Kind of machine, with the online dot on the tile's corner.
      Rectangle {
        implicitWidth: 30
        implicitHeight: 30
        radius: Theme.controlRadius + 4
        color: machine.self ? Theme.alpha(Theme.accent, 0.2) : Theme.alpha(Theme.foreground, machine.online ? 0.08 : 0.04)

        Label {
          anchors.centerIn: parent
          text: root.osGlyph(machine.os)
          color: machine.self ? Theme.accent : machine.online ? Theme.foreground : Theme.muted
          font.pixelSize: Theme.iconSize + 1
          elide: Text.ElideNone
        }

        Rectangle {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: -2
          width: 10
          height: 10
          radius: 5
          color: machine.online ? Theme.green : Theme.muted
          border.width: 2
          border.color: Theme.background
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        Label {
          text: machine.name
          color: machine.online ? Theme.foreground : Theme.dim
          font.bold: machine.self
          Layout.fillWidth: true
        }
        Label {
          readonly property bool justCopied: root.copied === machine.ip && machine.ip !== ""
          text: justCopied ? "Copied " + machine.ip
            : [machine.owner, machine.ip, machine.online || machine.self ? "" : "offline"].filter(t => t !== "").join(" · ")
          color: justCopied ? Theme.accent : Theme.dim
          font.pixelSize: Theme.fontSmall
          Layout.fillWidth: true
        }
      }

      // A tag such as "This device" or "Exit node".
      Rectangle {
        visible: machine.note !== "" && !machine.hovered
        implicitWidth: noteLabel.implicitWidth + 12
        implicitHeight: 18
        radius: 9
        color: Theme.alpha(Theme.accent, 0.15)

        Label {
          id: noteLabel
          anchors.centerIn: parent
          text: machine.note
          color: Theme.accent
          font.pixelSize: Theme.fontSmall - 1
          elide: Text.ElideNone
        }
      }

      // Copy the address; send a file over Taildrop when it can take one.
      Label {
        visible: machine.hovered && machine.ip !== ""
        text: Icons.glyph(0xF018F)
        color: copyMouse.containsMouse ? Theme.foreground : Theme.dim
        font.pixelSize: Theme.iconSize
        elide: Text.ElideNone
        MouseArea {
          id: copyMouse
          anchors.fill: parent
          anchors.margins: -5
          hoverEnabled: true
          onClicked: root.copy(machine.ip)
        }
      }
      Label {
        visible: machine.hovered && machine.sendTo !== null
        text: Icons.glyph(0xF048A)
        color: sendMouse.containsMouse ? Theme.accent : Theme.dim
        font.pixelSize: Theme.iconSize
        elide: Text.ElideNone
        MouseArea {
          id: sendMouse
          anchors.fill: parent
          anchors.margins: -5
          hoverEnabled: true
          onClicked: {
            popup.close()
            Tailscale.sendFile(machine.sendTo)
          }
        }
      }
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 360
    contentHeight: column.implicitHeight

    onOpenChanged: Tailscale.watching = open

    ColumnLayout {
      id: column
      width: parent.width
      spacing: Theme.spacing

      // Logo, name and state, and the switch.
      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
          implicitWidth: 34
          implicitHeight: 34
          radius: Theme.controlRadius + 5
          color: Tailscale.active ? Theme.alpha(Theme.accent, 0.18) : Theme.alpha(Theme.foreground, 0.06)

          TailscaleIcon {
            anchors.centerIn: parent
            size: 16
            color: Tailscale.active ? Theme.accent : Theme.dim
            off: !Tailscale.active
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Label { text: "Tailscale"; font.bold: true; font.pixelSize: Theme.fontLarge; Layout.fillWidth: true }
          RowLayout {
            spacing: 5
            Rectangle {
              implicitWidth: 6
              implicitHeight: 6
              radius: 3
              color: Tailscale.running ? Theme.green : Tailscale.needsLogin ? Theme.yellow : Theme.muted
            }
            Label {
              text: Tailscale.busy ? "Working…" : Tailscale.running ? "Connected" + (Tailscale.tailnet !== "" ? " · " + Tailscale.tailnet : "") : Tailscale.status
              color: Theme.dim
              font.pixelSize: Theme.fontSmall
            }
          }
        }

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
        implicitHeight: Math.min(machines.implicitHeight, 42 * 9)
        contentHeight: machines.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: machines
          width: list.width
          spacing: 2

          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 8
            Layout.topMargin: 2
            Layout.bottomMargin: 4
            SectionHeader { text: "MY DEVICES"; Layout.fillWidth: true }
            Label {
              text: (Tailscale.ownPeers.filter(p => p.online).length + 1) + " of " + (Tailscale.ownPeers.length + 1) + " online"
              color: Theme.muted
              font.pixelSize: Theme.fontSmall
              elide: Text.ElideNone
            }
          }

          Machine {
            name: Tailscale.selfName
            ip: Tailscale.selfIp
            os: Tailscale.selfOs
            note: "This device"
            self: true
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
            Layout.topMargin: 12
            Layout.bottomMargin: 4
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
