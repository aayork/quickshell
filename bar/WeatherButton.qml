import QtQuick
import qs.services
import qs.theme
import qs.ui

// Current conditions on the bar: the condition glyph and the temperature.
// Click to open the weather window.
BarButton {
  id: root

  visible: Weather.ready
  active: Weather.windowOpen
  minimumWidth: 0
  text: Weather.icon + " " + Weather.temperature
  fontSize: Theme.fontSize
  onClicked: Weather.toggleWindow()
}
