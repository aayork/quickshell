import QtQuick
import QtQuick.Controls
import qs.bar.elsewhen.compat as Commons

ToolTip {
  id: root

  property string fontFamily: Commons.Style.font.family
  property real fontSize: Commons.Style.font.bodySmall

  delay: 400
  padding: 0

  background: Rectangle {
    color: Commons.Color.tooltip.background
    border.width: 1
    border.color: Commons.Color.tooltip.border
    radius: Commons.Style.cornerRadius
  }

  contentItem: Text {
    textFormat: Text.PlainText
    text: root.text
    color: Commons.Color.tooltip.text
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    wrapMode: Text.WordWrap
    leftPadding: 9; rightPadding: 9; topPadding: 5; bottomPadding: 5
  }
}
