import QtQuick
import QtQuick.Layouts
import qs.theme

// Picks one of a few options. Shows the current one; click to unfold the
// rest in place, so it needs no window of its own. With `floating` the rest
// opens as a list over whatever is below instead of pushing it down.
ColumnLayout {
  id: root

  // [{ label, value, colors? }]; colors: a few swatches shown on the row.
  property var options: []
  property var current: null
  property bool expanded: false
  property bool floating: false
  // The option under the pointer while the list is open, else null.
  property var hoveredValue: null
  signal picked(var value)

  spacing: 0

  onExpandedChanged: {
    if (!expanded) hoveredValue = null
    else if (floating) place()
  }
  onVisibleChanged: if (!visible) expanded = false

  // The nearest scrolling area above this, which clips the list; the open
  // list is moved into it so it draws over the rows below instead of
  // pushing them down.
  function scroller() {
    for (var p = root.parent; p; p = p.parent)
      if (p.contentY !== undefined && p.contentItem !== undefined) return p
    return null
  }
  readonly property Item host: floating && expanded ? (scroller() || box) : box

  property real dropX: 0
  property real dropY: 0
  // Under the box, or above it when there's no room below.
  function place() {
    if (host === box) { dropX = 0; dropY = box.height + 4; return }
    var at = box.mapToItem(host, 0, 0)
    var below = host.height - at.y - box.height
    var up = drop.implicitHeight + 4 > below && at.y > below
    dropX = at.x
    dropY = up ? at.y - drop.implicitHeight - 4 : at.y + box.height + 4
  }
  Connections {
    target: root.host !== root.box && root.host ? root.host : null
    ignoreUnknownSignals: true
    function onContentYChanged() { root.place() }
    function onWidthChanged() { root.place() }
    function onHeightChanged() { root.place() }
  }

  component Option: Rectangle {
    id: row
    property string label: ""
    property string trailing: ""
    property bool selected: false
    property var colors: []
    signal clicked()
    signal hovered(bool on)

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

    Row {
      anchors.right: tail.left
      anchors.rightMargin: tail.text !== "" ? 8 : 0
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      Repeater {
        model: row.colors || []
        Rectangle {
          required property var modelData
          width: 10
          height: 10
          radius: 5
          color: modelData
          border.width: 1
          border.color: Theme.alpha(Theme.foreground, 0.25)
        }
      }
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
      onContainsMouseChanged: row.hovered(containsMouse)
    }
  }

  // Closes the floating list on a click anywhere else in the scroller.
  MouseArea {
    parent: root.host
    visible: root.floating && root.expanded && root.host !== box
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    z: 99
    onPressed: function(mouse) { root.expanded = false; mouse.accepted = true }
  }

  Rectangle {
    id: box
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
        colors: {
          for (var i = 0; i < root.options.length; i++)
            if (root.options[i].value === root.current) return root.options[i].colors || []
          return []
        }
        trailing: root.options.length > 1 ? (root.expanded ? Icons.chevronDown : Icons.chevronRight) : ""
        onClicked: if (root.options.length > 1) root.expanded = !root.expanded
      }

      Repeater {
        model: root.expanded && !root.floating ? root.options.filter(o => o.value !== root.current) : []

        Option {
          required property var modelData
          label: modelData.label
          colors: modelData.colors || []
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

    Rectangle {
      id: drop
      parent: root.host
      visible: root.floating && root.expanded
      z: 100
      width: box.width
      x: root.dropX
      y: root.dropY
      onImplicitHeightChanged: if (visible) root.place()
      implicitHeight: dropList.implicitHeight + 8
      radius: Theme.controlRadius
      color: Theme.background
      border.width: 1
      border.color: Theme.alpha(Theme.foreground, 0.2)

      ColumnLayout {
        id: dropList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        spacing: 0

        Repeater {
          model: root.floating && root.expanded ? root.options : []

          Option {
            required property var modelData
            label: modelData.label
            colors: modelData.colors || []
            selected: modelData.value === root.current
            onHovered: function(on) {
              if (on) root.hoveredValue = modelData.value
              else if (root.hoveredValue === modelData.value) root.hoveredValue = null
            }
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
}
