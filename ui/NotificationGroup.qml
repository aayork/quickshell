import QtQuick
import QtQuick.Layouts
import qs.services
import qs.theme

// One app's notifications in the clock popup, stacked like iOS: the newest
// on top with the rest peeking out underneath. Clicking the stack fans it
// out into the full list; "Show less" folds it back.
Item {
  id: root

  // { key, name, icon, entries } from Notifs.groups.
  required property var group
  // Turns a timestamp into "5m", "2h"…; the clock popup owns the clock.
  property var ago: t => ""
  property bool expanded: false

  readonly property int count: group.entries.length
  // How many cards peek out under the top one while folded.
  readonly property int layers: Math.min(count - 1, 2)
  readonly property int peek: 6

  implicitHeight: expanded ? list.implicitHeight : topCard.implicitHeight + layers * peek

  // Folded: the newest card, with up to two slimmer cards showing below it.
  Item {
    anchors.fill: parent
    visible: !root.expanded

    Repeater {
      model: root.layers
      Rectangle {
        required property int index
        readonly property int depth: index + 1
        z: -depth
        x: depth * 8
        width: root.width - depth * 16
        height: topCard.radius * 2
        y: topCard.height + depth * root.peek - height
        radius: topCard.radius
        color: Qt.tint(Theme.background, Theme.alpha(Theme.foreground, 0.07 - depth * 0.02))
      }
    }

    Card {
      id: topCard
      width: parent.width
      entry: root.group.entries[0]
      more: root.count - 1
      onOpen: if (root.count > 1) root.expanded = true
    }
  }

  // Unfolded: a header, then every card.
  ColumnLayout {
    id: list
    width: parent.width
    visible: root.expanded
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 2
      spacing: 6

      Label {
        text: root.group.name
        color: Theme.brightForeground
        font.bold: true
        Layout.fillWidth: true
      }
      Pill {
        text: Icons.chevronDown + "  Show less"
        onClicked: root.expanded = false
      }
      Pill {
        text: Icons.close
        onClicked: Notifs.clearGroup(root.group.key)
      }
    }

    Repeater {
      model: root.expanded ? root.group.entries : []
      Card {
        required property var modelData
        Layout.fillWidth: true
        entry: modelData
      }
    }
  }

  component Pill: Rectangle {
    id: pill
    property alias text: label.text
    signal clicked()
    implicitWidth: label.implicitWidth + 14
    implicitHeight: label.implicitHeight + 6
    radius: height / 2
    color: pillMouse.containsMouse ? Theme.pressed : Theme.hover
    Label {
      id: label
      anchors.centerIn: parent
      color: pillMouse.containsMouse ? Theme.foreground : Theme.dim
      font.pixelSize: Theme.fontSmall
      elide: Text.ElideNone
    }
    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.clicked()
    }
  }

  component Card: Rectangle {
    id: card
    property var entry: ({})
    // Folded cards say how many more sit underneath.
    property int more: 0
    signal open()

    // The summary is often just the app's name again; then the body leads.
    readonly property bool summaryIsName: (entry.summary || "") === root.group.name || (entry.summary || "") === ""
    readonly property string title: summaryIsName ? (entry.body || "").split("\n")[0] : entry.summary
    readonly property string detail: summaryIsName ? (entry.body || "").split("\n").slice(1).join(" ") : (entry.body || "").replace(/\n+/g, " ")

    implicitHeight: content.implicitHeight + 20
    radius: 8
    color: Qt.tint(Theme.background, Theme.alpha(Theme.foreground, cardHover.hovered ? 0.11 : 0.07))
    Behavior on color { ColorAnimation { duration: 120 } }

    HoverHandler { id: cardHover }
    MouseArea {
      anchors.fill: parent
      cursorShape: card.more > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: card.open()
    }

    RowLayout {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 10
      spacing: 10

      // App icon, or its first letter when the app has none.
      Item {
        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        Layout.alignment: Qt.AlignTop
        // App icons get the glossy tile; symbolic ones stay plain glyphs.
        AppIcon {
          anchors.fill: parent
          source: root.group.icon
          visible: root.group.icon !== "" && !/-symbolic/.test(root.group.icon)
        }
        NotificationIcon {
          id: appIcon
          anchors.fill: parent
          source: root.group.icon
          visible: root.group.icon !== "" && /-symbolic/.test(root.group.icon)
        }
        Rectangle {
          anchors.fill: parent
          visible: root.group.icon === ""
          radius: 8
          color: Theme.alpha(Theme.accent, 0.25)
          Label {
            anchors.centerIn: parent
            text: root.group.name.charAt(0).toUpperCase()
            color: Theme.accent
            font.bold: true
            font.pixelSize: Theme.fontLarge
            elide: Text.ElideNone
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Label {
            text: root.group.name
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            Layout.fillWidth: true
          }
          Label {
            text: cardHover.hovered ? Icons.close : root.ago(card.entry.time)
            color: closeMouse.containsMouse ? Theme.foreground : Theme.dim
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideNone
            MouseArea {
              id: closeMouse
              anchors.fill: parent
              anchors.margins: -6
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Notifs.removeEntry(card.entry.id)
            }
          }
        }
        Label {
          visible: text !== ""
          text: card.title
          color: Theme.brightForeground
          font.bold: true
          Layout.fillWidth: true
        }
        Label {
          visible: text !== ""
          text: card.detail
          color: Theme.foreground
          font.pixelSize: Theme.fontSmall
          wrapMode: Text.Wrap
          maximumLineCount: 2
          Layout.fillWidth: true
        }
        Label {
          visible: card.more > 0
          Layout.topMargin: 2
          text: card.more + " more from " + root.group.name
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          Layout.fillWidth: true
        }
      }
    }
  }
}
