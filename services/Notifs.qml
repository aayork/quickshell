pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.theme

// The notification daemon. Live notifications show as toasts; a plain copy
// of each goes into the history the clock popup lists.
Singleton {
  id: root

  readonly property string historyFile: Quickshell.env("HOME") + "/.local/state/aayork-quickshell/notifications.json"
  readonly property int historyLimit: 50

  // Do not disturb: nothing pops up, everything still lands in history.
  property bool dnd: false
  // Notification objects currently on screen, newest first.
  property var toasts: []
  // [{ id, app, summary, body, icon, appIcon, time }], newest first.
  property var history: []
  // History bunched by app, like iOS: [{ key, name, icon, entries }],
  // the app with the newest notification first, each entries newest first.
  readonly property var groups: {
    var byKey = {}
    var order = []
    for (var i = 0; i < history.length; i++) {
      var e = history[i]
      var key = groupKey(e)
      if (!byKey[key]) {
        byKey[key] = { key: key, name: e.app || e.summary || "Notifications", icon: appIconSource(e), entries: [] }
        order.push(key)
      }
      byKey[key].entries.push(e)
    }
    return order.map(k => byKey[k])
  }

  function plain(text) {
    return String(text || "")
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<[^>]+>/g, "")
      .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&amp;/g, "&")
      .trim()
  }

  function iconFor(notification) {
    if (notification.image) return notification.image
    if (notification.appIcon) return Quickshell.iconPath(notification.appIcon, true)
    return ""
  }

  function groupKey(entry) {
    return (entry.app || entry.summary || "").toLowerCase()
  }

  // A lasting icon for the app that sent a notification: an icon name, or a
  // file path. Its picture (image://qsimage/...) only lives as long as the
  // notification itself, so history cannot rely on it.
  function appIconName(notification) {
    var entry = null
    if (notification.desktopEntry) entry = DesktopEntries.byId(notification.desktopEntry)
    if (entry && entry.icon) return entry.icon
    var icon = String(notification.appIcon || "")
    if (icon.startsWith("file://")) return icon.substring(7)
    if (icon !== "" && !icon.startsWith("image:")) return icon
    entry = notification.appName ? DesktopEntries.heuristicLookup(notification.appName) : null
    return entry && entry.icon ? entry.icon : ""
  }

  // Image source for a history entry's app icon. Older entries never saved
  // one, so fall back to their old icon or a guess from the app's name.
  function appIconSource(entry) {
    var name = entry.appIcon || ""
    if (name === "" && String(entry.icon || "").startsWith("image://icon/")) return entry.icon
    if (name === "" && entry.app) {
      var desktop = DesktopEntries.heuristicLookup(entry.app)
      if (desktop && desktop.icon) name = desktop.icon
    }
    if (name === "") return ""
    return name.charAt(0) === "/" ? "file://" + name : Quickshell.iconPath(name, true)
  }

  function clearGroup(key) {
    history = history.filter(e => groupKey(e) !== key)
    save()
  }

  function receive(notification) {
    notification.tracked = true
    notification.closed.connect(function() { root.drop(notification) })

    if (!notification.transient) {
      var entry = {
        id: Date.now() + "-" + notification.id,
        app: notification.appName,
        summary: plain(notification.summary),
        body: plain(notification.body),
        icon: String(iconFor(notification)),
        appIcon: appIconName(notification),
        time: Date.now()
      }
      history = [entry].concat(history).slice(0, historyLimit)
      save()
    }

    if (dnd && notification.urgency !== NotificationUrgency.Critical) {
      notification.expire()
      return
    }
    toasts = [notification].concat(toasts)
  }

  function drop(notification) {
    toasts = toasts.filter(n => n !== notification)
  }

  function dismissAll() {
    var live = toasts
    for (var i = 0; i < live.length; i++) live[i].dismiss()
  }

  function removeEntry(id) {
    history = history.filter(e => e.id !== id)
    save()
  }

  function clearHistory() {
    history = []
    save()
  }

  function save() {
    store.setText(JSON.stringify(history))
  }

  NotificationServer {
    actionsSupported: true
    bodySupported: true
    bodyMarkupSupported: true
    imageSupported: true
    keepOnReload: false
    onNotification: function(notification) { root.receive(notification) }
  }

  FileView {
    id: store
    path: root.historyFile
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        var saved = JSON.parse(text())
        if (Array.isArray(saved)) root.history = saved
      } catch (e) {}
    }
  }

  Process {
    command: ["mkdir", "-p", root.historyFile.replace(/\/[^\/]*$/, "")]
    running: true
  }

  IpcHandler {
    target: "notifications"
    function dismissAll(): void { root.dismissAll() }
    function clear(): void { root.clearHistory() }
    function toggleDnd(): void { root.dnd = !root.dnd }
  }
}
