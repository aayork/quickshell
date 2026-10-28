import QtQuick
import qs.theme

// Single-line text input: a white well, like the Windows 7 logon box, with a
// glossy blue arrow at the end that submits it.
Rectangle {
  id: root

  property alias text: input.text
  property string placeholder: ""
  property bool password: false
  signal accepted()
  signal cancelled()
  signal stepped(int step)  // Up/Down, which a one-line field has no use for

  function focusInput() {
    input.forceActiveFocus()
  }

  implicitHeight: Theme.rowHeight
  radius: height / 2
  border.width: 1
  border.color: input.activeFocus ? Theme.accent : Theme.alpha(Theme.foreground, 0.35)
  gradient: Gradient {
    GradientStop { position: 0; color: Qt.tint("#ffffff", Theme.alpha(Theme.foreground, 0.1)) }
    GradientStop { position: 0.3; color: "#ffffff" }
    GradientStop { position: 1; color: "#ffffff" }
  }

  // A soft blue glow while typing.
  Rectangle {
    anchors.fill: parent
    anchors.margins: -3
    radius: height / 2
    color: "transparent"
    border.width: 3
    border.color: Theme.alpha(Theme.accent, 0.25)
    visible: input.activeFocus
  }

  Label {
    anchors.fill: input
    visible: input.text === ""
    text: root.placeholder
    color: Theme.dim
  }

  TextInput {
    id: input
    anchors.fill: parent
    anchors.leftMargin: 14
    anchors.rightMargin: arrow.width + 8
    verticalAlignment: TextInput.AlignVCenter
    clip: true
    color: Theme.foreground
    selectionColor: Theme.selection
    selectedTextColor: Theme.brightForeground
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    echoMode: root.password ? TextInput.Password : TextInput.Normal
    onAccepted: root.accepted()
    Keys.onEscapePressed: root.cancelled()
    Keys.onUpPressed: root.stepped(-1)
    Keys.onDownPressed: root.stepped(1)
  }

  Gel {
    id: arrow
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: 3
    width: root.height - 6
    height: width
    opacity: root.enabled ? (arrowMouse.containsMouse ? 1 : 0.92) : 0.5

    Label {
      anchors.centerIn: parent
      text: String.fromCodePoint(0xF0054)
      color: "#ffffff"
      font.pixelSize: Theme.iconSize
      style: Text.Raised
      styleColor: Theme.alpha("#000000", 0.3)
      elide: Text.ElideNone
    }

    MouseArea {
      id: arrowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.accepted()
    }
  }
}
