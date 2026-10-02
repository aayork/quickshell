import QtQuick
import qs.theme

// A scrollbar for a Flickable: shows where you are, and can be dragged.
// Only there while the content is taller than the view.
Item {
  id: root

  required property Flickable flickable

  readonly property real ratio: flickable.visibleArea.heightRatio
  readonly property bool needed: ratio > 0 && ratio < 1

  visible: needed
  width: 6

  Rectangle {
    anchors.fill: parent
    radius: 3
    color: Theme.alpha(Theme.foreground, 0.06)
  }

  Rectangle {
    id: thumb
    y: root.flickable.visibleArea.yPosition * root.height
    width: parent.width
    height: Math.max(24, root.ratio * root.height)
    radius: 3
    color: Theme.alpha(Theme.foreground, drag.pressed ? 0.55 : drag.containsMouse ? 0.4 : 0.25)
  }

  MouseArea {
    id: drag
    anchors.fill: parent
    anchors.leftMargin: -4
    anchors.rightMargin: -4
    hoverEnabled: true
    preventStealing: true

    function scrollTo(y) {
      var range = root.flickable.contentHeight - root.flickable.height
      var travel = root.height - thumb.height
      if (range <= 0 || travel <= 0) return
      root.flickable.contentY = Math.max(0, Math.min(range, (y - thumb.height / 2) / travel * range))
    }

    onPressed: function(event) { scrollTo(event.y) }
    onPositionChanged: function(event) { if (pressed) scrollTo(event.y) }
  }
}
