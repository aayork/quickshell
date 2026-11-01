import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import "Emoji.js" as Emoji

// The launcher's `emoji:` keyword, drawn as a grid (EmojiGrid.qml). An empty
// query browses everything by category, with what you used lately first.
// Enter pastes into the window you came from and leaves it on the clipboard.
Scope {
  id: root

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/aayork-quickshell"
  readonly property int keepRecent: 30
  readonly property var toneNames: ["Default", "Light", "Medium-Light", "Medium", "Medium-Dark", "Dark"]
  // A hand in each tone, for the skin tone actions.
  readonly property var toneSamples: ["✋", "✋🏻", "✋🏼", "✋🏽", "✋🏾", "✋🏿"]

  property var entries: []
  property var byChar: ({})
  // Base characters, newest first.
  property var recent: []
  // 0 is the yellow default, 1-5 light to dark.
  property int tone: 0

  // Category bar order, with an icon for each.
  readonly property var groupIcons: ({
    "Recently Used": 0xF0150, "Popular": 0xF04D2, "Smileys": 0xF01F5, "People": 0xF1822,
    "Nature": 0xF03E9, "Food": 0xF0C84, "Travel": 0xF001D, "Activities": 0xF0806,
    "Objects": 0xF0336, "Symbols": 0xF02D5, "Flags": 0xF023D
  })

  function refresh() {}

  function shown(entry) {
    return tone > 0 && entry.tones ? entry.tones[tone - 1] : entry.e
  }

  function use(entry) {
    var next = [entry.e].concat(recent.filter(e => e !== entry.e)).slice(0, keepRecent)
    recent = next
    save()
  }

  function setTone(value) {
    tone = value
    save()
  }

  function save() {
    stateFile.setText(JSON.stringify({ recent: recent, tone: tone }))
  }

  function paste(entry) {
    var text = shown(entry)
    use(entry)
    Quickshell.execDetached(["wl-copy", "--", text])
    // The launcher closes first; the keystrokes need the old window focused.
    Quickshell.execDetached(["sh", "-c", "sleep 0.15; wtype -- \"$1\"", "sh", text])
  }

  function copy(entry) {
    use(entry)
    Quickshell.execDetached(["wl-copy", "--", shown(entry)])
  }

  function row(entry, group) {
    var name = Emoji.title(entry.name)
    var actions = [
      { title: "Paste Emoji", run: () => root.paste(entry) },
      { title: "Copy to Clipboard", run: () => root.copy(entry) },
      { title: "Copy Name", run: () => Quickshell.execDetached(["wl-copy", "--", name]) }
    ]
    if (entry.tones) {
      for (var t = 0; t < 6; t++) {
        actions.push({
          title: (t === tone ? "✓ " : "") + "Skin Tone: " + toneNames[t] + "  " + (t === 0 ? entry.e : entry.tones[t - 1]),
          keepOpen: true,
          run: (function(value) { return () => root.setTone(value) })(t)
        })
      }
    }
    if (recent.indexOf(entry.e) !== -1) {
      actions.push({ title: "Remove from Recently Used", keepOpen: true, run: () => {
        root.recent = root.recent.filter(e => e !== entry.e)
        root.save()
      } })
    }
    return {
      key: "emoji:" + entry.e,
      title: name,
      subtitle: entry.group,
      icon: "",
      glyph: shown(entry),
      chip: "",
      group: group,
      emoji: true,
      actions: actions
    }
  }

  function rows(query) {
    var list = []
    if (entries.length === 0) return list
    var text = query.trim()

    if (text !== "") {
      var found = Emoji.search(entries, text, 200)
      for (var i = 0; i < found.length; i++) list.push(row(found[i], ""))
      if (list.length === 0) {
        list.push({ key: "hint", title: "No emoji match “" + text + "”", subtitle: "", icon: "",
          glyph: Icons.glyph(0xF01F5), chip: "", hint: true, actions: [] })
      }
      return list
    }

    // Recently used, or a starter set until there is a history.
    var first = recent.map(e => byChar[e]).filter(e => e !== undefined)
    var firstGroup = "Recently Used"
    if (first.length === 0) {
      first = Emoji.popular.map(n => Emoji.best(entries, n)).filter(e => e !== null)
      firstGroup = "Popular"
    }
    for (var r = 0; r < first.length; r++) list.push(row(first[r], firstGroup))
    for (var a = 0; a < entries.length; a++) list.push(row(entries[a], entries[a].group))
    return list
  }

  FileView {
    path: Quickshell.shellDir + "/launcher/data/emoji.json"
    printErrors: true
    onLoaded: {
      try {
        var list = Emoji.prepare(JSON.parse(text()))
        var map = {}
        for (var i = 0; i < list.length; i++) map[list[i].e] = list[i]
        root.byChar = map
        root.entries = list
      } catch (e) {
        console.warn("emoji data:", e)
      }
    }
  }

  FileView {
    id: stateFile
    path: root.stateDir + "/emoji.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        var saved = JSON.parse(text())
        if (Array.isArray(saved.recent)) root.recent = saved.recent
        if (saved.tone >= 0 && saved.tone <= 5) root.tone = saved.tone
      } catch (e) {}
    }
  }
}
