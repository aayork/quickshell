import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.ui

// The screenshot editor: mark a capture up, crop it, put it on a background,
// then copy, save or pin the result.
//
// Everything is drawn in the picture's own pixels on a "sheet" that is scaled
// down to fit the screen, so what is exported is full resolution whatever
// size it is shown at.
Scope {
  id: root

  property bool open: false
  property string path: ""
  readonly property real naturalWidth: shot.implicitWidth
  readonly property real naturalHeight: shot.implicitHeight

  // Annotations, oldest first. Each is a plain object; see `begin`.
  property var ops: []
  property var undone: []
  // The one being drawn right now.
  property var draft: null

  property string tool: "arrow"
  property color ink: Theme.red
  // 0, 1, 2: thin, medium, thick.
  property int weight: 1
  // The part of the picture that is kept, in its own pixels.
  property rect crop: Qt.rect(0, 0, 0, 0)
  // The frame around it.
  property int padding: 0
  property int rounding: 0
  property bool shadow: false
  // "none", "theme", "accent" or "wallpaper".
  property string backdrop: "none"
  property bool exporting: false

  // Stroke widths follow the picture's size, so a line looks the same on a
  // small window grab and a full 4K screen.
  readonly property real unit: Math.max(2, Math.round(Math.max(naturalWidth, naturalHeight) / 600))
  readonly property real strokeWidth: unit * [1, 2, 3.5][weight]
  readonly property int counters: ops.filter(o => o.type === "counter").length

  readonly property var tools: [
    { id: "arrow", glyph: 0xF005C, name: "Arrow", key: "A" },
    { id: "line", glyph: 0xF055E, name: "Line", key: "L" },
    { id: "rect", glyph: 0xF0E5F, name: "Rectangle", key: "R" },
    { id: "ellipse", glyph: 0xF0EA1, name: "Ellipse", key: "O" },
    { id: "pen", glyph: 0xF03EB, name: "Pen", key: "P" },
    { id: "highlighter", glyph: 0xF0652, name: "Highlighter", key: "H" },
    { id: "text", glyph: 0xF0284, name: "Text", key: "T" },
    { id: "counter", glyph: 0xF0CA1, name: "Numbered step", key: "N" },
    { id: "blur", glyph: 0xF00B5, name: "Blur", key: "B" },
    { id: "pixelate", glyph: 0xF013A, name: "Pixelate", key: "X" },
    { id: "redact", glyph: 0xF0764, name: "Black out", key: "D" },
    { id: "spotlight", glyph: 0xF04C9, name: "Spotlight", key: "S" },
    { id: "crop", glyph: 0xF019E, name: "Crop", key: "C" }
  ]
  readonly property var inks: [Theme.red, pickOrange, Theme.yellow, Theme.green, pickBlue, Theme.accent, Theme.brightForeground, Theme.background]
  readonly property color pickOrange: Theme.pick("orange", "#da956c")
  readonly property color pickBlue: Theme.pick("blue", "#6c91da")

  function edit(file) {
    ops = []
    undone = []
    draft = null
    padding = 0
    rounding = 0
    shadow = false
    backdrop = "none"
    tool = "arrow"
    path = file
    // The picture loads at once, so its size is known here. Keep the whole of it.
    crop = Qt.rect(0, 0, naturalWidth, naturalHeight)
    open = true
  }

  function close() {
    textEntry.cancel()
    open = false
    path = ""
  }

  function commit(op) {
    ops = ops.concat([op])
    undone = []
  }

  function undo() {
    if (ops.length === 0) return
    undone = undone.concat([ops[ops.length - 1]])
    ops = ops.slice(0, -1)
  }

  function redo() {
    if (undone.length === 0) return
    ops = ops.concat([undone[undone.length - 1]])
    undone = undone.slice(0, -1)
  }

  // A press at (x, y) in picture pixels starts the current tool.
  function begin(x, y) {
    if (tool === "text") {
      textEntry.start(x, y)
      return
    }
    if (tool === "counter") {
      commit({ type: "counter", x: x, y: y, n: counters + 1, color: ink, size: unit * 9 })
      return
    }
    var op = { type: tool, x1: x, y1: y, x2: x, y2: y, color: ink, width: strokeWidth }
    if (tool === "pen" || tool === "highlighter") op.points = [Qt.point(x, y)]
    if (tool === "highlighter") op.width = strokeWidth * 5
    draft = op
  }

  function drag(x, y) {
    if (!draft) return
    var next = Object.assign({}, draft, { x2: x, y2: y })
    if (draft.points) next.points = draft.points.concat([Qt.point(x, y)])
    draft = next
  }

  function end() {
    if (!draft) return
    var op = draft
    draft = null
    var box = boxOf(op)
    var tiny = box.width < unit * 2 && box.height < unit * 2
    if (op.type === "crop") {
      if (!tiny) crop = Qt.rect(Math.round(box.x), Math.round(box.y), Math.round(box.width), Math.round(box.height))
      return
    }
    // A click without a drag draws nothing.
    if (tiny && !op.points) return
    commit(op)
  }

  function boxOf(op) {
    return Qt.rect(Math.min(op.x1, op.x2), Math.min(op.y1, op.y2), Math.abs(op.x2 - op.x1), Math.abs(op.y2 - op.y1))
  }

  // Renders the sheet at full size into a new file, then hands it on.
  function exportTo(then) {
    textEntry.commit()
    exporting = true
    var out = Captures.newPath()
    Qt.callLater(function() {
      sheet.grabToImage(function(result) {
        result.saveToFile(out)
        root.exporting = false
        then(out)
      }, Qt.size(Math.round(sheet.width), Math.round(sheet.height)))
    })
  }

  function finish(action) {
    var original = path
    exportTo(function(out) {
      Captures.dismiss(original)
      if (action === "copy") Captures.copy(out)
      else if (action === "save") Captures.save(out)
      else if (action === "pin") Captures.pin(out)
      else Captures.add(out)
      Captures.refresh()
      root.close()
    })
  }

  Connections {
    target: Captures
    function onEditRequested(path) { root.edit(path) }
  }

  // The crop defaults to the whole picture once its size is known.
  onNaturalWidthChanged: if (crop.width === 0 && naturalWidth > 0) crop = Qt.rect(0, 0, naturalWidth, naturalHeight)

  // ------------------------------------------------------------ annotations
  component Annotation: Loader {
    id: note
    property var op
    readonly property rect box: root.boxOf(op)

    anchors.fill: parent
    sourceComponent: op.type === "arrow" ? arrow : op.type === "line" ? line
      : op.type === "rect" ? rectangle : op.type === "ellipse" ? ellipse
      : op.type === "pen" || op.type === "highlighter" ? stroke
      : op.type === "text" ? label : op.type === "counter" ? counter
      : op.type === "blur" ? blur : op.type === "pixelate" ? pixelate
      : op.type === "redact" ? redact : op.type === "crop" ? cropMark : null

    Component {
      id: arrow
      Shape {
        readonly property real angle: Math.atan2(note.op.y2 - note.op.y1, note.op.x2 - note.op.x1)
        readonly property real head: note.op.width * 4.5
        // The shaft stops short so its round end does not poke out of the tip.
        readonly property real baseX: note.op.x2 - Math.cos(angle) * head * 0.8
        readonly property real baseY: note.op.y2 - Math.sin(angle) * head * 0.8
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeColor: note.op.color
          strokeWidth: note.op.width
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          startX: note.op.x1
          startY: note.op.y1
          PathLine { x: baseX; y: baseY }
        }
        ShapePath {
          strokeColor: "transparent"
          fillColor: note.op.color
          startX: note.op.x2
          startY: note.op.y2
          PathLine { x: note.op.x2 - Math.cos(angle - 0.45) * head; y: note.op.y2 - Math.sin(angle - 0.45) * head }
          PathLine { x: note.op.x2 - Math.cos(angle + 0.45) * head; y: note.op.y2 - Math.sin(angle + 0.45) * head }
          PathLine { x: note.op.x2; y: note.op.y2 }
        }
      }
    }

    Component {
      id: line
      Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: note.op.color
          strokeWidth: note.op.width
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          startX: note.op.x1
          startY: note.op.y1
          PathLine { x: note.op.x2; y: note.op.y2 }
        }
      }
    }

    Component {
      id: rectangle
      Item {
        Rectangle {
          x: note.box.x
          y: note.box.y
          width: note.box.width
          height: note.box.height
          color: "transparent"
          border.width: note.op.width
          border.color: note.op.color
          radius: note.op.width
        }
      }
    }

    Component {
      id: ellipse
      Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: note.op.color
          strokeWidth: note.op.width
          fillColor: "transparent"
          PathAngleArc {
            centerX: note.box.x + note.box.width / 2
            centerY: note.box.y + note.box.height / 2
            radiusX: note.box.width / 2
            radiusY: note.box.height / 2
            startAngle: 0
            sweepAngle: 360
          }
        }
      }
    }

    Component {
      id: stroke
      Shape {
        preferredRendererType: Shape.CurveRenderer
        opacity: note.op.type === "highlighter" ? 0.4 : 1
        ShapePath {
          strokeColor: note.op.color
          strokeWidth: note.op.width
          fillColor: "transparent"
          capStyle: note.op.type === "highlighter" ? ShapePath.FlatCap : ShapePath.RoundCap
          joinStyle: ShapePath.RoundJoin
          startX: note.op.points[0].x
          startY: note.op.points[0].y
          PathPolyline { path: note.op.points }
        }
      }
    }

    Component {
      id: label
      Item {
        Text {
          x: note.op.x
          y: note.op.y
          text: note.op.text
          color: note.op.color
          font.family: Theme.fontFamily
          font.pixelSize: note.op.size
          font.bold: true
          style: Text.Outline
          styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
      }
    }

    Component {
      id: counter
      Item {
        Rectangle {
          x: note.op.x - width / 2
          y: note.op.y - height / 2
          width: note.op.size * 2
          height: width
          radius: width / 2
          color: note.op.color
          border.width: Math.max(1, note.op.size / 8)
          border.color: Qt.rgba(1, 1, 1, 0.85)

          Text {
            anchors.centerIn: parent
            text: note.op.n
            // Dark on a light ink, light on a dark one.
            color: (0.299 * note.op.color.r + 0.587 * note.op.color.g + 0.114 * note.op.color.b) > 0.6 ? "#111111" : "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: note.op.size * 1.1
            font.bold: true
          }
        }
      }
    }

    Component {
      id: blur
      Item {
        Item {
          x: note.box.x
          y: note.box.y
          width: note.box.width
          height: note.box.height
          clip: true

          ShaderEffectSource {
            id: blurSource
            anchors.fill: parent
            sourceItem: shot
            sourceRect: note.box
            visible: false
          }
          MultiEffect {
            anchors.fill: parent
            source: blurSource
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1
          }
        }
      }
    }

    Component {
      id: pixelate
      Item {
        // A tiny copy of the area, drawn back at full size without smoothing.
        ShaderEffectSource {
          x: note.box.x
          y: note.box.y
          width: note.box.width
          height: note.box.height
          sourceItem: shot
          sourceRect: note.box
          textureSize: Qt.size(Math.max(1, Math.round(note.box.width / (root.unit * 5))), Math.max(1, Math.round(note.box.height / (root.unit * 5))))
          smooth: false
        }
      }
    }

    Component {
      id: redact
      Item {
        Rectangle {
          x: note.box.x
          y: note.box.y
          width: note.box.width
          height: note.box.height
          color: "#000000"
        }
      }
    }

    // The crop being dragged out: everything outside it dims.
    Component {
      id: cropMark
      Item {
        Shape {
          anchors.fill: parent
          ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.rgba(0, 0, 0, 0.55)
            fillRule: ShapePath.OddEvenFill
            PathSvg {
              path: "M0 0 H" + root.naturalWidth + " V" + root.naturalHeight + " H0 Z M" + note.box.x + " " + note.box.y
                + " h" + note.box.width + " v" + note.box.height + " h" + (-note.box.width) + " Z"
            }
          }
        }
        Rectangle {
          x: note.box.x
          y: note.box.y
          width: note.box.width
          height: note.box.height
          color: "transparent"
          border.width: root.unit
          border.color: "#ffffff"
        }
      }
    }
  }

  // ------------------------------------------------------------ small parts
  component ToolButton: Rectangle {
    id: button
    property int glyph: 0
    property string hint: ""
    property bool selected: false
    signal clicked()

    implicitWidth: 32
    implicitHeight: 32
    radius: Theme.controlRadius + 2
    opacity: enabled ? 1 : 0.35
    color: selected ? Theme.accent : buttonMouse.containsMouse ? Theme.hover : "transparent"

    Label {
      anchors.centerIn: parent
      text: Icons.glyph(button.glyph)
      color: button.selected ? Theme.background : Theme.foreground
      font.pixelSize: Theme.iconLarge
      elide: Text.ElideNone
    }

    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: button.clicked()
    }

    // What it is, and its key, on hover.
    Rectangle {
      visible: buttonMouse.containsMouse && button.hint !== ""
      anchors.top: parent.bottom
      anchors.topMargin: 6
      anchors.horizontalCenter: parent.horizontalCenter
      width: hintLabel.implicitWidth + 12
      height: 22
      radius: Theme.controlRadius
      color: Theme.surface
      border.width: 1
      border.color: Theme.alpha(Theme.foreground, 0.2)
      z: 10

      Label {
        id: hintLabel
        anchors.centerIn: parent
        text: button.hint
        font.pixelSize: Theme.fontSmall
        elide: Text.ElideNone
      }
    }
  }

  component Divider: Rectangle {
    implicitWidth: 1
    implicitHeight: 20
    color: Theme.separator
  }

  // ------------------------------------------------------------ window
  PanelWindow {
    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    visible: root.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.alpha(Theme.darkerBackground, 0.92)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aayork-capture-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    FocusScope {
      id: keys
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        var control = (event.modifiers & Qt.ControlModifier) !== 0
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0
        event.accepted = true
        if (event.key === Qt.Key_Escape) {
          if (root.draft) root.draft = null
          else root.close()
        } else if (control && event.key === Qt.Key_Z) {
          if (shift) root.redo()
          else root.undo()
        } else if (control && event.key === Qt.Key_Y) {
          root.redo()
        } else if (control && event.key === Qt.Key_C) {
          root.finish("copy")
        } else if (control && event.key === Qt.Key_S) {
          root.finish("save")
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.finish("keep")
        } else if (!control) {
          var match = root.tools.find(t => t.key === event.text.toUpperCase())
          if (match) root.tool = match.id
          else event.accepted = false
        } else {
          event.accepted = false
        }
      }

      // ---- tools along the top
      Rectangle {
        id: toolbar
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: toolRow.implicitWidth + 20
        height: 44
        color: Theme.background
        border.width: 1
        border.color: Theme.alpha(Theme.foreground, 0.2)
        radius: Theme.controlRadius + 6
        z: 5

        RowLayout {
          id: toolRow
          anchors.centerIn: parent
          spacing: 4

          Repeater {
            model: root.tools

            ToolButton {
              required property var modelData
              glyph: modelData.glyph
              hint: modelData.name + "  " + modelData.key
              selected: root.tool === modelData.id
              onClicked: root.tool = modelData.id
            }
          }

          Divider {}

          Repeater {
            model: root.inks

            Rectangle {
              required property color modelData
              implicitWidth: 20
              implicitHeight: 20
              radius: 10
              color: modelData
              border.width: Qt.colorEqual(root.ink, modelData) ? 3 : 1
              border.color: Qt.colorEqual(root.ink, modelData) ? Theme.brightForeground : Theme.alpha(Theme.foreground, 0.3)

              MouseArea {
                anchors.fill: parent
                onClicked: root.ink = parent.modelData
              }
            }
          }

          Divider {}

          Repeater {
            model: 3

            Rectangle {
              required property int index
              implicitWidth: 28
              implicitHeight: 28
              radius: Theme.controlRadius + 2
              color: root.weight === index ? Theme.selection : "transparent"

              Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 2 + index * 2.5
                radius: height / 2
                color: Theme.foreground
              }
              MouseArea {
                anchors.fill: parent
                onClicked: root.weight = parent.index
              }
            }
          }

          Divider {}

          ToolButton { glyph: 0xF054C; hint: "Undo  Ctrl Z"; enabled: root.ops.length > 0; onClicked: root.undo() }
          ToolButton { glyph: 0xF044E; hint: "Redo  Ctrl Shift Z"; enabled: root.undone.length > 0; onClicked: root.redo() }
        }
      }

      // ---- frame options down the right
      Rectangle {
        id: side
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 220
        height: sideColumn.implicitHeight + 28
        color: Theme.background
        border.width: 1
        border.color: Theme.alpha(Theme.foreground, 0.2)
        radius: Theme.controlRadius + 6
        z: 5

        ColumnLayout {
          id: sideColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 14
          spacing: 8

          SectionHeader { text: "BACKGROUND" }

          GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
              model: [
                { id: "none", label: "None" },
                { id: "theme", label: "Theme" },
                { id: "accent", label: "Accent" },
                { id: "wallpaper", label: "Wallpaper" }
              ]

              TextButton {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.label
                selected: root.backdrop === modelData.id
                onClicked: {
                  root.backdrop = modelData.id
                  // A background needs room around the picture to show.
                  if (modelData.id !== "none" && root.padding === 0) root.padding = Math.round(root.unit * 20)
                  if (modelData.id === "none") root.padding = 0
                }
              }
            }
          }

          Label { text: "Padding"; color: Theme.dim; font.pixelSize: Theme.fontSmall }
          Slider {
            Layout.fillWidth: true
            enabled: root.backdrop !== "none"
            value: root.padding / (root.unit * 60)
            onMoved: function(value) { root.padding = Math.round(value * root.unit * 60) }
          }

          Label { text: "Rounded corners"; color: Theme.dim; font.pixelSize: Theme.fontSmall }
          Slider {
            Layout.fillWidth: true
            value: root.rounding / (root.unit * 16)
            onMoved: function(value) { root.rounding = Math.round(value * root.unit * 16) }
          }

          RowLayout {
            Layout.fillWidth: true
            Label { text: "Shadow"; Layout.fillWidth: true }
            Toggle {
              enabled: root.backdrop !== "none"
              checked: root.shadow
              onToggled: root.shadow = !root.shadow
            }
          }

          Separator { Layout.fillWidth: true }

          TextButton {
            Layout.fillWidth: true
            text: "Reset crop"
            icon: Icons.glyph(0xF019E)
            enabled: root.crop.width !== root.naturalWidth || root.crop.height !== root.naturalHeight
            onClicked: root.crop = Qt.rect(0, 0, root.naturalWidth, root.naturalHeight)
          }

          Label {
            text: Math.round(sheet.width) + " × " + Math.round(sheet.height) + " px"
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      // ---- what to do with it, along the bottom
      Rectangle {
        id: actions
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: actionRow.implicitWidth + 20
        height: 44
        color: Theme.background
        border.width: 1
        border.color: Theme.alpha(Theme.foreground, 0.2)
        radius: Theme.controlRadius + 6
        z: 5

        RowLayout {
          id: actionRow
          anchors.centerIn: parent
          spacing: 6

          TextButton { text: "Cancel"; icon: Icons.glyph(0xF0156); onClicked: root.close() }
          Divider {}
          TextButton { text: "Copy"; icon: Icons.glyph(0xF018F); onClicked: root.finish("copy") }
          TextButton { text: "Save"; icon: Icons.glyph(0xF0193); onClicked: root.finish("save") }
          TextButton { text: "Pin"; icon: Icons.glyph(0xF0403); onClicked: root.finish("pin") }
          TextButton { text: "Done"; icon: Icons.glyph(0xF012C); selected: true; onClicked: root.finish("keep") }
        }
      }

      // ---- the picture
      Item {
        id: viewport
        anchors.top: toolbar.bottom
        anchors.bottom: actions.top
        anchors.left: parent.left
        anchors.right: side.left
        anchors.margins: 24

        readonly property real fit: Math.min(1, width / Math.max(1, sheet.width), height / Math.max(1, sheet.height))

        // Everything that ends up in the exported file.
        Item {
          id: sheet
          width: root.crop.width + root.padding * 2
          height: root.crop.height + root.padding * 2
          scale: viewport.fit
          transformOrigin: Item.TopLeft
          x: Math.round((viewport.width - width * viewport.fit) / 2)
          y: Math.round((viewport.height - height * viewport.fit) / 2)

          // Background.
          Rectangle {
            anchors.fill: parent
            visible: root.backdrop === "theme"
            color: Theme.background
          }
          Rectangle {
            anchors.fill: parent
            visible: root.backdrop === "accent"
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0; color: Theme.accent }
              GradientStop { position: 1; color: Qt.darker(Theme.accent, 1.7) }
            }
          }
          Image {
            anchors.fill: parent
            visible: root.backdrop === "wallpaper"
            source: visible ? Background.source : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
          }

          // Shadow, cast by a shape the size of the picture.
          Rectangle {
            x: frame.x
            y: frame.y
            width: frame.width
            height: frame.height
            radius: root.rounding
            color: "#000000"
            visible: root.shadow && root.backdrop !== "none"
            layer.enabled: visible
            layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: "#000000"
              shadowOpacity: 0.55
              shadowBlur: 1
              blurMax: 64
              shadowVerticalOffset: root.unit * 4
            }
          }

          Rectangle {
            id: frameMask
            width: frame.width
            height: frame.height
            radius: root.rounding
            visible: false
            layer.enabled: true
          }

          // The kept part of the picture, with its corners rounded.
          Item {
            id: frame
            x: root.padding
            y: root.padding
            width: root.crop.width
            height: root.crop.height
            clip: true
            layer.enabled: root.rounding > 0
            layer.effect: MultiEffect {
              maskEnabled: true
              maskSource: frameMask
              maskThresholdMin: 0.5
              maskSpreadAtMin: 1
            }

            // The whole picture in its own pixels, shifted so the crop shows.
            Item {
              id: stage
              x: -root.crop.x
              y: -root.crop.y
              width: root.naturalWidth
              height: root.naturalHeight

              Image {
                id: shot
                source: root.path !== "" ? "file://" + root.path : ""
                cache: false
                asynchronous: false
                smooth: true
              }

              // Spotlights: one dim layer with a hole for each. Under the other
              // marks, so those stay at full strength.
              Shape {
                id: spotlights
                anchors.fill: parent
                visible: spots.length > 0
                readonly property var spots: root.ops.concat(root.draft ? [root.draft] : []).filter(o => o.type === "spotlight")

                ShapePath {
                  strokeColor: "transparent"
                  fillColor: Qt.rgba(0, 0, 0, 0.6)
                  fillRule: ShapePath.OddEvenFill
                  PathSvg {
                    path: {
                      var d = "M0 0 H" + root.naturalWidth + " V" + root.naturalHeight + " H0 Z"
                      var list = spotlights.spots
                      for (var i = 0; i < list.length; i++) {
                        var b = root.boxOf(list[i])
                        d += " M" + b.x + " " + b.y + " h" + b.width + " v" + b.height + " h" + (-b.width) + " Z"
                      }
                      return d
                    }
                  }
                }
              }

              Repeater {
                model: root.ops.filter(o => o.type !== "spotlight")
                Annotation {
                  required property var modelData
                  op: modelData
                }
              }

              Loader {
                anchors.fill: parent
                active: root.draft !== null && root.draft.type !== "spotlight" && !root.exporting
                sourceComponent: Annotation { op: root.draft }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                onPressed: function(event) {
                  if (textEntry.active) {
                    textEntry.commit()
                    return
                  }
                  root.begin(event.x, event.y)
                }
                onPositionChanged: function(event) { if (pressed) root.drag(event.x, event.y) }
                onReleased: root.end()
              }

              // Typing a text annotation, in place.
              TextInput {
                id: textEntry
                property bool active: false

                function start(px, py) {
                  x = px
                  y = py
                  text = ""
                  active = true
                  forceActiveFocus()
                }
                function commit() {
                  if (!active) return
                  active = false
                  if (text.trim() !== "") root.commit({ type: "text", x: x, y: y, text: text, color: root.ink, size: font.pixelSize })
                  text = ""
                  keys.forceActiveFocus()
                }
                function cancel() {
                  active = false
                  text = ""
                  keys.forceActiveFocus()
                }

                visible: active
                color: root.ink
                font.family: Theme.fontFamily
                font.pixelSize: root.unit * [7, 11, 16][root.weight]
                font.bold: true
                cursorVisible: active
                onAccepted: commit()
                Keys.onEscapePressed: cancel()

                Rectangle {
                  anchors.fill: parent
                  anchors.margins: -root.unit * 2
                  z: -1
                  visible: !root.exporting
                  color: "transparent"
                  border.width: Math.max(1, root.unit / 2)
                  border.color: Qt.rgba(1, 1, 1, 0.6)
                }
              }
            }
          }
        }
      }
    }
  }
}
