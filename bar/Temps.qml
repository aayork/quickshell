import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme
import qs.ui

// CPU temperature on the bar (yellow when warm, red when hot); click for
// every sensor and a graph of the last few minutes.
BarButton {
  id: root

  readonly property alias popup: popup
  readonly property int cpuLevel: Temps.level(Temps.cpu, 80, 90)

  function levelColor(level, normal) {
    return level === 2 ? Theme.red : level === 1 ? Theme.yellow : normal
  }

  visible: Temps.available
  active: popup.open
  minimumWidth: 0
  text: Icons.glyph(0xF050F) + "\u2009" + Temps.format(Temps.cpu)
  fontSize: Theme.fontSize
  foreground: levelColor(cpuLevel, Theme.foreground)
  onClicked: popup.toggle()

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 300
    contentHeight: column.implicitHeight

    ColumnLayout {
      id: column
      width: parent.width
      spacing: Theme.spacing

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        SectionHeader { text: "TEMPERATURES"; Layout.fillWidth: true }
        Label {
          text: "Last " + Math.round(Temps.historyLength * Temps.interval / 60000) + " min"
          color: Theme.muted
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
      }

      // CPU (accent) and GPU (dim) on one scale.
      Item {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        implicitHeight: 54

        Canvas {
          id: graph
          anchors.fill: parent
          readonly property var cpu: Temps.cpuHistory
          readonly property var gpu: Temps.gpuHistory
          onCpuChanged: requestPaint()
          onWidthChanged: requestPaint()

          function area(context, values, low, high, color, fill) {
            if (values.length < 2) return
            var step = width / (Temps.historyLength - 1)
            var x0 = width - (values.length - 1) * step
            var y = v => height - 2 - (height - 4) * (v - low) / (high - low)
            context.beginPath()
            context.moveTo(x0, height)
            for (var i = 0; i < values.length; i++) context.lineTo(x0 + i * step, y(values[i]))
            context.lineTo(width, height)
            context.closePath()
            context.fillStyle = Theme.alpha(color, fill)
            context.fill()
            context.beginPath()
            for (var j = 0; j < values.length; j++) context.lineTo(x0 + j * step, y(values[j]))
            context.strokeStyle = Theme.alpha(color, 0.9)
            context.lineWidth = 1.5
            context.stroke()
          }

          onPaint: {
            var context = getContext("2d")
            context.reset()
            var all = cpu.concat(gpu)
            if (all.length === 0) return
            // At least 30° of range, so idle wobble stays flat.
            var low = Math.min.apply(null, all) - 3
            var high = Math.max(Math.max.apply(null, all) + 3, low + 30)
            area(context, gpu, low, high, Theme.foreground, 0.12)
            area(context, cpu, low, high, Theme.accent, 0.28)
          }
        }

        Row {
          anchors.left: parent.left
          anchors.top: parent.top
          spacing: 10
          Label { text: "CPU " + Temps.format(Temps.cpu); font.pixelSize: Theme.fontSmall; color: Theme.accent }
          Label { visible: !isNaN(Temps.gpu); text: "GPU " + Temps.format(Temps.gpu); font.pixelSize: Theme.fontSmall; color: Theme.dim }
        }
      }

      Separator { Layout.fillWidth: true }

      Repeater {
        model: Temps.sensors

        RowLayout {
          id: sensor
          required property var modelData
          readonly property int level: Temps.level(modelData.value, modelData.warn, modelData.hot)
          Layout.fillWidth: true
          Layout.leftMargin: 6
          Layout.rightMargin: 8
          spacing: 10

          Rectangle {
            implicitWidth: 30
            implicitHeight: 30
            radius: Theme.controlRadius + 4
            color: Theme.alpha(root.levelColor(sensor.level, Theme.foreground), sensor.level > 0 ? 0.18 : 0.08)

            Label {
              anchors.centerIn: parent
              text: Icons.glyph(sensor.modelData.glyph)
              color: root.levelColor(sensor.level, Theme.foreground)
              font.pixelSize: Theme.iconSize + 1
              elide: Text.ElideNone
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label { text: sensor.modelData.name; Layout.fillWidth: true }
            Label {
              visible: sensor.modelData.detail !== ""
              text: sensor.modelData.detail
              color: Theme.dim
              font.pixelSize: Theme.fontSmall
              Layout.fillWidth: true
            }
          }

          Label {
            text: Temps.format(sensor.modelData.value)
            color: root.levelColor(sensor.level, Theme.foreground)
            font.bold: true
            elide: Text.ElideNone
          }
        }
      }
    }
  }
}
