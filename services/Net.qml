pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.theme

// What the network widget and the control center need to know, read from
// NetworkManager through Quickshell.Networking.
Singleton {
  id: root

  readonly property var devices: Networking.devices.values
  readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
  // Real ethernet ports only: Docker, bridges and VMs also show up as wired
  // devices, and their always-up links would read as "Ethernet".
  readonly property var wiredPorts: devices.filter(d => d.type === DeviceType.Wired
    && !/^(veth|docker|br-|virbr|vnet|vmnet|vboxnet|tap|tun|lo)/.test(d.name))
  readonly property var wiredDevice: wiredPorts.find(d => d.connected) ?? null
  // The port to talk about: the connected one, else one with a cable in.
  readonly property var wiredPort: wiredDevice ?? wiredPorts.find(d => d.hasLink) ?? null
  readonly property bool wiredChanging: !!wiredPort && (wiredPort.state === ConnectionState.Connecting
    || wiredPort.state === ConnectionState.Disconnecting)
  readonly property string wiredStatus: {
    if (!wiredPort) return ""
    if (wiredPort.state === ConnectionState.Connecting) return "Connecting…"
    if (wiredPort.state === ConnectionState.Disconnecting) return "Disconnecting…"
    if (!wiredPort.connected) return "Not connected"
    var speed = wiredPort.linkSpeed || 0
    if (speed <= 0) return "Connected"
    return "Connected · " + (speed >= 1000 ? (speed / 1000) + " Gb/s" : speed + " Mb/s")
  }
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

  // Wi-Fi on its own, for the Wi-Fi header in the popup.
  readonly property string wifiStatus: {
    if (!wifiDevice) return "No Wi-Fi"
    if (!wifiEnabled) return "Off"
    if (activeWifi) return activeWifi.name
    return "Not connected"
  }

  // Overall: ethernet wins when both are up, as it carries the traffic.
  readonly property string status: {
    if (wiredDevice) return activeWifi ? "Ethernet · " + activeWifi.name : "Ethernet"
    if (wiredChanging) return "Ethernet connecting…"
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

  // Ethernet: NetworkManager brings the port back up with its saved profile.
  function connectWired() {
    if (wiredPort && wiredPort.network) wiredPort.network.connect()
  }
  function disconnectWired() {
    if (wiredPort) wiredPort.disconnect()
  }

  function setWifiEnabled(on) {
    Networking.wifiEnabled = on
  }

  // Scanning costs power and briefly stalls the radio, so only while a list
  // is actually on screen.
  function setScanning(on) {
    if (wifiDevice) wifiDevice.scannerEnabled = on
  }

  // Details of the connection in use (ethernet first), for the popup:
  // bin/net-info every 2s while `detailsWanted`, plus up/down speeds from its
  // byte counters and the last minute of them for the graph.
  property bool detailsWanted: false
  readonly property string detailsIface: wiredDevice ? wiredDevice.name
    : activeWifi && wifiDevice ? wifiDevice.name : ""
  property var details: ({})
  property real downRate: 0
  property real upRate: 0
  property var downHistory: []
  property var upHistory: []
  readonly property int historyLength: 30
  property var lastSample: null

  onDetailsIfaceChanged: {
    details = ({})
    lastSample = null
    downRate = 0
    upRate = 0
    downHistory = []
    upHistory = []
  }

  Timer {
    interval: 2000
    repeat: true
    triggeredOnStart: true
    running: root.detailsWanted && root.detailsIface !== ""
    onTriggered: if (!infoProcess.running) {
      infoProcess.command = [Quickshell.shellDir + "/bin/net-info", root.detailsIface]
      infoProcess.running = true
    }
  }

  Process {
    id: infoProcess
    stdout: StdioCollector {
      onStreamFinished: root.takeDetails(text)
    }
  }

  function takeDetails(text) {
    var info
    try { info = JSON.parse(text) } catch (e) { return }
    if (info.iface !== detailsIface) return
    var now = Date.now()
    if (lastSample && info.rxBytes !== null && lastSample.rx !== null && now > lastSample.at) {
      var seconds = (now - lastSample.at) / 1000
      downRate = Math.max(0, (info.rxBytes - lastSample.rx) / seconds)
      upRate = Math.max(0, (info.txBytes - lastSample.tx) / seconds)
      downHistory = downHistory.concat([downRate]).slice(-historyLength)
      upHistory = upHistory.concat([upRate]).slice(-historyLength)
    }
    lastSample = { at: now, rx: info.rxBytes, tx: info.txBytes }
    details = info
  }

  function formatRate(bytesPerSecond) {
    var units = ["B/s", "KB/s", "MB/s", "GB/s"]
    var v = bytesPerSecond, i = 0
    while (v >= 1000 && i < units.length - 1) { v /= 1000; i++ }
    return (i === 0 || v >= 100 ? Math.round(v) : v.toFixed(1)) + " " + units[i]
  }

  function signalWord(dbm) {
    if (dbm >= -55) return "Excellent"
    if (dbm >= -65) return "Good"
    if (dbm >= -75) return "Fair"
    return "Weak"
  }
}
