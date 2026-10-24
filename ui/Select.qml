import QtQuick
import QtQuick.Layouts
import qs.theme

// Picks one of a few options. Shows the current one; click to unfold the
// rest in place, so it needs no window of its own.
ColumnLayout {
  id: root

  // [{ label, value }]
  property var options: []
  property var current: null
  property bool expanded: false
  signal picked(var value)

  spacing: 0

  component Option: Rectangle {
    id: row
    property string label: ""
    property string trailing: ""
    property bool selected: false
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Theme.rowHeight
    radius: Theme.controlRadius
    color: mouse.containsMouse ? Theme.hover : "transparent"

    Label {
      anchors.left: parent.left
      anchors.right: tail.left
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: row.label
      color: row.selected ? Theme.accent : Theme.foreground
    }

    Label {
      id: tail
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: row.trailing
      color: Theme.dim
      elide: Text.ElideNone
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: row.clicked()
    }
  }

  Rectangle {
    Layout.fillWidth: true
    implicitHeight: body.implicitHeight
    radius: Theme.controlRadius
    color: Theme.alpha(Theme.foreground, 0.04)
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.2)

    ColumnLayout {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: 0

      Option {
        label: {
          for (var i = 0; i < root.options.length; i++)
            if (root.options[i].value === root.current) return root.options[i].label
          return "None"
        }
        trailing: root.options.length > 1 ? (root.expanded ? Icons.chevronDown : Icons.chevronRight) : ""
        onClicked: if (root.options.length > 1) root.expanded = !root.expanded
      }

      Repeater {
        model: root.expanded ? root.options.filter(o => o.value !== root.current) : []

        Option {
          required property var modelData
          label: modelData.label
          // Report the pick before folding up: folding empties the model and
          // destroys this row, and nothing after that would run.
          onClicked: {
            var value = modelData.value
            root.picked(value)
            root.expanded = false
          }
        }
      }
    }
  }
}
