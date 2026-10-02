import QtQuick
import QtQuick.Layouts
import qs.theme

// A whole number with a button either side.
RowLayout {
  id: root

  property int value: 0
  property int from: 0
  property int to: 100
  property int step: 1
  property string suffix: ""
  // What is shown; override when the number needs converting first.
  property string display: value + suffix
  signal moved(int value)

  spacing: 4

  IconButton {
    icon: "−"
    enabled: root.value > root.from
    onClicked: root.moved(Math.max(root.from, root.value - root.step))
  }
  Label {
    text: root.display
    horizontalAlignment: Text.AlignHCenter
    Layout.preferredWidth: 60
    elide: Text.ElideNone
  }
  IconButton {
    icon: "+"
    enabled: root.value < root.to
    onClicked: root.moved(Math.min(root.to, root.value + root.step))
  }
}
