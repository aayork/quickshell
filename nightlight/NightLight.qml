import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "Sun.js" as Sun

// Warms the screen at night through hyprsunset. On the "sunset" schedule the
// times come from where the system timezone says this machine is.
Scope {
  id: root

  readonly property int neutral: 6000
  readonly property string schedule: Config.nightlight.schedule
  readonly property int warmth: Math.max(2500, Math.min(5500, Config.nightlight.temperature))

  // Whether the tint is on right now.
  property bool active: false
  // What the schedule last decided. A manual toggle holds until this changes.
  property var scheduled: null
  property real latitude: NaN
  property real longitude: NaN

  function minutes(text) {
    var parts = String(text).split(":")
    return Number(parts[0]) * 60 + Number(parts[1] || 0)
  }

  // [start, end] in minutes after midnight, or null when there is no schedule.
  function window() {
    if (schedule === "custom") return [minutes(Config.nightlight.start), minutes(Config.nightlight.end)]
    if (schedule === "sunset" && !isNaN(latitude)) {
      var sun = Sun.sunTimes(new Date(), latitude, longitude)
      return [sun.sunset, sun.sunrise]
    }
    return null
  }

  function evaluate() {
    var span = window()
    if (!span) {
      if (schedule === "off" && scheduled !== null) set(false)
      scheduled = null
      return
    }
    var now = new Date()
    var wanted = Sun.inWindow(now.getHours() * 60 + now.getMinutes(), span[0], span[1])
    if (wanted === scheduled) return
    scheduled = wanted
    set(wanted)
  }

  function set(on) {
    active = on
    apply.temperature = on ? warmth : neutral
    if (apply.running) apply.again = true
    else apply.running = true
  }

  onScheduleChanged: { scheduled = null; evaluate() }
  onWarmthChanged: if (active) set(true)
  onLatitudeChanged: { scheduled = null; evaluate() }

  Connections {
    target: Config.nightlight
    function onStartChanged() { root.scheduled = null; root.evaluate() }
    function onEndChanged() { root.scheduled = null; root.evaluate() }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.evaluate()
  }

  // Starts hyprsunset if it is not there yet, then sets the temperature.
  Process {
    id: apply
    property int temperature: root.neutral
    property bool again: false
    command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null || { setsid -f hyprsunset >/dev/null 2>&1; sleep 1; }; hyprctl hyprsunset temperature \"$1\"", "sh", String(temperature)]
    onExited: {
      if (!again) return
      again = false
      running = true
    }
  }

  // The timezone's reference city is close enough to say when the sun sets.
  Process {
    running: true
    command: ["sh", "-c", "tz=$(timedatectl show -p Timezone --value 2>/dev/null); [ -n \"$tz\" ] || tz=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||'); awk -F'\\t' -v tz=\"$tz\" '$3 == tz { print $2; exit }' /usr/share/zoneinfo/zone1970.tab"]
    stdout: StdioCollector {
      onStreamFinished: {
        var place = Sun.parseIsoCoordinates(text.trim())
        if (!place) return
        root.longitude = place.longitude
        root.latitude = place.latitude
      }
    }
  }

  IpcHandler {
    target: "nightlight"
    function toggle(): void { root.set(!root.active) }
    function status(): string {
      var span = root.window()
      return JSON.stringify({ active: root.active, schedule: root.schedule, temperature: root.warmth, window: span })
    }
  }
}
