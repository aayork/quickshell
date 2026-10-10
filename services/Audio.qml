pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default output and input, the devices they can be switched to, and the
// apps playing sound.
Singleton {
  id: root

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource

  readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
  readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

  // Playback streams grouped by app (an app can hold several, Spotify keeps
  // an idle one around): [{ name, nodes }].
  readonly property var apps: {
    var groups = []
    for (var n of Pipewire.nodes.values) {
      if (!n.audio || !n.isStream || n.properties["media.class"] !== "Stream/Output/Audio") continue
      var name = n.properties["application.name"] || n.description || n.name
      // Apps built on Chromium (Spotify) call their stream "Chromium"; the
      // program behind it knows better.
      var binary = n.properties["application.process.binary"] || ""
      if (/^chrom/i.test(name) && binary !== "" && !/chrom/i.test(binary))
        name = binary.charAt(0).toUpperCase() + binary.slice(1)
      // Match what its MPRIS bridge calls it in the player switcher.
      if (name === "Music Player Daemon") name = "MPD"
      var group = groups.find(g => g.name === name)
      if (group) group.nodes.push(n)
      else groups.push({ name: name, nodes: [n] })
    }
    return groups.sort((a, b) => a.name.localeCompare(b.name))
  }

  // A node's volume and mute are only live while something tracks it.
  PwObjectTracker {
    objects: [root.sink, root.source].concat(Pipewire.nodes.values.filter(n => n.isStream))
  }

  // An app's level is its loudest stream's; setting it sets them all.
  function appVolume(app) {
    return Math.max(0, ...app.nodes.map(n => volume(n)))
  }

  function appMuted(app) {
    return app.nodes.every(n => muted(n))
  }

  function setAppVolume(app, value) {
    for (var n of app.nodes) setVolume(n, value)
  }

  function toggleAppMute(app) {
    var mute = !appMuted(app)
    for (var n of app.nodes) if (n.audio) n.audio.muted = mute
  }

  function label(node) {
    return node ? (node.description || node.nickname || node.name) : ""
  }

  function volume(node) {
    return node && node.audio ? node.audio.volume : 0
  }

  function muted(node) {
    return node && node.audio ? node.audio.muted : false
  }

  function setVolume(node, value) {
    if (!node || !node.audio) return
    node.audio.volume = Math.max(0, Math.min(1, value))
  }

  function toggleMute(node) {
    if (node && node.audio) node.audio.muted = !node.audio.muted
  }

  function setDefaultSink(node) {
    Pipewire.preferredDefaultAudioSink = node
  }

  function setDefaultSource(node) {
    Pipewire.preferredDefaultAudioSource = node
  }
}
