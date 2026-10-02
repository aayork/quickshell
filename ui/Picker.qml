import QtQuick
import QtQuick.Layouts
import qs.theme

// Picks one of many: shows the current choice, and unfolds into a filterable
// list in place when clicked. For lists too long for Select.
ColumnLayout {
  id: root

  // Strings, or { label, value } objects.
  property var options: []
  property var current: null
  property bool expanded: false
  property int visibleRows: 7
  signal picked(var value)

  function valueOf(option) { return typeof option === "object" ? option.value : option }
  function labelOf(option) { return typeof option === "object" ? option.label : String(option) }

  readonly property string currentLabel: {
    for (var i = 0; i < options.length; i++)
      if (valueOf(options[i]) === current) return labelOf(options[i])
    return current ? String(current) : "None"
  }
  readonly property var filtered: {
    var needle = filter.text.trim().toLowerCase()
    return needle === "" ? options : options.filter(o => labelOf(o).toLowerCase().indexOf(needle) !== -1)
  }

  spacing: 4
  onExpandedChanged: {
    filter.text = ""
    if (expanded) filter.focusInput()
  }

  Rectangle {
    Layout.fillWidth: true
    implicitHeight: Theme.rowHeight
    radius: Theme.controlRadius
    color: headMouse.containsMouse ? Theme.hover : Theme.alpha(Theme.foreground, 0.04)
    border.width: 1
    border.color: root.expanded ? Theme.accent : Theme.alpha(Theme.foreground, 0.2)

    Label {
      anchors.left: parent.left
      anchors.right: chevron.left
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: root.currentLabel
    }
    Label {
      id: chevron
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: root.expanded ? Icons.chevronDown : Icons.chevronRight
      color: Theme.dim
      elide: Text.ElideNone
    }
    MouseArea {
      id: headMouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: root.expanded = !root.expanded
    }
  }

  Field {
    id: filter
    visible: root.expanded && root.options.length > root.visibleRows
    Layout.fillWidth: true
    placeholder: "Filter"
    onCancelled: root.expanded = false
    onAccepted: {
      if (root.filtered.length === 0) return
      root.picked(root.valueOf(root.filtered[0]))
      root.expanded = false
    }
  }

  ListView {
    id: list
    visible: root.expanded
    Layout.fillWidth: true
    implicitHeight: Math.min(count, root.visibleRows) * Theme.rowHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: root.expanded ? root.filtered : []

    delegate: Rectangle {
      id: option
      required property var modelData

      readonly property bool chosen: root.valueOf(modelData) === root.current

      width: list.width
      height: Theme.rowHeight
      radius: Theme.controlRadius
      color: optionMouse.containsMouse ? Theme.hover : "transparent"

      Label {
        anchors.left: parent.left
        anchors.right: tick.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.labelOf(option.modelData)
        color: option.chosen ? Theme.accent : Theme.foreground
      }
      Label {
        id: tick
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: option.chosen ? Icons.check : ""
        color: Theme.accent
        elide: Text.ElideNone
      }
      MouseArea {
        id: optionMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
          root.picked(root.valueOf(option.modelData))
          root.expanded = false
        }
      }
    }
  }
}
