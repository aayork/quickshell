import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui

// The capture menu (ALT+SHIFT+5): pick what to grab. Number keys work too.
Scope {
  id: root

  property bool open: false
  Connections {
    target: Session
    function onScreensaverChanged() { if (Session.screensaver) root.open = false }
  }

  readonly property string script: Quickshell.shellDir + "/bin/screenshot"
  readonly property var modes: [
    { id: "region", label: "Area", glyph: 0xF0A6D },
    { id: "smart", label: "Window", glyph: 0xF0614 },
    { id: "fullscreen", label: "Screen", glyph: 0xF0379 },
    { id: "scroll", label: "Scrolling", glyph: 0xF084F },
    { id: "history", label: "History", glyph: 0xF02DA }
  ]

  // Captures are started by Hyprland, not from inside the shell: run from
  // here, the screen freeze and the first click of the selection misbehave.
  function pick(id) {
    open = false
    if (id === "history") PopupState.request("shots")
    else if (id === "scroll") Hyprland.dispatch("hl.dsp.exec_cmd(\"" + Quickshell.shellDir + "/bin/scroll-capture\")")
    else Hyprland.dispatch("hl.dsp.exec_cmd(\"" + script + " " + id + "\")")
  }

  Connections {
    target: Captures
    function onMenuRequested() { root.open = !root.open }
  }

  PanelWindow {
    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    visible: root.open
    anchors.top: true
    margins.top: 60
    implicitWidth: row.implicitWidth + 24
    implicitHeight: 84
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aayork-capture-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    Rectangle {
      anchors.fill: parent
      color: Theme.background
      border.width: Theme.borderWidth
      border.color: Theme.accent
      radius: Theme.controlRadius + 6

      Item {
        id: keys
        focus: true
        Keys.onPressed: function(event) {
          event.accepted = true
          if (event.key === Qt.Key_Escape) root.open = false
          else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.modes.length) root.pick(root.modes[event.key - Qt.Key_1].id)
          else event.accepted = false
        }
      }

      RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
          model: root.modes

          Rectangle {
            id: mode
            required property var modelData
            required property int index

            implicitWidth: 78
            implicitHeight: 60
            radius: Theme.controlRadius + 4
            color: modeMouse.containsMouse ? Theme.selection : Theme.alpha(Theme.foreground, 0.04)

            Column {
              anchors.centerIn: parent
              spacing: 4
              Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.glyph(mode.modelData.glyph)
                font.pixelSize: 20
                color: modeMouse.containsMouse ? Theme.accent : Theme.foreground
                elide: Text.ElideNone
              }
              Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: mode.modelData.label
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideNone
              }
            }

            Label {
              anchors { top: parent.top; right: parent.right; margins: 4 }
              text: mode.index + 1
              color: Theme.muted
              font.pixelSize: Theme.fontSmall - 1
            }

            MouseArea {
              id: modeMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.pick(mode.modelData.id)
            }
          }
        }
      }
    }
  }

  // While a scrolling capture runs, a pill to stop it.
  PanelWindow {
    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    visible: Captures.scrolling
    anchors.top: true
    margins.top: 40
    implicitWidth: stopRow.implicitWidth + 28
    implicitHeight: 36
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aayork-capture-scroll"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: stopMouse.containsMouse ? Theme.red : Theme.background
      border.width: Theme.borderWidth
      border.color: Theme.red
      radius: height / 2

      RowLayout {
        id: stopRow
        anchors.centerIn: parent
        spacing: 8
        Label { text: Icons.glyph(0xF0EC3); color: stopMouse.containsMouse ? Theme.background : Theme.red; font.pixelSize: Theme.iconSize; elide: Text.ElideNone }
        Label { text: "Scroll the area, then click here to finish"; color: stopMouse.containsMouse ? Theme.background : Theme.foreground; elide: Text.ElideNone }
      }

      MouseArea {
        id: stopMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Quickshell.execDetached([Quickshell.shellDir + "/bin/scroll-capture"])
      }
    }
  }
}
