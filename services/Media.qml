pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The player the shell talks about: whichever one is playing, otherwise the
// first one that exists.
Singleton {
  id: root

  readonly property var players: Mpris.players.values
  readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null

  readonly property bool hasMedia: player !== null && (player.trackTitle || "") !== ""
  readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  readonly property bool playing: player ? player.isPlaying : false
  readonly property bool hasProgress: player !== null && player.positionSupported && player.lengthSupported && player.length > 0
  readonly property real progress: hasProgress ? Math.max(0, Math.min(1, player.position / player.length)) : 0

  function toggle() {
    if (player && player.canTogglePlaying) player.togglePlaying()
  }

  function previous() {
    if (player && player.canGoPrevious) player.previous()
  }

  function next() {
    if (player && player.canGoNext) player.next()
  }

  // MPRIS does not push position updates; whoever shows progress calls this.
  function refreshPosition() {
    if (hasProgress) player.positionChanged()
  }
}
