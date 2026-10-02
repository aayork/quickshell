import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.theme
import qs.ui

// Bose headphones: battery, listening mode, noise cancellation, equalizer.
// Only on the bar while the headphones are connected.
BarButton {
  id: root

  readonly property alias popup: popup

  visible: Bose.connected
  onVisibleChanged: if (!visible) popup.close()
  minimumWidth: 34
  active: popup.open
  onClicked: popup.toggle()

  // The Bose wordmark's "B", from the brand SVG.
  Item {
    id: mark
    readonly property real markWidth: 44.822
    readonly property real markHeight: 24.967
    readonly property real factor: 18 / markWidth

    anchors.centerIn: parent
    width: markWidth * factor
    height: markHeight * factor
    clip: true

    Shape {
      width: 215
      height: 27
      x: -33.009 * mark.factor
      y: -1.054 * mark.factor
      transform: Scale { xScale: mark.factor; yScale: mark.factor }
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: root.foreground
        strokeWidth: -1
        fillRule: ShapePath.WindingFill
        PathSvg {
          path: "M73.8 1.054L45.295 1.054L33.009 21.892L5.88 21.892L5.8935314 26.021L60.629 26.021C64.266 26.021 65.445 24.251 66.232 22.875L69.18 17.764C69.967 16.388 69.967 14.815 68.394 13.931C69.97 13.931 72.129 12.85 73.407 10.589L76.356 5.576C77.831 3.119 76.061 1.054 73.8 1.054zM59.155 17.863L57.68 20.221C57.287 21.008 56.599 21.892 54.928 21.892L47.654 21.892L51.392 15.602L58.466 15.602C59.744 15.602 59.744 16.781 59.155 17.863zM65.347 7.443L63.872 9.802C63.479 10.589 62.791 11.473 61.12 11.473L53.846 11.473L57.581 5.183L64.658 5.183C65.937 5.183 65.937 6.362 65.347 7.443z"
        }
      }
    }
  }

  // One equalizer band: label, slider across its own range, value.
  component Band: RowLayout {
    id: band
    required property var modelData
    signal changed(int value)

    Layout.fillWidth: true
    spacing: Theme.spacing

    Label { text: band.modelData.label; Layout.preferredWidth: 48 }
    Slider {
      Layout.fillWidth: true
      value: (band.modelData.value - band.modelData.minimum) / (band.modelData.maximum - band.modelData.minimum)
      step: 1 / (band.modelData.maximum - band.modelData.minimum)
      onMoved: function(value) {
        band.changed(Math.round(band.modelData.minimum + value * (band.modelData.maximum - band.modelData.minimum)))
      }
    }
    Label {
      text: (band.modelData.value > 0 ? "+" : "") + band.modelData.value
      color: Theme.dim
      font.pixelSize: Theme.fontSmall
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: 24
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 320
    contentHeight: column.implicitHeight

    onOpenChanged: Bose.watching = open

    ColumnLayout {
      id: column
      width: parent.width
      spacing: 12

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing

        Label { text: Bose.name; font.bold: true; Layout.fillWidth: true }
        Label {
          text: Bose.battery >= 0 ? Bose.battery + "%" : Bose.busy ? "Reading…" : ""
          color: Bose.battery >= 0 && Bose.battery <= 15 ? Theme.red : Theme.dim
        }
      }

      Label {
        visible: Bose.error !== ""
        text: Bose.error
        color: Theme.red
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
      }

      SectionHeader { text: "MODE"; visible: modes.visible }

      Flow {
        id: modes
        visible: Bose.modes.length > 0
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: Bose.modes

          TextButton {
            required property var modelData
            text: modelData.label
            selected: modelData.id === Bose.mode
            onClicked: Bose.setMode(modelData.id)
          }
        }
      }

      SectionHeader { text: "NOISE CANCELLATION"; visible: noise.visible }

      RowLayout {
        id: noise
        visible: Bose.hasNoiseControl
        Layout.fillWidth: true
        spacing: Theme.spacing

        Slider {
          Layout.fillWidth: true
          value: Bose.noiseMaximum > 0 ? Bose.noiseLevel / Bose.noiseMaximum : 0
          step: Bose.noiseMaximum > 0 ? 1 / Bose.noiseMaximum : 0.1
          onMoved: function(value) { Bose.setNoiseLevel(value * Bose.noiseMaximum) }
        }
        Label {
          text: Bose.noiseLevel + "/" + Bose.noiseMaximum
          color: Theme.dim
          font.pixelSize: Theme.fontSmall
          horizontalAlignment: Text.AlignRight
          Layout.preferredWidth: 34
        }
      }

      RowLayout {
        visible: equalizer.visible
        Layout.fillWidth: true
        SectionHeader { text: "EQUALIZER"; Layout.fillWidth: true }
        Label {
          text: "Reset"
          color: resetMouse.containsMouse ? Theme.foreground : Theme.dim
          font.pixelSize: Theme.fontSmall
          MouseArea {
            id: resetMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: Bose.setEqualizer({ bass: 0, mid: 0, treble: 0 })
          }
        }
      }

      ColumnLayout {
        id: equalizer
        visible: Bose.bands.length === 3
        Layout.fillWidth: true
        spacing: 2

        function values(id, value) {
          var next = {}
          for (var i = 0; i < Bose.bands.length; i++) next[Bose.bands[i].id] = Bose.bands[i].value
          next[id] = value
          return next
        }

        Repeater {
          model: Bose.bands

          Band {
            onChanged: function(value) { Bose.setEqualizer(equalizer.values(modelData.id, value)) }
          }
        }
      }
    }
  }
}
