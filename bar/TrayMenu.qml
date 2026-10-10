import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.ui

// A tray item's menu, drawn by the shell so it matches everything else.
// It takes the place of the tray list, and submenus replace it in turn, with
// a row at the top to step back out.
ColumnLayout {
  id: root

  // The item's root menu; null while no menu is showing.
  property var handle: null
  property string title: ""
  // Submenus entered so far, below the root.
  property var path: []

  // Back was pressed at the root of the menu.
  signal exited()
  // An entry was triggered.
  signal done()

  onHandleChanged: path = []

  spacing: 0

  QsMenuOpener {
    id: opener
    menu: root.path.length > 0 ? root.path[root.path.length - 1] : root.handle
  }

  component Entry: Rectangle {
    id: entry
    property string label: ""
    property string leading: ""
    property string trailing: ""
    property bool dimmed: false
    property bool bold: false
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Theme.rowHeight
    radius: Theme.controlRadius
    color: mouse.containsMouse && !dimmed ? Theme.hover : "transparent"

    Label {
      id: lead
      anchors.left: parent.left
      anchors.leftMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      width: 16
      text: entry.leading
      color: Theme.accent
      elide: Text.ElideNone
    }

    Label {
      anchors.left: lead.right
      anchors.leftMargin: 4
      anchors.right: tail.left
      anchors.verticalCenter: parent.verticalCenter
      text: entry.label
      color: entry.dimmed ? Theme.dim : Theme.foreground
      font.bold: entry.bold
    }

    Label {
      id: tail
      anchors.right: parent.right
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      text: entry.trailing
      color: Theme.dim
      elide: Text.ElideNone
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: !entry.dimmed
      onClicked: entry.clicked()
    }
  }

  Entry {
    leading: Icons.chevronLeft
    label: root.path.length > 0 ? "Back" : root.title
    bold: root.path.length === 0
    onClicked: {
      if (root.path.length > 0) root.path = root.path.slice(0, -1)
      else root.exited()
    }
  }

  Item {
    Layout.fillWidth: true
    implicitHeight: 9
    Separator { anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
  }

  Repeater {
    model: opener.children

    Loader {
      id: row
      required property var modelData
      Layout.fillWidth: true
      sourceComponent: modelData.isSeparator ? separator : item

      Component {
        id: separator
        Item {
          implicitHeight: 9
          Separator { anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
        }
      }

      Component {
        id: item
        Entry {
          // Menus mark keyboard mnemonics with an underscore.
          label: String(row.modelData.text || "").replace(/_/g, "")
          leading: row.modelData.checkState === Qt.Checked ? Icons.check : ""
          trailing: row.modelData.hasChildren ? Icons.chevronRight : ""
          dimmed: !row.modelData.enabled
          onClicked: {
            if (row.modelData.hasChildren) {
              root.path = root.path.concat([row.modelData])
            } else {
              row.modelData.triggered()
              root.done()
            }
          }
        }
      }
    }
  }
}
