import QtQuick
import QtQuick.Controls as QQC
import qs.bar.elsewhen.compat as Commons

// Omarchy's Ui TextField, reduced: a themed single-line field.
QQC.TextField {
  id: root

  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property bool hasCursor: false
  property real verticalPadding: 6

  font.family: Commons.Style.font.family
  font.pixelSize: Commons.Style.font.body
  color: foreground
  selectionColor: Commons.Util.alpha(accent, 0.35)
  selectedTextColor: foreground
  placeholderTextColor: Qt.darker(foreground, 1.6)
  leftPadding: 9
  rightPadding: 9
  topPadding: verticalPadding
  bottomPadding: verticalPadding

  background: Rectangle {
    color: Commons.Util.alpha(root.foreground, root.activeFocus ? 0.06 : 0.03)
    border.width: 1
    border.color: root.activeFocus || root.hovered || root.hasCursor ? root.accent : Commons.Util.alpha(root.foreground, 0.3)
    radius: Commons.Style.cornerRadius
  }
}
