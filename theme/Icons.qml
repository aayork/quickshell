pragma Singleton
import QtQuick
import Quickshell

// Nerd Font glyphs by codepoint (Material Design set), checked against
// nerd-fonts' glyphnames.json. Kept as numbers so a wrong one is easy to spot.
Singleton {
  function glyph(code) { return String.fromCodePoint(code) }

  readonly property string wifi1: glyph(0xF091F)
  readonly property string wifi2: glyph(0xF0922)
  readonly property string wifi3: glyph(0xF0925)
  readonly property string wifi4: glyph(0xF0928)
  readonly property string wifiNone: glyph(0xF092F)
  readonly property string wifiOff: glyph(0xF05AA)
  readonly property string ethernet: glyph(0xF0200)
  readonly property string lock: glyph(0xF033E)
  readonly property string check: glyph(0xF012C)
  readonly property string close: glyph(0xF0156)
  readonly property string chevronRight: glyph(0xF0142)
  readonly property string chevronDown: glyph(0xF0140)
  readonly property string chevronLeft: glyph(0xF0141)

  readonly property string volumeHigh: glyph(0xF057E)
  readonly property string volumeMedium: glyph(0xF0580)
  readonly property string volumeLow: glyph(0xF057F)
  readonly property string volumeOff: glyph(0xF0581)
  readonly property string microphone: glyph(0xF036C)
  readonly property string microphoneOff: glyph(0xF036D)

  readonly property string bluetooth: glyph(0xF00AF)
  readonly property string bluetoothOff: glyph(0xF00B2)
  readonly property string bluetoothConnected: glyph(0xF00B1)

  readonly property string music: glyph(0xF0387)
  readonly property string spotify: glyph(0xF04C7)
  readonly property string previous: glyph(0xF04AE)
  readonly property string next: glyph(0xF04AD)
  readonly property string play: glyph(0xF040A)
  readonly property string pause: glyph(0xF03E4)

  function wifi(strength) {
    if (strength >= 0.75) return wifi4
    if (strength >= 0.5) return wifi3
    if (strength >= 0.25) return wifi2
    return wifi1
  }

  function volume(level, muted) {
    if (muted || level <= 0) return volumeOff
    if (level < 0.34) return volumeLow
    if (level < 0.67) return volumeMedium
    return volumeHigh
  }
}
