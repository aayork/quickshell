import QtQuick
import Quickshell
import qs.services
import qs.theme

// The launcher's `shots:` keyword: capture history, with the picture beside
// the list.
Scope {
  id: root

  function refresh() {
    Captures.refresh()
  }

  function when(time) {
    var minutes = Math.floor((Date.now() - time) / 60000)
    if (minutes < 1) return "Just now"
    if (minutes < 60) return minutes + " min ago"
    if (minutes < 1440) return Math.floor(minutes / 60) + " h ago"
    return Qt.formatDateTime(new Date(time), "ddd MMM d, h:mm AP")
  }

  function rows(query) {
    var needle = query.trim().toLowerCase()
    var list = []
    var history = Captures.history

    for (var i = 0; i < history.length; i++) {
      var shot = history[i]
      var title = Qt.formatDateTime(new Date(shot.time), "MMM d, h:mm AP")
      if (needle !== "" && title.toLowerCase().indexOf(needle) === -1) continue
      list.push({
        key: "shot:" + shot.path,
        title: title,
        subtitle: when(shot.time),
        icon: "",
        glyph: Icons.glyph(0xF02E9),
        chip: "",
        preview: { text: "", image: "file://" + shot.path, colour: "", info: [["Taken", when(shot.time)]] },
        actions: [
          { title: "Edit", run: (function(p) { return () => Captures.edit(p) })(shot.path) },
          { title: "Copy", run: (function(p) { return () => Captures.copy(p) })(shot.path) },
          { title: "Save to Pictures", run: (function(p) { return () => Captures.save(p) })(shot.path) },
          { title: "Pin to Screen", run: (function(p) { return () => Captures.pin(p) })(shot.path) },
          { title: "Delete", keepOpen: true, run: (function(p) { return () => Captures.remove(p) })(shot.path) }
        ]
      })
    }

    if (list.length === 0) {
      list.push({ key: "hint", title: history.length === 0 ? "No captures yet" : "Nothing matches", subtitle: "", icon: "",
        glyph: Icons.glyph(0xF02E9), chip: "", hint: true, actions: [] })
    }
    return list
  }
}
