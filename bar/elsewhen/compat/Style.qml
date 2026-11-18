pragma Singleton
import QtQuick
import Quickshell
import qs.theme

// The slice of Omarchy's Style that Elsewhen reads, at Omarchy's default
// scale (body text 12px, like Theme.fontSize), so its measurements carry over.
Singleton {
  readonly property int cornerRadius: Theme.radius

  function spaceReal(px) {
    var n = Number(px)
    return isFinite(n) && n > 0 ? n : 0
  }
  function space(px) {
    var n = spaceReal(px)
    return n <= 0 ? 0 : Math.max(1, Math.round(n))
  }
  function duration(ms) { return ms }

  readonly property var easeOut: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]

  readonly property QtObject spacing: QtObject {
    readonly property int xs: 3
    readonly property int sm: 4
    readonly property int md: 6
    readonly property int lg: 8
    readonly property int xl: 10
    readonly property int popupRowHeight: 28
    readonly property int rowPaddingX: 12
    readonly property int panelGap: 14
    readonly property int controlPaddingX: 8
    readonly property int controlPaddingY: 4
  }

  readonly property QtObject font: QtObject {
    readonly property string family: Theme.fontFamily
    readonly property int caption: 10
    readonly property int bodySmall: 11
    readonly property int body: 12
    readonly property int subtitle: 13
    readonly property int title: 14
    readonly property int heading: 16
    readonly property int display: 24
    readonly property int icon: 14
  }

  readonly property QtObject bar: QtObject {
    readonly property int statusSlot: Theme.barIconSlot
  }

  function hoverFillFor(foreground, accent) { return Theme.alpha(foreground, 0.08) }
  function focusFillFor(foreground, accent) { return Theme.alpha(foreground, 0.12) }
  function selectedFillFor(foreground, accent) { return Theme.alpha(foreground, 0.16) }
}
