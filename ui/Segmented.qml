import QtQuick
import qs.theme

// A few mutually exclusive choices side by side.
Row {
  id: root

  // [{ label, value, icon? }]
  property var options: []
  property var current: null
  signal picked(var value)

  spacing: 4

  Repeater {
    model: root.options

    TextButton {
      required property var modelData
      text: modelData.label
      icon: modelData.icon || ""
      selected: modelData.value === root.current
      onClicked: root.picked(modelData.value)
    }
  }
}
