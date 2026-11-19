import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.ui

// The right-click menu of a capture card, styled as the shell's menus.
Rectangle {
  id: root

  required property string path
  signal done()

  readonly property var items: [
    { label: "Copy", run: () => { Captures.copy(root.path); Captures.dismiss(root.path) } },
    { label: "Save", run: () => { Captures.save(root.path); Captures.dismiss(root.path) } },
    { label: "Save As…", run: () => Captures.saveAs(root.path) },
    { label: Captures.isVideo(root.path) ? "Open" : "Annotate", run: () => Captures.edit(root.path) },
    { label: "Pin to Screen", hidden: Captures.isVideo(root.path), run: () => Captures.pin(root.path) },
    { label: "Show in Files", run: () => Quickshell.execDetached(["xdg-open", root.path.replace(/\/[^\/]*$/, "")]) },
    { label: "Move to Trash", danger: true, run: () => Captures.remove(root.path) },
    { label: "Close", run: () => Captures.dismiss(root.path) }
  ]

  width: 170
  height: list.implicitHeight + 8
  radius: Theme.radius
  color: Theme.background
  border.width: Theme.borderWidth
  border.color: Theme.accent

  Column {
    id: list
    x: 4
    y: 4
    width: parent.width - 8

    Repeater {
      model: root.items.filter(i => !i.hidden)

      Rectangle {
        required property var modelData
        width: list.width
        height: 24
        radius: Theme.controlRadius
        color: itemMouse.containsMouse ? (modelData.danger ? Theme.alpha(Theme.red, 0.2) : Theme.selection) : "transparent"

        Label {
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.label
          color: parent.modelData.danger ? Theme.red : itemMouse.containsMouse ? Theme.brightForeground : Theme.foreground
          font.pixelSize: Theme.fontSmall
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
