pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.theme

// What the network widget and the control center need to know, read from
// NetworkManager through Quickshell.Networking.
Singleton {
  id: root

  readonly property var devices: Networking.devices.values
  readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
  readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
  readonly property bool wifiEnabled: Networking.wifiEnabled
  readonly property var activeWifi: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null

  // Connected first, then saved networks, then by signal. One entry per name:
  // a network seen on several access points shows once.
  readonly property var networks: {
    if (!wifiDevice || !wifiEnabled) return []
    var seen = {}
    var list = []
    var all = wifiDevice.networks.values
    for (var i = 0; i < all.length; i++) {
      var net = all[i]
      if (!net.name || seen[net.name]) continue
      seen[net.name] = true
      list.push(net)
    }
    list.sort(function(a, b) {
      if (a.connected !== b.connected) return a.connected ? -1 : 1
      if (a.known !== b.known) return a.known ? -1 : 1
      // Whole bars, so a flickering reading does not reshuffle the list.
      var bars = Math.round(b.signalStrength * 4) - Math.round(a.signalStrength * 4)
      return bars !== 0 ? bars : a.name.localeCompare(b.name)
    })
    return list
  }

  readonly property string status: {
    if (wiredDevice) return "Ethernet"
    if (activeWifi) return activeWifi.name
    if (wifiDevice && !wifiEnabled) return "Wi-Fi off"
    return "Disconnected"
  }

  readonly property string icon: {
    if (wiredDevice) return Icons.ethernet
    if (activeWifi) return Icons.wifi(activeWifi.signalStrength)
    if (wifiDevice && !wifiEnabled) return Icons.wifiOff
    return Icons.wifiNone
  }

  function isSecure(net) {
    return net.security !== WifiSecurityType.Open
  }

  function setWifiEnabled(on) {
    Networking.wifiEnabled = on
  }

  // Scanning costs power and briefly stalls the radio, so only while a list
  // is actually on screen.
  function setScanning(on) {
    if (wifiDevice) wifiDevice.scannerEnabled = on
  }
}
