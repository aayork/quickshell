import QtQuick
import qs.theme

// A dashed hairline, across (default) or down when `vertical`.
Item {
  id: root

  property bool vertical: false
  property color color: Theme.line
  property int dash: 3
  property int gap: 3

  implicitWidth: vertical ? 1 : 0
  implicitHeight: vertical ? 0 : 1

  readonly property real span: vertical ? height : width

  Repeater {
    model: Math.max(0, Math.ceil(root.span / (root.dash + root.gap)))
    Rectangle {
      required property int index
      readonly property real at: index * (root.dash + root.gap)
      x: root.vertical ? 0 : at
      y: root.vertical ? at : 0
      width: root.vertical ? 1 : Math.min(root.dash, root.span - at)
      height: root.vertical ? Math.min(root.dash, root.span - at) : 1
      color: root.color
    }
  }
}
