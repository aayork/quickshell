import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
// Qualified: the Bose, Tailscale and Things widgets here share names with services.
import qs.services as Services
import qs.theme
import qs.ui

Scope {
  id: root

  // Popups can be opened from a keybind: `qs ipc call bar toggle network`.
  signal toggleRequested(string name)

  IpcHandler {
    target: "bar"
    function toggle(name: string): void { root.toggleRequested(name) }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bar
      required property var modelData

      // Fullscreen, macOS style: while a fullscreen window covers this monitor
      // the bar tucks away past the top edge, and touching that edge slides it
      // back in. The surface itself never moves; the content slides inside it
      // and the input mask shrinks to a thin strip, so the hidden bar does not
      // swallow clicks meant for the fullscreen window.
      readonly property var monitor: Hyprland.monitorFor(screen)
      readonly property bool fullscreen: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.hasFullscreen === true : false
      property bool peeking: false
      readonly property bool tucked: fullscreen && (!peeking || Services.Session.screensaver)
      readonly property bool peekHeld: slideHover.hovered || edgeHover.hovered || PopupState.active !== null

      // See-through over the wallpaper, solid when it peeks over a window.
      readonly property color foreground: fullscreen ? Theme.foreground : Theme.barForeground

      // One text colour for the whole bar, from the wallpaper behind all of
      // it, so both sides always match. x and w are kept for the callers.
      readonly property color wholeBarForeground: Theme.barForegroundOver(0, 1,
        Services.Config.bar.glass ? Services.Config.bar.tint : 0)
      function foregroundOver(x, w) {
        if (fullscreen || width <= 0) return foreground
        return wholeBarForeground
      }

      screen: modelData
      anchors { top: true; left: true; right: true }
      implicitHeight: Theme.barHeight
      color: "transparent"
      surfaceFormat.opaque: false
      WlrLayershell.namespace: "aayork-bar"
      // A Top layer bar is drawn underneath a fullscreen window.
      WlrLayershell.layer: fullscreen ? WlrLayer.Overlay : WlrLayer.Top
      mask: tucked ? edgeRegion : null

      onFullscreenChanged: if (!fullscreen) peeking = false
      onPeekHeldChanged: {
        if (peekHeld) peekTimer.stop()
        else if (peeking) peekTimer.restart()
      }

      function togglePopup(name) {
          // Only on the monitor that has focus.
          if (Hyprland.focusedMonitor !== bar.monitor) return
          // A tucked bar comes out to show what was asked for.
          if (bar.fullscreen) bar.peeking = true
          var popups = { "tray": tray.popup, "things": things.popup, "clock": clock.popup, "bose": bose.popup, "tailscale": tailscale.popup, "network": network.popup, "control-center": controlCenter.popup }
          if (popups[name]) popups[name].toggle()
      }

      Connections {
        target: root
        function onToggleRequested(name) { bar.togglePopup(name) }
      }

      Connections {
        target: PopupState
        function onRequested(name) { bar.togglePopup(name) }
      }

      Timer {
        id: peekTimer
        interval: 400
        onTriggered: if (!bar.peekHeld) bar.peeking = false
      }

      property Region edgeRegion: Region { item: edge }

      Item {
        id: edge
        width: parent.width
        height: 2

        HoverHandler {
          id: edgeHover
          enabled: bar.fullscreen
          onHoveredChanged: if (hovered) bar.peeking = true
        }
      }

      Item {
        id: slide
        width: parent.width
        height: parent.height
        y: bar.tucked ? -height : 0
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        HoverHandler { id: slideHover; enabled: bar.fullscreen }

        // Solid over a fullscreen window; otherwise as much of the theme
        // background as the tint setting asks for, and nothing at all with
        // background effects off.
        Rectangle {
          anchors.fill: parent
          color: Theme.alpha(Theme.background, bar.fullscreen ? 1 : Services.Config.bar.glass ? Services.Config.bar.tint : 0)
        }

        Workspaces {
          id: workspaces
          anchors.left: parent.left
          anchors.leftMargin: Theme.barPadding + 3
          foreground: bar.foregroundOver(workspaces.x, workspaces.width)
        }

        RowLayout {
          id: row
          anchors.right: parent.right
          anchors.rightMargin: Theme.barPadding + 3
          height: parent.height
          spacing: 0

          Tray { id: tray; foreground: bar.foregroundOver(row.x + tray.x, tray.width) }
          Bose { id: bose; foreground: bar.foregroundOver(row.x + bose.x, bose.width) }
          Things { id: things; foreground: bar.foregroundOver(row.x + things.x, things.width) }
          Tailscale { id: tailscale; foreground: bar.foregroundOver(row.x + tailscale.x, tailscale.width) }
          Network { id: network; foreground: bar.foregroundOver(row.x + network.x, network.width) }
          ControlCenter { id: controlCenter; foreground: bar.foregroundOver(row.x + controlCenter.x, controlCenter.width) }
          Clock { id: clock; foreground: bar.foregroundOver(row.x + clock.x, clock.width) }
        }
      }
    }
  }
}
