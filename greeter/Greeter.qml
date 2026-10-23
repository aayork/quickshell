import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// The login logic: who can log in, which sessions exist, and the greetd
// conversation. Run outside greetd it only pretends, so the looks can be
// worked on without logging anyone in.
Scope {
  id: root

  // { name, display } for each login account.
  property var users: []
  property int userIndex: 0
  readonly property var user: users.length ? users[userIndex] : null

  // { file, name, exec, desktop } for each Wayland session.
  property var sessions: []
  property int sessionIndex: 0
  readonly property var session: sessions.length ? sessions[sessionIndex] : null

  // "", "checking", "prompt" (greetd asked something beyond the password),
  // "failed" or "launching".
  property string status: ""
  property string message: ""
  property string prompt: ""
  property bool promptEcho: false
  property string pending: ""
  property bool answered: false
  readonly property bool busy: status === "checking" || status === "launching"

  readonly property string stateDir: Greetd.available
    ? (Quickshell.env("XDG_CACHE_HOME") || "/var/cache/aayork-greeter")
    : Quickshell.env("HOME") + "/.cache/aayork-greeter-preview"
  property var saved: ({})

  function cycleUser(step) {
    if (busy || users.length < 2) return
    userIndex = (userIndex + step + users.length) % users.length
    reset()
  }

  // The account `step` places away from the current one, wrapping round.
  function neighbour(step) {
    if (users.length < 2) return null
    return users[(userIndex + step + users.length) % users.length]
  }

  function pickSession(index) {
    if (index >= 0 && index < sessions.length) sessionIndex = index
  }

  function reset() {
    if (Greetd.available && Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
    status = ""
    message = ""
    prompt = ""
    pending = ""
  }

  // The field's text goes here: the password, or the answer to a follow-up.
  function submit(text) {
    if (busy || !user) return
    if (status === "prompt") {
      status = "checking"
      prompt = ""
      Greetd.respond(text)
      return
    }
    if (text === "") return
    pending = text
    answered = false
    message = ""
    status = "checking"
    if (!Greetd.available) {
      previewTimer.start()
      return
    }
    Greetd.createSession(user.name)
  }

  function fail(text) {
    pending = ""
    if (Greetd.available && Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
    message = text
    status = "failed"
  }

  function launch() {
    var s = session
    saved = { user: user.name, session: s ? s.file : "" }
    stateFile.setText(JSON.stringify(saved))
    status = "launching"
    if (!s) return fail("No session to start")
    // The same wrapper tuigreet used, so session output still lands in the journal.
    var command = ["/usr/local/bin/greetd-session-wrapper"].concat(s.exec.split(/\s+/).filter(a => a !== ""))
    var env = ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + s.file.replace(/\.desktop$/, "")]
    if (s.desktop) env.push("XDG_CURRENT_DESKTOP=" + s.desktop.replace(/;+$/, "").replace(/;/g, ":"))
    if (!Greetd.available) {
      console.log("preview: would launch", JSON.stringify(command), JSON.stringify(env))
      previewReset.start()
      return
    }
    // Let the screen fade to black first (Surface.qml); greetd only starts
    // the session once this exits, and the desktop fades in from black.
    launchArgs = [command, env]
    launchTimer.start()
  }

  property var launchArgs: null
  readonly property int fadeOut: 350
  Timer {
    id: launchTimer
    interval: root.fadeOut
    onTriggered: Greetd.launch(root.launchArgs[0], root.launchArgs[1], true)
  }

  Connections {
    target: Greetd
    function onAuthMessage(text, error, responseRequired, echoResponse) {
      if (responseRequired) {
        if (!root.answered && !echoResponse) {
          root.answered = true
          Greetd.respond(root.pending)
          root.pending = ""
        } else {
          root.prompt = text
          root.promptEcho = echoResponse
          root.status = "prompt"
        }
      } else {
        root.message = text
      }
    }
    function onAuthFailure(text) { root.fail("That password didn't work") }
    function onError(text) { root.fail(text || "Something went wrong") }
    function onReadyToLaunch() { root.launch() }
  }

  Timer {
    id: previewTimer
    interval: 700
    onTriggered: root.pending === "fail" ? root.fail("That password didn't work") : root.launch()
  }
  Timer {
    id: previewReset
    interval: 1500
    onTriggered: { root.status = ""; root.pending = "" }
  }

  function choose() {
    if (saved.user) {
      var u = users.findIndex(x => x.name === saved.user)
      if (u >= 0) userIndex = u
    }
    var want = saved.session || "hyprland.desktop"
    var s = sessions.findIndex(x => x.file === want)
    if (s < 0) s = sessions.findIndex(x => x.file === "hyprland.desktop")
    if (s >= 0) sessionIndex = s
  }

  FileView {
    path: "/etc/passwd"
    onLoaded: {
      var list = []
      var lines = text().split("\n")
      for (var i = 0; i < lines.length; i++) {
        var f = lines[i].split(":")
        if (f.length < 7) continue
        var uid = parseInt(f[2])
        if (uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(f[6])) continue
        var display = f[4].split(",")[0]
        list.push({ name: f[0], display: display || f[0] })
      }
      // Preview only: AAYORK_GREETER_DEMO_USERS="sam:Sam Lee,alex:Alex Kim"
      // adds pretend accounts so the switcher can be seen with one real one.
      var demo = Greetd.available ? "" : (Quickshell.env("AAYORK_GREETER_DEMO_USERS") || "")
      demo.split(",").filter(d => d !== "").forEach(d => {
        var p = d.split(":")
        list.push({ name: p[0], display: p[1] || p[0] })
      })
      root.users = list
      root.choose()
    }
  }

  Process {
    running: true
    command: ["sh", "-c", "grep -HE '^(Name|Exec|DesktopNames|NoDisplay|Hidden)=' /usr/share/wayland-sessions/*.desktop"]
    stdout: StdioCollector {
      onStreamFinished: {
        var byFile = {}
        var order = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var m = lines[i].match(/^(.*\/)?([^\/:]+\.desktop):([A-Za-z]+)=(.*)$/)
          if (!m) continue
          var file = m[2]
          if (!byFile[file]) { byFile[file] = { file: file }; order.push(file) }
          if (byFile[file][m[3]] === undefined) byFile[file][m[3]] = m[4]
        }
        var list = []
        for (var j = 0; j < order.length; j++) {
          var e = byFile[order[j]]
          if (!e.Exec || e.NoDisplay === "true" || e.Hidden === "true") continue
          list.push({ file: e.file, name: e.Name || e.file, exec: e.Exec, desktop: e.DesktopNames || "" })
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        root.sessions = list
        root.choose()
      }
    }
  }

  FileView {
    id: stateFile
    path: root.stateDir + "/state.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try { root.saved = JSON.parse(text()) || {} } catch (e) {}
      root.choose()
    }
  }

  // Tells greeter/run-shell the screen is up; without this within 20 s it
  // gives up and greeter/start falls back to tuigreet.
  function markReady() {
    var cache = Quickshell.env("AAYORK_GREETER_CACHE")
    if (cache && !readyProc.running) {
      readyProc.command = ["touch", cache + "/ready"]
      readyProc.running = true
    }
  }
  Process { id: readyProc }

  function power(action) {
    if (busy) return
    if (!Greetd.available) return console.log("preview: would", action)
    powerProc.command = ["systemctl", action]
    powerProc.running = true
  }
  Process { id: powerProc }
}
