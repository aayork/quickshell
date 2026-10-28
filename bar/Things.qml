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

  // Each list's icon and colour, like the Things sidebar, from the theme.
  readonly property var looks: ({
    inbox: { glyph: 0xF0687, color: Theme.pick("blue", Theme.accent) },
    today: { glyph: 0xF04CE, color: Theme.yellow },
    upcoming: { glyph: 0xF00ED, color: Theme.red },
    anytime: { glyph: 0xF0328, color: Theme.pick("cyan", Theme.accent) },
    someday: { glyph: 0xF003C, color: Theme.pick("dark_foreground", Theme.dim) }
  })
  readonly property var look: looks[view]
  readonly property string viewLabel: Things.views.find(v => v.id === view).label

  // What a row is grouped under: the day in Upcoming, the project or area in
  // Anytime and Someday, nothing in Today and Inbox, as Things does it.
  function groupOf(todo) {
    if (view === "upcoming") return todo.date
    if (view === "anytime" || view === "someday") return todo.context
    return ""
  }

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

  // One to-do. The box completes it; a click on the rest opens its details.
  // The first of a group carries the group's heading above it.
  component Todo: ColumnLayout {
    id: todo
    required property var modelData
    required property int index

    readonly property bool open: root.expanded === modelData.uuid
    readonly property var items: Things.loaded ? Things.checklist(modelData.uuid) : []
    readonly property int done: items.filter(i => i.done).length
    readonly property string group: root.groupOf(modelData)
    readonly property bool startsGroup: group !== "" && (index === 0 || root.groupOf(root.rows[index - 1]) !== group)
    // Today and Inbox show where a to-do lives under its title.
    readonly property string where: root.view === "today" || root.view === "inbox" ? modelData.context : ""

    Layout.fillWidth: true
    spacing: 0
    opacity: modelData.pending ? 0.5 : 1

    // Group heading: a day as a big number and its name, or a project.
    ColumnLayout {
      visible: todo.startsGroup
      Layout.fillWidth: true
      Layout.topMargin: todo.index === 0 ? 2 : 14
      Layout.bottomMargin: 4
      spacing: 3

      RowLayout {
        Layout.leftMargin: 4
        spacing: 8
        Label {
          visible: root.view === "upcoming"
          text: todo.group !== "" ? String(Number(todo.group.slice(8, 10))) : ""
          font.pixelSize: Theme.fontLarge + 4
          font.bold: true
          elide: Text.ElideNone
        }
        Label {
          text: root.view === "upcoming" ? root.dayLabel(todo.group) : todo.group
          color: root.view === "upcoming" ? Theme.dim : Theme.foreground
          font.bold: root.view !== "upcoming"
          Layout.alignment: Qt.AlignBaseline
        }
      }
      Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.separator }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: todo.where !== "" ? Theme.rowHeight + 12 : Theme.rowHeight
      radius: 3
      color: "transparent"

      HoverHandler { id: hover }

      // Windows 7 Explorer selection.
      AeroHighlight {
        anchors.fill: parent
        hovered: hover.hovered
        selected: todo.open
      }

      MouseArea {
        anchors.fill: parent
        onClicked: {
          root.trashing = ""
          root.expanded = todo.open || todo.modelData.pending ? "" : todo.modelData.uuid
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10

        // The checkbox: a small rounded square, as in Things.
        // A Vista check box.
        VistaCheck {
          Layout.alignment: todo.where !== "" ? Qt.AlignTop : Qt.AlignVCenter
          Layout.topMargin: todo.where !== "" ? 7 : 0
          hovered: tick.containsMouse

          MouseArea {
            id: tick
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            onClicked: Things.complete(todo.modelData)
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1
          Label { text: todo.modelData.title; Layout.fillWidth: true }
          Label {
            visible: todo.where !== ""
            text: todo.where
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            Layout.fillWidth: true
          }
        }

        // Note and checklist markers, as small dim glyphs.
        Label {
          visible: todo.modelData.note !== ""
          text: Icons.glyph(0xF09ED)
          color: Theme.muted
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
        Label {
          visible: todo.items.length > 0
          text: Icons.glyph(0xF0E1E) + " " + todo.done + "/" + todo.items.length
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }

        // Deadline with a flag; red once it is due.
        Label {
          visible: todo.modelData.deadline !== ""
          text: Icons.glyph(0xF023B) + " " + root.dayLabel(todo.modelData.deadline)
          color: todo.modelData.deadline <= Things.dateKey(0) ? Theme.red : Theme.dim
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
      }
    }

    // Details: note, checklist, and where to send it.
    ColumnLayout {
      visible: todo.open
      Layout.fillWidth: true
      Layout.leftMargin: 32
      Layout.rightMargin: 8
      Layout.topMargin: 4
      Layout.bottomMargin: 10
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
          spacing: 8

          Rectangle {
            implicitWidth: 10
            implicitHeight: 10
            radius: 5
            color: modelData.done ? Theme.alpha(Theme.dim, 0.5) : "transparent"
            border.width: 1
            border.color: Theme.dim
          }
          Label {
            text: modelData.title
            color: modelData.done ? Theme.dim : Theme.foreground
            font.strikeout: modelData.done
            font.pixelSize: Theme.fontSmall
            Layout.fillWidth: true
          }
        }
      }

      Label {
        visible: todo.items.length > 0
        text: "Checklist items can only be ticked off in Things itself."
        color: Theme.muted
        font.pixelSize: Theme.fontSmall
        // Wrap within the row: at its full width it would widen the to-do
        // and push the row's markers past the edge.
        wrapMode: Text.Wrap
        Layout.fillWidth: true
      }

      Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: ["today", "tomorrow", "anytime", "someday", "inbox"].filter(id => id !== root.view)

          TextButton {
            required property string modelData
            text: modelData === "tomorrow" ? "Tomorrow" : Things.views.find(v => v.id === modelData).label
            icon: Icons.glyph(modelData === "tomorrow" ? root.looks.upcoming.glyph : root.looks[modelData].glyph)
            onClicked: {
              Things.move(todo.modelData, modelData)
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
      if (open && Things.ready) entry.forceActiveFocus()
    }

    ColumnLayout {
      id: column
      width: parent.width
      spacing: Theme.spacing

      Label {
        visible: !Things.ready
        text: "Things"
        font.bold: true
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
      // The lists as a row of icons, like Things' sidebar folded sideways.
      RowLayout {
        visible: Things.ready
        Layout.fillWidth: true
        spacing: 2

        Repeater {
          model: Things.views

          Rectangle {
            id: tab
            required property var modelData

            readonly property bool current: root.view === modelData.id
            readonly property int count: (Things.lists[modelData.id] || []).length
            readonly property var look: root.looks[modelData.id]

            Layout.fillWidth: true
            implicitHeight: 30
            radius: 3
            color: "transparent"

            // The current list is a lit Vista button; the others light on hover.
            VistaFace {
              anchors.fill: parent
              visible: tab.current || tabMouse.containsMouse
              hovered: tabMouse.containsMouse
              lit: tab.current
            }

            Row {
              anchors.centerIn: parent
              spacing: 5
              Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.glyph(tab.look.glyph)
                color: tab.look.color
                font.pixelSize: Theme.iconSize + 1
                elide: Text.ElideNone
              }
              Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: tab.count > 0
                text: tab.count
                color: tab.current ? "#ffffff" : Theme.dim
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideNone
              }
            }

            MouseArea {
              id: tabMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                root.view = tab.modelData.id
                root.expanded = ""
                entry.forceActiveFocus()
              }
            }
          }
        }

        // Sync, at the end of the row.
        Label {
          text: Icons.glyph(0xF0450)
          color: Things.busy ? Theme.accent : refreshMouse.containsMouse ? Theme.foreground : Theme.muted
          font.pixelSize: Theme.iconSize
          elide: Text.ElideNone
          Layout.leftMargin: 6
          MouseArea {
            id: refreshMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            onClicked: Things.refresh()
          }
        }
      }

      // The list's name, big, with its coloured icon.
      RowLayout {
        visible: Things.ready
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.leftMargin: 4
        spacing: 8

        Label {
          text: Icons.glyph(root.look.glyph)
          color: root.look.color
          font.pixelSize: Theme.iconLarge + 4
          elide: Text.ElideNone
        }
        Label {
          text: root.viewLabel
          font.pixelSize: Theme.fontLarge + 6
          font.bold: true
          Layout.fillWidth: true
        }
        Label {
          text: Things.busy ? "Syncing…" : ""
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
      }

      Label {
        visible: Things.ready && root.rows.length === 0
        text: !Things.loaded ? "Loading…" : root.view === "today" ? "Nothing left for today" : "Nothing here"
        color: Theme.dim
        Layout.leftMargin: 8
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

      // New to-do, at the end of the list as in Things.
      RowLayout {
        visible: Things.ready
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        implicitHeight: Theme.rowHeight
        spacing: 10

        Label {
          text: Icons.glyph(0xF0415)
          color: root.look.color
          font.pixelSize: Theme.iconSize
          elide: Text.ElideNone
          Layout.preferredWidth: 14
          horizontalAlignment: Text.AlignHCenter
        }

        TextInput {
          id: entry
          Layout.fillWidth: true
          color: Theme.foreground
          selectionColor: Theme.selection
          selectedTextColor: Theme.brightForeground
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          clip: true
          onAccepted: {
            Things.add(text, root.view)
            text = ""
          }
          Keys.onEscapePressed: popup.close()

          Label {
            anchors.fill: parent
            visible: entry.text === ""
            text: root.view === "upcoming" ? "New To-Do for tomorrow" : "New To-Do"
            color: Theme.dim
          }
        }
      }

      Separator { visible: Things.ready; Layout.fillWidth: true }

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
