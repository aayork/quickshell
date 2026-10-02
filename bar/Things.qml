import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme
import qs.ui

// Things 3: today's to-dos and the inbox, a box to add one, and a circle to
// tick one off. The number on the bar is what is left today.
BarButton {
  id: root

  readonly property alias popup: popup
  // Where a new to-do goes.
  property string destination: "today"
  property bool showInbox: false

  text: Icons.glyph(0xF05E1) + (Things.ready && Things.loaded && Things.today.length > 0 ? " " + Things.today.length : "")
  fontSize: Theme.fontSize + 1
  minimumWidth: Theme.barIconSlot
  active: popup.open
  onClicked: popup.toggle()

  // One to-do: a circle to complete it, its title, and its project.
  component Todo: Rectangle {
    id: todo
    required property var modelData
    property bool inbox: false

    Layout.fillWidth: true
    implicitHeight: Theme.rowHeight
    radius: Theme.controlRadius
    color: hover.hovered ? Theme.hover : "transparent"
    opacity: modelData.pending ? 0.5 : 1

    HoverHandler { id: hover }

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

      Label {
        visible: todo.inbox && hover.hovered && !todo.modelData.pending
        text: "Today"
        color: toToday.containsMouse ? Theme.accent : Theme.dim
        font.pixelSize: Theme.fontSmall
        elide: Text.ElideNone
        MouseArea {
          id: toToday
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          onClicked: Things.moveToToday(todo.modelData)
        }
      }

      Label {
        visible: text !== "" && !(todo.inbox && hover.hovered)
        text: todo.modelData.deadlineDate ? "Due " + Qt.formatDate(new Date(todo.modelData.deadlineDate), "MMM d") : Things.project(todo.modelData)
        color: todo.modelData.deadlineDate ? Theme.red : Theme.dim
        font.pixelSize: Theme.fontSmall
        Layout.maximumWidth: 110
      }
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 340
    contentHeight: column.implicitHeight

    onOpenChanged: {
      Things.watching = open
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
          text: !Things.ready ? "" : Things.busy ? "Syncing…" : Things.loaded ? Things.today.length + " today" : ""
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
      RowLayout {
        visible: Things.ready
        Layout.fillWidth: true
        spacing: 6

        Field {
          id: entry
          Layout.fillWidth: true
          placeholder: "New to-do"
          onAccepted: {
            Things.add(text, root.destination)
            text = ""
          }
          onCancelled: popup.close()
        }
        Segmented {
          options: [{ label: "Today", value: "today" }, { label: "Inbox", value: "inbox" }]
          current: root.destination
          onPicked: function(value) { root.destination = value; entry.focusInput() }
        }
      }

      Separator { Layout.fillWidth: true; visible: Things.ready }

      SectionHeader { visible: Things.ready; text: "TODAY" }

      Label {
        visible: Things.ready && Things.today.length === 0
        text: !Things.loaded ? "Loading…" : "Nothing left for today"
        color: Theme.dim
      }

      Flickable {
        id: todayList
        visible: Things.ready && Things.today.length > 0
        Layout.fillWidth: true
        implicitHeight: Math.min(todayRows.implicitHeight, Theme.rowHeight * 10)
        contentHeight: todayRows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: todayRows
          width: todayList.width
          spacing: 0

          Repeater {
            model: Things.today
            Todo {}
          }
        }
      }

      // The inbox stays folded until asked for.
      RowLayout {
        visible: Things.ready && Things.inbox.length > 0
        Layout.fillWidth: true

        SectionHeader { text: "INBOX · " + Things.inbox.length; Layout.fillWidth: true }
        IconButton {
          icon: root.showInbox ? Icons.chevronDown : Icons.chevronRight
          onClicked: root.showInbox = !root.showInbox
        }
      }

      ColumnLayout {
        visible: Things.ready && root.showInbox
        Layout.fillWidth: true
        spacing: 0

        Repeater {
          model: root.showInbox ? Things.inbox.slice(0, 8) : []
          Todo { inbox: true }
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
