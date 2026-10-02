pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default output and input, plus the devices they can be switched to.
Singleton {
  id: root

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource

  readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
  readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

  // A node's volume and mute are only live while something tracks it.
  PwObjectTracker {
    objects: [root.sink, root.source]
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
