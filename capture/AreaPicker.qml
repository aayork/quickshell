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
//   Esc, right click, or the shortcut again   cancel
//
// A loupe beside the pointer magnifies the pixels under it with their
// coordinates, and the selection shows its size as you drag. The result is
// cropped out of the still, so nothing of the picker gets into it.
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

      // Dim everything but the focus.
      Item {
        anchors.fill: parent
        readonly property var r: surface.target
        readonly property color shade: Theme.alpha("#000000", 0.42)

        Rectangle { visible: !parent.r; anchors.fill: parent; color: Theme.alpha("#000000", 0.22) }
        Rectangle { visible: !!parent.r; x: 0; y: 0; width: parent.width; height: parent.r ? parent.r.y : 0; color: parent.shade }
        Rectangle { visible: !!parent.r; x: 0; y: parent.r ? parent.r.y + parent.r.h : 0; width: parent.width; height: parent.r ? parent.height - parent.r.y - parent.r.h : 0; color: parent.shade }
        Rectangle { visible: !!parent.r; x: 0; y: parent.r ? parent.r.y : 0; width: parent.r ? parent.r.x : 0; height: parent.r ? parent.r.h : 0; color: parent.shade }
        Rectangle { visible: !!parent.r; x: parent.r ? parent.r.x + parent.r.w : 0; y: parent.r ? parent.r.y : 0; width: parent.r ? parent.width - parent.r.x - parent.r.w : 0; height: parent.r ? parent.r.h : 0; color: parent.shade }

        // The outline: white, with a dark line outside it for contrast.
        Rectangle {
          visible: !!parent.r
          x: parent.r ? parent.r.x - 1 : 0
          y: parent.r ? parent.r.y - 1 : 0
          width: parent.r ? parent.r.w + 2 : 0
          height: parent.r ? parent.r.h + 2 : 0
          color: "transparent"
          border.width: 1
          border.color: Theme.alpha("#000000", 0.45)
          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            border.width: 1
            border.color: surface.dragging ? "#ffffff" : Theme.alpha("#ffffff", 0.85)
          }
        }
      }

      // Crosshair lines across the screen while choosing a starting point.
      Item {
        anchors.fill: parent
        visible: !surface.dragging && surface.seen
        Rectangle { x: 0; y: Math.round(surface.cy); width: parent.width; height: 1; color: Theme.alpha("#ffffff", 0.45) }
        Rectangle { x: Math.round(surface.cx); y: 0; width: 1; height: parent.height; color: Theme.alpha("#ffffff", 0.45) }
      }

      // Size, in device pixels, under the selection (or above it when it
      // reaches the bottom of the screen).
      Rectangle {
        id: sizeTag
        readonly property var r: surface.target
        visible: !!r
        x: r ? Math.max(4, Math.min(parent.width - width - 4, r.x + r.w - width)) : 0
        y: r ? (r.y + r.h + height + 10 < parent.height ? r.y + r.h + 8 : Math.max(4, r.y - height - 8)) : 0
        width: sizeLabel.implicitWidth + 16
        height: 22
        radius: 6
        color: Theme.alpha("#000000", 0.75)
        border.width: 1
        border.color: Theme.alpha("#ffffff", 0.18)
        Label {
          id: sizeLabel
          anchors.centerIn: parent
          text: sizeTag.r ? Math.round(sizeTag.r.w * surface.ratio) + " × " + Math.round(sizeTag.r.h * surface.ratio) : ""
          color: "#ffffff"
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
      }

      // The loupe: the pixels under the crosshair, magnified, with a
      // centre marker and the coordinates below.
      Item {
        id: loupe
        readonly property int size: 132
        visible: surface.seen && !surface.moving
        width: size
        height: size + 26
        x: surface.cx + 26 + size > surface.width ? surface.cx - 26 - size : surface.cx + 26
        y: surface.cy + 26 + height > surface.height ? surface.cy - 26 - height : surface.cy + 26

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

          // Faint crosshair through the lens, and the pixel under the pointer.
          Rectangle { x: 0; y: (loupe.size - surface.zoom) / 2; width: loupe.size; height: surface.zoom; color: Theme.alpha("#ffffff", 0.1) }
          Rectangle { x: (loupe.size - surface.zoom) / 2; y: 0; width: surface.zoom; height: loupe.size; color: Theme.alpha("#ffffff", 0.1) }
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
          width: loupe.size
          height: loupe.size
          radius: width / 2
          color: "transparent"
          border.width: 2
          border.color: Theme.alpha("#ffffff", 0.9)
        }

        Rectangle {
          anchors.horizontalCenter: lens.horizontalCenter
          anchors.top: lens.bottom
          anchors.topMargin: 6
          width: coords.implicitWidth + 14
          height: 20
          radius: 6
          color: Theme.alpha("#000000", 0.75)
          Label {
            id: coords
            anchors.centerIn: parent
            text: Math.round(surface.cx * surface.ratio) + ", " + Math.round(surface.cy * surface.ratio)
            color: "#ffffff"
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideNone
          }
        }
      }

      // What the keys do, along the bottom until the pointer first moves.
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        visible: !surface.dragging
        opacity: surface.seen ? 0.0 : 1
        Behavior on opacity { NumberAnimation { duration: 400 } }
        width: hint.implicitWidth + 28
        height: 32
        radius: 16
        color: Theme.alpha("#000000", 0.72)
        border.width: 1
        border.color: Theme.alpha("#ffffff", 0.15)
        Label {
          id: hint
          anchors.centerIn: parent
          text: root.mode === "windows"
            ? "Click a window  ·  Esc to cancel"
            : "Drag to select  ·  Click a window  ·  Space to move  ·  Shift for a square  ·  Esc to cancel"
          color: "#ffffff"
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor

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
