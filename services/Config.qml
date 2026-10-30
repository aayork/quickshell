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
  readonly property alias media: adapter.media
  readonly property alias jot: adapter.jot
  readonly property alias features: adapter.features

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
        property var zones: []
      }

      property JsonObject bar: JsonObject {
        // Frosted strip of wallpaper behind the bar.
        property bool glass: true
        // How much of the theme background the bar keeps, 0 (clear) to 1.
        property real tint: 0
        // Right-hand icons, left to right, as dragged on the bar. Names as in
        // bar/Bar.qml's defaultOrder; empty or missing ones fall back to it.
        property var order: []
      }

      // Widgets for particular hardware or accounts, off unless turned on:
      // Bose headphones, a Razer mouse (OpenRazer), Things 3 (things-cli).
      property JsonObject features: JsonObject {
        property bool bose: false
        property bool mouse: false
        property bool things: false
      }

      property JsonObject media: JsonObject {
        // A player that starts playing pauses the others.
        property bool exclusive: false
      }

      // Jot, the scratchpad under the bar's note button.
      property JsonObject jot: JsonObject {
        // 20% smaller than Antinote's 360 x 412 note.
        property int width: 288
        property int height: 330
        property int fontSize: 14
        // Where the note was dragged to, from its place under the bar button.
        property real offsetX: 0
        property real offsetY: 0
        // Line height as a multiple of the font size; Antinote's is about 1.63.
        property real lineSpacing: 1.63
        // Colours: "antinote" or one of Antinote's themes (services/JotThemes.js).
        property string theme: "antinote"
        // Behind the text: "none", "ruled" (lined), "lines" (a grid) or "dots".
        property string paper: "none"
        // "last" (the note you were on) or "newest".
        property string openOn: "last"
        // Notes untouched this many days go away; 0 keeps them.
        property int autoDeleteDays: 30
        property bool swipeInvert: false
        property string exportDir: "~/Documents/Jot"
        // Daily euro reference rates from the European Central Bank, for
        // "32 USD to JPY". Jot's only connection, so off until switched on.
        property bool currency: false
        // Words that switch a note's feature on, comma-separated.
        property JsonObject keywords: JsonObject {
          property string math: "math, calc, calcs"
          property string list: "list, todo"
          property string sum: "sum, total"
          property string avg: "avg, average"
          property string count: "count"
          property string timer: "timer"
          property string stopwatch: "stopwatch"
          property string pomodoro: "pomodoro, pomo"
        }
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
