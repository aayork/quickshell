import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// The Vista CPU meter: a big dial for the processor, a smaller one overlapping
// it for memory. Reads /proc/stat and /proc/meminfo every second and a half.
Item {
  id: root

  implicitWidth: 172
  implicitHeight: 118

  property real cpu: 0
  property real memory: 0
  property var last: null

  Timer {
    interval: 1500
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      stat.reload()
      meminfo.reload()
    }
  }

  FileView {
    id: stat
    path: "/proc/stat"
    blockLoading: true
    onLoaded: {
      var line = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
      var idle = line[3] + (line[4] || 0)
      var total = line.reduce((a, b) => a + b, 0)
      if (root.last) {
        var dt = total - root.last.total
        if (dt > 0) root.cpu = 1 - (idle - root.last.idle) / dt
      }
      root.last = { idle: idle, total: total }
    }
  }

  FileView {
    id: meminfo
    path: "/proc/meminfo"
    blockLoading: true
    onLoaded: {
      var t = text()
      var total = Number((t.match(/MemTotal:\s+(\d+)/) || [0, 0])[1])
      var avail = Number((t.match(/MemAvailable:\s+(\d+)/) || [0, 0])[1])
      if (total > 0) root.memory = 1 - avail / total
    }
  }

  Dial {
    x: 0
    y: 10
    width: 108
    height: 108
    label: "CPU"
    value: root.cpu
    readout: Math.round(root.cpu * 100) + "%"
  }

  Dial {
    x: 100
    y: 0
    width: 72
    height: 72
    label: "MEM"
    value: root.memory
    readout: Math.round(root.memory * 100) + "%"
  }

  // Click for the full picture: btop in a terminal.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])
  }
}
