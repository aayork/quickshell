pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.theme

// Every MPRIS player, and the one the shell talks about: one picked by hand,
// else the most recent to start among those playing now, else the one that
// played last. The media keys (IPC target "media") act on that same player.
// With Config.media.exclusive set, a player that starts playing pauses the rest.
Singleton {
  id: root

  // playerctld mirrors whichever player is active, so it would show up twice.
  // So would an app built on Chromium (Spotify) that has its own player:
  // Chromium's media layer adds a second one, chromium.instance<pid>.
  readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld") && !shadow(p))

  // Program name (/proc/<pid>/comm) behind each chromium.instance<pid> player.
  property var owners: ({})

  function instancePid(p) {
    var match = /\.chromium\.instance(\d+)$/.exec(p.dbusName)
    return match ? match[1] : ""
  }

  // A Chromium player from a program that is not a browser.
  function embeddedIn(p) {
    var owner = owners[instancePid(p)] || ""
    return owner !== "" && !/chrom|brave|vivaldi|edge|opera/.test(owner) ? owner : ""
  }

  // An embedded Chromium player whose program has a player of its own.
  function shadow(p) {
    var owner = embeddedIn(p)
    return owner !== "" && Mpris.players.values.some(o => o !== p
      && ((o.desktopEntry || "").toLowerCase() === owner || (o.identity || "").toLowerCase() === owner))
  }

  // Looks up the programs behind new chromium.instance players.
  onPlayersChanged: lookUpOwners()
  Connections {
    target: Mpris.players
    function onValuesChanged() { root.lookUpOwners() }
  }

  function lookUpOwners() {
    var pids = Mpris.players.values.map(instancePid).filter(pid => pid !== "" && !(pid in owners))
    if (pids.length === 0 || ownerLookup.running) return
    ownerLookup.command = ["sh", "-c", 'for p; do printf "%s %s\\n" "$p" "$(cat /proc/$p/comm 2>/dev/null)"; done', "sh"].concat(pids)
    ownerLookup.running = true
  }

  Process {
    id: ownerLookup
    stdout: StdioCollector {
      onStreamFinished: {
        var next = Object.assign({}, root.owners)
        for (var line of text.trim().split("\n")) {
          var parts = line.trim().split(" ")
          if (parts[0]) next[parts[0]] = (parts[1] || "").toLowerCase()
        }
        root.owners = next
        root.lookUpOwners()
      }
    }
  }
  // dbusName of a player picked by hand; cleared when any player starts playing.
  property string picked: ""
  // dbusNames of players in the order they last started playing, newest first.
  property var recent: []
  // Players with a track loaded, paused or not; the ones the switcher offers.
  readonly property var loaded: players.filter(p => (p.trackTitle || "") !== "")
  readonly property var playingPlayers: players.filter(p => p.isPlaying)
  readonly property MprisPlayer player: players.find(p => p.dbusName === picked)
    ?? newest(playingPlayers) ?? newest(players.filter(p => recent.includes(p.dbusName)))
    ?? loaded[0] ?? players[0] ?? null

  function newest(list) {
    var rank = p => { var i = recent.indexOf(p.dbusName); return i < 0 ? recent.length : i }
    return list.slice().sort((a, b) => rank(a) - rank(b))[0] ?? null
  }

  readonly property bool hasMedia: player !== null && (player.trackTitle || "") !== ""
  readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  readonly property bool playing: player ? player.isPlaying : false
  // Spotify sends its track length in a form Quickshell reads as 0; the
  // hidden Chromium player in the same app has it right.
  readonly property MprisPlayer twin: player === null ? null
    : Mpris.players.values.find(o => o !== player && shadow(o)
      && [(player.desktopEntry || "").toLowerCase(), (player.identity || "").toLowerCase()].includes(embeddedIn(o))) ?? null
  readonly property real length: player === null ? 0
    : player.lengthSupported && player.length > 0 ? player.length
    : twin !== null && twin.lengthSupported ? twin.length : 0
  readonly property bool hasProgress: player !== null && player.positionSupported && length > 0
  readonly property real progress: hasProgress ? Math.max(0, Math.min(1, player.position / length)) : 0

  Instantiator {
    model: Mpris.players

    Connections {
      required property MprisPlayer modelData
      target: modelData

      function onIsPlayingChanged() {
        if (!modelData.isPlaying || modelData.dbusName.includes("playerctld")) return
        root.recent = [modelData.dbusName].concat(root.recent.filter(n => n !== modelData.dbusName))
        root.picked = ""
        if (Config.media.exclusive) root.pauseOthers(modelData)
      }
    }
  }


  function name(p) {
    if (!p) return ""
    var owner = embeddedIn(p)
    if (owner !== "") return owner.charAt(0).toUpperCase() + owner.slice(1)
    return p.identity || p.dbusName.replace("org.mpris.MediaPlayer2.", "")
  }

  function icon(p) {
    var id = p ? (embeddedIn(p) || p.desktopEntry || p.dbusName).toLowerCase() : ""
    return id.includes("spotify") ? Icons.spotify : Icons.music
  }

  function select(p) {
    if (p) picked = p.dbusName
  }

  // Pause every player but `keep` (the shown one by default).
  function pauseOthers(keep) {
    var kept = keep ?? player
    for (var p of players)
      if (p !== kept && p.isPlaying && p.canPause) p.pause()
  }

  function toggle() {
    if (player && player.canTogglePlaying) player.togglePlaying()
  }

  function previous() {
    if (player && player.canGoPrevious) player.previous()
  }

  function next() {
    if (player && player.canGoNext) player.next()
  }

  IpcHandler {
    target: "media"
    function toggle(): void { root.toggle() }
    function next(): void { root.next() }
    function previous(): void { root.previous() }
    function current(): string { return root.player ? root.name(root.player) : "" }
  }

  // MPRIS does not push position updates; whoever shows progress calls this.
  function refreshPosition() {
    if (hasProgress) player.positionChanged()
  }
}
