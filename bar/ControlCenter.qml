import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.theme
import qs.ui

// Quick settings: now playing, output and input volume, and the Wi-Fi and
// Bluetooth switches. Scroll on the button changes the volume, right click
// mutes.
BarButton {
  id: root

  readonly property alias popup: popup

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool bluetoothOn: adapter !== null && adapter.enabled
  readonly property var pairedDevices: Bluetooth.devices.values.filter(d => d.paired || d.connected)
  readonly property var connectedDevices: pairedDevices.filter(d => d.connected)
  property bool showDevices: false

  // The two-switch icon is its own one-glyph font (assets/build-glyph.py), so
  // the text renderer pixel-snaps it like the Nerd Font icons beside it.
  FontLoader {
    id: glyphFont
    source: Qt.resolvedUrl("../assets/control-center.otf")
  }

  text: ""
  fontFamily: glyphFont.name
  fontSize: 13
  active: popup.open

  onClicked: function(button) {
    if (button === Qt.RightButton) Audio.toggleMute(Audio.sink)
    else popup.toggle()
  }
  onScrolled: function(delta) {
    Audio.setVolume(Audio.sink, Audio.volume(Audio.sink) + (delta > 0 ? 0.05 : -0.05))
  }

  component Volume: ColumnLayout {
    id: section
    property string title: ""
    property var node: null
    property var devices: []
    property bool input: false
    signal devicePicked(var node)

    readonly property bool muted: Audio.muted(node)
    readonly property real level: Audio.volume(node)

    Layout.fillWidth: true
    spacing: 6

    SectionHeader { text: section.title }

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacing

      IconButton {
        icon: section.input
          ? (section.muted ? Icons.microphoneOff : Icons.microphone)
          : Icons.volume(section.level, section.muted)
        foreground: section.muted ? Theme.dim : Theme.foreground
        enabled: section.node !== null
        onClicked: Audio.toggleMute(section.node)
      }

      Slider {
        Layout.fillWidth: true
        value: section.level
        opacity: section.muted ? 0.5 : 1
        enabled: section.node !== null
        onMoved: function(value) { Audio.setVolume(section.node, value) }
      }

      Label {
        text: Math.round(section.level * 100) + "%"
        color: section.muted ? Theme.dim : Theme.foreground
        font.pixelSize: Theme.fontSmall
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 34
      }
    }

    Select {
      Layout.fillWidth: true
      visible: section.devices.length > 0
      options: section.devices.map(n => ({ label: Audio.label(n), value: n.id }))
      current: section.node ? section.node.id : null
      onPicked: function(value) {
        var node = section.devices.find(n => n.id === value)
        if (node) section.devicePicked(node)
      }
    }
  }

  // Icon, name over status, and a switch.
  component SwitchRow: RowLayout {
    id: row
    property string icon: ""
    property string title: ""
    property string status: ""
    property bool available: true
    property bool checked: false
    property bool expandable: false
    property bool expanded: false
    signal toggled()
    signal expandClicked()

    Layout.fillWidth: true
    spacing: 10

    Label {
      text: row.icon
      font.pixelSize: Theme.iconSize
      horizontalAlignment: Text.AlignHCenter
      Layout.preferredWidth: 22
      elide: Text.ElideNone
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      Label { text: row.title; Layout.fillWidth: true }
      Label { text: row.status; color: Theme.dim; font.pixelSize: Theme.fontSmall; Layout.fillWidth: true }
    }

    Toggle {
      visible: row.available
      checked: row.checked
      onToggled: row.toggled()
    }

    IconButton {
      visible: row.expandable
      icon: row.expanded ? Icons.chevronDown : Icons.chevronRight
      onClicked: row.expandClicked()
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 340
    contentHeight: column.implicitHeight

    onOpenChanged: {
      if (open) Media.refreshPosition()
      else root.showDevices = false
    }

    Timer {
      interval: 1000
      repeat: true
      running: popup.open && Media.hasProgress && Media.playing
      onTriggered: Media.refreshPosition()
    }

    ColumnLayout {
      id: column
      width: parent.width
      spacing: 12

      SectionHeader { text: "NOW PLAYING" }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
          Layout.preferredWidth: 52
          Layout.preferredHeight: 52
          radius: Theme.controlRadius
          color: Theme.alpha(Theme.foreground, 0.04)
          border.width: 1
          border.color: Theme.alpha(Theme.foreground, 0.2)

          Image {
            id: art
            anchors.fill: parent
            anchors.margins: 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: Media.artUrl
            visible: status === Image.Ready
          }

          Label {
            anchors.centerIn: parent
            visible: !art.visible
            text: Icons.music
            color: Media.hasMedia ? Theme.foreground : Theme.dim
            font.pixelSize: Theme.iconLarge
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Label {
            text: Media.hasMedia ? Media.title : "Nothing playing"
            color: Media.hasMedia ? Theme.foreground : Theme.dim
            font.bold: Media.hasMedia
            Layout.fillWidth: true
          }
          Label {
            visible: text !== ""
            text: Media.hasMedia ? Media.artist : ""
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            Layout.fillWidth: true
          }
        }

        IconButton {
          icon: Icons.previous
          enabled: Media.player !== null && Media.player.canGoPrevious
          onClicked: Media.previous()
        }
        IconButton {
          icon: Media.playing ? Icons.pause : Icons.play
          size: Theme.iconLarge
          enabled: Media.player !== null && Media.player.canTogglePlaying
          onClicked: Media.toggle()
        }
        IconButton {
          icon: Icons.next
          enabled: Media.player !== null && Media.player.canGoNext
          onClicked: Media.next()
        }
      }

      Rectangle {
        visible: Media.hasProgress
        Layout.fillWidth: true
        implicitHeight: 3
        color: Theme.track

        Rectangle {
          height: parent.height
          width: parent.width * Media.progress
          color: Theme.accent
          Behavior on width { NumberAnimation { duration: 250 } }
        }
      }

      Separator { Layout.fillWidth: true }

      Volume {
        title: "OUTPUT"
        node: Audio.sink
        devices: Audio.sinks
        onDevicePicked: function(node) { Audio.setDefaultSink(node) }
      }

      Volume {
        title: "INPUT"
        input: true
        node: Audio.source
        devices: Audio.sources
        onDevicePicked: function(node) { Audio.setDefaultSource(node) }
      }

      Separator { Layout.fillWidth: true }

      SwitchRow {
        icon: Net.icon
        title: "Network"
        status: Net.status
        available: Net.wifiDevice !== null
        checked: Net.wifiEnabled
        onToggled: Net.setWifiEnabled(!Net.wifiEnabled)
      }

      SwitchRow {
        icon: !root.bluetoothOn ? Icons.bluetoothOff
          : root.connectedDevices.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth
        title: "Bluetooth"
        status: !root.adapter ? "Unavailable"
          : !root.bluetoothOn ? "Off"
          : root.connectedDevices.length > 0 ? root.connectedDevices.map(d => d.name).join(", ")
          : "On"
        available: root.adapter !== null
        checked: root.bluetoothOn
        expandable: root.bluetoothOn && root.pairedDevices.length > 0
        expanded: root.showDevices
        onToggled: root.adapter.enabled = !root.adapter.enabled
        onExpandClicked: root.showDevices = !root.showDevices
      }

      ColumnLayout {
        visible: root.showDevices && root.bluetoothOn
        Layout.fillWidth: true
        Layout.leftMargin: 32
        spacing: 0

        Repeater {
          model: root.showDevices ? root.pairedDevices : []

          Rectangle {
            id: device
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: Theme.rowHeight
            radius: Theme.controlRadius
            color: deviceMouse.containsMouse ? Theme.hover : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: Theme.spacing

              Label {
                text: device.modelData.name
                color: device.modelData.connected ? Theme.accent : Theme.foreground
                Layout.fillWidth: true
              }
              Label {
                visible: device.modelData.connected && device.modelData.batteryAvailable
                text: Math.round(device.modelData.battery * 100) + "%"
                color: Theme.dim
                font.pixelSize: Theme.fontSmall
              }
              Label {
                text: device.modelData.pairing ? "Pairing…"
                  : device.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                  : device.modelData.connected ? (deviceMouse.containsMouse ? "Disconnect" : "Connected")
                  : (deviceMouse.containsMouse ? "Connect" : "")
                color: Theme.dim
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideNone
              }
            }

            MouseArea {
              id: deviceMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                if (device.modelData.connected) device.modelData.disconnect()
                else device.modelData.connect()
              }
            }
          }
        }
      }
    }
  }
}
