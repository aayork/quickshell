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
          var popups = { "jot": jot.popup, "tray": tray.popup, "things": things.popup, "clock": clock.popup, "bose": bose.popup, "tailscale": tailscale.popup, "network": network.popup, "control-center": controlCenter.popup }
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

        // The bar's glass, measured from a real macOS Sequoia screenshot: the
        // menu bar is a near-flat band of the wallpaper's average colour (its
        // brightness moves only ~10% across the screen even where the
        // wallpaper under it swings from black to white), 15-20% darker,
        // colour strength unchanged, with a hard bottom edge. No blur can
        // average that widely, so the band is painted straight from the
        // probe's colour readings of the strip behind the bar, each one
        // averaged with its neighbours (a window of `reach` sections either
        // side, of 48 across). Drawn in the bar's own layer, above windows,
        // so a window dragged up under the bar is covered by it.
        Canvas {
          id: barGlass

          visible: Services.Config.bar.glass && !bar.fullscreen
          readonly property int reach: 20
          readonly property var strip: Theme.wallpaperStrip

          anchors.fill: parent
          onStripChanged: requestPaint()
          onWidthChanged: requestPaint()

          onPaint: {
            var context = getContext("2d")
            context.reset()
            var parts = strip
            if (!parts || parts.length === 0) return
            var gradient = context.createLinearGradient(0, 0, width, 0)
            for (var i = 0; i < parts.length; i++) {
              var r = 0, g = 0, b = 0, n = 0
              for (var j = Math.max(0, i - reach); j <= Math.min(parts.length - 1, i + reach); j++) {
                r += parts[j].r; g += parts[j].g; b += parts[j].b; n++
              }
              gradient.addColorStop(parts.length === 1 ? 0 : i / (parts.length - 1), Qt.rgba(r / n, g / n, b / n, 1))
            }
            context.fillStyle = gradient
            context.fillRect(0, 0, width, height)
          }

          // With the bar's tint on top this lands at Sequoia's ~15-20% shift:
          // darker in dark mode, lighter in light mode.
          Rectangle {
            anchors.fill: parent
            color: Theme.background.hslLightness < 0.5 ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.3)
          }
        }

        // Solid over a fullscreen window; otherwise as much of the theme
        // background as the tint setting asks for, and nothing at all with
        // background effects off.
        Rectangle {
          anchors.fill: parent
          color: Theme.alpha(Theme.background, bar.fullscreen ? 1 : Services.Config.bar.glass ? Services.Config.bar.tint : 0)
        }

        // Background effects on: the glass band above, then the tint.
        // Off, the bar stays fully clear.

        Workspaces {
          id: workspaces
          anchors.left: parent.left
          anchors.leftMargin: Theme.barPadding + 3
          foreground: bar.foregroundOver(workspaces.x, workspaces.width)
        }

        // The right-hand icons. Drag one sideways to move it; the others
        // slide aside, and the order is saved to config.json (bar.order).
        Item {
          id: row
          anchors.right: parent.right
          anchors.rightMargin: Theme.barPadding + 3
          height: parent.height
          width: layout.width

          readonly property var defaultOrder: ["jot", "tray", "bose", "things", "tailscale", "network", "control-center", "clock"]
          // The saved order, cleaned up: unknown names dropped, new ones put
          // back where the default has them.
          function savedOrder() {
            var saved = Services.Config.bar.order || []
            var out = []
            for (var i = 0; i < saved.length; i++)
              if (defaultOrder.indexOf(saved[i]) >= 0 && out.indexOf(saved[i]) < 0) out.push(saved[i])
            for (var j = 0; j < defaultOrder.length; j++) {
              if (out.indexOf(defaultOrder[j]) >= 0) continue
              var at = out.length
              for (var k = j + 1; k < defaultOrder.length; k++) {
                var next = out.indexOf(defaultOrder[k])
                if (next >= 0) { at = next; break }
              }
              out.splice(at, 0, defaultOrder[j])
            }
            return out
          }
          property var order: savedOrder()

          function widget(name) {
            return { "jot": jot, "tray": tray, "bose": bose, "things": things, "tailscale": tailscale,
                     "network": network, "control-center": controlCenter, "clock": clock }[name]
          }

          // Where each icon sits; a recording in progress always comes first.
          readonly property var layout: {
            var x = recording.visible ? recording.implicitWidth : 0
            var xs = {}
            for (var i = 0; i < order.length; i++) {
              var w = widget(order[i])
              xs[order[i]] = x
              if (w && w.visible) x += w.implicitWidth
            }
            return { start: recording.visible ? recording.implicitWidth : 0, xs: xs, width: x }
          }

          property string dragging: ""
          property real dragStart: 0
          property real dragX: 0
          // Slide only while something is being moved, not at startup.
          readonly property bool animate: dragging !== "" || settle.running

          Timer { id: settle; interval: 220 }

          function beginMove(name) {
            dragging = name
            dragStart = layout.xs[name]
            dragX = dragStart
          }
          function move(name, dx) {
            if (dragging !== name) return
            var w = widget(name).implicitWidth
            dragX = Math.max(layout.start, Math.min(layout.width - w, dragStart + dx))
            // Put the icon before the first one whose middle it is left of.
            var centre = dragX + w / 2
            var rest = order.filter(function(n) { return n !== name })
            var pos = layout.start
            var at = rest.length
            for (var i = 0; i < rest.length; i++) {
              var other = widget(rest[i])
              if (!other.visible) continue
              if (centre < pos + other.implicitWidth / 2) { at = i; break }
              pos += other.implicitWidth
            }
            var next = rest.slice(0, at).concat([name], rest.slice(at))
            if (next.join() !== order.join()) order = next
          }
          function endMove(name) {
            if (dragging !== name) return
            dragging = ""
            settle.restart()
            Services.Config.bar.order = order.slice()
            order = Qt.binding(savedOrder)
          }
          function slotX(name) { return dragging === name ? dragX : (layout.xs[name] || 0) }

          // A recording in progress: its time, and click to stop.
          Recording { id: recording; x: 0 }
          Jot {
            id: jot; x: row.slotX("jot"); z: moving ? 1 : 0
            foreground: bar.foregroundOver(row.x + jot.x, jot.width)
            movable: true; onMoveStarted: row.beginMove("jot"); onMoved: dx => row.move("jot", dx); onMoveEnded: row.endMove("jot")
            BarSlide on x {}
          }
          Tray {
            id: tray; x: row.slotX("tray"); z: moving ? 1 : 0
            foreground: bar.foregroundOver(row.x + tray.x, tray.width)
            movable: true; onMoveStarted: row.beginMove("tray"); onMoved: dx => row.move("tray", dx); onMoveEnded: row.endMove("tray")
            BarSlide on x {}
          }
          Bose {
            id: bose; x: row.slotX("bose"); z: moving ? 1 : 0
            foreground: bar.foregroundOver(row.x + bose.x, bose.width)
            movable: true; onMoveStarted: row.beginMove("bose"); onMoved: dx => row.move("bose", dx); onMoveEnded: row.endMove("bose")
            BarSlide on x {}
          }
          Things {
            id: things; x: row.slotX("things"); z: moving ? 1 : 0
            foreground: bar.foregroundOver(row.x + things.x, things.width)
            movable: true; onMoveStarted: row.beginMove("things"); onMoved: dx => row.move("things", dx); onMoveEnded: row.endMove("things")
            BarSlide on x {}
          }
          Tailscale {
            id: tailscale; x: row.slotX("tailscale"); z: moving ? 1 : 0
            foreground: bar.foregroundOver(row.x + tailscale.x, tailscale.width)
            movable: true; onMoveStarted: row.beginMove("tailscale"); onMoved: dx => row.move("tailscale", dx); onMoveEnded: row.endMove("tailscale")
            BarSlide on x {}
          }
          Network {
            id: network; x: row.slotX("network"); z: moving ? 1 : 0
            foreground: bar.foregroundOver(row.x + network.x, network.width)
            movable: true; onMoveStarted: row.beginMove("network"); onMoved: dx => row.move("network", dx); onMoveEnded: row.endMove("network")
            BarSlide on x {}
          }
          ControlCenter {
            id: controlCenter; x: row.slotX("control-center"); z: moving ? 1 : 0
            foreground: bar.foregroundOver(row.x + controlCenter.x, controlCenter.width)
            movable: true; onMoveStarted: row.beginMove("control-center"); onMoved: dx => row.move("control-center", dx); onMoveEnded: row.endMove("control-center")
            BarSlide on x {}
          }
          Clock {
            id: clock; x: row.slotX("clock"); z: moving ? 1 : 0
            foreground: bar.foregroundOver(row.x + clock.x, clock.width)
            movable: true; onMoveStarted: row.beginMove("clock"); onMoved: dx => row.move("clock", dx); onMoveEnded: row.endMove("clock")
            BarSlide on x {}
          }
        }
      }
    }
  }
}
