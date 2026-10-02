pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Settings, kept in ~/.config/aayork-quickshell/config.json. Edit the file or
// set a property here; either way the other follows.
Singleton {
  id: root

  readonly property alias nightlight: adapter.nightlight
  readonly property alias idle: adapter.idle
  readonly property alias clock: adapter.clock
  readonly property alias screensaver: adapter.screensaver
  readonly property alias bar: adapter.bar
  readonly property alias windows: adapter.windows

  FileView {
    path: Quickshell.env("HOME") + "/.config/aayork-quickshell/config.json"
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    // First run: write the defaults out so there is a file to edit.
    onLoadFailed: writeAdapter()

    JsonAdapter {
      id: adapter

      property JsonObject nightlight: JsonObject {
        // "off", "sunset" (sunset to sunrise) or "custom" (start to end).
        property string schedule: "sunset"
        // Kelvin; lower is warmer. 6000 is no tint.
        property int temperature: 5250
        property string start: "20:00"
        property string end: "07:00"
      }

      property JsonObject idle: JsonObject {
        // Seconds without input.
        property int screensaver: 300
        property int lock: 450
        // Seconds an untouched lock screen stays lit.
        property int blank: 20
      }

      property JsonObject screensaver: JsonObject {
        // Off: the screen just locks when its time comes.
        property bool enabled: true
        // Folder of videos to play, shuffled.
        property string folder: "~/Videos/aerial"
        property bool sound: false
      }

      property JsonObject clock: JsonObject {
        property string format: "ddd MMM d h:mm AP"
        // Other places shown in the clock popup: [{ zone, label }].
        property var zones: [{ zone: "Asia/Seoul", label: "Seoul" }]
      }

      property JsonObject bar: JsonObject {
        // Frosted strip of wallpaper behind the bar.
        property bool glass: true
        // How much of the theme background the bar keeps, 0 (clear) to 1.
        property real tint: 0
      }

      // Hyprland window look; applied by bin/window-style.
      property JsonObject windows: JsonObject {
        property int rounding: 0
        property int gapsIn: 2
        property int gapsOut: 4
        property int border: 1
        property bool shadow: false
        // "off", "minimal" or "full".
        property string animations: "minimal"
      }
    }
  }
}
