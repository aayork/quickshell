import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui

// The area picker, after CleanShot X's. bin/screenshot freezes the monitor
// into a still (grim) and asks for a pick; this shows that still full screen
// and lets you choose part of it:
//
//   drag            select an area (Shift keeps it square)
//   Space, held     move the area while dragging
//   click / Enter   take the window under the pointer (or the whole screen)
//   arrow keys      nudge the crosshair a pixel (Shift: ten)
//   M               show or hide the magnifier
//   Esc, right click, or the shortcut again   cancel
//
// Drawn as CleanShot draws it: the screen untouched until you drag, a small
// crosshair with its coordinates beside it, then the outside dimmed, white
// handles on the selection's corners and edges, and its size by the pointer.
// The result is cropped out of the still, so nothing of the picker gets in.
Scope {
  id: root

  property bool open: false
  property string mode: "smart"
  property string monitorName: ""
  property string frozen: ""
  property string out: ""

  // The monitor's place in the layout, and the windows on show there,
  // topmost first, in this screen's own coordinates.
  property var monitorInfo: null
  property var windows: []

  Connections {
    target: Captures
    function onPickRequested(mode, monitor, frozen, out) {
      root.mode = mode
      root.monitorName = monitor
      root.frozen = frozen
      root.out = out
      layout.running = true
    }
    function onPickCancelled() { root.cancel() }
  }

  function start() {
    surface.reset()
    open = true
    Captures.picking = true
  }

  function cancel() {
    if (!open && frozen === "") return
    open = false
    Captures.picking = false
    if (frozen !== "") Quickshell.execDetached(["rm", "-f", "--", frozen])
    frozen = ""
  }

  // Crop the still to `rect` (in this screen's coordinates) and hand it on.
  function finish(rect) {
    if (!rect || rect.w < 1 || rect.h < 1) return cancel()
    var ratio = surface.ratio
    var x = Math.round(rect.x * ratio), y = Math.round(rect.y * ratio)
    var w = Math.max(1, Math.round(rect.w * ratio)), h = Math.max(1, Math.round(rect.h * ratio))
    open = false
    Captures.picking = false
    crop.command = ["sh", "-c", "magick \"$1\" -crop \"$3\" +repage \"$2\" && rm -f -- \"$1\"", "sh",
      frozen, out, w + "x" + h + "+" + x + "+" + y]
    crop.running = true
  }

  Process {
    id: crop
    onExited: function(code) {
      if (code === 0) Captures.add(root.out)
      root.frozen = ""
    }
  }

  // Monitors and windows, read once each time the picker opens.
  Process {
    id: layout
    command: ["sh", "-c", "hyprctl monitors -j; printf '\\n\\036\\n'; hyprctl clients -j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var parts = text.split("\u001e")
          var monitors = JSON.parse(parts[0])
          var clients = JSON.parse(parts[1])
          var mon = monitors.find(m => m.name === root.monitorName) || monitors.find(m => m.focused) || monitors[0]
          root.monitorInfo = mon
          var shown = [mon.activeWorkspace ? mon.activeWorkspace.id : -1, mon.specialWorkspace ? mon.specialWorkspace.id : 0]
          var list = clients.filter(c => c.mapped !== false && c.hidden !== true && shown.indexOf(c.workspace.id) !== -1)
          // Fullscreen first, then floating over tiled, then most recently focused.
          list.sort(function(a, b) {
            var fa = a.fullscreen ? 0 : a.floating ? 1 : 2
            var fb = b.fullscreen ? 0 : b.floating ? 1 : 2
            return fa - fb || a.focusHistoryID - b.focusHistoryID
          })
          root.windows = list.map(c => ({ x: c.at[0] - mon.x, y: c.at[1] - mon.y, w: c.size[0], h: c.size[1] }))
        } catch (e) {
          root.windows = []
        }
        root.start()
      }
    }
  }

  PanelWindow {
    id: window

    screen: Quickshell.screens.find(s => s.name === root.monitorName)
      ?? Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
      ?? Quickshell.screens[0]
    visible: root.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "black"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aayork-area-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) surface.forceActiveFocus()

    Item {
      id: surface
      anchors.fill: parent
      focus: true

      // Device pixels per point: the still is at the monitor's full resolution.
      readonly property real ratio: still.implicitWidth > 0 ? still.implicitWidth / width : 1
      readonly property int zoom: 8

      // The crosshair, which follows the pointer and the arrow keys.
      property real cx: width / 2
      property real cy: height / 2
      property bool dragging: false
      property bool moving: false
      property real ax: 0
      property real ay: 0
      property bool square: false
      property bool seen: false
      // The magnifier, off unless asked for (M), as in CleanShot.
      property bool magnify: false

      function reset() {
        dragging = false
        moving = false
        square = false
        seen = false
      }

      function clampX(v) { return Math.max(0, Math.min(width - 1, v)) }
      function clampY(v) { return Math.max(0, Math.min(height - 1, v)) }

      // The area between the anchor and the crosshair.
      readonly property var selection: {
        if (!dragging) return null
        var w = Math.abs(cx - ax), h = Math.abs(cy - ay)
        if (square) { var side = Math.max(w, h); w = side; h = side }
        var x = cx >= ax ? ax : ax - w
        var y = cy >= ay ? ay : ay - h
        x = Math.max(0, x); y = Math.max(0, y)
        w = Math.min(width - x, w); h = Math.min(height - y, h)
        return { x: x, y: y, w: w, h: h }
      }

      // The window under the crosshair, when not dragging.
      readonly property var hovered: {
        if (dragging || !seen) return null
        for (var i = 0; i < root.windows.length; i++) {
          var r = root.windows[i]
          if (cx >= r.x && cx < r.x + r.w && cy >= r.y && cy < r.y + r.h) return r
        }
        return null
      }

      // What gets taken: the selection, else the window under the pointer.
      readonly property var target: selection && selection.w >= 1 ? selection : hovered

      function pickPoint() {
        root.finish(hovered || { x: 0, y: 0, w: width, h: height })
      }

      function moveTo(x, y) {
        var nx = clampX(x), ny = clampY(y)
        if (dragging && moving) {
          ax = clampX(ax + nx - cx)
          ay = clampY(ay + ny - cy)
        }
        cx = nx
        cy = ny
        seen = true
      }

      Keys.onPressed: function(event) {
        var step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1
        if (event.key === Qt.Key_Escape) root.cancel()
        else if (event.key === Qt.Key_Space && !event.isAutoRepeat) moving = true
        else if (event.key === Qt.Key_Shift) square = true
        else if (event.key === Qt.Key_M) magnify = !magnify
        else if (event.key === Qt.Key_Left) moveTo(cx - step, cy)
        else if (event.key === Qt.Key_Right) moveTo(cx + step, cy)
        else if (event.key === Qt.Key_Up) moveTo(cx, cy - step)
        else if (event.key === Qt.Key_Down) moveTo(cx, cy + step)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (dragging && selection && selection.w >= 4 && selection.h >= 4) root.finish(selection)
          else pickPoint()
        } else return
        event.accepted = true
      }
      Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat) moving = false
        else if (event.key === Qt.Key_Shift) square = false
      }

      Image {
        id: still
        anchors.fill: parent
        source: root.frozen !== "" ? "file://" + root.frozen : ""
        cache: false
        smooth: true
      }

      // While dragging: the outside dimmed, the selection outlined, with
      // white L-shaped handles on its corners and short bars mid-edge.
      Item {
        anchors.fill: parent
        readonly property var r: surface.selection && surface.selection.w >= 1 ? surface.selection : null
        readonly property color shade: Theme.alpha("#000000", 0.38)
        visible: !!r

        Rectangle { x: 0; y: 0; width: parent.width; height: parent.r ? parent.r.y : 0; color: parent.shade }
        Rectangle { x: 0; y: parent.r ? parent.r.y + parent.r.h : 0; width: parent.width; height: parent.r ? parent.height - parent.r.y - parent.r.h : 0; color: parent.shade }
        Rectangle { x: 0; y: parent.r ? parent.r.y : 0; width: parent.r ? parent.r.x : 0; height: parent.r ? parent.r.h : 0; color: parent.shade }
        Rectangle { x: parent.r ? parent.r.x + parent.r.w : 0; y: parent.r ? parent.r.y : 0; width: parent.r ? parent.width - parent.r.x - parent.r.w : 0; height: parent.r ? parent.r.h : 0; color: parent.shade }

        Item {
          x: parent.r ? parent.r.x : 0
          y: parent.r ? parent.r.y : 0
          width: parent.r ? parent.r.w : 0
          height: parent.r ? parent.r.h : 0

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha("#ffffff", 0.7)
          }

          // Corners: two bars each, 3 px thick, sitting just outside.
          Repeater {
            model: [[0, 0], [1, 0], [0, 1], [1, 1]]
            Item {
              required property var modelData
              readonly property int len: Math.min(16, Math.max(6, Math.min(parent.width, parent.height) / 3))
              x: modelData[0] ? parent.width - len + 3 : -3
              y: modelData[1] ? parent.height - len + 3 : -3
              width: len
              height: len
              Rectangle { x: 0; y: parent.modelData[1] ? parent.height - 3 : 0; width: parent.width; height: 3; color: "#ffffff" }
              Rectangle { x: parent.modelData[0] ? parent.width - 3 : 0; y: 0; width: 3; height: parent.height; color: "#ffffff" }
            }
          }
          // Mid-edge handles.
          Rectangle { visible: parent.width > 48; x: (parent.width - 14) / 2; y: -2; width: 14; height: 3; radius: 1.5; color: "#ffffff" }
          Rectangle { visible: parent.width > 48; x: (parent.width - 14) / 2; y: parent.height - 1; width: 14; height: 3; radius: 1.5; color: "#ffffff" }
          Rectangle { visible: parent.height > 48; x: -2; y: (parent.height - 14) / 2; width: 3; height: 14; radius: 1.5; color: "#ffffff" }
          Rectangle { visible: parent.height > 48; x: parent.width - 1; y: (parent.height - 14) / 2; width: 3; height: 14; radius: 1.5; color: "#ffffff" }
        }
      }

      // The window under the pointer, when a click would take it: a soft
      // tint and an outline, nothing else dimmed.
      Rectangle {
        readonly property var r: surface.dragging ? null : surface.hovered
        visible: !!r
        x: r ? r.x : 0
        y: r ? r.y : 0
        width: r ? r.w : 0
        height: r ? r.h : 0
        color: Theme.alpha(Theme.accent, 0.14)
        border.width: 2
        border.color: Theme.alpha(Theme.accent, 0.8)
      }

      // The pointer: a small crosshair with a ring, black with a white halo
      // so it shows on any picture, and beside it the coordinates (or, while
      // dragging, the size) in two short lines.
      Item {
        id: crosshair
        visible: surface.seen && !surface.moving
        x: Math.round(surface.cx)
        y: Math.round(surface.cy)

        Repeater {
          // Halo first, then the black lines over it.
          model: [{ c: Theme.alpha("#ffffff", 0.85), w: 3 }, { c: "#000000", w: 1 }]
          Item {
            required property var modelData
            Rectangle { x: -11; y: -modelData.w / 2; width: 22; height: modelData.w; color: modelData.c }
            Rectangle { x: -modelData.w / 2; y: -11; width: modelData.w; height: 22; color: modelData.c }
            Rectangle {
              x: -6; y: -6; width: 12; height: 12; radius: 6
              color: "transparent"
              border.width: modelData.w
              border.color: modelData.c
            }
          }
        }

        Column {
          x: 12
          y: 6
          spacing: -2
          Repeater {
            model: surface.dragging && surface.selection
              ? [String(Math.round(surface.selection.w * surface.ratio)), String(Math.round(surface.selection.h * surface.ratio))]
              : [String(Math.round(surface.cx * surface.ratio)), String(Math.round(surface.cy * surface.ratio))]
            Text {
              required property string modelData
              text: modelData
              color: "#000000"
              style: Text.Outline
              styleColor: Theme.alpha("#ffffff", 0.85)
              font.family: Theme.fontFamily
              font.pixelSize: 11
            }
          }
        }
      }

      // The magnifier (M): the pixels under the crosshair, enlarged, with the
      // pixel itself marked.
      Item {
        id: loupe
        readonly property int size: 132
        visible: surface.magnify && surface.seen && !surface.moving
        width: size
        height: size
        x: surface.cx + 34 + size > surface.width ? surface.cx - 34 - size : surface.cx + 34
        y: surface.cy + 34 + size > surface.height ? surface.cy - 34 - size : surface.cy + 34

        RectangularShadow {
          anchors.fill: lens
          radius: lens.width / 2
          blur: 20
          offset.y: 4
          color: Theme.alpha("#000000", 0.6)
        }

        Item {
          id: lens
          width: loupe.size
          height: loupe.size
          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: lensMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
          }

          Rectangle { anchors.fill: parent; color: "black" }

          Image {
            source: still.source
            cache: false
            smooth: false
            width: surface.width * surface.zoom
            height: surface.height * surface.zoom
            x: -surface.cx * surface.zoom + loupe.size / 2 - surface.zoom / 2
            y: -surface.cy * surface.zoom + loupe.size / 2 - surface.zoom / 2
          }

          Rectangle {
            x: (loupe.size - surface.zoom) / 2 - 1
            y: (loupe.size - surface.zoom) / 2 - 1
            width: surface.zoom + 2
            height: surface.zoom + 2
            color: "transparent"
            border.width: 1
            border.color: "#ffffff"
          }
        }

        Item {
          id: lensMask
          width: loupe.size
          height: loupe.size
          visible: false
          layer.enabled: true
          Rectangle { anchors.fill: parent; radius: width / 2 }
        }

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: "transparent"
          border.width: 2
          border.color: Theme.alpha("#ffffff", 0.9)
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // The crosshair above stands in for the pointer.
        cursorShape: Qt.BlankCursor

        onPositionChanged: function(mouse) { surface.moveTo(mouse.x, mouse.y) }
        onPressed: function(mouse) {
          surface.moveTo(mouse.x, mouse.y)
          if (mouse.button === Qt.RightButton) return root.cancel()
          if (root.mode === "windows") return
          surface.ax = mouse.x
          surface.ay = mouse.y
          surface.dragging = true
        }
        onReleased: function(mouse) {
          if (mouse.button !== Qt.LeftButton) return
          if (root.mode === "windows") return surface.pickPoint()
          var sel = surface.selection
          surface.dragging = false
          surface.moving = false
          // A click rather than a drag takes the window under it.
          if (!sel || sel.w < 4 || sel.h < 4) surface.pickPoint()
          else root.finish(sel)
        }
      }
    }
  }
}
