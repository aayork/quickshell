import QtQuick

Rectangle {
  property var borderSpec: null
  border.width: borderSpec ? borderSpec.width : 0
  border.color: borderSpec ? borderSpec.color : "transparent"
}
