import QtQuick
import Quickshell
import qs.services
import qs.theme
import "Fuzzy.js" as Fuzzy

// The launcher's `ch:` keyword: clipboard history, with what each entry is
// shown beside the list.
Scope {
  id: root

  function refresh() {}

  function ago(time) {
    var minutes = Math.floor((Date.now() - time) / 60000)
    if (minutes < 1) return "just now"
    if (minutes < 60) return minutes + " min ago"
    if (minutes < 1440) return Math.floor(minutes / 60) + " h ago"
    return Qt.formatDateTime(new Date(time), "MMM d, h:mm AP")
  }

  function bytes(size) {
    if (size < 1024) return size + " B"
    if (size < 1048576) return (size / 1024).toFixed(1) + " KB"
    return (size / 1048576).toFixed(1) + " MB"
  }

  // What kind of text it is, for the icon and the information panel.
  function describe(text) {
    var trimmed = text.trim()
    if (/^https?:\/\/\S+$/.test(trimmed)) return { type: "Link", glyph: 0xF0337 }
    if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(trimmed)) return { type: "Colour", glyph: 0xF03D8, colour: trimmed }
    if (/^(\/|~\/)\S*$/.test(trimmed)) return { type: "Path", glyph: 0xF024B }
    return { type: "Text", glyph: 0xF0284 }
  }

  function rows(query) {
    var needle = query.trim()
    var list = []
    var entries = Clipboard.entries

    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      var image = entry.kind === "image"
      var text = image ? "" : entry.text
      if (needle !== "") {
        if (image) {
          if (Fuzzy.score(needle, "image") === 0) continue
        } else if (text.toLowerCase().indexOf(needle.toLowerCase()) === -1) {
          continue
        }
      }

      var kind = image ? { type: "Image", glyph: 0xF02E9 } : describe(text)
      var info = [["Type", kind.type]]
      if (image) info.push(["Size", bytes(entry.size)])
      else {
        info.push(["Characters", String(text.length)])
        var lines = text.split("\n").length
        if (lines > 1) info.push(["Lines", String(lines)])
      }
      info.push(["Copied", ago(entry.time)])

      list.push({
        key: "clip:" + entry.id,
        title: image ? "Image" : text.trim().split("\n")[0].slice(0, 120),
        subtitle: "",
        icon: "",
        glyph: Icons.glyph(kind.glyph),
        chip: "",
        keepOpen: false,
        preview: { text: image ? "" : text.slice(0, 4000), image: image ? "file://" + entry.path : "", colour: kind.colour || "", info: info },
        actions: [
          { title: "Copy to Clipboard", run: (function(e) { return () => Clipboard.copy(e) })(entry) },
          { title: "Delete Entry", keepOpen: true, run: (function(e) { return () => Clipboard.remove(e) })(entry) },
          { title: "Clear History", keepOpen: true, run: () => Clipboard.clear() }
        ]
      })
    }

    if (list.length === 0) {
      list.push({ key: "hint", title: entries.length === 0 ? "Nothing copied yet" : "Nothing matches", subtitle: "", icon: "",
        glyph: Icons.glyph(0xF014D), chip: "", hint: true, actions: [] })
    }
    return list
  }
}
