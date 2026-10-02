import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme
import qs.ui

// Power menu. Anything that ends the session asks for a second press.
BarButton {
  id: root

  readonly property alias popup: popup
  property int cursor: 0
  // Action waiting for its second press.
  property string armed: ""

  function activate(index) {
    var action = Session.actions[index]
    cursor = index
    if (action.confirm && armed !== action.id) {
      armed = action.id
      disarm.restart()
      return
    }
    armed = ""
    popup.close()
    Session.run(action.id)
  }

  text: Icons.glyph(0xF0425)
  active: popup.open
  onClicked: popup.toggle()

  Timer {
    id: disarm
    interval: 3000
    onTriggered: root.armed = ""
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 200
    contentHeight: column.implicitHeight

    onOpenChanged: {
      root.cursor = 0
      root.armed = ""
    }

    ColumnLayout {
      id: column
      width: parent.width
      spacing: 0
      focus: true

      Keys.onPressed: function(event) {
        var count = Session.actions.length
        if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Tab) {
          root.cursor = (root.cursor + 1) % count
          root.armed = ""
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K || event.key === Qt.Key_Backtab) {
          root.cursor = (root.cursor + count - 1) % count
          root.armed = ""
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
          root.activate(root.cursor)
        } else {
          return
        }
        event.accepted = true
      }

      Repeater {
        model: Session.actions

        Rectangle {
          id: row
          required property var modelData
          required property int index

          readonly property bool armed: root.armed === modelData.id

          Layout.fillWidth: true
          implicitHeight: Theme.rowHeight + 4
          radius: Theme.controlRadius
          color: armed ? Theme.alpha(Theme.red, 0.2) : root.cursor === index ? Theme.hover : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10

            Label {
              text: Icons.glyph(row.modelData.icon)
              font.pixelSize: Theme.iconSize
              color: row.armed ? Theme.red : Theme.foreground
              horizontalAlignment: Text.AlignHCenter
              Layout.preferredWidth: 18
              elide: Text.ElideNone
            }
            Label {
              text: row.armed ? "Again to " + row.modelData.label.toLowerCase() : row.modelData.label
              color: row.armed ? Theme.red : Theme.foreground
              Layout.fillWidth: true
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
              if (root.cursor !== row.index) root.armed = ""
              root.cursor = row.index
            }
            onClicked: root.activate(row.index)
          }
        }
      }
    }
  }
}
