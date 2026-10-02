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

      property JsonObject clock: JsonObject {
        property string format: "ddd MMM d h:mm AP"
      }
    }
  }
}
