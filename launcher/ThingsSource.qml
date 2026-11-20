import QtQuick
import Quickshell
import qs.services
import qs.theme

// The launcher's `things:` keyword, like Raycast's Things extension: Today,
// Inbox, Upcoming, Anytime and Someday as one list, typed text filters it,
// and anything that matches nothing can be added as a new to-do.
//
// Enter ticks a to-do off and stays open; Ctrl+K moves it, ticks checklist
// items, trashes it, syncs or signs out. The pane beside the list shows the
// note and checklist.
Scope {
  id: root

  readonly property string glyph: Icons.glyph(0xF05E1)

  // Each list's icon and colour, like the Things sidebar, from the theme.
  readonly property var looks: ({
    inbox: { glyph: 0xF0687, color: Theme.pick("blue", Theme.accent) },
    today: { glyph: 0xF04CE, color: Theme.yellow },
    upcoming: { glyph: 0xF00ED, color: Theme.red },
    anytime: { glyph: 0xF0328, color: Theme.pick("cyan", Theme.accent) },
    someday: { glyph: 0xF003C, color: Theme.pick("dark_foreground", Theme.dim) }
  })

  readonly property var moves: [
    { id: "today", title: "Move to Today" },
    { id: "tomorrow", title: "Move to Tomorrow" },
    { id: "anytime", title: "Move to Anytime" },
    { id: "someday", title: "Move to Someday" },
    { id: "inbox", title: "Move to Inbox" }
  ]

  // Opening the keyword syncs, or checks the sign-in if that is not done.
  function refresh() {
    if (Things.ready) Things.refresh()
    else Things.check()
  }

  function dayLabel(key) {
    if (key === "") return ""
    if (key === Things.dateKey(0)) return "Today"
    if (key === Things.dateKey(1)) return "Tomorrow"
    return Qt.formatDate(new Date(key + "T12:00:00"), "ddd MMM d")
  }

  function hint(title, actions) {
    return { key: "hint", title: title, subtitle: "", icon: "", glyph: glyph, chip: "", hint: !actions, actions: actions || [] }
  }

  // Things Cloud sign-in, in a terminal so the password is never on screen.
  function signIn() {
    Quickshell.execDetached(["xdg-terminal-exec", "--", "sh", "-c",
      "printf 'Things Cloud email: '; read -r e; printf 'Password: '; stty -echo; read -r p; stty echo; echo; "
      + "printf '%s\\n' \"$p\" | \"$0\" login \"$e\" && echo 'Signed in. Open things: again.'; sleep 2", Things.bin])
  }

  readonly property var toolActions: [
    { title: "Sync Now", keepOpen: true, run: () => Things.refresh() },
    { title: "Sign Out of Things Cloud", run: () => Things.logout() }
  ]

  function todoRow(todo, view) {
    var look = looks[view]
    var items = Things.checklist(todo.uuid)
    var done = items.filter(i => i.done).length

    // Right-hand detail, as Things shows it: the day in Upcoming, a deadline,
    // or how far the checklist has got.
    var subtitle = view === "upcoming" ? dayLabel(todo.date)
      : todo.deadline !== "" ? "Due " + Qt.formatDate(new Date(todo.deadline + "T12:00:00"), "MMM d")
      : items.length > 0 ? done + "/" + items.length : ""

    var text = todo.note
    if (items.length > 0) text += (text !== "" ? "\n\n" : "") + items.map(i => (i.done ? "☑ " : "☐ ") + i.title).join("\n")

    var info = [["List", Things.views.find(v => v.id === view).label]]
    if (todo.context !== "") info.push(["In", todo.context])
    if (todo.date !== "") info.push(["When", dayLabel(todo.date)])
    if (todo.deadline !== "") info.push(["Deadline", Qt.formatDate(new Date(todo.deadline + "T12:00:00"), "ddd MMM d")])
    if (items.length > 0) info.push(["Checklist", done + " of " + items.length])

    var actions = [{ title: "Complete", keepOpen: true, run: () => Things.complete(todo) }]
    for (var i = 0; i < items.length; i++) {
      actions.push({ title: (items[i].done ? "Uncheck “" : "Check “") + items[i].title + "”", keepOpen: true,
        run: (function(item) { return () => Things.toggleItem(item) })(items[i]) })
    }
    for (var m = 0; m < moves.length; m++) {
      if (moves[m].id === view) continue
      actions.push({ title: moves[m].title, keepOpen: true, run: (function(where) { return () => Things.move(todo, where) })(moves[m].id) })
    }
    actions.push({ title: "Move to Trash", keepOpen: true, run: () => Things.trash(todo) })
    actions.push({ title: "Copy Title", run: () => Quickshell.execDetached(["wl-copy", "--", todo.title]) })

    return {
      key: "things:" + todo.uuid,
      title: todo.title,
      detail: view === "today" || view === "inbox" ? todo.context : "",
      subtitle: subtitle,
      icon: "",
      // An empty box in the list's colour: Enter ticks it.
      glyph: Icons.glyph(0xF0131),
      glyphColor: look.color,
      chip: "",
      group: Things.views.find(v => v.id === view).label,
      pending: todo.pending === true,
      preview: { text: text !== "" ? text : "No notes", image: "", colour: "", info: info },
      actions: todo.pending ? [] : actions.concat(toolActions)
    }
  }

  // Add what was typed as a new to-do; Enter puts it in Today.
  function newRow(text) {
    var where = [["today", "Add to Today"], ["inbox", "Add to Inbox"], ["upcoming", "Add for Tomorrow"],
                 ["anytime", "Add to Anytime"], ["someday", "Add to Someday"]]
    return {
      key: "things-new",
      title: "New To-Do “" + text + "”",
      subtitle: "Today",
      icon: "",
      glyph: Icons.glyph(0xF0415),
      glyphColor: looks.today.color,
      chip: "",
      group: "New",
      preview: { text: "Enter adds it to Today. Shift+Enter: Inbox. Ctrl+K for other lists.", image: "", colour: "", info: [] },
      actions: where.map(w => ({ title: w[1], query: "things: ", run: (function(view) { return () => Things.add(text, view) })(w[0]) }))
    }
  }

  function rows(query) {
    if (!Things.enabled) return [hint("Things is switched off (extensions:)")]
    if (Things.setup === "") return [hint("Checking Things Cloud…")]
    if (Things.setup === "no-cli") return [hint("things-cli is not installed (install.sh --with-things)")]
    if (Things.setup === "no-login") return [hint("Sign in to Things Cloud", [{ title: "Sign In", run: () => root.signIn() }])]

    var list = []
    if (Things.error !== "") list.push(hint(Things.error))
    if (!Things.loaded) return list.concat([hint("Loading…")])

    var text = query.trim()
    var needle = text.toLowerCase()
    for (var v = 0; v < Things.views.length; v++) {
      var view = Things.views[v].id
      var todos = Things.lists[view] || []
      for (var t = 0; t < todos.length; t++) {
        var todo = todos[t]
        if (needle !== "" && (todo.title + " " + todo.context + " " + todo.note).toLowerCase().indexOf(needle) === -1) continue
        list.push(todoRow(todo, view))
      }
    }

    if (text !== "") list.push(newRow(text))
    else if (list.length === 0) list.push(hint("Nothing to do. Type to add a to-do"))
    return list
  }
}
