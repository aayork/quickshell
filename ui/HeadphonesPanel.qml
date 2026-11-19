import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.services
import qs.theme

// Everything headphones in one place: what is playing and how loud, the
// headset microphone, the controls of Bose and AirPods that are connected,
// and every output to switch to: Bluetooth headphones (connecting them if
// need be), a jack with headphones in it, USB, speakers and screens.
ColumnLayout {
  id: root

  // Set while the panel is on screen: polls jacks and device state.
  property bool active: false

  readonly property var sink: Audio.sink
  readonly property string sinkKind: Headphones.kind(sink)
  // The Bluetooth headphones playing right now, if they are.
  readonly property var sinkDevice: Headphones.bluetoothDevices.find(d => Headphones.isDefault(Headphones.bluetoothSink(d))) ?? null
  readonly property var sinkCard: Headphones.bluetoothCard(sinkDevice)
  readonly property bool sinkIsAirPods: sinkDevice !== null && AirPods.connected && AirPods.info.address === sinkDevice.address.toUpperCase()
  readonly property bool sinkIsBose: sinkDevice !== null && Bose.connected && Bose.info.address === sinkDevice.address.toUpperCase()

  readonly property bool showBose: Config.features.bose && Bose.connected
  readonly property bool showAirPods: AirPods.connected

  spacing: 10

  onActiveChanged: {
    Headphones.watching = active
    Bose.watching = active && Bose.connected
  }

  function glyph(kind) {
    if (kind === "bluetooth") return "\u{F02CB}"
    if (kind === "headphones") return "\u{F02CB}"
    if (kind === "usb") return "\u{F0553}"
    if (kind === "hdmi") return "\u{F0379}"
    return "\u{F04C3}"
  }

  function kindLabel(kind) {
    return { bluetooth: "Bluetooth", headphones: "Headphone jack", usb: "USB", hdmi: "Screen", speakers: "Speakers" }[kind]
  }

  function sinkLabel(node) {
    if (Headphones.kind(node) === "headphones") return "Headphones"
    return node.nickname || Audio.label(node)
  }

  // Battery of a Bluetooth device, from whichever source knows it.
  function batteryOf(device) {
    if (!device) return -1
    var address = device.address.toUpperCase()
    if (Bose.connected && Bose.info && Bose.info.address === address && Bose.battery >= 0) return Bose.battery
    if (device.batteryAvailable) return Math.round(device.battery * 100)
    return -1
  }

  // Every output, playing or ready to be: sinks, then plugged jacks whose
  // card is off, then paired headphones that are not connected.
  readonly property var outputs: {
    var list = []
    for (var node of Audio.sinks) {
      var kind = Headphones.kind(node)
      var device = kind === "bluetooth" ? Headphones.bluetoothDevices.find(d => Headphones.bluetoothSink(d) === node) ?? null : null
      list.push({ key: "sink:" + node.id, kind: kind, label: sinkLabel(node), node: node, device: device, current: Headphones.isDefault(node) })
    }
    for (var jack of Headphones.jacks)
      if (!jack.active) list.push({ key: "jack:" + jack.card + jack.port, kind: "headphones", label: "Headphones", detail: jack.device, jack: jack })
    for (var d of Headphones.bluetoothDevices)
      if (!d.connected) list.push({ key: "bt:" + d.address, kind: "bluetooth", label: d.name, detail: "Not connected", device: d, connect: true })
    // Headphones first, then the rest.
    var rank = { bluetooth: 0, headphones: 0, usb: 1, speakers: 2, hdmi: 3 }
    return list.sort((a, b) => (b.current === true) - (a.current === true) || rank[a.kind] - rank[b.kind])
  }

  // ---- what is playing
  RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Label {
      text: root.glyph(root.sinkKind)
      color: Theme.accent
      font.pixelSize: Theme.iconLarge
      elide: Text.ElideNone
      Layout.preferredWidth: 22
      horizontalAlignment: Text.AlignHCenter
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 1

      Label {
        text: root.sink ? root.sinkLabel(root.sink) : "No output"
        font.bold: true
        Layout.fillWidth: true
      }
      Label {
        text: {
          var parts = [root.kindLabel(root.sinkKind)]
          if (root.sinkIsAirPods && AirPods.model !== "") parts = [AirPods.model]
          if (root.sinkCard && root.sinkCard.codec !== "") parts.push(root.sinkCard.call ? "Headset mode" : root.sinkCard.codec)
          if (Bose.multipoint && root.sinkIsBose) parts.push("Multipoint")
          return parts.join(" · ")
        }
        color: Theme.dim
        font.pixelSize: Theme.fontSmall
        Layout.fillWidth: true
      }
    }

    // AirPods show each pod's battery below instead.
    BatteryGauge {
      visible: root.batteryOf(root.sinkDevice) >= 0 && !root.sinkIsAirPods
      Layout.alignment: Qt.AlignVCenter
      level: root.batteryOf(root.sinkDevice)
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Theme.spacing

    IconButton {
      icon: Icons.volume(Audio.volume(root.sink), Audio.muted(root.sink))
      foreground: Audio.muted(root.sink) ? Theme.dim : Theme.foreground
      enabled: root.sink !== null
      onClicked: Audio.toggleMute(root.sink)
    }
    Slider {
      Layout.fillWidth: true
      value: Audio.volume(root.sink)
      opacity: Audio.muted(root.sink) ? 0.5 : 1
      enabled: root.sink !== null
      onMoved: function(value) { Audio.setVolume(root.sink, value) }
    }
    Label {
      text: Math.round(Audio.volume(root.sink) * 100) + "%"
      color: Audio.muted(root.sink) ? Theme.dim : Theme.foreground
      font.pixelSize: Theme.fontSmall
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: 34
    }
  }

  // Bluetooth headphones play in high quality or, with their microphone on,
  // in the lower quality headset mode; it is one or the other.
  RowLayout {
    visible: root.sinkCard !== null && root.sinkCard.canCall && root.sinkCard.canMusic
    Layout.fillWidth: true
    spacing: Theme.spacing

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 1
      Label { text: "Headset microphone"; Layout.fillWidth: true }
      Label {
        text: root.sinkCard && root.sinkCard.call ? "On: sound is lower quality while it is" : "Off: best sound quality"
        color: Theme.dim
        font.pixelSize: Theme.fontSmall
        Layout.fillWidth: true
      }
    }
    Toggle {
      checked: root.sinkCard !== null && root.sinkCard.call
      enabled: !Headphones.busy
      onToggled: Headphones.setCallMode(root.sinkCard, !root.sinkCard.call)
    }
  }

  Label {
    visible: Headphones.error !== ""
    text: Headphones.error
    color: Theme.red
    font.pixelSize: Theme.fontSmall
    wrapMode: Text.Wrap
    elide: Text.ElideNone
    Layout.fillWidth: true
  }

  // ---- AirPods
  Separator { visible: root.showAirPods; Layout.fillWidth: true }
  SectionHeader {
    visible: root.showAirPods && !root.sinkIsAirPods
    text: AirPods.name.toUpperCase()
    Layout.fillWidth: true
  }
  AirPodsSettings {
    visible: root.showAirPods
    Layout.fillWidth: true
  }

  // ---- Bose
  Separator { visible: root.showBose; Layout.fillWidth: true }
  SectionHeader {
    visible: root.showBose && !root.sinkIsBose
    text: Bose.name.toUpperCase()
    Layout.fillWidth: true
  }
  BoseSettings {
    visible: root.showBose
    showHeader: false
    Layout.fillWidth: true
  }

  // ---- every output
  Separator { Layout.fillWidth: true }
  SectionHeader { text: "OUTPUT"; Layout.fillWidth: true }

  ColumnLayout {
    Layout.fillWidth: true
    Layout.topMargin: -4
    spacing: 0

    Repeater {
      model: root.outputs

      Rectangle {
        id: output
        required property var modelData
        readonly property var entry: modelData
        readonly property int battery: entry.device && entry.device.connected ? root.batteryOf(entry.device) : -1
        readonly property bool canDisconnect: entry.device !== null && entry.device !== undefined && entry.device.connected

        Layout.fillWidth: true
        implicitHeight: Theme.rowHeight + (entry.detail ? 10 : 0)
        radius: Theme.controlRadius
        color: entry.current ? Theme.alpha(Theme.accent, 0.1) : hover.hovered ? Theme.hover : "transparent"

        HoverHandler { id: hover }

        MouseArea {
          anchors.fill: parent
          onClicked: {
            if (output.entry.node) Audio.setDefaultSink(output.entry.node)
            else if (output.entry.jack) Headphones.useJack(output.entry.jack)
            else if (output.entry.connect) output.entry.device.connect()
          }
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 6
          anchors.rightMargin: 8
          spacing: 10

          Label {
            text: root.glyph(output.entry.kind)
            color: output.entry.current ? Theme.accent : output.entry.connect ? Theme.muted : Theme.dim
            font.pixelSize: Theme.iconSize
            elide: Text.ElideNone
            Layout.preferredWidth: 16
            horizontalAlignment: Text.AlignHCenter
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
              text: output.entry.label
              color: output.entry.current ? Theme.accent : output.entry.connect ? Theme.dim : Theme.foreground
              Layout.fillWidth: true
            }
            Label {
              visible: !!output.entry.detail
              text: output.entry.detail || ""
              color: Theme.dim
              font.pixelSize: Theme.fontSmall
              Layout.fillWidth: true
            }
          }

          Label {
            visible: !disconnect.visible && output.battery >= 0
            text: output.battery + "%"
            color: output.battery <= 15 ? Theme.red : Theme.dim
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideNone
          }
          Label {
            visible: !disconnect.visible && output.entry.connect === true && output.entry.device.state === BluetoothDeviceState.Connecting
            text: "Connecting…"
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideNone
          }

          // Bluetooth headphones can be let go of from here.
          Label {
            id: disconnect
            visible: hover.hovered && output.canDisconnect
            text: "Disconnect"
            color: disconnectMouse.containsMouse ? Theme.brightForeground : Theme.dim
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideNone

            MouseArea {
              id: disconnectMouse
              anchors.fill: parent
              anchors.margins: -6
              hoverEnabled: true
              onClicked: output.entry.device.disconnect()
            }
          }
        }
      }
    }
  }
}
