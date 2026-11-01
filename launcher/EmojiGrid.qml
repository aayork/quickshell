import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.ui

// The emoji picker's grid: a category bar, then big tiles in sections. The
// launcher owns the cursor and the keys; this lays out the rows it is given
// and works out where the arrow keys land.
ColumnLayout {
  id: root

  property var rows: []
  property int cursor: 0
  property int columns: 10
  // group name -> Nerd Font codepoint
  property var groupIcons: ({})

  signal hovered(int index)
  signal activated(int index)

  spacing: 0

  readonly property real cellWidth: Math.floor((width - 16) / columns)
  readonly property int cellHeight: 52

  // Header lines and lines of up to `columns` cells, plus where each cell and
  // each group sits in them.
  readonly property var layout: {
    var lines = []
    var lineOf = []
    var groups = []
    for (var i = 0; i < rows.length; i++) {
      var header = rows[i].header || ""
      if (header !== "") {
        lines.push({ header: header, cells: [] })
        groups.push({ name: header, start: i, line: lines.length - 1 })
      }
      var last = lines[lines.length - 1]
      if (!last || last.header !== "" || last.cells.length >= columns) {
        last = { header: "", cells: [] }
        lines.push(last)
      }
      last.cells.push(i)
      lineOf[i] = lines.length - 1
    }
    return { lines: lines, lineOf: lineOf, groups: groups }
  }

  readonly property int currentGroup: groupOf(cursor)

  function groupOf(index) {
    var groups = layout.groups
    var at = -1
    for (var g = 0; g < groups.length; g++) if (groups[g].start <= index) at = g
    return at
  }

  // Where an arrow key goes from `index`: dx steps along the reading order,
  // dy moves whole lines and keeps the column where it can.
  function step(index, dx, dy) {
    var count = rows.length
    if (count === 0) return 0
    if (dx !== 0) return Math.max(0, Math.min(count - 1, index + dx))
    var lines = layout.lines
    var line = layout.lineOf[index]
    var column = lines[line].cells.indexOf(index)
    var moves = Math.abs(dy)
    var direction = dy > 0 ? 1 : -1
    while (moves > 0) {
      var next = line + direction
      while (next >= 0 && next < lines.length && lines[next].cells.length === 0) next += direction
      if (next < 0 || next >= lines.length) break
      line = next
      moves--
    }
    var cells = lines[line].cells
    return cells[Math.min(column, cells.length - 1)]
  }

  // Start of the next or previous category. Going back from inside a
  // category lands on its own start first.
  function jump(index, direction) {
    var groups = layout.groups
    if (groups.length === 0) return index
    var g = Math.max(0, groupOf(index))
    if (direction < 0 && index > groups[g].start) return groups[g].start
    g = Math.max(0, Math.min(groups.length - 1, g + direction))
    return groups[g].start
  }

  // Keeps the cursor in view; a category start shows its heading too.
  property bool fromMouse: false
  onCursorChanged: reveal()
  // Later, so the list has the new lines before it is scrolled.
  onLayoutChanged: Qt.callLater(reveal)

  function reveal() {
    if (fromMouse) { fromMouse = false; return }
    var line = layout.lineOf[cursor]
    if (line === undefined) return
    if (cursor === 0) { view.positionViewAtBeginning(); return }
    var group = layout.groups.find(g => g.start === cursor)
    if (group) view.positionViewAtIndex(group.line, ListView.Beginning)
    else view.positionViewAtIndex(line, ListView.Contain)
  }

  // Category bar, only while browsing.
  Row {
    visible: root.layout.groups.length > 1
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.topMargin: 6
    Layout.bottomMargin: 2
    spacing: 2

    Repeater {
      model: root.layout.groups

      Rectangle {
        id: tab
        required property var modelData
        required property int index
        readonly property bool active: root.currentGroup === index

        width: 34
        height: 28
        radius: Theme.controlRadius
        color: active ? Theme.alpha(Theme.accent, 0.18) : tabMouse.containsMouse ? Theme.alpha(Theme.foreground, 0.07) : "transparent"

        Label {
          anchors.centerIn: parent
          text: Icons.glyph(root.groupIcons[tab.modelData.name] || 0xF01F5)
          font.pixelSize: Theme.iconSize
          color: tab.active ? Theme.accent : Theme.dim
          elide: Text.ElideNone
        }

        MouseArea {
          id: tabMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.hovered(tab.modelData.start)
        }
      }
    }
  }

  ListView {
    id: view
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    // About six lines of tiles. Fixed, so the card does not jump as you type.
    implicitHeight: 6 * root.cellHeight + 30
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: 400
    model: root.layout.lines

    delegate: Item {
      id: line
      required property var modelData
      width: view.width
      height: modelData.header !== "" ? 28 : root.cellHeight

      SectionHeader {
        visible: line.modelData.header !== ""
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: line.modelData.header
        font.letterSpacing: 0
      }

      Row {
        visible: line.modelData.header === ""
        Repeater {
          model: line.modelData.cells

          Item {
            id: cell
            required property int modelData
            readonly property var entry: root.rows[modelData]
            readonly property bool current: root.cursor === modelData

            width: root.cellWidth
            height: root.cellHeight

            Rectangle {
              anchors.fill: parent
              anchors.margins: 2
              radius: Theme.controlRadius + 2
              color: cell.current ? Theme.alpha(Theme.accent, 0.2) : cellMouse.containsMouse ? Theme.alpha(Theme.foreground, 0.07) : "transparent"
              border.width: cell.current ? 1 : 0
              border.color: Theme.alpha(Theme.accent, 0.55)
            }

            Text {
              anchors.centerIn: parent
              text: cell.entry ? cell.entry.glyph : ""
              font.pixelSize: 30
              scale: cell.current ? 1.08 : 1
              Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            }

            MouseArea {
              id: cellMouse
              anchors.fill: parent
              hoverEnabled: true
              onPositionChanged: if (root.cursor !== cell.modelData) { root.fromMouse = true; root.hovered(cell.modelData) }
              onClicked: root.activated(cell.modelData)
            }
          }
        }
      }
    }
  }
}
