//@ pragma IconTheme Colloid
import QtQuick
import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Wayland

// The login screen, run by greetd (see greeter/start). A config of its own,
// apart from the desktop shell in the folder above: it runs as the greeter
// user and only reads the copy of the theme in /var/lib/aayork-greeter.
//
// Preview without logging out: `quickshell -p greeter` from the repo opens it
// in a window; any password logs "would launch", and "fail" shows the error.
ShellRoot {
  Greeter { id: login }

  Variants {
    model: Greetd.available ? Quickshell.screens : []

    PanelWindow {
      id: win
      required property var modelData
      readonly property bool primary: modelData === Quickshell.screens[0]
      screen: modelData
      anchors { left: true; right: true; top: true; bottom: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "aayork-greeter"
      WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      color: "black"

      Surface {
        anchors.fill: parent
        greeter: login
        primary: win.primary
      }
    }
  }

  LazyLoader {
    active: !Greetd.available

    FloatingWindow {
      implicitWidth: 1100
      implicitHeight: 720
      title: "Greeter preview"
      color: "black"

      Surface {
        anchors.fill: parent
        greeter: login
      }
    }
  }
}
