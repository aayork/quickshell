import QtQuick
import qs.services
import qs.theme
import qs.ui

// CleanShot's All-In-One bar, under the kept area: the capture modes with
// their names (Area, Fullscreen, Window, Scrolling, Timer, OCR, Recording),
// and beside them a pill with the exact size, an aspect-ratio lock and the
// capture button. Recording swaps the bar for the recording panel: what to
// record (system audio, microphone, cursor) and Record GIF / Record Video.
Item {
  id: root

  // The picker (capture/AreaPicker.qml) and its drawing surface.
  required property var picker
  required property var area

  readonly property var r: area.kept
  readonly property int gap: 14

  width: content.width
  height: content.height
  // As CleanShot places it: inside the area, centred, a little below the
  // middle. An area too small to hold it gets it underneath (or above).
  readonly property bool fitsInside: r && r.w > width + 40 && r.h > height + 60
  x: r ? Math.max(8, Math.min(area.width - width - 8, r.x + r.w / 2 - width / 2)) : 0
  y: {
    if (!r) return 0
    if (fitsInside) return Math.round(r.y + r.h * 0.62 - height / 2)
    if (r.y + r.h + gap + height < area.height - 8) return r.y + r.h + gap
    if (r.y - gap - height > 8) return r.y - gap - height
    return r.y + r.h - height - gap
  }

  readonly property color panel: Theme.alpha("#1e1e20", 0.94)
  readonly property color edge: Theme.alpha("#ffffff", 0.12)

  // Clicks on the bar stay on the bar.
  MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

  Item {
    id: content
    width: picker.recordPanel ? recordColumn.width : modes.width
    height: picker.recordPanel ? recordColumn.height : modes.height

    // ---- the modes, and the size pill
    Row {
      id: modes
      visible: !picker.recordPanel
      spacing: 10

      Rectangle {
        width: modeRow.width + 10
        height: 50
        radius: 13
        color: root.panel
        border.width: 1
        border.color: root.edge

        Row {
          id: modeRow
          anchors.centerIn: parent
          spacing: 0

          Repeater {
            model: [
              { id: "area", label: "Area", glyph: 0xF0489 },
              { id: "fullscreen", label: "Fullscreen", glyph: 0xF0379 },
              { id: "window", label: "Window", glyph: 0xF0614 },
              { id: "scrolling", label: "Scrolling", glyph: 0xF0045 },
              { id: "timer", label: "Timer", glyph: 0xF051B },
              { id: "sep" },
              { id: "ocr", label: "OCR", text: "Aa" },
              { id: "sep" },
              { id: "recording", label: "Recording", glyph: 0xF0BDC }
            ]

            Item {
              id: mode
              required property var modelData
              readonly property bool sep: modelData.id === "sep"
              width: sep ? 11 : Math.max(52, modeLabel.implicitWidth + 14)
              height: 44

              Rectangle {
                visible: mode.sep
                anchors.centerIn: parent
                width: 1
                height: 28
                color: root.edge
              }

              Rectangle {
                visible: !mode.sep
                anchors.fill: parent
                radius: 9
                color: modeMouse.pressed ? Theme.alpha("#ffffff", 0.16) : modeMouse.containsMouse ? Theme.alpha("#ffffff", 0.09) : "transparent"
              }

              Column {
                visible: !mode.sep
                anchors.centerIn: parent
                spacing: 2

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: mode.modelData.text || Icons.glyph(mode.modelData.glyph || 0)
                  color: "#ffffff"
                  font.family: mode.modelData.text ? Theme.fontFamily : Theme.fontFamily
                  font.pixelSize: mode.modelData.text ? 13 : 17
                  font.bold: !!mode.modelData.text
                }
                Text {
                  id: modeLabel
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: mode.modelData.id === "timer" ? "Timer · " + picker.timerSeconds + "s" : (mode.modelData.label || "")
                  color: Theme.alpha("#ffffff", 0.82)
                  font.family: Theme.fontFamily
                  font.pixelSize: 10
                }
              }

              MouseArea {
                id: modeMouse
                anchors.fill: parent
                enabled: !mode.sep
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                // Right click (or the wheel) on Timer changes its delay.
                onWheel: function(wheel) { if (mode.modelData.id === "timer") root.cycleTimer() }
                onClicked: function(mouse) {
                  var id = mode.modelData.id
                  if (id === "timer" && mouse.button === Qt.RightButton) return root.cycleTimer()
                  if (mouse.button !== Qt.LeftButton) return
                  if (id === "area") picker.aioArea()
                  else if (id === "fullscreen") picker.aioFullscreen()
                  else if (id === "window") picker.aioWindow()
                  else if (id === "scrolling") picker.aioScrolling()
                  else if (id === "timer") picker.aioTimer()
                  else if (id === "ocr") picker.aioOcr()
                  else if (id === "recording") picker.recordPanel = true
                }
              }
            }
          }
        }
      }

      // Exact size, the ratio lock, and the capture button.
      Rectangle {
        width: sizeRow.width + 18
        height: 50
        radius: 13
        color: root.panel
        border.width: 1
        border.color: root.edge

        Row {
          id: sizeRow
          anchors.centerIn: parent
          spacing: 6

          SizeField {
            anchors.verticalCenter: parent.verticalCenter
            value: root.r ? Math.round(root.r.w * area.ratio) : 0
            onCommitted: function(v) { area.setSize(v, Math.round(root.r.h * area.ratio)); area.forceActiveFocus() }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "×"
            color: Theme.alpha("#ffffff", 0.6)
            font.family: Theme.fontFamily
            font.pixelSize: 14
          }
          SizeField {
            anchors.verticalCenter: parent.verticalCenter
            value: root.r ? Math.round(root.r.h * area.ratio) : 0
            onCommitted: function(v) { area.setSize(Math.round(root.r.w * area.ratio), v); area.forceActiveFocus() }
          }

          // Aspect-ratio lock.
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 24
            radius: 6
            color: picker.lockRatio ? Theme.alpha("#ffffff", 0.2) : lockMouse.containsMouse ? Theme.alpha("#ffffff", 0.09) : "transparent"
            border.width: 1
            border.color: picker.lockRatio ? Theme.alpha("#ffffff", 0.4) : root.edge
            Text {
              anchors.centerIn: parent
              text: Icons.glyph(0xF0616)
              color: picker.lockRatio ? "#ffffff" : Theme.alpha("#ffffff", 0.6)
              font.family: Theme.fontFamily
              font.pixelSize: 14
            }
            MouseArea {
              id: lockMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: picker.lockRatio = !picker.lockRatio
            }
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 28
            color: root.edge
          }

          // Capture the area (Enter does the same).
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 8
            color: shotMouse.pressed ? Theme.alpha("#ffffff", 0.16) : shotMouse.containsMouse ? Theme.alpha("#ffffff", 0.09) : "transparent"
            Text {
              anchors.centerIn: parent
              text: Icons.glyph(0xF019E)
              color: "#ffffff"
              font.family: Theme.fontFamily
              font.pixelSize: 17
            }
            MouseArea {
              id: shotMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: picker.aioArea()
            }
          }
        }
      }
    }

    // ---- the recording panel
    Column {
      id: recordColumn
      visible: picker.recordPanel
      spacing: 8
      width: 260

      Rectangle {
        width: parent.width
        height: 104
        radius: 18
        color: root.panel
        border.width: 1
        border.color: root.edge

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          y: 12
          text: root.r ? Math.round(root.r.w * area.ratio) + "  ×  " + Math.round(root.r.h * area.ratio) : ""
          color: "#ffffff"
          font.family: Theme.fontFamily
          font.pixelSize: 15
        }

        Rectangle { x: 0; y: 46; width: parent.width; height: 1; color: root.edge }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          y: 54
          spacing: 6

          Repeater {
            model: [
              { key: "recMic", on: 0xF036C, off: 0xF036D, hint: "Microphone" },
              { key: "recSystem", on: 0xF057E, off: 0xF0581, hint: "System audio" },
              { key: "recCursor", on: 0xF01C0, off: 0xF01C0, hint: "Cursor" }
            ]

            Rectangle {
              id: option
              required property var modelData
              readonly property bool active: picker[modelData.key]
              width: 84
              height: 42
              radius: 10
              color: optionMouse.containsMouse ? Theme.alpha("#ffffff", 0.09) : "transparent"

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Icons.glyph(option.active ? option.modelData.on : option.modelData.off)
                  color: option.active ? "#ffffff" : Theme.alpha("#ffffff", 0.35)
                  font.family: Theme.fontFamily
                  font.pixelSize: 18
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: option.modelData.hint
                  color: option.active ? Theme.alpha("#ffffff", 0.8) : Theme.alpha("#ffffff", 0.35)
                  font.family: Theme.fontFamily
                  font.pixelSize: 9
                }
              }

              MouseArea {
                id: optionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: picker[option.modelData.key] = !option.active
              }
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: 104
        radius: 18
        color: root.panel
        border.width: 1
        border.color: root.edge

        Column {
          anchors.fill: parent
          anchors.margins: 4

          Repeater {
            model: [
              { format: "gif", label: "Record GIF", keys: "Shift ↵" },
              { format: "mp4", label: "Record Video", keys: "↵" }
            ]

            Rectangle {
              id: recordRow
              required property var modelData
              width: parent.width
              height: 48
              radius: 14
              color: recordMouse.containsMouse ? Theme.alpha("#ffffff", 0.09) : "transparent"

              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 20
                radius: 4
                color: recordRow.modelData.format === "gif" ? "#ffffff" : "transparent"
                Text {
                  anchors.centerIn: parent
                  text: recordRow.modelData.format === "gif" ? "GIF" : Icons.glyph(0xF0567)
                  color: recordRow.modelData.format === "gif" ? "#1e1e20" : "#ffffff"
                  font.family: recordRow.modelData.format === "gif" ? Theme.fontFamily : Theme.fontFamily
                  font.pixelSize: recordRow.modelData.format === "gif" ? 10 : 20
                  font.bold: true
                }
              }
              Text {
                anchors.left: parent.left
                anchors.leftMargin: 56
                anchors.verticalCenter: parent.verticalCenter
                text: recordRow.modelData.label
                color: "#ffffff"
                font.family: Theme.fontFamily
                font.pixelSize: 15
              }
              Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: recordRow.modelData.keys
                color: Theme.alpha("#ffffff", 0.5)
                font.family: Theme.fontFamily
                font.pixelSize: 12
              }
              MouseArea {
                id: recordMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: picker.aioRecord(recordRow.modelData.format)
              }
            }
          }
        }
      }
    }
  }

  function cycleTimer() {
    picker.timerSeconds = picker.timerSeconds === 3 ? 5 : picker.timerSeconds === 5 ? 10 : 3
  }
}
