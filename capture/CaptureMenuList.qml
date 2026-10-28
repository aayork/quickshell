import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.ui

// The right-click menu of a capture card: a compact dark list.
Rectangle {
  id: root

  required property string path
  signal done()

  readonly property var items: [
    { label: "Copy", run: () => { Captures.copy(root.path); Captures.dismiss(root.path) } },
    { label: "Save", run: () => { Captures.save(root.path); Captures.dismiss(root.path) } },
    { label: "Save As…", run: () => Captures.saveAs(root.path) },
    { label: "Annotate", run: () => Captures.edit(root.path) },
    { label: "Pin to Screen", run: () => Captures.pin(root.path) },
    { label: "Show in Files", run: () => Quickshell.execDetached(["xdg-open", root.path.replace(/\/[^\/]*$/, "")]) },
    { label: "Move to Trash", danger: true, run: () => Captures.remove(root.path) },
    { label: "Close", run: () => Captures.dismiss(root.path) }
  ]

  width: 150
  height: list.implicitHeight + 8
  radius: 7
  color: Theme.alpha("#1c1c1e", 0.96)
  border.width: 1
  border.color: Theme.alpha("#ffffff", 0.14)

  Column {
    id: list
    x: 4
    y: 4
    width: parent.width - 8

    Repeater {
      model: root.items

      Rectangle {
        required property var modelData
        width: list.width
        height: 15
        radius: 4
        color: itemMouse.containsMouse ? (modelData.danger ? Theme.red : Theme.accent) : "transparent"

        Label {
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.label
          color: itemMouse.containsMouse ? "#ffffff" : parent.modelData.danger ? Theme.red : "#f0f0f0"
          font.pixelSize: 10
          elide: Text.ElideNone
        }

        MouseArea {
          id: itemMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            root.done()
            parent.modelData.run()
          }
        }
      }
    }
  }
}
