import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.theme

// Bluetooth: power, the devices already paired, and (while `active`) the ones
// in range that are not.
ColumnLayout {
  id: root

  // Look for new devices. Set while the panel is on screen.
  property bool active: false

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool on: adapter !== null && adapter.enabled
  readonly property var paired: Bluetooth.devices.values.filter(d => d.paired || d.connected)
  // A device with no name of its own reports its address instead; those are
  // other people's beacons and earbuds, not something to pair with.
  readonly property var nearby: Bluetooth.devices.values.filter(d => !d.paired && !d.connected && d.name !== ""
    && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(d.name))

  spacing: Theme.spacing

  // Discovery drains batteries on both ends, so only while someone is looking.
  function syncDiscovery() {
    if (adapter) adapter.discovering = active && on
  }
  onActiveChanged: syncDiscovery()
  onOnChanged: syncDiscovery()
  Component.onDestruction: if (adapter) adapter.discovering = false

  component Device: Rectangle {
    id: device
    required property var modelData

    Layout.fillWidth: true
    implicitHeight: Theme.rowHeight
    radius: Theme.controlRadius
    color: hover.hovered ? Theme.hover : "transparent"

    HoverHandler { id: hover }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        if (device.modelData.connected) device.modelData.disconnect()
        else if (device.modelData.paired) device.modelData.connect()
        else device.modelData.pair()
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 6
      anchors.rightMargin: 6
      spacing: Theme.spacing

      Label {
        text: device.modelData.connected ? Icons.bluetoothConnected : Icons.bluetooth
        font.pixelSize: Theme.iconSize
        color: device.modelData.connected ? Theme.accent : Theme.dim
        elide: Text.ElideNone
      }
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
        elide: Text.ElideNone
      }
      Label {
        visible: !forget.visible
        text: device.modelData.pairing ? "Pairing…"
          : device.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
          : device.modelData.connected ? "Connected"
          : device.modelData.paired ? "" : "Pair"
        color: Theme.dim
        font.pixelSize: Theme.fontSmall
        elide: Text.ElideNone
      }
      Label {
        id: forget
        visible: hover.hovered && device.modelData.paired
        text: "Forget"
        color: forgetMouse.containsMouse ? Theme.brightForeground : Theme.dim
        font.pixelSize: Theme.fontSmall
        elide: Text.ElideNone

        MouseArea {
          id: forgetMouse
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          onClicked: device.modelData.forget()
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Theme.spacing

    Label { text: "Bluetooth"; font.bold: true }
    Label {
      text: !root.adapter ? "No adapter" : !root.on ? "Off" : root.adapter.discovering ? "Looking for devices…" : "On"
      color: Theme.dim
      Layout.fillWidth: true
    }
    Toggle {
      visible: root.adapter !== null
      checked: root.on
      onToggled: root.adapter.enabled = !root.adapter.enabled
    }
  }

  Separator { Layout.fillWidth: true; visible: root.on }

  SectionHeader { visible: root.on && root.paired.length > 0; text: "MY DEVICES" }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    Repeater {
      model: root.on ? root.paired : []
      Device {}
    }
  }

  SectionHeader { visible: root.on && root.active; text: "NEARBY" }

  Label {
    visible: root.on && root.active && root.nearby.length === 0
    text: "Nothing new in range yet"
    color: Theme.dim
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    Repeater {
      model: root.on && root.active ? root.nearby : []
      Device {}
    }
  }
}
