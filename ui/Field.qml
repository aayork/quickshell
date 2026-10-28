import QtQuick
import qs.theme

// Single-line text input.
Rectangle {
  id: root

  property alias text: input.text
  property string placeholder: ""
  property bool password: false
  signal accepted()
  signal cancelled()

  function focusInput() {
    input.forceActiveFocus()
  }

  implicitHeight: Theme.rowHeight
  radius: Theme.controlRadius
  // A white well with a faint shade along its top edge, ringed in blue
  // while typing.
  border.width: 1
  border.color: input.activeFocus ? Theme.accent : Theme.alpha(Theme.foreground, 0.25)
  gradient: Gradient {
    GradientStop { position: 0; color: Qt.tint("#ffffff", Theme.alpha(Theme.foreground, 0.08)) }
    GradientStop { position: 0.25; color: "#ffffff" }
    GradientStop { position: 1; color: "#ffffff" }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: -3
    radius: root.radius + 3
    color: "transparent"
    border.width: 3
    border.color: Theme.alpha(Theme.accent, 0.22)
    visible: input.activeFocus
  }

  Label {
    anchors.fill: input
    visible: input.text === ""
    text: root.placeholder
    color: "#6d8597"
  }

  TextInput {
    id: input
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    verticalAlignment: TextInput.AlignVCenter
    clip: true
    // The well is white whatever the theme, so the text is always dark.
    color: "#0b2540"
    selectionColor: Theme.alpha(Theme.accent, 0.35)
    selectedTextColor: "#0b2540"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    echoMode: root.password ? TextInput.Password : TextInput.Normal
    onAccepted: root.accepted()
    Keys.onEscapePressed: root.cancelled()
  }
}
