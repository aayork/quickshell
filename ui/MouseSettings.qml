import QtQuick
import QtQuick.Layouts
import qs.services
import qs.theme

// The control center's MOUSE section: the Razer mouse's battery, DPI stages,
// polling rate and Hyprland's pointer acceleration and speed.
ColumnLayout {
  id: root

  // The mouse's own button stages, so a stage lights up whichever way the
  // DPI was picked.
  readonly property var stages: Mouse.stages.length > 0 ? Mouse.stages : [400, 800, 1600, 3200, 6400]
  // The colour the mouse's indicator LED flashes for each stage slot, from
  // Razer's guide (red, green, blue, cyan, yellow); the firmware fixes it.
  // Saturated like the LED itself rather than the theme's softer palette.
  readonly property var stageColors: ["#ff2a2a", "#22e04a", "#2346ff", "#1fd8f0", "#ffd81f"]
  readonly property int stage: stages.indexOf(Mouse.dpi)
  readonly property color stageColor: stage >= 0 && stage < stageColors.length ? stageColors[stage] : Theme.dim

  spacing: 8

  // Equal-width choices joined in one rounded strip.
  component Choices: Rectangle {
    id: choices
    property var options: []
    property var current: null
    // Optional colour per option, shown as a dot beside its label.
    property var colors: []
    signal picked(var value)

    implicitHeight: Theme.rowHeight
    radius: Theme.controlRadius
    color: Theme.alpha(Theme.foreground, 0.04)

    RowLayout {
      anchors.fill: parent
      anchors.margins: 2
      spacing: 2
      uniformCellSizes: true

      Repeater {
        model: choices.options

        Rectangle {
          id: cell
          required property var modelData
          required property int index
          readonly property bool chosen: modelData.value === choices.current
          readonly property var tint: index < choices.colors.length ? choices.colors[index] : null

          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Math.max(0, Theme.controlRadius - 1)
          color: chosen ? (tint ? Theme.alpha(tint, 0.16) : Theme.alpha(Theme.foreground, 0.14)) : cellMouse.pressed ? Theme.pressed : cellMouse.containsMouse ? Theme.hover : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          Row {
            anchors.centerIn: parent
            spacing: 5

            Rectangle {
              visible: cell.tint !== null
              anchors.verticalCenter: parent.verticalCenter
              width: 6
              height: 6
              radius: 3
              color: cell.tint || "transparent"
              opacity: cell.chosen ? 1 : 0.45
            }
            Label {
              text: cell.modelData.label
              color: cell.chosen ? Theme.foreground : Theme.dim
              font.pixelSize: Theme.fontSmall
              elide: Text.ElideNone
            }
          }

          MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: choices.picked(cell.modelData.value)
          }
        }
      }
    }
  }

  // Header: section title on the left, battery on the right.
  RowLayout {
    Layout.fillWidth: true
    spacing: 6

    SectionHeader { text: "MOUSE"; Layout.fillWidth: true }

    BatteryGauge {
      visible: Mouse.battery >= 0
      Layout.alignment: Qt.AlignVCenter
      level: Mouse.battery
      charging: Mouse.charging
    }
  }

  // Logo and name, the DPI, and fine steps.
  RowLayout {
    Layout.fillWidth: true
    spacing: Theme.spacing

    RazerLogo {
      size: 14
      color: Theme.dim
    }
    Label {
      text: Mouse.name.replace(/^Razer\s+/, "")
      Layout.fillWidth: true
    }
    Rectangle {
      visible: root.stage >= 0
      Layout.alignment: Qt.AlignVCenter
      implicitWidth: 6
      implicitHeight: 6
      radius: 3
      color: root.stageColor
    }
    Label {
      text: Mouse.dpi + " DPI"
      color: Theme.dim
      font.pixelSize: Theme.fontSmall
      elide: Text.ElideNone
    }

    IconButton {
      icon: "−"
      enabled: Mouse.dpi > 100
      onClicked: Mouse.setDpi(Math.max(100, Mouse.dpi - 50))
    }
    IconButton {
      icon: "+"
      enabled: Mouse.dpi < Mouse.maxDpi
      onClicked: Mouse.setDpi(Math.min(Mouse.maxDpi, Mouse.dpi + 50))
    }
  }

  Label {
    visible: Mouse.error !== ""
    text: Mouse.error
    color: Theme.red
    font.pixelSize: Theme.fontSmall
    wrapMode: Text.Wrap
    elide: Text.ElideNone
    Layout.fillWidth: true
  }

  Choices {
    Layout.fillWidth: true
    options: root.stages.map(s => ({ label: s, value: s }))
    current: Mouse.dpi
    colors: root.stageColors
    onPicked: function(value) { Mouse.setDpi(value) }
  }

  RowLayout {
    visible: Mouse.poll > 0
    Layout.fillWidth: true
    spacing: Theme.spacing

    Label { text: "Polling"; color: Theme.dim; Layout.fillWidth: true }
    Choices {
      Layout.preferredWidth: 170
      options: Mouse.pollRates.map(r => ({ label: r + " Hz", value: r }))
      current: Mouse.poll
      onPicked: function(value) { Mouse.setPoll(value) }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Theme.spacing

    Label { text: "Acceleration"; color: Theme.dim; Layout.fillWidth: true }
    Toggle {
      checked: !Mouse.flat
      onToggled: Mouse.setFlat(!Mouse.flat)
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Theme.spacing

    Label { text: "Speed"; color: Theme.dim; Layout.preferredWidth: 48 }

    Item {
      Layout.fillWidth: true
      implicitHeight: Theme.rowHeight

      // Mark where the pointer is left alone.
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 10
        color: Theme.alpha(Theme.foreground, 0.35)
      }

      Slider {
        anchors.fill: parent
        // Hyprland's sensitivity runs -1..1; 0 leaves the pointer alone.
        value: (Mouse.sensitivity + 1) / 2
        step: 0.025
        onMoved: function(value) { Mouse.setSensitivity(value * 2 - 1) }
      }
    }

    Label {
      text: (Mouse.sensitivity > 0 ? "+" : "") + Mouse.sensitivity.toFixed(2)
      color: Mouse.sensitivity === 0 ? Theme.dim : Theme.foreground
      font.pixelSize: Theme.fontSmall
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: 38
    }
  }
}
