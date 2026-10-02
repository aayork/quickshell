import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme
import qs.ui

// What a locked screen shows: the wallpaper out of focus, the time, and a
// password field.
Item {
  id: root

  required property var lock

  Image {
    id: wallpaper
    anchors.fill: parent
    source: Background.source
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    visible: false
  }

  MultiEffect {
    anchors.fill: parent
    source: wallpaper
    autoPaddingEnabled: false
    blurEnabled: true
    blurMax: 64
    blur: 1
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.alpha(Theme.background, 0.55)
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  ColumnLayout {
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

    Field {
      id: password
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 28
      Layout.preferredWidth: 280
      implicitHeight: 34
      password: true
      enabled: root.lock.status !== "checking"
      placeholder: root.lock.status === "checking" ? "Checking…" : "Password"
      onAccepted: {
        root.lock.submit(text)
        text = ""
      }
      onCancelled: text = ""
    }

    Label {
      Layout.alignment: Qt.AlignHCenter
      // Keeps its line so the field does not jump when the message appears.
      opacity: root.lock.status === "failed" ? 1 : 0
      text: "That password didn't work"
      color: Theme.red
      elide: Text.ElideNone
    }
  }

  // The field must hold focus whenever the surface is up, including after a
  // failed attempt re-enables it.
  function focusPassword() { password.focusInput() }
  Component.onCompleted: focusPassword()
  onVisibleChanged: if (visible) focusPassword()
  Connections {
    target: root.lock
    function onStatusChanged() { if (root.lock.status !== "checking") root.focusPassword() }
  }
  MouseArea {
    anchors.fill: parent
    z: -1
    onClicked: root.focusPassword()
  }
}
