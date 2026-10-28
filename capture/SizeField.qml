import QtQuick
import qs.theme

// One number in the All-In-One size pill: a dark inset field you can type a
// size into (device pixels); Enter or leaving it applies the value.
Rectangle {
  id: root

  property int value: 0
  signal committed(int value)

  width: 58
  height: 28
  radius: 7
  color: Theme.alpha("#000000", 0.35)
  border.width: 1
  border.color: input.activeFocus ? Theme.alpha("#ffffff", 0.45) : Theme.alpha("#ffffff", 0.08)

  TextInput {
    id: input
    anchors.fill: parent
    horizontalAlignment: TextInput.AlignHCenter
    verticalAlignment: TextInput.AlignVCenter
    color: "#ffffff"
    selectionColor: Theme.alpha("#ffffff", 0.3)
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
