import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.ui

// A tray item's menu, drawn by the shell so it matches everything else.
// Submenus replace the list in place, with a row to step back out.
Popup {
  id: root

  property Item target: null
  // Menu handles from the item's root menu down to the one on screen.
  property var path: []

  function show(item, handle) {
    target = item
    path = [handle]
    open = true
  }

  anchorItem: target
  contentWidth: 240
  contentHeight: column.implicitHeight

  QsMenuOpener {
    id: opener
    menu: root.path.length > 0 ? root.path[root.path.length - 1] : null
  }

  component Entry: Rectangle {
    id: entry
    property string label: ""
    property string leading: ""
    property string trailing: ""
    property bool dimmed: false
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

  ColumnLayout {
    id: column
    width: parent.width
    spacing: 0

    Entry {
      visible: root.path.length > 1
      leading: Icons.chevronLeft
      label: "Back"
      onClicked: root.path = root.path.slice(0, -1)
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
                root.close()
              }
            }
          }
        }
      }
    }
  }
}
