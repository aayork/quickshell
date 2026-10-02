import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme
import qs.ui

// Things 3: Today, Inbox, Upcoming, Anytime and Someday. Add a to-do to the
// list on show, tick one off, or click one for its note, checklist and where
// it should go. The number on the bar is what is left today.
BarButton {
  id: root

  readonly property alias popup: popup
  property string view: "today"
  // uuid of the to-do whose details are open.
  property string expanded: ""
  // uuid waiting for a second click to move to the trash.
  property string trashing: ""

  readonly property var rows: Things.lists[view] || []

  function dayLabel(key) {
    if (key === "") return ""
    if (key === Things.dateKey(0)) return "Today"
    if (key === Things.dateKey(1)) return "Tomorrow"
    return Qt.formatDate(new Date(key + "T12:00:00"), "ddd MMM d")
  }

  text: Icons.glyph(0xF05E1) + (Things.ready && Things.loaded && Things.todayCount > 0 ? " " + Things.todayCount : "")
  fontSize: Theme.fontSize + 1
  active: popup.open
  onClicked: popup.toggle()

  // One to-do. The circle completes it; a click on the rest opens its details.
  component Todo: ColumnLayout {
    id: todo
    required property var modelData

    readonly property bool open: root.expanded === modelData.uuid
    readonly property var items: Things.loaded ? Things.checklist(modelData.uuid) : []
    readonly property int done: items.filter(i => i.done).length

    Layout.fillWidth: true
    spacing: 0
    opacity: modelData.pending ? 0.5 : 1

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: Theme.rowHeight
      radius: Theme.controlRadius
      color: todo.open ? Theme.selection : hover.hovered ? Theme.hover : "transparent"

      HoverHandler { id: hover }

      MouseArea {
        anchors.fill: parent
        onClicked: {
          root.trashing = ""
          root.expanded = todo.open || todo.modelData.pending ? "" : todo.modelData.uuid
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 6
        spacing: 6

        Label {
          text: Icons.glyph(tick.containsMouse ? 0xF0134 : 0xF0130)
          color: tick.containsMouse ? Theme.accent : Theme.dim
          font.pixelSize: Theme.iconLarge
          elide: Text.ElideNone

          MouseArea {
            id: tick
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            onClicked: Things.complete(todo.modelData)
          }
        }

        Label { text: todo.modelData.title; Layout.fillWidth: true }

        // Checklist progress, when it has one.
        Label {
          visible: todo.items.length > 0
          text: Icons.glyph(0xF0E1E) + " " + todo.done + "/" + todo.items.length
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }

        Label {
          visible: todo.modelData.deadline !== ""
          text: "Due " + root.dayLabel(todo.modelData.deadline)
          color: todo.modelData.deadline <= Things.dateKey(0) ? Theme.red : Theme.yellow
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }

        Label {
          visible: text !== ""
          text: root.view === "upcoming" ? root.dayLabel(todo.modelData.date) : todo.modelData.context
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          Layout.maximumWidth: 110
        }
      }
    }

    // Details: note, checklist, and where to send it.
    ColumnLayout {
      visible: todo.open
      Layout.fillWidth: true
      Layout.leftMargin: 30
      Layout.rightMargin: 6
      Layout.topMargin: 4
      Layout.bottomMargin: 8
      spacing: 6

      Label {
        visible: text !== ""
        text: todo.modelData.note
        color: Theme.dim
        font.pixelSize: Theme.fontSmall
        wrapMode: Text.Wrap
        maximumLineCount: 6
        Layout.fillWidth: true
      }

      Repeater {
        model: todo.open ? todo.items : []

        RowLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: 6

          Label {
            text: Icons.glyph(modelData.done ? 0xF0134 : 0xF0130)
            color: modelData.done ? Theme.accent : Theme.muted
            font.pixelSize: Theme.iconSize
            elide: Text.ElideNone
          }
          Label {
            text: modelData.title
            color: modelData.done ? Theme.dim : Theme.foreground
            font.strikeout: modelData.done
            Layout.fillWidth: true
          }
        }
      }

      Label {
        visible: todo.items.length > 0
        text: "Checklist items can only be ticked off in Things itself."
        color: Theme.muted
        font.pixelSize: Theme.fontSmall
      }

      Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: [
            { id: "today", label: "Today", glyph: 0xF04CE },
            { id: "tomorrow", label: "Tomorrow", glyph: 0xF00F6 },
            { id: "anytime", label: "Anytime", glyph: 0xF0328 },
            { id: "someday", label: "Someday", glyph: 0xF003C },
            { id: "inbox", label: "Inbox", glyph: 0xF0687 }
          ].filter(o => o.id !== root.view)

          TextButton {
            required property var modelData
            text: modelData.label
            icon: Icons.glyph(modelData.glyph)
            onClicked: {
              Things.move(todo.modelData, modelData.id)
              root.expanded = ""
            }
          }
        }

        TextButton {
          readonly property bool armed: root.trashing === todo.modelData.uuid
          text: armed ? "Click again" : "Trash"
          icon: Icons.glyph(0xF0A79)
          onClicked: {
            if (!armed) {
              root.trashing = todo.modelData.uuid
              return
            }
            root.trashing = ""
            root.expanded = ""
            Things.trash(todo.modelData)
          }
        }
      }
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 400
    contentHeight: column.implicitHeight

    onOpenChanged: {
      Things.watching = open
      root.expanded = ""
      root.trashing = ""
      if (open && Things.ready) entry.focusInput()
    }

    ColumnLayout {
      id: column
      width: parent.width
      spacing: Theme.spacing

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing

        Label { text: "Things"; font.bold: true }
        Label {
          text: !Things.ready ? "" : Things.busy ? "Syncing…" : Things.loaded ? Things.todayCount + " left today" : ""
          color: Theme.dim
          Layout.fillWidth: true
        }
        Label {
          visible: Things.ready
          text: Icons.glyph(0xF0450)
          color: refreshMouse.containsMouse ? Theme.foreground : Theme.dim
          font.pixelSize: Theme.iconSize
          elide: Text.ElideNone
          MouseArea {
            id: refreshMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            onClicked: Things.refresh()
          }
        }
      }

      // ---- not set up yet
      Label {
        visible: Things.setup === "no-cli"
        text: "The Things Cloud command (things-cli) is not installed yet."
        color: Theme.dim
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
      }

      ColumnLayout {
        visible: Things.setup === "no-login"
        Layout.fillWidth: true
        spacing: 6

        Label {
          text: "Sign in with your Things Cloud account. The password goes straight to the keyring."
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          wrapMode: Text.Wrap
          elide: Text.ElideNone
          Layout.fillWidth: true
        }
        Field { id: email; Layout.fillWidth: true; placeholder: "Things Cloud email"; onAccepted: password.focusInput() }
        Field {
          id: password
          Layout.fillWidth: true
          placeholder: "Password"
          password: true
          onAccepted: signIn.clicked()
        }
        TextButton {
          id: signIn
          Layout.fillWidth: true
          text: "Sign in"
          enabled: email.text.trim() !== "" && password.text !== ""
          onClicked: {
            Things.login(email.text.trim(), password.text)
            password.text = ""
          }
        }
      }

      Label {
        visible: Things.error !== ""
        text: Things.error
        color: Theme.red
        font.pixelSize: Theme.fontSmall
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
      }

      // ---- ready
      // The lists, each with how many open to-dos it holds.
      RowLayout {
        visible: Things.ready
        Layout.fillWidth: true
        spacing: 4

        Repeater {
          model: Things.views

          Rectangle {
            id: tab
            required property var modelData

            readonly property bool current: root.view === modelData.id
            readonly property int count: (Things.lists[modelData.id] || []).length

            Layout.fillWidth: true
            implicitHeight: 38
            radius: Theme.controlRadius
            color: current ? Theme.accent : tabMouse.containsMouse ? Theme.hover : Theme.alpha(Theme.foreground, 0.04)

            Column {
              anchors.centerIn: parent
              Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tab.count
                color: tab.current ? Theme.background : Theme.foreground
                font.bold: true
              }
              Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tab.modelData.label
                color: tab.current ? Theme.background : Theme.dim
                font.pixelSize: Theme.fontSmall - 1
              }
            }

            MouseArea {
              id: tabMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                root.view = tab.modelData.id
                root.expanded = ""
                entry.focusInput()
              }
            }
          }
        }
      }

      Field {
        id: entry
        visible: Things.ready
        Layout.fillWidth: true
        placeholder: root.view === "upcoming" ? "New to-do for tomorrow"
          : "New to-do in " + Things.views.find(v => v.id === root.view).label
        onAccepted: {
          Things.add(text, root.view)
          text = ""
        }
        onCancelled: popup.close()
      }

      Label {
        visible: Things.ready && root.rows.length === 0
        text: !Things.loaded ? "Loading…" : root.view === "today" ? "Nothing left for today" : "Nothing here"
        color: Theme.dim
      }

      Flickable {
        id: list
        visible: Things.ready && root.rows.length > 0
        Layout.fillWidth: true
        implicitHeight: Math.min(rows.implicitHeight, 420)
        contentHeight: rows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: rows
          width: list.width - (scroll.needed ? 10 : 0)
          spacing: 0

          Repeater {
            model: root.rows
            Todo {}
          }
        }

        Scrollbar {
          id: scroll
          flickable: list
          parent: list
          anchors.right: parent.right
          height: list.height
          z: 2
        }
      }

      Label {
        visible: Things.ready
        text: "Sign out"
        color: signOut.containsMouse ? Theme.foreground : Theme.muted
        font.pixelSize: Theme.fontSmall
        MouseArea {
          id: signOut
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          onClicked: Things.logout()
        }
      }
    }
  }
}
