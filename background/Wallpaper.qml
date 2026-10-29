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

      // Reads the wallpaper behind the bar so the bar can pick light or dark
      // text. A canvas only paints while
      // visible, so it sits here underneath the wallpaper where nobody sees it.
      Canvas {
        id: probe
        width: 128
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
          // The plain file URL: the canvas does not load one with a query on
          // it, and it is unloaded after every reading so nothing goes stale.
          loaded = "file://" + Background.path
          if (isImageLoaded(loaded)) requestPaint()
          else loadImage(loaded)
        }

        onImageLoaded: requestPaint()
        onPaint: {
          if (!isImageLoaded(loaded) || image.implicitWidth <= 0) return
          var context = getContext("2d")
          context.clearRect(0, 0, width * 4, height * 4)
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
          // The canvas holds device pixels, so on a scaled screen a read of
          // width x height covers only its top-left corner. Read well past
          // it and count only what was drawn.
          var stride = width * 4
          var pixels = context.getImageData(0, 0, stride, height * 4).data
          // How wide the drawn part is, in device pixels.
          var drawn = 0
          while (drawn < stride && pixels[drawn * 4 + 3] !== 0) drawn++
          if (drawn === 0) return
          // The whole strip, and the same in sections left to right for the
          // solid bar's gradient.
          var sections = 48
          var sum = [0, 0, 0]
          var count = 0
          var parts = []
          for (var n = 0; n < sections; n++) parts.push([0, 0, 0, 0])
          for (var i = 0; i + 3 < pixels.length; i += 4) {
            if (pixels[i + 3] === 0) continue
            var part = parts[Math.min(sections - 1, Math.floor(((i / 4) % stride) / drawn * sections))]
            for (var c = 0; c < 3; c++) {
              sum[c] += pixels[i + c]
              part[c] += pixels[i + c]
            }
            part[3]++
            count++
          }
          // Nothing was drawn; keep the last answer over guessing from black.
          if (sum[0] + sum[1] + sum[2] === 0) return
          Theme.wallpaperTop = Qt.rgba(sum[0] / count / 255, sum[1] / count / 255, sum[2] / count / 255, 1)
          Theme.wallpaperStrip = parts.filter(p => p[3] > 0)
            .map(p => Qt.rgba(p[0] / p[3] / 255, p[1] / p[3] / 255, p[2] / p[3] / 255, 1))
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

      // The bar's frosted glass, macOS Sequoia style: a heavy blur with the
      // colour pushed up (Apple's "vibrancy"), so the wallpaper reads only as
      // soft colour, ending in a clean edge at the bar's bottom. Drawn here
      // rather than by Hyprland so it stays exactly the bar's strip. A taller
      // piece of wallpaper is blurred so the bottom edge has real colour to
      // blend with. Windows sit above this layer, so they cover it as usual.
      Item {
        id: glass

        visible: Config.bar.glass
        readonly property int depth: Theme.barHeight + 48

        width: parent.width
        height: Theme.barHeight
        clip: true

        Item {
          width: parent.width
          height: glass.depth

          ShaderEffectSource {
            id: strip
            anchors.fill: parent
            sourceItem: wallpaper
            sourceRect: Qt.rect(0, 0, glass.width, glass.depth)
            visible: false
          }

          MultiEffect {
            anchors.fill: parent
            source: strip
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1
            blurMultiplier: 0.6
            saturation: 0.4
            brightness: 0.04
          }
        }
      }

      // At login the wallpaper fades in from black, carrying on from the
      // login screen's fade-out. Only the first load: later wallpaper changes
      // swap as before.
      Rectangle {
        id: cover
        anchors.fill: parent
        color: "black"
        property bool revealed: image.status === Image.Ready || image.status === Image.Error || coverTimeout.triggeredOnce
        onRevealedChanged: if (revealed) opacity = 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        visible: opacity > 0
        // No wallpaper (or a slow one): don't stay black.
        Timer {
          id: coverTimeout
          property bool triggeredOnce: false
          interval: 2500
          running: true
          onTriggered: triggeredOnce = true
        }
      }
    }
  }
}
