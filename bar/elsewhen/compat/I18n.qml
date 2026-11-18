pragma Singleton
import QtQuick
import Quickshell
import "Strings.js" as Strings

// English only: Elsewhen's strings from Omarchy's English catalog.
Singleton {
  readonly property string formatLocale: Qt.locale().name.replace("_", "-") || "en-US"

  function t(key, fallback) {
    var value = Strings.strings[key]
    if (value && typeof value === "object") value = value.other
    if (typeof value === "string" && value.length > 0) return value
    return fallback !== undefined ? fallback : key
  }
  function tn(key, count, fallback) {
    var value = Strings.strings[key]
    if (value && typeof value === "object") value = Number(count) === 1 ? (value.one || value.other) : value.other
    if (typeof value === "string" && value.length > 0) return value
    return fallback !== undefined ? fallback : key
  }
  function formatNumber(value, decimals) {
    var n = Number(value)
    if (!isFinite(n)) return String(value)
    return decimals === undefined ? String(n) : n.toFixed(decimals)
  }
}
