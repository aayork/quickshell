pragma Singleton
import QtQuick
import Quickshell

// One bar popup at a time. The bar also reads this to stay out while a popup
// it opened is still showing.
Singleton {
  property var active: null

  // Ask the bar on the focused monitor to open one of its popups by name.
  signal requested(string name)
  function request(name) { requested(name) }

  function opened(popup) {
    if (active && active !== popup) active.open = false
    active = popup
  }

  function closed(popup) {
    if (active === popup) active = null
  }
}
