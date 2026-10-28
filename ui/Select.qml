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
    radius: 3
    // Vista menu highlight: pale blue with a blue edge.
    color: mouse.containsMouse ? "#dcebfc" : "transparent"
    border.width: mouse.containsMouse ? 1 : 0
    border.color: "#7da2ce"

    Label {
      anchors.left: parent.left
      anchors.right: tail.left
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: row.label
      color: row.selected ? "#0b4f86" : "#1e1e1e"
    }

    Label {
      id: tail
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: row.trailing
      color: "#4a4a4a"
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
    // A Vista drop-down: a silver button face on top, a white menu below
    // it while open.
    radius: 3
    color: "#ffffff"
    border.width: 1
    border.color: "#8e8f8f"

    VistaFace {
      width: parent.width
      height: Theme.rowHeight
      hovered: headerHover.hovered
      lit: root.expanded
      HoverHandler { id: headerHover }
    }

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
