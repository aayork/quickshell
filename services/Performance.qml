pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The machine's load and temperatures (bin/system-stats), every two seconds:
// CPU, memory and GPU use plus the CPU temperature for the bar; every sensor
// and a few minutes of history for the popup.
Singleton {
  id: root

  // Use, in percent; NaN until known (CPU needs two samples).
  property real cpuUsage: NaN
  property real memUsage: NaN
  property real gpuUsage: NaN
  // Bytes.
  property real memUsed: NaN
  property real memTotal: NaN
  property real swapUsed: NaN
  property real swapTotal: NaN
  property real vramUsed: NaN
  property real vramTotal: NaN

  // °C, NaN when the machine has no such sensor.
  property real cpu: NaN
  property real gpu: NaN
  // One per part: { key, name, glyph, value, detail, warn, hot }.
  property var sensors: []
  property var cpuHistory: []
  property var gpuHistory: []
  property var cpuUsageHistory: []
  property var gpuUsageHistory: []
  readonly property int interval: 2000
  // Three minutes.
  readonly property int historyLength: 90
  readonly property bool available: !isNaN(memUsage)

  property real lastBusy: NaN
  property real lastTotal: NaN

  // Normal, getting warm, or hot.
  function level(value, warn, hot) {
    if (isNaN(value)) return 0
    return value >= hot ? 2 : value >= warn ? 1 : 0
  }
  function format(value) { return isNaN(value) ? "–" : Math.round(value) + "°" }
  function percent(value) { return isNaN(value) ? "–" : Math.round(value) + "%" }
  function gib(bytes) { return isNaN(bytes) ? "–" : (bytes / 1073741824).toFixed(1) }

  function parse(text) {
    // chip -> [{ label, value }], in the order the kernel lists them.
    var chips = {}
    var lines = text.split("\n")
    var gpuBusy = NaN
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].split("\t")
      if (f[0] === "@cpu") {
        var busy = Number(f[1]), total = Number(f[2])
        if (total > lastTotal) cpuUsage = Math.max(0, Math.min(100, 100 * (busy - lastBusy) / (total - lastTotal)))
        lastBusy = busy
        lastTotal = total
        continue
      }
      if (f[0] === "@mem") {
        memTotal = Number(f[1]) * 1024
        memUsed = (Number(f[1]) - Number(f[2])) * 1024
        memUsage = memTotal > 0 ? 100 * memUsed / memTotal : NaN
        swapTotal = Number(f[3]) * 1024
        swapUsed = (Number(f[3]) - Number(f[4])) * 1024
        continue
      }
      if (f[0] === "@gpu") {
        gpuBusy = Number(f[1])
        vramUsed = Number(f[2])
        vramTotal = Number(f[3])
        continue
      }
      var value = parseInt(f[2]) / 1000
      // Unwired inputs read as -55 or so on some boards.
      if (f.length < 3 || isNaN(value) || value <= -40 || value > 150) continue
      ;(chips[f[0]] = chips[f[0]] || []).push({ label: f[1], value: value })
    }
    function find(chip, labels) {
      var list = chips[chip] || []
      for (var j = 0; j < labels.length; j++)
        for (var k = 0; k < list.length; k++)
          if (labels[j] === "" || list[k].label === labels[j]) return list[k].value
      return NaN
    }
    function others(chip, labels) {
      return (chips[chip] || []).filter(s => labels.indexOf(s.label) >= 0)
        .map(s => s.label + " " + format(s.value)).join(" · ")
    }

    var out = []

    // AMD (k10temp, zenpower), Intel (coretemp), or a board's cpu_thermal.
    var cpu = find("k10temp", ["Tctl", "Tdie", ""])
    var cpuDetail = others("k10temp", ["Tccd1", "Tccd2", "Tccd3", "Tccd4"]).replace(/Tccd(\d)/g, "CCD $1")
    if (isNaN(cpu)) { cpu = find("zenpower", ["Tdie", "Tctl", ""]); cpuDetail = "" }
    if (isNaN(cpu)) { cpu = find("coretemp", ["Package id 0", ""]); cpuDetail = "" }
    if (isNaN(cpu)) cpu = find("cpu_thermal", [""])
    if (!isNaN(cpu)) out.push({ key: "cpu", name: "CPU", glyph: 0xF061A, value: cpu, detail: cpuDetail, warn: 80, hot: 90 })

    // AMD cards report the edge, the hottest spot and the memory.
    var gpu = find("amdgpu", ["edge", ""])
    if (!isNaN(gpu)) out.push({ key: "gpu", name: "GPU", glyph: 0xF08AE, value: gpu,
                                detail: others("amdgpu", ["junction", "mem"]).replace("junction", "Hot spot").replace("mem", "Memory"),
                                warn: 80, hot: 95 })

    var drive = 0
    for (var chip in chips) {
      if (chip === "nvme" || chip === "drivetemp") {
        // Several drives share a chip name; each is its own entry.
        var list = chips[chip].filter(s => s.label === "Composite" || s.label === "")
        for (var d = 0; d < list.length; d++) {
          drive++
          out.push({ key: "drive" + drive, name: "SSD" + (drive > 1 ? " " + drive : ""), glyph: 0xF02CA,
                     value: list[d].value, detail: "", warn: 60, hot: 70 })
        }
      }
    }
    for (var wifi in chips) {
      if (!/^(mt7\d+|iwlwifi|ath\d+k|rtw)/.test(wifi)) continue
      out.push({ key: "wifi", name: "Wi-Fi card", glyph: 0xF05A9, value: chips[wifi][0].value, detail: "", warn: 70, hot: 85 })
      break
    }

    root.cpu = cpu
    root.gpu = gpu
    root.gpuUsage = gpuBusy
    root.sensors = out
    if (!isNaN(cpuUsage)) cpuUsageHistory = cpuUsageHistory.concat([cpuUsage]).slice(-historyLength)
    if (!isNaN(gpuBusy)) gpuUsageHistory = gpuUsageHistory.concat([gpuBusy]).slice(-historyLength)
    if (!isNaN(cpu)) cpuHistory = cpuHistory.concat([cpu]).slice(-historyLength)
    if (!isNaN(gpu)) gpuHistory = gpuHistory.concat([gpu]).slice(-historyLength)
  }

  Timer {
    interval: root.interval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!reader.running) reader.running = true
  }

  Process {
    id: reader
    command: [Quickshell.shellDir + "/bin/system-stats"]
    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }
  }
}
