import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Monitor settings for the launcher's `displays:` keyword: resolution,
// refresh rate and scale. A change applies straight away and then waits for
// a "keep"; without one it goes back, so a mode the screen cannot show
// undoes itself.
//
// Kept settings are written to ~/.config/hypr/hyprmoncfg-monitors.lua, the
// file hyprland.lua already loads monitor rules from.
Scope {
  id: root

  readonly property string keyword: "displays"
  readonly property string rulesPath: Quickshell.env("HOME") + "/.config/hypr/hyprmoncfg-monitors.lua"
  readonly property int graceSeconds: 12
  readonly property var scales: [1, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.75, 2, 2.5, 3]

  property var monitors: []
  property string rules: ""
  // { rule, previousRule, summary } while a change is waiting to be kept.
  property var pending: null
  property int secondsLeft: 0
  // Bumped so the launcher re-reads rows when something here changes.
  property int revision: 0

  function refresh() {
    if (!query.running) query.running = true
    rulesFile.reload()
  }

  function label(monitor) {
    return monitor.name + " · " + (monitor.model || monitor.description)
  }

  function modeText(monitor) {
    return monitor.width + "x" + monitor.height + " @ " + Math.round(monitor.refreshRate) + " Hz"
  }

  function scaleText(scale) {
    return String(Math.round(scale * 100) / 100) + "x"
  }

  // Hyprland only takes a scale that lands on whole logical pixels.
  function validScales(monitor) {
    return scales.filter(function(scale) {
      var w = monitor.width / scale
      var h = monitor.height / scale
      return Math.abs(w - Math.round(w)) < 0.01 && Math.abs(h - Math.round(h)) < 0.01
    })
  }

  // "3840x2560@119.99Hz" -> { size, rate, mode }
  function modes(monitor) {
    var seen = {}
    var list = []
    for (var i = 0; i < monitor.availableModes.length; i++) {
      var match = monitor.availableModes[i].match(/^(\d+x\d+)@([\d.]+)Hz$/)
      if (!match || seen[match[0]]) continue
      seen[match[0]] = true
      list.push({ size: match[1], rate: Number(match[2]), mode: match[1] + "@" + match[2] })
    }
    list.sort(function(a, b) {
      var aw = Number(a.size.split("x")[0]) * Number(a.size.split("x")[1])
      var bw = Number(b.size.split("x")[0]) * Number(b.size.split("x")[1])
      return bw - aw || b.rate - a.rate
    })
    return list
  }

  function escapeRegex(text) {
    return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  }

  // The saved rule for this monitor, or a plain one describing how it is now.
  function ruleFor(monitor) {
    var match = rules.match(new RegExp("hl\\.monitor\\(\\{[^}]*output\\s*=\\s*\"desc:" + escapeRegex(monitor.description) + "\"[^}]*\\}\\)"))
    if (match) return match[0]
    return "hl.monitor({\n  output = \"desc:" + monitor.description + "\",\n  mode = \"" + monitor.width + "x" + monitor.height + "@"
      + monitor.refreshRate.toFixed(2) + "\",\n  position = \"" + monitor.x + "x" + monitor.y + "\",\n  scale = " + monitor.scale + ",\n})"
  }

  function withValue(rule, key, value) {
    var pattern = new RegExp("(\\b" + key + "\\s*=\\s*)(\"[^\"]*\"|[\\d.]+)")
    if (pattern.test(rule)) return rule.replace(pattern, "$1" + value)
    return rule.replace(/\}\)$/, "  " + key + " = " + value + ",\n})")
  }

  function change(monitor, key, value, summary) {
    var previous = ruleFor(monitor)
    var next = withValue(previous, key, value)
    pending = { rule: next, previousRule: previous, summary: summary }
    secondsLeft = graceSeconds
    apply(next)
    countdown.restart()
    revision += 1
  }

  function apply(rule) {
    Quickshell.execDetached(["hyprctl", "eval", rule.replace(/\n/g, " ")])
    settle.restart()
  }

  function keep() {
    if (!pending) return
    countdown.stop()
    var saved = rules
    if (saved.indexOf(pending.previousRule) !== -1) saved = saved.replace(pending.previousRule, pending.rule)
    else saved = (saved.trim() === "" ? "-- Monitor rules, loaded from hyprland.lua.\n" : saved.replace(/\s*$/, "\n")) + "\n" + pending.rule + "\n"
    rules = saved
    rulesFile.setText(saved)
    pending = null
    revision += 1
  }

  function revert() {
    if (!pending) return
    countdown.stop()
    apply(pending.previousRule)
    pending = null
    revision += 1
  }

  function row(key, title, subtitle, accessory, extra) {
    return Object.assign({
      key: "displays:" + key, title: title, subtitle: subtitle, icon: "", glyph: Icons.glyph(0xF0379),
      accessory: accessory, keepOpen: true
    }, extra)
  }

  // What the launcher lists for the text after `displays:`.
  function rows(text) {
    var _ = revision
    if (pending) {
      return [
        row("keep", "Keep " + pending.summary, "Going back in " + secondsLeft + "s", "", { glyph: Icons.check, run: () => root.keep() }),
        row("revert", "Go back", "Undo the change now", "", { glyph: Icons.close, run: () => root.revert() })
      ]
    }

    var words = text.trim().toLowerCase().split(/\s+/).filter(w => w !== "")
    var single = monitors.length === 1
    var list = []

    for (var i = 0; i < monitors.length; i++) {
      var monitor = monitors[i]
      var mine = words.slice()
      if (!single) {
        if (mine.length > 0 && mine[0] !== monitor.name.toLowerCase()) {
          if (monitor.name.toLowerCase().indexOf(mine[0]) !== 0) continue
        }
        if (mine.length > 0 && monitor.name.toLowerCase().indexOf(mine[0]) === 0) mine.shift()
      }
      var prefix = keyword + ": " + (single ? "" : monitor.name + " ")
      var setting = mine[0] || ""
      var filter = mine.slice(1).join(" ")

      if (setting !== "" && "resolution".indexOf(setting) === 0 && mine.length > 1 || setting === "resolution") {
        var current = monitor.width + "x" + monitor.height
        var available = modes(monitor)
        for (var m = 0; m < available.length; m++) {
          var mode = available[m]
          var text2 = mode.size + " " + Math.round(mode.rate)
          if (filter !== "" && text2.indexOf(filter) === -1) continue
          var active = mode.size === current && Math.abs(mode.rate - monitor.refreshRate) < 0.05
          list.push(row(monitor.name + ":mode:" + mode.mode, mode.size, Math.round(mode.rate) + " Hz", active ? "Current" : "",
            active ? { hint: false } : { run: (function(mon, md) { return () => root.change(mon, "mode", "\"" + md.mode + "\"", md.size + " at " + Math.round(md.rate) + " Hz") })(monitor, mode) }))
        }
        continue
      }

      if (setting === "scale") {
        var options = validScales(monitor)
        for (var s = 0; s < options.length; s++) {
          var scale = options[s]
          var isCurrent = Math.abs(scale - monitor.scale) < 0.01
          if (filter !== "" && scaleText(scale).indexOf(filter) === -1) continue
          list.push(row(monitor.name + ":scale:" + scale, scaleText(scale),
            Math.round(monitor.width / scale) + "x" + Math.round(monitor.height / scale) + " of working space", isCurrent ? "Current" : "",
            isCurrent ? {} : { run: (function(mon, sc) { return () => root.change(mon, "scale", String(Math.round(sc * 1000000) / 1000000), root.scaleText(sc) + " scale") })(monitor, scale) }))
        }
        continue
      }

      var entries = [
        row(monitor.name + ":resolution", "Resolution", single ? label(monitor) : monitor.name, modeText(monitor), { fill: prefix + "resolution " }),
        row(monitor.name + ":scale", "Scale", single ? label(monitor) : monitor.name, scaleText(monitor.scale), { fill: prefix + "scale " })
      ]
      for (var e = 0; e < entries.length; e++)
        if (setting === "" || entries[e].title.toLowerCase().indexOf(setting) === 0) list.push(entries[e])
    }

    if (list.length === 0) list.push(row("none", monitors.length === 0 ? "Reading displays…" : "Nothing matches", "", "", { hint: true }))
    return list
  }

  Timer {
    id: countdown
    interval: 1000
    repeat: true
    onTriggered: {
      root.secondsLeft -= 1
      if (root.secondsLeft <= 0) root.revert()
      else root.revision += 1
    }
  }

  // Hyprland needs a moment before it reports the new mode.
  Timer {
    id: settle
    interval: 700
    onTriggered: root.refresh()
  }

  Process {
    id: query
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.monitors = JSON.parse(text).filter(m => !m.disabled)
          root.revision += 1
        } catch (e) {}
      }
    }
  }

  FileView {
    id: rulesFile
    path: root.rulesPath
    printErrors: false
    atomicWrites: true
    onLoaded: root.rules = text()
    onLoadFailed: root.rules = ""
  }
}
