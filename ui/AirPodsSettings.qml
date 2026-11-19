import QtQuick
import QtQuick.Layouts
import qs.services
import qs.theme

// AirPods: battery per pod and case, whether they are in, listening mode and
// conversational awareness. Shown in the Headphones panel.
ColumnLayout {
  id: root

  spacing: 10

  function noiseGlyph(id) {
    if (id === 2) return "\u{F0A45}"
    if (id === 3) return "\u{F07C5}"
    if (id === 4) return "\u{F05C5}"
    return "\u{F062E}"
  }

  // Left, right and case, or one battery for AirPods Max.
  RowLayout {
    visible: Object.keys(AirPods.battery).length > 0
    Layout.fillWidth: true
    spacing: 14

    Repeater {
      model: ["left", "right", "case", "single"].filter(k => AirPods.battery[k] !== undefined)

      RowLayout {
        required property string modelData
        spacing: 5

        Label {
          text: modelData === "case" ? "Case" : modelData === "single" ? "Battery" : modelData === "left" ? "L" : "R"
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          elide: Text.ElideNone
        }
        BatteryGauge {
          level: AirPods.battery[modelData].level
          charging: AirPods.battery[modelData].charging
        }
      }
    }

    Item { Layout.fillWidth: true }

    Label {
      visible: AirPods.ear.length > 0
      text: AirPods.inEar === 2 ? "In ears" : AirPods.inEar === 1 ? "In one ear" : "Not in ears"
      color: Theme.dim
      font.pixelSize: Theme.fontSmall
      elide: Text.ElideNone
    }
  }

  Label {
    visible: AirPods.state === null && AirPods.error === ""
    text: "Connecting to the AirPods…"
    color: Theme.dim
    font.pixelSize: Theme.fontSmall
  }

  Label {
    visible: AirPods.error !== ""
    text: AirPods.error
    color: Theme.red
    font.pixelSize: Theme.fontSmall
    wrapMode: Text.Wrap
    elide: Text.ElideNone
    Layout.fillWidth: true
  }

  SectionHeader { visible: AirPods.hasNoiseControl; text: "NOISE CONTROL"; Layout.fillWidth: true }

  // The listening modes as one joined strip, like the Bose modes.
  Rectangle {
    visible: AirPods.hasNoiseControl
    Layout.fillWidth: true
    implicitHeight: Theme.rowHeight + 4
    radius: Theme.controlRadius
    color: Theme.alpha(Theme.foreground, 0.04)

    RowLayout {
      anchors.fill: parent
      anchors.margins: 2
      spacing: 2
      uniformCellSizes: true

      Repeater {
        model: AirPods.noiseModes

        Rectangle {
          id: cell
          required property var modelData
          readonly property bool chosen: modelData.id === AirPods.noise

          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Math.max(0, Theme.controlRadius - 1)
          color: chosen ? Theme.alpha(Theme.accent, 0.18) : cellMouse.pressed ? Theme.pressed : cellMouse.containsMouse ? Theme.hover : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          Row {
            anchors.centerIn: parent
            spacing: 5

            Label {
              anchors.verticalCenter: parent.verticalCenter
              text: root.noiseGlyph(cell.modelData.id)
              color: cell.chosen ? Theme.accent : Theme.dim
              font.pixelSize: Theme.iconSize
              elide: Text.ElideNone
            }
            Label {
              anchors.verticalCenter: parent.verticalCenter
              // The long name only fits when there are few cells.
              text: cell.modelData.id === 2 && AirPods.noiseModes.length > 3 ? "ANC" : cell.modelData.label
              color: cell.chosen ? Theme.foreground : Theme.dim
              font.pixelSize: Theme.fontSmall
              elide: Text.ElideNone
            }
          }

          MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: AirPods.setNoise(cell.modelData.id)
          }
        }
      }
    }
  }

  RowLayout {
    visible: AirPods.hasConversationalAwareness
    Layout.fillWidth: true
    spacing: Theme.spacing

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 1
      Label { text: "Conversation Awareness"; Layout.fillWidth: true }
      Label {
        text: "Lowers media and lets voices in when you speak"
        color: Theme.dim
        font.pixelSize: Theme.fontSmall
        Layout.fillWidth: true
      }
    }
    Toggle {
      checked: AirPods.conversationalAwareness
      onToggled: AirPods.setConversationalAwareness(!AirPods.conversationalAwareness)
    }
  }
}
