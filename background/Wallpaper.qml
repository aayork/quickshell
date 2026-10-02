import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.theme

// The wallpaper, plus the frosted strip a see-through bar sits on.
Scope {
  id: root

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      readonly property bool primary: Quickshell.screens.length > 0 && Quickshell.screens[0].name === modelData.name
      readonly property url source: Background.source

      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      color: Theme.background
      // The image can be ready before the surface has a size to crop it to.
      onWidthChanged: probe.sample()
      onHeightChanged: probe.sample()
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "aayork-wallpaper"
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      // Reads how bright the wallpaper is behind the bar so the bar can pick
      // light or dark text. A canvas only paints while visible, so it sits
      // here underneath the wallpaper where nobody sees it.
      Canvas {
        id: probe
        width: 32
        height: 4
        enabled: panel.primary

        property url loaded: ""

        // WCAG relative luminance of an sRGB colour.
        function luminance(r, g, b) {
          function linear(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
          return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }

        function sample() {
          if (!panel.primary || image.status !== Image.Ready || panel.width <= 0 || panel.height <= 0) return
          if (loaded.toString() !== "" && loaded !== panel.source) unloadImage(loaded)
          loaded = panel.source
          if (isImageLoaded(loaded)) requestPaint()
          else loadImage(loaded)
        }

        onImageLoaded: requestPaint()
        onPaint: {
          if (!isImageLoaded(loaded) || image.implicitWidth <= 0) return
          var context = getContext("2d")
          // Same crop the wallpaper uses, narrowed to the bar's strip.
          var scale = Math.max(panel.width / image.implicitWidth, panel.height / image.implicitHeight)
          var cropWidth = panel.width / scale
          var cropHeight = panel.height / scale
          // Whole pixels, kept inside the image: drawImage rejects a source
          // rectangle that overshoots by even a rounding error.
          var left = Math.ceil((image.implicitWidth - cropWidth) / 2)
          var top = Math.ceil((image.implicitHeight - cropHeight) / 2)
          context.drawImage(loaded, left, top,
            Math.max(1, Math.floor(cropWidth) - 1), Math.max(1, Math.floor(Theme.barHeight / scale)),
            0, 0, width, height)
          var pixels = context.getImageData(0, 0, width, height).data
          var sum = [0, 0, 0]
          for (var i = 0; i + 3 < pixels.length; i += 4)
            for (var c = 0; c < 3; c++) sum[c] += pixels[i + c]
          var count = pixels.length / 4
          var behind = probe.luminance(sum[0] / count / 255, sum[1] / count / 255, sum[2] / count / 255)
          // Whichever of the theme's dark and light reads better against it.
          var dark = Theme.background
          var light = Theme.brightForeground
          var darkContrast = (behind + 0.05) / (probe.luminance(dark.r, dark.g, dark.b) + 0.05)
          var lightContrast = (probe.luminance(light.r, light.g, light.b) + 0.05) / (behind + 0.05)
          Theme.barForeground = darkContrast > lightContrast ? dark : light
          unloadImage(loaded)
        }
      }

      Item {
        id: wallpaper
        anchors.fill: parent

        Image {
          id: image
          anchors.fill: parent
          source: panel.source
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          smooth: true
          mipmap: true
          onStatusChanged: probe.sample()
        }
      }

      // Hyprland's own layer blur stops in a hard line at the bar's edge.
      // Drawn here instead, it fades out into the wallpaper. Windows sit
      // above this layer, so they cover it as usual.
      Item {
        id: glass

        readonly property int fade: 40
        readonly property int depth: Theme.barHeight + fade

        width: parent.width
        height: depth

        ShaderEffectSource {
          id: strip
          anchors.fill: parent
          sourceItem: wallpaper
          sourceRect: Qt.rect(0, 0, glass.width, glass.height)
          visible: false
        }

        Rectangle {
          id: fadeMask
          anchors.fill: parent
          visible: false
          layer.enabled: true
          gradient: Gradient {
            GradientStop { position: 0; color: "white" }
            GradientStop { position: Theme.barHeight * 0.2 / glass.depth; color: "white" }
            GradientStop { position: 1; color: "transparent" }
          }
        }

        MultiEffect {
          anchors.fill: parent
          source: strip
          autoPaddingEnabled: false
          blurEnabled: true
          blurMax: 64
          blur: 1
          maskEnabled: true
          maskSource: fadeMask
          // Centred so the fade spans the whole gradient; at 0 the edge is hard.
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1
        }
      }
    }
  }
}
