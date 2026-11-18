pragma Singleton
import QtQuick
import Quickshell

Singleton {
  function clamp(value, min, max) {
    var n = Number(value)
    if (!isFinite(n)) return min
    return Math.max(min, Math.min(max, n))
  }
  function alpha(c, opacity) {
    var a = clamp(opacity, 0, 1)
    if (!c) return Qt.rgba(0, 0, 0, a)
    if (typeof c === "string") c = Qt.color(c)
    return Qt.rgba(c.r, c.g, c.b, a)
  }
  function execArgv(argv) {
    Quickshell.execDetached(["bash", "-lc", 'exec "$@"', "bash"].concat(argv))
  }
}
