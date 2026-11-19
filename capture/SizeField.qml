import QtQuick
import qs.theme

// One number in the All-In-One size pill: an inset field you can type a
// size into (device pixels); Enter or leaving it applies the value.
Rectangle {
  id: root

  property int value: 0
  signal committed(int value)

  width: 58
  height: 28
  radius: Theme.controlRadius
  color: Theme.darkerBackground
  border.width: 1
  border.color: input.activeFocus ? Theme.accent : Theme.alpha(Theme.foreground, 0.2)

  TextInput {
    id: input
    anchors.fill: parent
    horizontalAlignment: TextInput.AlignHCenter
    verticalAlignment: TextInput.AlignVCenter
    color: Theme.foreground
    selectionColor: Theme.selection
    font.family: Theme.fontFamily
    font.pixelSize: 13
    validator: IntValidator { bottom: 1; top: 99999 }
    selectByMouse: true
    // Follows the area unless being typed in.
    text: activeFocus ? text : String(root.value)
    onAccepted: { root.committed(parseInt(text) || root.value); focus = false }
    onActiveFocusChanged: if (activeFocus) selectAll()
    Keys.onEscapePressed: focus = false
  }
}
