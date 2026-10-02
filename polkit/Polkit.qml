import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.theme
import qs.ui

// The password prompt for anything that needs administrator rights
// (pkexec, system settings, package tools).
Scope {
  id: root

  PolkitAgent {
    id: agent
  }

  readonly property var flow: agent.flow

  PanelWindow {
    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    visible: agent.isActive
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.alpha(Theme.background, 0.5)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aayork-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
      password.text = ""
      if (visible) password.focusInput()
    }

    Rectangle {
      width: 420
      height: column.implicitHeight + 2 * (Theme.popupPadding + Theme.borderWidth)
      anchors.centerIn: parent
      color: Theme.background
      border.width: Theme.borderWidth
      border.color: root.flow && root.flow.failed ? Theme.red : Theme.accent
      radius: Theme.radius

      ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Theme.popupPadding + Theme.borderWidth
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: Icons.lock
            font.pixelSize: Theme.iconLarge
            color: Theme.accent
            elide: Text.ElideNone
          }
          Label {
            text: "Authentication required"
            font.bold: true
            font.pixelSize: Theme.fontLarge
            Layout.fillWidth: true
          }
        }

        Label {
          text: root.flow ? root.flow.message : ""
          wrapMode: Text.Wrap
          elide: Text.ElideNone
          Layout.fillWidth: true
        }

        Field {
          id: password
          Layout.fillWidth: true
          implicitHeight: 32
          password: !(root.flow && root.flow.responseVisible)
          placeholder: root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
          enabled: root.flow !== null && root.flow.isResponseRequired
          onEnabledChanged: if (enabled) { text = ""; focusInput() }
          onAccepted: if (root.flow) root.flow.submit(text)
          onCancelled: if (root.flow) root.flow.cancelAuthenticationRequest()
        }

        Label {
          visible: text !== ""
          text: root.flow
            ? (root.flow.supplementaryMessage || (root.flow.failed ? "That password didn't work" : ""))
            : ""
          color: root.flow && (root.flow.failed || root.flow.supplementaryIsError) ? Theme.red : Theme.dim
          wrapMode: Text.Wrap
          elide: Text.ElideNone
          Layout.fillWidth: true
        }

        Label {
          text: "Enter to confirm · Esc to cancel"
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          Layout.fillWidth: true
        }
      }
    }
  }
}
