import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme

// Wi-Fi: a switch and the networks in range. Click one to join it; a network
// that needs a password asks for it right there. Used by the bar's popup and
// by Settings.
ColumnLayout {
  id: root

  // Scan for networks. Set while the panel is on screen.
  property bool active: false
  property int maxRows: 9

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

  spacing: Theme.spacing
  onActiveChanged: {
    Net.setScanning(active)
    Net.detailsWanted = active
    if (!active) {
      prompting = ""
      failed = ""
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Theme.spacing

    Label { text: "Wi-Fi"; font.bold: true }
    Label { text: Net.wifiStatus; color: Theme.dim; Layout.fillWidth: true }
    Toggle {
      visible: Net.wifiDevice !== null
      checked: Net.wifiEnabled
      onToggled: Net.setWifiEnabled(!Net.wifiEnabled)
    }
  }

  // Ethernet, while a cable is in: its state, and connect/disconnect on hover.
  Rectangle {
    visible: Net.wiredPort !== null
    Layout.fillWidth: true
    implicitHeight: Theme.rowHeight
    radius: Theme.controlRadius
    color: wiredHover.hovered ? Theme.hover : "transparent"

    HoverHandler { id: wiredHover }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 6
      anchors.rightMargin: 6
      spacing: Theme.spacing

      Label {
        text: Icons.ethernet
        font.pixelSize: Theme.iconSize
        color: Net.wiredDevice ? Theme.accent : Theme.foreground
        elide: Text.ElideNone
      }
      Label {
        text: "Ethernet"
        color: Net.wiredDevice ? Theme.accent : Theme.foreground
        Layout.fillWidth: true
      }
      Label {
        visible: !wiredAction.visible
        text: Net.wiredStatus
        color: Theme.dim
        font.pixelSize: Theme.fontSmall
        elide: Text.ElideNone
      }
      Label {
        id: wiredAction
        visible: wiredHover.hovered && !Net.wiredChanging
        text: Net.wiredDevice ? "Disconnect" : "Connect"
        color: wiredMouse.containsMouse ? Theme.brightForeground : Theme.dim
        font.pixelSize: Theme.fontSmall
        elide: Text.ElideNone

        MouseArea {
          id: wiredMouse
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          onClicked: Net.wiredDevice ? Net.disconnectWired() : Net.connectWired()
        }
      }
    }
  }

  // The connection in use, macOS Option-click style: live traffic with a
  // graph, then the link and addresses. Click a value to copy it.
  ColumnLayout {
    id: details
    readonly property var info: Net.details
    readonly property bool wifi: info.dbm !== undefined
    visible: Net.detailsIface !== "" && info.iface === Net.detailsIface
    Layout.fillWidth: true
    Layout.leftMargin: 6
    Layout.rightMargin: 6
    Layout.topMargin: 4
    spacing: 2

    // Down (accent) and up (dim) over the last minute, on one scale.
    Item {
      Layout.fillWidth: true
      implicitHeight: 34

      Canvas {
        id: graph
        anchors.fill: parent
        readonly property var down: Net.downHistory
        readonly property var up: Net.upHistory
        onDownChanged: requestPaint()
        onWidthChanged: requestPaint()

        function line(context, values, top, color, fill) {
          if (values.length < 2) return
          var step = width / (Net.historyLength - 1)
          var x0 = width - (values.length - 1) * step
          context.beginPath()
          context.moveTo(x0, height)
          for (var i = 0; i < values.length; i++)
            context.lineTo(x0 + i * step, height - 2 - (height - 4) * values[i] / top)
          context.lineTo(width, height)
          context.closePath()
          context.fillStyle = Theme.alpha(color, fill)
          context.fill()
        }

        onPaint: {
          var context = getContext("2d")
          context.reset()
          var top = 1024
          for (var i = 0; i < down.length; i++) top = Math.max(top, down[i], up[i] || 0)
          line(context, down, top, Theme.accent, 0.35)
          line(context, up, top, Theme.foreground, 0.2)
        }
      }

      Row {
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 10
        Label { text: "↓ " + Net.formatRate(Net.downRate); font.pixelSize: Theme.fontSmall; color: Theme.accent }
        Label { text: "↑ " + Net.formatRate(Net.upRate); font.pixelSize: Theme.fontSmall; color: Theme.dim }
      }
    }

    Repeater {
      model: {
        var d = details.info, rows = []
        if (details.wifi) {
          rows.push(["Signal", d.dbm + " dBm · " + Net.signalWord(d.dbm)])
          var radio = [d.band, d.channel ? "Ch " + d.channel : "", d.width ? d.width + " MHz" : ""]
          rows.push(["Band", radio.filter(x => x).join(" · ")])
          if (d.standard) rows.push(["Standard", d.standard])
          if (d.rxRate) rows.push(["Link rate", "↓ " + Math.round(d.rxRate) + " · ↑ " + Math.round(d.txRate || 0) + " Mb/s"])
          if (d.security) rows.push(["Security", d.security])
        } else if (d.linkSpeed) {
          rows.push(["Link rate", d.linkSpeed >= 1000 ? (d.linkSpeed / 1000) + " Gb/s" : d.linkSpeed + " Mb/s"])
        }
        if (d.ip4) rows.push(["IP address", d.ip4])
        if (d.gateway) rows.push(["Router", d.gateway + (d.latency !== undefined && d.latency !== null ? " · " + Math.round(d.latency) + " ms" : "")])
        if (d.dns && d.dns.length) rows.push(["DNS", d.dns.join(", ")])
        if (d.ip6) rows.push(["IPv6", d.ip6])
        if (d.mac) rows.push(["MAC", d.mac])
        return rows
      }

      RowLayout {
        id: stat
        required property var modelData
        Layout.fillWidth: true
        spacing: Theme.spacing

        Label {
          text: stat.modelData[0]
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          Layout.preferredWidth: 70
        }
        Label {
          id: value
          // Copy just the address, not the ping time after it.
          readonly property string copyText: stat.modelData[1].split(" · ")[0]
          text: copied.running ? "Copied" : stat.modelData[1]
          color: valueMouse.containsMouse ? Theme.brightForeground : Theme.foreground
          font.pixelSize: Theme.fontSmall
          horizontalAlignment: Text.AlignRight
          Layout.fillWidth: true

          Timer { id: copied; interval: 900 }

          MouseArea {
            id: valueMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              Quickshell.execDetached(["wl-copy", "--", value.copyText])
              copied.restart()
            }
          }
        }
      }
    }
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
    implicitHeight: Math.min(rows.implicitHeight, Theme.rowHeight * root.maxRows)
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
