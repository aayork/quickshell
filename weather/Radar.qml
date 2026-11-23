import QtQuick
import qs.services
import qs.theme
import qs.ui
import "Places.js" as Places

// Precipitation radar: a slippy map of Esri grey canvas tiles (dark or light to
// match the theme) under RainViewer's last ~2 hours of radar frames, played
// as a loop. Drag to pan; scroll, double-click or the buttons zoom about
// the middle. RainViewer only serves up to zoom 7, so closer in its tiles
// are scaled up. Place names are drawn here, not taken from map tiles.
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
  // `zoom` is the level asked for; `zf` is the level drawn, which glides to
  // it, so a zoom step scales what is already on screen right away.
  property real zf: zoom
  Behavior on zf { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

  function world(z) { return 256 * Math.pow(2, z) }
  function lonToX(lon, z) { return (lon + 180) / 360 * world(z) }
  function latToY(lat, z) {
    var r = Math.max(-85, Math.min(85, lat)) * Math.PI / 180
    return (1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * world(z)
  }
  function xToLon(x, z) { return x / world(z) * 360 - 180 }
  function yToLat(y, z) { return Math.atan(Math.sinh(Math.PI * (1 - 2 * y / world(z)))) * 180 / Math.PI }

  readonly property real cx: lonToX(centerLon, zf)
  readonly property real cy: latToY(centerLat, zf)

  readonly property int radarZoom: Math.min(zoom, radarMaxZoom)

  // Esri's grey canvas basemap (no key needed). Fetched one level deeper
  // than shown and drawn at half size, so it stays sharp on a HiDPI screen.
  // Tiles alternate between Esri's two hostnames (same tiles), doubling the
  // connections Qt will open at once.
  function mapUrl(layer, z, x, y) {
    return "https://" + ((x + y) % 2 ? "services" : "server") + ".arcgisonline.com/ArcGIS/rest/services/Canvas/" + layer + "/MapServer/tile/" + z + "/" + y + "/" + x
  }
  readonly property string baseLayer: dark ? "World_Dark_Gray_Base" : "World_Light_Gray_Base"

  // Radar frames load one at a time, newest first (RainViewer rate-limits
  // a burst), and playback only steps through the ones already loaded.
  // They only reload when the radar's own zoom changes (it stops at 7).
  property int loaded: 1
  readonly property int firstLoaded: Math.max(0, frames.length - loaded)
  // When the radar's zoom changes, the newest frame at the old zoom stays
  // up (scaled, clipped to what was on screen) until it has reloaded.
  property int lastRadarZoom: 6   // set in Component.onCompleted
  property int lastViewZoom: 6
  property string holdPath: ""
  property int holdZoom: 0
  property int holdViewZoom: 0
  onRadarZoomChanged: {
    if (frames.length && loaded > 0) {
      holdPath = frames[frames.length - 1].path
      holdZoom = lastRadarZoom
      holdViewZoom = lastViewZoom
    }
    lastRadarZoom = radarZoom
    loaded = 1
    frameIndex = Math.max(0, frames.length - 1)
  }
  Timer {
    running: root.holdPath !== ""
    interval: 150
    repeat: true
    onTriggered: {
      var l = frameRepeater.itemAt(root.frames.length - 1)
      if (l && l.item && l.item.ready) root.holdPath = ""
    }
  }
  Timer {
    running: root.running && root.loaded < root.frames.length
    interval: 700
    repeat: true
    onTriggered: root.loaded++
  }

  clip: true

  Rectangle { anchors.fill: parent; color: root.dark ? "#0e0e0e" : "#f2f2f2" }

  // Backstop: the whole world at zoom 3 (64 tiles), loaded while the
  // window is open, so any area that has not arrived yet shows a soft map
  // rather than black. The hidden images keep them in the image cache.
  Loader {
    active: root.running
    sourceComponent: Item {
      visible: false
      Repeater {
        model: 64
        Image {
          required property int index
          source: root.mapUrl(root.baseLayer, 3, index % 8, Math.floor(index / 8))
          asynchronous: true
          cache: true
        }
      }
    }
  }
  TileLayer {
    anchors.fill: parent
    cx: root.cx; cy: root.cy
    tileZoom: 3
    size: 256 * Math.pow(2, root.zf - 3)
    minSize: 256
    url: function(z, x, y) { return root.mapUrl(root.baseLayer, z, x, y) }
  }
  // Prefetch: the next level out, over twice the view, loaded but not
  // drawn, so a zoom out finds its tiles already here.
  TileLayer {
    visible: false
    enabled: root.zoom > root.minZoom
    anchors.centerIn: parent
    width: root.width * 2; height: root.height * 2
    cx: root.cx; cy: root.cy
    tileZoom: root.zoom
    size: 256 * Math.pow(2, root.zf - root.zoom)
    minSize: 128
    // Only once the level on screen has finished, so it never competes.
    url: function(z, x, y) { return root.zoom > root.minZoom && base.ready ? root.mapUrl(root.baseLayer, z, x, y) : "" }
  }

  // The last level that finished loading stays underneath, scaled to match,
  // until the new tiles arrive, so a zoom never flashes empty map.
  property int prevZoom: 6     // set once in Component.onCompleted (not a binding)
  // Updated after this change has been handled, so onRadarZoomChanged sees the old value.
  function syncViewZoom() { lastViewZoom = zoom }
  onZoomChanged: { underlayTimer.stop(); Qt.callLater(syncViewZoom); placeLabels() }
  Timer { id: underlayTimer; interval: 300; onTriggered: root.prevZoom = root.zoom }
  TileLayer {
    anchors.fill: parent
    visible: root.prevZoom !== root.zoom
    cx: root.cx; cy: root.cy
    tileZoom: root.prevZoom + 1
    size: 256 * Math.pow(2, root.zf - root.prevZoom - 1)
    minSize: 64
    url: function(z, x, y) { return root.mapUrl(root.baseLayer, z, x, y) }
  }
  TileLayer {
    id: base
    anchors.fill: parent
    cx: root.cx; cy: root.cy
    onReadyChanged: if (ready) underlayTimer.restart()
    tileZoom: root.zoom + 1
    size: 256 * Math.pow(2, root.zf - root.zoom - 1)
    minSize: 64
    url: function(z, x, y) { return root.mapUrl(root.baseLayer, z, x, y) }
  }
  // Lean the map toward the theme.
  Rectangle { anchors.fill: parent; color: Theme.background; opacity: 0.35 }

  // Radar frames, stacked; only the current one shows, so stepping through
  // loaded frames never waits on a download. 512px tiles drawn at 256.
  Item {
    // Clipped to the area the old view covered: only those tiles are cached,
    // and anything outside would be a fresh request (RainViewer rate-limits).
    // Never bigger than the view itself: zooming in, the old view scaled up
    // is many times the window (holdViewZoom starts at 0, so 2^6 = 64x on
    // first show), and a tile grid that size is hundreds of thousands of
    // slots built in one go, freezing the shell for seconds.
    id: hold
    visible: root.holdPath !== ""
    anchors.centerIn: parent
    width: Math.min(root.width, root.width * Math.pow(2, root.zf - root.holdViewZoom))
    height: Math.min(root.height, root.height * Math.pow(2, root.zf - root.holdViewZoom))
    clip: true
    opacity: 0.85
    TileLayer {
      anchors.fill: parent
      active: hold.visible
      cx: root.cx; cy: root.cy
      tileZoom: root.holdZoom
      size: 256 * Math.pow(2, root.zf - root.holdZoom)
      minSize: 64
      url: function(z, x, y) { return root.holdPath === "" ? "" : Weather.radarHost + root.holdPath + "/512/" + z + "/" + x + "/" + y + "/2/1_1.png" }
    }
  }
  Repeater {
    id: frameRepeater
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
        size: 256 * Math.pow(2, root.zf - root.radarZoom)
        minSize: 128
        url: function(z, x, y) { return Weather.radarHost + frame.modelData.path + "/512/" + z + "/" + x + "/" + y + "/2/1_1.png" }
      }
    }
  }

  // ---------------------------------------------------------------- place names
  // Drawn as text (crisp at any scale) from Natural Earth's populated
  // places: the biggest first, skipping any that would overlap one already
  // placed. Worked out per zoom level for the area around the view, again
  // only once panning has settled.
  property var labels: []
  function placeLabels() {
    var z = zoom, w = world(z)
    var vx = lonToX(centerLon, z), vy = latToY(centerLat, z)
    var x0 = vx - width * 1.5, x1 = vx + width * 1.5
    var y0 = vy - height * 1.5, y1 = vy + height * 1.5
    var out = [], boxes = [], all = Places.places
    for (var i = 0; i < all.length && out.length < 160; i++) {
      var p = all[i]
      if (p[3] > z + 1) continue
      var x = lonToX(p[2], z), y = latToY(p[1], z)
      if (x < x0 || x > x1 || y < y0 || y > y1) continue
      var big = p[5] === 2 || p[4] > 1000000
      var bw = p[0].length * (big ? 7.6 : 6.8) + 12, bh = big ? 17 : 15
      var bx = x - 4, by = y - bh / 2
      var hit = false
      for (var j = 0; j < boxes.length; j++) {
        var b = boxes[j]
        if (bx < b[0] + b[2] + 6 && bx + bw + 6 > b[0] && by < b[1] + b[3] + 2 && by + bh + 2 > b[1]) { hit = true; break }
      }
      if (hit) continue
      boxes.push([bx, by, bw, bh])
      out.push({ name: p[0], lat: p[1], lon: p[2], big: big, capital: p[5] })
    }
    labels = out
  }
  Timer { id: labelTimer; interval: 120; onTriggered: root.placeLabels() }
  onCenterLatChanged: labelTimer.restart()
  onCenterLonChanged: labelTimer.restart()
  onWidthChanged: labelTimer.restart()
  Component.onCompleted: { prevZoom = zoom; lastRadarZoom = radarZoom; lastViewZoom = zoom; placeLabels() }

  Repeater {
    model: root.labels
    Item {
      required property var modelData
      x: Math.round(root.lonToX(modelData.lon, root.zf) - root.cx + root.width / 2)
      y: Math.round(root.latToY(modelData.lat, root.zf) - root.cy + root.height / 2)
      Rectangle {
        anchors.centerIn: parent
        width: modelData.capital ? 5 : 4; height: width; radius: width / 2
        color: Theme.alpha(Theme.foreground, 0.7)
        border.width: modelData.capital === 2 ? 1 : 0
        border.color: Theme.background
      }
      Text {
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        text: modelData.name
        textFormat: Text.PlainText
        font.family: Theme.fontFamily
        font.pixelSize: modelData.big ? 13 : 11
        font.weight: modelData.big ? Font.DemiBold : Font.Normal
        color: Theme.alpha(Theme.foreground, modelData.big ? 0.92 : 0.75)
        style: Text.Outline
        styleColor: Theme.alpha(Theme.background, 0.75)
      }
    }
  }

  // Where the place is.
  Item {
    x: root.lonToX(root.longitude, root.zf) - root.cx + root.width / 2
    y: root.latToY(root.latitude, root.zf) - root.cy + root.height / 2
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
  // Drag to pan. Zooming (wheel, double-click, buttons) always keeps the
  // middle of the view still: the location dot, unless the map was dragged.
  MouseArea {
    anchors.fill: parent
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    property real lastX: 0
    property real lastY: 0
    onPressed: function(e) { lastX = e.x; lastY = e.y }
    onPositionChanged: function(e) {
      if (!pressed) return
      var z = root.zf
      var x = root.cx - (e.x - lastX), y = root.cy - (e.y - lastY)
      lastX = e.x; lastY = e.y
      root.centerLon = root.xToLon(x, z)
      root.centerLat = root.yToLat(Math.max(0, Math.min(root.world(z), y)), z)
    }
    onDoubleClicked: root.zoomBy(1)
    // One zoom level per full wheel notch (a touchpad's many small steps
    // add up to one), and at most one level every 180 ms.
    property real wheelSum: 0
    property double lastZoom: 0
    onWheel: function(e) {
      wheelSum += e.angleDelta.y
      if (Math.abs(wheelSum) < 120) return
      var step = wheelSum > 0 ? 1 : -1
      wheelSum = 0
      if (Date.now() - lastZoom < 180) return
      lastZoom = Date.now()
      root.zoomBy(step)
    }
  }

  function zoomBy(step) {
    zoom = Math.max(minZoom, Math.min(maxZoom, zoom + step))
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
    MapButton { icon: Icons.glyph(0xF0415); onClicked: root.zoomBy(1) }
    MapButton { icon: Icons.glyph(0xF0374); onClicked: root.zoomBy(-1) }
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
    text: "Map: Esri, HERE, Garmin, © OpenStreetMap · Places: Natural Earth · Radar: RainViewer"
    font.pixelSize: 9
    color: Theme.alpha(Theme.foreground, 0.55)
  }
}
