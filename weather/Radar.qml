import QtQuick
import qs.services
import qs.theme
import qs.ui

// Precipitation radar: a slippy map of Esri grey canvas tiles (dark or light to
// match the theme) under RainViewer's last ~2 hours of radar frames, played
// as a loop. Drag to pan, scroll or double-click to zoom. RainViewer only
// serves up to zoom 7, so closer in its tiles are scaled up.
Item {
  id: root

  property real latitude: 0
  property real longitude: 0
  property real centerLat: latitude
  property real centerLon: longitude
  property int zoom: 6
  readonly property int minZoom: 3
  readonly property int maxZoom: 10
  readonly property int radarMaxZoom: 7
  property bool running: true

  property int frameIndex: Math.max(0, frames.length - 1)
  property bool playing: true
  // The last hour (7 frames, 10 minutes apart).
  readonly property var frames: Weather.radarFrames.slice(-7)
  readonly property bool dark: Theme.background.hslLightness < 0.5

  function recenter() { centerLat = latitude; centerLon = longitude }
  onLatitudeChanged: recenter()
  onLongitudeChanged: recenter()
  onFramesChanged: frameIndex = Math.max(0, frames.length - 1)

  // ---------------------------------------------------------------- projection
  function world(z) { return 256 * Math.pow(2, z) }
  function lonToX(lon, z) { return (lon + 180) / 360 * world(z) }
  function latToY(lat, z) {
    var r = Math.max(-85, Math.min(85, lat)) * Math.PI / 180
    return (1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * world(z)
  }
  function xToLon(x, z) { return x / world(z) * 360 - 180 }
  function yToLat(y, z) { return Math.atan(Math.sinh(Math.PI * (1 - 2 * y / world(z)))) * 180 / Math.PI }

  readonly property real cx: lonToX(centerLon, zoom)
  readonly property real cy: latToY(centerLat, zoom)

  readonly property int radarZoom: Math.min(zoom, radarMaxZoom)

  // Esri's grey canvas basemap (no key needed), base and labels separately.
  function mapUrl(layer, z, x, y) {
    return "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/" + layer + "/MapServer/tile/" + z + "/" + y + "/" + x
  }

  // Radar frames load one at a time, newest first (RainViewer rate-limits
  // a burst), and playback only steps through the ones already loaded.
  property int loaded: 1
  readonly property int firstLoaded: Math.max(0, frames.length - loaded)
  onZoomChanged: { loaded = 1; frameIndex = Math.max(0, frames.length - 1) }
  Timer {
    running: root.running && root.loaded < root.frames.length
    interval: 700
    repeat: true
    onTriggered: root.loaded++
  }

  clip: true

  Rectangle { anchors.fill: parent; color: root.dark ? "#0e0e0e" : "#f2f2f2" }

  TileLayer {
    anchors.fill: parent
    cx: root.cx; cy: root.cy; tileZoom: root.zoom
    url: function(z, x, y) { return root.mapUrl(root.dark ? "World_Dark_Gray_Base" : "World_Light_Gray_Base", z, x, y) }
  }
  // Lean the map toward the theme.
  Rectangle { anchors.fill: parent; color: Theme.background; opacity: 0.35 }

  // Radar frames, stacked; only the current one shows, so stepping through
  // loaded frames never waits on a download.
  Repeater {
    model: root.frames
    Loader {
      id: frame
      required property var modelData
      required property int index
      anchors.fill: parent
      active: index >= root.firstLoaded
      opacity: index === root.frameIndex ? 0.85 : 0
      sourceComponent: TileLayer {
        cx: root.cx; cy: root.cy
        tileZoom: root.radarZoom
        size: 256 * Math.pow(2, root.zoom - root.radarZoom)
        url: function(z, x, y) { return Weather.radarHost + frame.modelData.path + "/256/" + z + "/" + x + "/" + y + "/2/1_1.png" }
      }
    }
  }

  // Place names over the radar.
  TileLayer {
    anchors.fill: parent
    cx: root.cx; cy: root.cy; tileZoom: root.zoom
    tileOpacity: 0.9
    url: function(z, x, y) { return root.mapUrl(root.dark ? "World_Dark_Gray_Reference" : "World_Light_Gray_Reference", z, x, y) }
  }

  // Where the place is.
  Item {
    x: root.lonToX(root.longitude, root.zoom) - root.cx + root.width / 2
    y: root.latToY(root.latitude, root.zoom) - root.cy + root.height / 2
    Rectangle {
      anchors.centerIn: parent
      width: 26; height: 26; radius: 13
      color: "transparent"
      border.width: 2; border.color: Theme.accent
      SequentialAnimation on scale {
        running: root.running; loops: Animation.Infinite
        NumberAnimation { from: 0.4; to: 1.2; duration: 1600; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 400 }
      }
      SequentialAnimation on opacity {
        running: root.running; loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0; duration: 1600; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 400 }
      }
    }
    Rectangle {
      anchors.centerIn: parent
      width: 10; height: 10; radius: 5
      color: Theme.accent
      border.width: 2; border.color: Theme.background
    }
  }

  // ---------------------------------------------------------------- input
  MouseArea {
    anchors.fill: parent
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    property real lastX: 0
    property real lastY: 0
    onPressed: function(e) { lastX = e.x; lastY = e.y }
    onPositionChanged: function(e) {
      if (!pressed) return
      var x = root.cx - (e.x - lastX), y = root.cy - (e.y - lastY)
      lastX = e.x; lastY = e.y
      root.centerLon = root.xToLon(x, root.zoom)
      root.centerLat = root.yToLat(Math.max(0, Math.min(root.world(root.zoom), y)), root.zoom)
    }
    onDoubleClicked: function(e) { root.zoomAt(1, e.x, e.y) }
    // One zoom level per full wheel notch (a touchpad's many small steps
    // add up to one), and at most one level every 250 ms.
    property real wheelSum: 0
    property double lastZoom: 0
    onWheel: function(e) {
      wheelSum += e.angleDelta.y
      if (Math.abs(wheelSum) < 120) return
      var step = wheelSum > 0 ? 1 : -1
      wheelSum = 0
      if (Date.now() - lastZoom < 250) return
      lastZoom = Date.now()
      root.zoomAt(step, e.x, e.y)
    }
  }

  // Zoom keeping the point under the pointer still.
  function zoomAt(step, px, py) {
    var z = Math.max(minZoom, Math.min(maxZoom, zoom + step))
    if (z === zoom) return
    var lon = xToLon(cx + px - width / 2, zoom), lat = yToLat(cy + py - height / 2, zoom)
    var nx = lonToX(lon, z) - (px - width / 2), ny = latToY(lat, z) - (py - height / 2)
    zoom = z
    centerLon = xToLon(nx, z)
    centerLat = yToLat(ny, z)
  }

  // ---------------------------------------------------------------- playback
  Timer {
    running: root.running && root.playing && root.loaded > 1
    repeat: true
    interval: root.frameIndex === root.frames.length - 1 ? 1600 : 450
    onTriggered: root.frameIndex = root.frameIndex >= root.frames.length - 1 ? root.firstLoaded : root.frameIndex + 1
  }

  function frameLabel() {
    if (frames.length === 0) return "Loading radar…"
    var t = frames[frameIndex].time * 1000
    var ago = Math.round((Date.now() - t) / 60000)
    return Qt.formatTime(new Date(t), "h:mm AP") + (ago <= 5 ? " · now" : " · " + ago + " min ago")
  }

  // ---------------------------------------------------------------- controls
  component MapButton: Rectangle {
    id: mb
    property string icon: ""
    signal clicked()
    width: 28; height: 28
    radius: Theme.controlRadius
    color: Theme.alpha(Theme.background, mbMouse.containsMouse ? 0.95 : 0.8)
    border.width: 1; border.color: Theme.alpha(Theme.foreground, 0.12)
    Label { anchors.centerIn: parent; text: mb.icon; font.pixelSize: Theme.iconSize; color: Theme.foreground }
    MouseArea { id: mbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: mb.clicked() }
  }

  Column {
    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
    spacing: 4
    MapButton { icon: Icons.glyph(0xF0415); onClicked: root.zoomAt(1, root.width / 2, root.height / 2) }
    MapButton { icon: Icons.glyph(0xF0374); onClicked: root.zoomAt(-1, root.width / 2, root.height / 2) }
    MapButton { icon: Icons.glyph(0xF01A4); onClicked: { root.recenter(); root.zoom = 6 } }
  }

  // Timeline: play/pause, time, and a tick per frame.
  Rectangle {
    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
    height: 40
    color: Theme.alpha(Theme.background, 0.82)
    Row {
      anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 10
      spacing: 8
      MapButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.glyph(root.playing ? 0xF03E4 : 0xF040A)
        onClicked: root.playing = !root.playing
      }
      Label {
        anchors.verticalCenter: parent.verticalCenter
        width: 150
        text: root.frameLabel()
        font.pixelSize: Theme.fontSmall
        color: Theme.foreground
      }
      Row {
        id: ticks
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 28 - 150 - legend.width - 3 * 8 - 6
        spacing: 2
        Repeater {
          model: root.frames.length
          Rectangle {
            required property int index
            width: (ticks.width - (root.frames.length - 1) * 2) / Math.max(1, root.frames.length)
            height: index === root.frameIndex ? 10 : 6
            anchors.verticalCenter: parent.verticalCenter
            radius: 1
            color: index === root.frameIndex ? Theme.accent : Theme.alpha(Theme.foreground, tickMouse.containsMouse ? 0.5 : 0.25)
            MouseArea {
              id: tickMouse
              anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -8
              hoverEnabled: true
              onClicked: { root.playing = false; root.frameIndex = index }
            }
          }
        }
      }
      // RainViewer's colours, light to heavy.
      Column {
        id: legend
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Rectangle {
          width: 110; height: 6; radius: 1
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#d8d1c0" }
            GradientStop { position: 0.2; color: "#88ddee" }
            GradientStop { position: 0.4; color: "#0099cc" }
            GradientStop { position: 0.6; color: "#ffee00" }
            GradientStop { position: 0.8; color: "#ff8800" }
            GradientStop { position: 1.0; color: "#d00000" }
          }
        }
        Item {
          width: 110; height: 12
          Label { anchors.left: parent.left; text: "Light"; font.pixelSize: 9; color: Theme.dim }
          Label { anchors.right: parent.right; text: "Heavy"; font.pixelSize: 9; color: Theme.dim }
        }
      }
    }
  }

  Label {
    anchors.left: parent.left; anchors.bottom: parent.bottom
    anchors.leftMargin: 6; anchors.bottomMargin: 44
    text: "Map: Esri, HERE, Garmin, © OpenStreetMap · Radar: RainViewer"
    font.pixelSize: 9
    color: Theme.alpha(Theme.foreground, 0.55)
  }
}
