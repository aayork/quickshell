import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.theme
import qs.ui

// System performance next to the workspaces: CPU, memory and GPU use and the
// CPU temperature, each yellow when high and red when maxed. Click opens btop
// (bin/temps-monitor; clicking again closes it); right click shows the popup
// with a few minutes of CPU/GPU use, memory details and every temperature.
BarButton {
  id: root

  readonly property alias popup: popup

  function levelColor(level, normal) {
    return level === 2 ? Theme.red : level === 1 ? Theme.yellow : normal
  }
  function fixed(value, suffix) { return isNaN(value) ? "–" + suffix : Math.round(value) + suffix }

  // Every value gets the width of "88%", so the bar does not shift whenever
  // one gains or loses a digit.
  TextMetrics { id: digits; text: "88%"; font.pixelSize: Theme.fontSize; font.family: Theme.fontFamily }

  readonly property var metrics: [
    { glyph: 0xF061A, text: fixed(Performance.cpuUsage, "%"), level: Performance.level(Performance.cpuUsage, 80, 95), show: true },
    { glyph: 0xF035B, text: fixed(Performance.memUsage, "%"), level: Performance.level(Performance.memUsage, 80, 92), show: true },
    { glyph: 0xF08AE, text: fixed(Performance.gpuUsage, "%"), level: Performance.level(Performance.gpuUsage, 80, 95), show: !isNaN(Performance.gpuUsage) },
    { glyph: 0xF050F, text: fixed(Performance.cpu, "°"), level: Performance.level(Performance.cpu, 80, 90), show: !isNaN(Performance.cpu) }
  ]

  visible: Performance.available
  active: popup.open
  minimumWidth: strip.implicitWidth + Theme.barPadding * 2

  onClicked: button => {
    if (button === Qt.RightButton) popup.toggle()
    else Quickshell.execDetached([Quickshell.shellDir + "/bin/temps-monitor"])
  }

  Row {
    id: strip
    anchors.centerIn: parent
    spacing: 7

    Repeater {
      model: root.metrics

      Row {
        required property var modelData
        visible: modelData.show
        spacing: 2

        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: Icons.glyph(parent.modelData.glyph)
          color: root.levelColor(parent.modelData.level, Theme.alpha(root.foreground, 0.55))
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(implicitWidth, digits.advanceWidth)
          text: parent.modelData.text
          color: root.levelColor(parent.modelData.level, root.foreground)
          font.pixelSize: Theme.fontSize
          elide: Text.ElideNone
        }
      }
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 320
    contentHeight: column.implicitHeight

    ColumnLayout {
      id: column
      width: parent.width
      spacing: Theme.spacing

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        SectionHeader { text: "PERFORMANCE"; Layout.fillWidth: true }
        Label {
          text: "Last " + Math.round(Performance.historyLength * Performance.interval / 60000) + " min"
          color: Theme.muted
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
      }

      // CPU (accent) and GPU (dim) use, 0-100%.
      Item {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        implicitHeight: 60

        Canvas {
          id: graph
          anchors.fill: parent
          readonly property var cpu: Performance.cpuUsageHistory
          readonly property var gpu: Performance.gpuUsageHistory
          onCpuChanged: requestPaint()
          onWidthChanged: requestPaint()

          function area(context, values, color, fill) {
            if (values.length < 2) return
            var step = width / (Performance.historyLength - 1)
            var x0 = width - (values.length - 1) * step
            var y = v => height - 2 - (height - 4) * v / 100
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
            area(context, gpu, Theme.foreground, 0.12)
            area(context, cpu, Theme.accent, 0.28)
          }
        }

        Row {
          anchors.left: parent.left
          anchors.top: parent.top
          spacing: 10
          Label { text: "CPU " + Performance.percent(Performance.cpuUsage); font.pixelSize: Theme.fontSmall; color: Theme.accent }
          Label { visible: !isNaN(Performance.gpuUsage); text: "GPU " + Performance.percent(Performance.gpuUsage); font.pixelSize: Theme.fontSmall; color: Theme.dim }
        }
      }

      Separator { Layout.fillWidth: true }

      // Use: one row per part, with a thin meter.
      Repeater {
        model: [
          { name: "CPU", glyph: 0xF061A, value: Performance.cpuUsage, warn: 80, hot: 95,
            detail: "", show: true },
          { name: "Memory", glyph: 0xF035B, value: Performance.memUsage, warn: 80, hot: 92,
            detail: Performance.gib(Performance.memUsed) + " / " + Performance.gib(Performance.memTotal) + " GiB"
                    + (Performance.swapUsed > 1048576 ? " · swap " + Performance.gib(Performance.swapUsed) + " GiB" : ""),
            show: true },
          { name: "GPU", glyph: 0xF08AE, value: Performance.gpuUsage, warn: 80, hot: 95,
            detail: "VRAM " + Performance.gib(Performance.vramUsed) + " / " + Performance.gib(Performance.vramTotal) + " GiB",
            show: !isNaN(Performance.gpuUsage) }
        ]

        ColumnLayout {
          id: use
          required property var modelData
          readonly property int level: Performance.level(modelData.value, modelData.warn, modelData.hot)
          visible: modelData.show
          Layout.fillWidth: true
          Layout.leftMargin: 6
          Layout.rightMargin: 8
          spacing: 4

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
              Layout.preferredWidth: 20
              horizontalAlignment: Text.AlignHCenter
              text: Icons.glyph(use.modelData.glyph)
              color: root.levelColor(use.level, Theme.dim)
              font.pixelSize: Theme.iconSize + 1
              elide: Text.ElideNone
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1
              Label { text: use.modelData.name; Layout.fillWidth: true }
              Label {
                visible: use.modelData.detail !== ""
                text: use.modelData.detail
                color: Theme.dim
                font.pixelSize: Theme.fontSmall
                Layout.fillWidth: true
              }
            }
            Label {
              text: Performance.percent(use.modelData.value)
              color: root.levelColor(use.level, Theme.foreground)
              font.bold: true
              elide: Text.ElideNone
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 30
            implicitHeight: 3
            color: Theme.alpha(Theme.foreground, 0.1)
            Rectangle {
              height: parent.height
              width: parent.width * (isNaN(use.modelData.value) ? 0 : Math.min(100, use.modelData.value) / 100)
              color: root.levelColor(use.level, Theme.accent)
              Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
          }
        }
      }

      Separator { Layout.fillWidth: true }

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        SectionHeader { text: "TEMPERATURES"; Layout.fillWidth: true }
      }

      Repeater {
        model: Performance.sensors

        RowLayout {
          id: sensor
          required property var modelData
          readonly property int level: Performance.level(modelData.value, modelData.warn, modelData.hot)
          Layout.fillWidth: true
          Layout.leftMargin: 6
          Layout.rightMargin: 8
          spacing: 10

          Label {
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
            text: Icons.glyph(sensor.modelData.glyph)
            color: root.levelColor(sensor.level, Theme.dim)
            font.pixelSize: Theme.iconSize + 1
            elide: Text.ElideNone
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
            text: Performance.format(sensor.modelData.value)
            color: root.levelColor(sensor.level, Theme.foreground)
            font.bold: true
            elide: Text.ElideNone
          }
        }
      }
    }
  }
}
