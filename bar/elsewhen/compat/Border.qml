pragma Singleton
import QtQuick
import Quickshell

// Omarchy border specs reduced to { width, color }.
Singleton {
  function none() { return { width: 0, color: "transparent" } }
  function flat(color, width) { return { width: width === undefined ? 1 : width, color: color } }
  function controlSpec(state, foreground, accent) {
    return state === "normal" ? flat(Qt.rgba(foreground.r, foreground.g, foreground.b, 0.3), 1) : flat(accent, 1)
  }
  function left(spec) { return spec ? spec.width : 0 }
  function right(spec) { return spec ? spec.width : 0 }
  function top(spec) { return spec ? spec.width : 0 }
  function bottom(spec) { return spec ? spec.width : 0 }
}
