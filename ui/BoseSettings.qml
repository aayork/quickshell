import QtQuick
import QtQuick.Layouts
import qs.services
import qs.theme

// The Bose popup: headphones and battery, listening mode, noise control and
// equalizer.
ColumnLayout {
  id: root

  spacing: 10

  // A section title led by a small glyph.
  component Heading: RowLayout {
    property string icon: ""
    property string text: ""
    spacing: 6

    Label {
      text: parent.icon
      color: Theme.dim
      font.pixelSize: Theme.fontSmall
      elide: Text.ElideNone
    }
    SectionHeader { text: parent.text; Layout.fillWidth: true }
  }

  // Listening modes as one joined strip, each with its glyph.
  component ModeStrip: Rectangle {
    id: strip

    function glyph(id) {
      if (id === "quiet") return "\u{F0A45}"
      if (id === "aware") return "\u{F07C5}"
      if (id === "immersion") return "\u{F05C5}"
      return "\u{F062E}"
    }

    implicitHeight: Theme.rowHeight + 4
    radius: Theme.controlRadius
    color: Theme.alpha(Theme.foreground, 0.04)

    RowLayout {
      anchors.fill: parent
      anchors.margins: 2
      spacing: 2
      uniformCellSizes: true

      Repeater {
        // A custom mode the presets do not cover shows as its own, current cell.
        model: Bose.mode === "" && Bose.modeLabel !== ""
          ? Bose.modes.concat([{ id: "", label: Bose.modeLabel.charAt(0).toUpperCase() + Bose.modeLabel.slice(1), custom: true }])
          : Bose.modes

        Rectangle {
          id: cell
          required property var modelData
          readonly property bool chosen: modelData.custom === true || modelData.id === Bose.mode

          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Math.max(0, Theme.controlRadius - 1)
          color: chosen ? Theme.alpha(Theme.accent, 0.18) : cellMouse.pressed ? Theme.pressed : cellMouse.containsMouse ? Theme.hover : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          Row {
            anchors.centerIn: parent
            spacing: 6

            Label {
              anchors.verticalCenter: parent.verticalCenter
              text: strip.glyph(cell.modelData.id)
              color: cell.chosen ? Theme.accent : Theme.dim
              font.pixelSize: Theme.iconSize
              elide: Text.ElideNone
            }
            Label {
              anchors.verticalCenter: parent.verticalCenter
              text: cell.modelData.label
              color: cell.chosen ? Theme.foreground : Theme.dim
              elide: Text.ElideNone
            }
          }

          MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (!cell.modelData.custom) Bose.setMode(cell.modelData.id)
          }
        }
      }
    }
  }

  // Headphones, name, connection and battery.
  RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Rectangle {
      implicitWidth: 36
      implicitHeight: 36
      radius: Theme.controlRadius
      color: Theme.alpha(Theme.accent, 0.15)

      Label {
        anchors.centerIn: parent
        text: "\u{F02CB}"
        color: Theme.accent
        font.pixelSize: Theme.iconLarge
        elide: Text.ElideNone
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 1

      Label { text: Bose.name; font.bold: true; Layout.fillWidth: true }
      Label {
        text: "\u{F00AF} Connected" + (Bose.multipoint ? " · Multipoint" : "")
        color: Theme.dim
        font.pixelSize: Theme.fontSmall
        Layout.fillWidth: true
      }
    }

    BatteryGauge {
      visible: Bose.battery >= 0
      Layout.alignment: Qt.AlignVCenter
      level: Bose.battery
    }
    Label {
      visible: Bose.battery < 0 && Bose.busy
      text: "Reading…"
      color: Theme.dim
      font.pixelSize: Theme.fontSmall
    }
  }

  Separator { Layout.fillWidth: true }

  RowLayout {
    visible: Bose.error !== ""
    Layout.fillWidth: true
    spacing: 6

    Label {
      Layout.alignment: Qt.AlignTop
      text: "\u{F05D6}"
      color: Theme.red
      elide: Text.ElideNone
    }
    Label {
      text: Bose.error
      color: Theme.red
      font.pixelSize: Theme.fontSmall
      wrapMode: Text.Wrap
      elide: Text.ElideNone
      Layout.fillWidth: true
    }
  }

  Heading { icon: "\u{F062E}"; text: "MODE"; visible: modes.visible; Layout.fillWidth: true }

  ModeStrip {
    id: modes
    visible: Bose.modes.length > 0
    Layout.fillWidth: true
  }

  Heading { icon: "\u{F0A45}"; text: "NOISE CONTROL"; visible: noise.visible; Layout.fillWidth: true; Layout.topMargin: 4 }

  // The level is how much noise is cancelled: 0 lets the most sound in.
  RowLayout {
    id: noise
    visible: Bose.hasNoiseControl
    Layout.fillWidth: true
    spacing: Theme.spacing

    Label {
      text: "\u{F07C5}"
      color: Theme.dim
      font.pixelSize: Theme.iconSize
      elide: Text.ElideNone
    }
    Slider {
      Layout.fillWidth: true
      enabled: Bose.noiseEditable
      value: Bose.noiseMaximum > 0 ? Bose.noiseLevel / Bose.noiseMaximum : 0
      step: Bose.noiseMaximum > 0 ? 1 / Bose.noiseMaximum : 0.1
      onMoved: function(value) { Bose.setNoiseLevel(value * Bose.noiseMaximum) }
    }
    Label {
      text: "\u{F0A45}"
      color: Theme.dim
      font.pixelSize: Theme.iconSize
      elide: Text.ElideNone
    }
    Label {
      text: Bose.noiseLevel
      color: Theme.dim
      font.pixelSize: Theme.fontSmall
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: 18
    }
  }

  Label {
    visible: noise.visible && !Bose.noiseEditable
    Layout.topMargin: -6
    text: "Set by the mode"
    color: Theme.dim
    font.pixelSize: Theme.fontSmall
  }

  RowLayout {
    visible: equalizer.visible
    Layout.fillWidth: true
    Layout.topMargin: 4
    spacing: 6

    Heading { icon: "\u{F066A}"; text: "EQUALIZER"; Layout.fillWidth: true }
    IconButton {
      implicitWidth: 22
      implicitHeight: 22
      icon: "\u{F099B}"
      size: Theme.fontSmall + 1
      foreground: Theme.dim
      enabled: Bose.bands.some(b => b.value !== 0)
      onClicked: Bose.setEqualizer({ bass: 0, mid: 0, treble: 0 })
    }
  }

  EqGraph {
    id: equalizer
    visible: Bose.bands.length === 3
    Layout.fillWidth: true
    bands: Bose.bands

    function values(id, value) {
      var next = {}
      for (var i = 0; i < Bose.bands.length; i++) next[Bose.bands[i].id] = Bose.bands[i].value
      for (var k in held) next[k] = held[k]
      next[id] = value
      return next
    }

    onChanged: function(id, value) { Bose.setEqualizer(values(id, value)) }
  }
}
