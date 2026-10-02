pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Leaving the session, one way or another.
Singleton {
  id: root

  // The lock screen listens for this.
  signal lockRequested()

  readonly property var actions: [
    { id: "lock", label: "Lock", icon: 0xF033E, confirm: false },
    { id: "suspend", label: "Suspend", icon: 0xF04B2, confirm: false },
    { id: "logout", label: "Log out", icon: 0xF0343, confirm: true },
    { id: "reboot", label: "Restart", icon: 0xF0709, confirm: true },
    { id: "shutdown", label: "Shut down", icon: 0xF0425, confirm: true }
  ]

  function run(id) {
    if (id === "lock") lockRequested()
    else if (id === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
    else if (id === "logout") Hyprland.dispatch("hl.dsp.exit()")
    else if (id === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
    else if (id === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"])
  }
}
