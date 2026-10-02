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
  // [{ id, app, summary, body, icon, time }], newest first.
  property var history: []

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
