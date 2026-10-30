import QtQuick
import QtQuick.Layouts
import qs.theme

// Picks one of many: shows the current choice, and opens a filterable list
// over whatever is below when clicked (like Select's `floating`), so the page
// under it doesn't get pushed down. For lists too long for Select.
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

  spacing: 0
  onExpandedChanged: {
    filter.text = ""
    if (expanded) {
      place()
      filter.focusInput()
    }
  }
  onVisibleChanged: if (!visible) expanded = false

  // The nearest scrolling area above this; the open list is moved into it so
  // it draws over the rows below instead of pushing them down.
  function scroller() {
    for (var p = root.parent; p; p = p.parent)
      if (p.contentY !== undefined && p.contentItem !== undefined) return p
    return null
  }
  readonly property Item host: expanded ? (scroller() || head) : head

  property real dropX: 0
  property real dropY: 0
  // Under the box, or above it when there's no room below.
  function place() {
    if (host === head) { dropX = 0; dropY = head.height + 4; return }
    var at = head.mapToItem(host, 0, 0)
    var below = host.height - at.y - head.height
    var up = drop.implicitHeight + 4 > below && at.y > below
    dropX = at.x
    dropY = up ? at.y - drop.implicitHeight - 4 : at.y + head.height + 4
  }
  Connections {
    target: root.host !== head && root.host ? root.host : null
    ignoreUnknownSignals: true
    function onContentYChanged() { root.place() }
    function onWidthChanged() { root.place() }
    function onHeightChanged() { root.place() }
  }

  // Closes the list on a click anywhere else in the scroller.
  MouseArea {
    parent: root.host
    visible: root.expanded && root.host !== head
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    z: 99
    onPressed: function(mouse) { root.expanded = false; mouse.accepted = true }
  }

  Rectangle {
    id: head
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

  Rectangle {
    id: drop
    parent: root.host
    visible: root.expanded
    z: 100
    width: head.width
    x: root.dropX
    y: root.dropY
    implicitHeight: dropList.implicitHeight + 8
    height: implicitHeight
    onImplicitHeightChanged: if (visible) root.place()
    radius: Theme.controlRadius
    color: Theme.background
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.2)

    // Swallow clicks on the list's own padding so they don't reach the
    // click-away catcher underneath.
    MouseArea { anchors.fill: parent }

    ColumnLayout {
      id: dropList
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 4
      spacing: 4

      Field {
        id: filter
        visible: root.options.length > root.visibleRows
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
        Layout.fillWidth: true
        implicitHeight: Math.max(1, Math.min(count, root.visibleRows)) * Theme.rowHeight
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
  }
}
