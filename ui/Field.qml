import QtQuick
import qs.theme

// Single-line text input.
Rectangle {
  id: root

  property alias text: input.text
  property string placeholder: ""
  property bool password: false
  // Also commit when the field loses focus, so clicking elsewhere or closing
  // the window does not throw away what was typed.
  property bool commitOnBlur: false
  signal accepted()
  signal cancelled()
  property bool _cancelled: false

  function focusInput() {
    input.forceActiveFocus()
  }

  implicitHeight: Theme.rowHeight
  radius: Theme.controlRadius
  color: Theme.alpha(Theme.foreground, 0.04)
  border.width: 1
  border.color: input.activeFocus ? Theme.accent : Theme.alpha(Theme.foreground, 0.25)

  Label {
    anchors.fill: input
    visible: input.text === ""
    text: root.placeholder
    color: Theme.dim
  }

  TextInput {
    id: input
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    verticalAlignment: TextInput.AlignVCenter
    clip: true
    color: Theme.foreground
    selectionColor: Theme.selection
    selectedTextColor: Theme.brightForeground
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    echoMode: root.password ? TextInput.Password : TextInput.Normal
    onAccepted: if (!root.commitOnBlur) root.accepted()
    onEditingFinished: if (root.commitOnBlur && !root._cancelled) root.accepted()
    Keys.onEscapePressed: {
      root._cancelled = true
      root.cancelled()
      root._cancelled = false
    }
  }
}
