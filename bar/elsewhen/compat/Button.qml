import QtQuick
import qs.bar.elsewhen.compat as Commons

// A text button: Omarchy's Ui Button, reduced to what Elsewhen sets.
Rectangle {
  id: root

  property string text: ""
  property bool hasCursor: false
  property bool bordered: false
  property color foreground: Commons.Color.foreground
  property string fontFamily: Commons.Style.font.family
  property real fontSize: Commons.Style.font.body

  signal clicked()

  readonly property bool hot: mouseArea.containsMouse || hasCursor

  implicitWidth: label.implicitWidth + 16
  implicitHeight: label.implicitHeight + 8
  radius: Commons.Style.cornerRadius
  color: mouseArea.pressed ? Commons.Util.alpha(foreground, 0.16)
    : hot ? Commons.Util.alpha(foreground, 0.08) : "transparent"
  border.width: bordered || hot ? 1 : 0
  border.color: hot ? Commons.Color.accent : Commons.Util.alpha(foreground, 0.3)
  Behavior on color { ColorAnimation { duration: 120 } }

  Text {
    id: label
    anchors.centerIn: parent
    width: Math.min(implicitWidth, root.width - 16)
    textFormat: Text.PlainText
    text: root.text
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    elide: Text.ElideRight
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
