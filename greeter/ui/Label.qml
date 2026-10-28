import QtQuick
import qs.theme

Text {
  textFormat: Text.PlainText
  color: Theme.foreground
  font.family: Theme.familyFor(text)
  font.pixelSize: Theme.fontSize
  elide: Text.ElideRight
  verticalAlignment: Text.AlignVCenter
}
