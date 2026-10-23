import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.ui

// One screen of the login screen. It looks like the lock screen: the
// wallpaper out of focus and the time, then who is logging in, the password
// field, the session to start and the power buttons. Only the primary screen
// gets the controls.
Item {
  id: root

  required property var greeter
  property bool primary: true

  Rectangle {
    anchors.fill: parent
    color: Theme.base
  }

  Image {
    id: wallpaper
    anchors.fill: parent
    source: Theme.wallpaper
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    visible: false
  }

  MultiEffect {
    anchors.fill: parent
    source: wallpaper
    visible: wallpaper.status === Image.Ready
    autoPaddingEnabled: false
    blurEnabled: true
    blurMax: 64
    blur: 1
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.alpha(Theme.base, 0.55)
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  ColumnLayout {
    id: column
    anchors.centerIn: parent
    spacing: 6

    Label {
      Layout.alignment: Qt.AlignHCenter
      text: Qt.formatDateTime(clock.date, "h:mm AP")
      color: Theme.brightForeground
      font.pixelSize: 64
      elide: Text.ElideNone
    }

    Label {
      Layout.alignment: Qt.AlignHCenter
      text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
      color: Theme.foreground
      font.pixelSize: Theme.fontLarge
      elide: Text.ElideNone
    }

    // Who is logging in. Other accounts sit either side, smaller and faded;
    // click one, or press Up/Down in the field, to switch.
    RowLayout {
      visible: root.primary
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 36
      spacing: 22

      // Fixed-width slots keep the current picture centred.
      Item {
        implicitWidth: 52
        implicitHeight: 52
        Avatar {
          anchors.fill: parent
          size: 52
          current: false
          opacity: 0.55
          visible: root.greeter.users.length > 2
          user: root.greeter.neighbour(-1)
          onClicked: root.greeter.cycleUser(-1)
        }
      }

      Avatar {
        size: 88
        user: root.greeter.user
      }

      Item {
        implicitWidth: 52
        implicitHeight: 52
        Avatar {
          anchors.fill: parent
          size: 52
          current: false
          opacity: 0.55
          visible: root.greeter.users.length > 1
          user: root.greeter.neighbour(1)
          onClicked: root.greeter.cycleUser(1)
        }
      }
    }

    Label {
      visible: root.primary
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 6
      text: root.greeter.user ? root.greeter.user.display : "No accounts"
      color: Theme.brightForeground
      font.pixelSize: Theme.fontLarge + 2
      elide: Text.ElideNone
    }

    Field {
      id: password
      visible: root.primary
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 16
      Layout.preferredWidth: 280
      implicitHeight: 34
      password: root.greeter.status !== "prompt" || !root.greeter.promptEcho
      enabled: !root.greeter.busy
      placeholder: root.greeter.status === "checking" ? "Checking…"
        : root.greeter.status === "launching" ? "Starting " + (root.greeter.session ? root.greeter.session.name : "") + "…"
        : root.greeter.status === "prompt" ? root.greeter.prompt
        : "Password"
      onAccepted: {
        root.greeter.submit(text)
        text = ""
      }
      onCancelled: {
        text = ""
        root.greeter.reset()
      }
      onStepped: step => root.greeter.cycleUser(step)
    }

    Label {
      visible: root.primary
      Layout.alignment: Qt.AlignHCenter
      Layout.maximumWidth: 420
      // Keeps its line so the field does not jump when the message appears.
      opacity: root.greeter.message !== "" ? 1 : 0
      text: root.greeter.message || " "
      color: root.greeter.status === "failed" ? Theme.red : Theme.dim
    }
  }

  // Session picker, bottom left. The list opens upward.
  Item {
    id: sessionButton
    visible: root.primary
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.margins: 24
    implicitWidth: sessionRow.implicitWidth + 20
    implicitHeight: Theme.rowHeight + 4

    property bool open: false

    Rectangle {
      anchors.fill: parent
      radius: Theme.controlRadius
      color: sessionMouse.pressed ? Theme.pressed : sessionMouse.containsMouse || sessionButton.open ? Theme.hover : "transparent"
    }

    RowLayout {
      id: sessionRow
      anchors.centerIn: parent
      spacing: 8
      Label {
        text: String.fromCodePoint(0xF0379)
        color: Theme.accent
        font.pixelSize: Theme.iconSize
        elide: Text.ElideNone
      }
      Label {
        text: root.greeter.session ? root.greeter.session.name : "No sessions"
        elide: Text.ElideNone
      }
      Label {
        text: String.fromCodePoint(sessionButton.open ? 0xF0140 : 0xF0143)
        color: Theme.dim
        font.pixelSize: Theme.iconSize
        elide: Text.ElideNone
      }
    }

    MouseArea {
      id: sessionMouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: sessionButton.open = !sessionButton.open
    }
  }

  // Clicking anywhere else closes the list and gives the field its focus back.
  MouseArea {
    anchors.fill: parent
    z: -1
    onClicked: {
      sessionButton.open = false
      root.focusPassword()
    }
  }

  Rectangle {
    visible: sessionButton.open
    anchors.left: sessionButton.left
    anchors.bottom: sessionButton.top
    anchors.bottomMargin: 6
    width: Math.max(220, sessionList.implicitWidth + 12)
    height: sessionList.implicitHeight + 12
    radius: Theme.controlRadius
    color: Theme.alpha(Theme.base, 0.92)
    border.width: 1
    border.color: Theme.separator

    ColumnLayout {
      id: sessionList
      anchors.fill: parent
      anchors.margins: 6
      spacing: 2

      Repeater {
        model: root.greeter.sessions

        Item {
          id: row
          required property var modelData
          required property int index
          Layout.fillWidth: true
          implicitWidth: rowLabel.implicitWidth + 36
          implicitHeight: Theme.rowHeight

          Rectangle {
            anchors.fill: parent
            radius: Theme.controlRadius
            color: rowMouse.pressed ? Theme.pressed : rowMouse.containsMouse ? Theme.hover : "transparent"
          }
          Label {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            text: row.index === root.greeter.sessionIndex ? String.fromCodePoint(0xF012C) : ""
            color: Theme.accent
            elide: Text.ElideNone
          }
          Label {
            id: rowLabel
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.name
            color: row.index === root.greeter.sessionIndex ? Theme.brightForeground : Theme.foreground
            elide: Text.ElideNone
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              root.greeter.pickSession(row.index)
              sessionButton.open = false
              root.focusPassword()
            }
          }
        }
      }
    }
  }

  // Power, bottom right.
  RowLayout {
    visible: root.primary
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 24
    spacing: 4

    IconButton {
      icon: String.fromCodePoint(0xF04B2)
      size: Theme.iconLarge
      implicitWidth: Theme.rowHeight + 4
      implicitHeight: Theme.rowHeight + 4
      onClicked: root.greeter.power("suspend")
    }
    IconButton {
      icon: String.fromCodePoint(0xF0709)
      size: Theme.iconLarge
      implicitWidth: Theme.rowHeight + 4
      implicitHeight: Theme.rowHeight + 4
      onClicked: root.greeter.power("reboot")
    }
    IconButton {
      icon: String.fromCodePoint(0xF0425)
      size: Theme.iconLarge
      implicitWidth: Theme.rowHeight + 4
      implicitHeight: Theme.rowHeight + 4
      onClicked: root.greeter.power("poweroff")
    }
  }

  // The field holds focus whenever the screen is up, including after a
  // failed attempt re-enables it.
  function focusPassword() { if (primary) password.focusInput() }
  Component.onCompleted: {
    focusPassword()
    if (primary) greeter.markReady()
  }
  Connections {
    target: root.greeter
    function onStatusChanged() { if (!root.greeter.busy) root.focusPassword() }
    function onUserIndexChanged() {
      password.text = ""
      root.focusPassword()
    }
  }
}
