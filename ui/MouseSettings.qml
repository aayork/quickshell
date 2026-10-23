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
  readonly property bool low: Mouse.battery >= 0 && Mouse.battery <= 15 && !Mouse.charging

  spacing: 8

  // Equal-width choices joined in one rounded strip.
  component Choices: Rectangle {
    id: choices
    property var options: []
    property var current: null
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
          readonly property bool chosen: modelData.value === choices.current

          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Math.max(0, Theme.controlRadius - 1)
          color: chosen ? Theme.alpha(Theme.foreground, 0.14) : cellMouse.pressed ? Theme.pressed : cellMouse.containsMouse ? Theme.hover : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          Label {
            anchors.centerIn: parent
            text: cell.modelData.label
            color: cell.chosen ? Theme.foreground : Theme.dim
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideNone
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

    Label {
      visible: Mouse.battery >= 0
      text: Mouse.charging ? "Charging" : ""
      color: Theme.dim
      font.pixelSize: Theme.fontSmall
      elide: Text.ElideNone
    }

    // A small drawn battery, filled to the charge.
    Row {
      visible: Mouse.battery >= 0
      spacing: 1
      Layout.alignment: Qt.AlignVCenter

      Rectangle {
        width: 20
        height: 10
        radius: Theme.controlRadius
        color: "transparent"
        border.width: 1
        border.color: root.low ? Theme.red : Theme.alpha(Theme.foreground, 0.5)

        Rectangle {
          x: 2
          y: 2
          height: parent.height - 4
          width: Math.max(1, (parent.width - 4) * Math.max(0, Math.min(100, Mouse.battery)) / 100)
          radius: Math.max(0, Theme.controlRadius - 1)
          color: root.low ? Theme.red : Theme.alpha(Theme.foreground, 0.7)
          Behavior on width { NumberAnimation { duration: 250 } }
        }
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 4
        color: root.low ? Theme.red : Theme.alpha(Theme.foreground, 0.5)
      }
    }

    Label {
      visible: Mouse.battery >= 0
      text: Mouse.battery + "%"
      color: root.low ? Theme.red : Theme.dim
      font.pixelSize: Theme.fontSmall
      elide: Text.ElideNone
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
