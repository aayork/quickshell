import QtQuick

// One layer of map tiles. The grid of slots is fixed (sized for the smallest
// the tiles get, `minSize`), and each slot always holds the tiles whose
// column/row fall on it modulo the grid, so a tile keeps its slot for as
// long as it is on screen: panning and animated zooming move and scale the
// slots but never reload a visible tile. Slots outside the view are hidden.
Item {
  id: tiles

  required property real cx        // view centre in world px at the display zoom
  required property real cy
  property int tileZoom: 0         // zoom of the tiles fetched
  property real size: 256          // on-screen size of one tile
  property real minSize: size      // smallest `size` will get (sets the grid)
  property var url: function(z, x, y) { return "" }
  property real tileOpacity: 1
  // Off: no slots at all (a hidden layer should cost nothing).
  property bool active: true

  readonly property int n: Math.pow(2, tileZoom)
  readonly property real viewLeft: cx - width / 2
  readonly property real viewTop: cy - height / 2
  readonly property int cols: Math.ceil(width / minSize) + 2
  readonly property int rows: Math.ceil(height / minSize) + 2
  // The grid is centred on the view, so while tiles are smaller than
  // `minSize` (mid zoom-out) it still covers the middle.
  readonly property int col0: Math.floor(cx / size) - Math.floor(cols / 2)
  readonly property int row0: Math.floor(cy / size) - Math.floor(rows / 2)

  function wrap(a, m) { return ((a % m) + m) % m }

  // True once every tile in view is loaded.
  property bool ready: false
  function recount() {
    for (var i = 0; i < children.length; i++) {
      var t = children[i]
      if (t.inside && !(t.status === Image.Ready && t.source == t.want)) { ready = false; return }
    }
    ready = true
  }
  Timer { id: recountTimer; interval: 50; onTriggered: tiles.recount() }

  Repeater {
    model: tiles.active && tiles.width > 0 ? tiles.cols * tiles.rows : 0
    Image {
      required property int index
      readonly property int ci: index % tiles.cols
      readonly property int ri: Math.floor(index / tiles.cols)
      readonly property int tx: tiles.col0 + tiles.wrap(ci - tiles.col0, tiles.cols)
      readonly property int ty: tiles.row0 + tiles.wrap(ri - tiles.row0, tiles.rows)
      readonly property real px: tx * tiles.size - tiles.viewLeft
      readonly property real py: ty * tiles.size - tiles.viewTop
      readonly property bool inside: ty >= 0 && ty < tiles.n
                                     && px < tiles.width && px + tiles.size > 0
                                     && py < tiles.height && py + tiles.size > 0
      x: Math.round(px)
      y: Math.round(py)
      // Round both edges so neighbours meet without a seam.
      width: Math.round(px + tiles.size) - Math.round(px)
      height: Math.round(py + tiles.size) - Math.round(py)
      // A slot only ever switches to another tile, never back to nothing:
      // while the view moves, `inside` can flicker for a moment, and clearing
      // the source then would reload a tile that is still on screen.
      readonly property string want: inside ? tiles.url(tiles.tileZoom, tiles.wrap(tx, tiles.n), ty) : ""
      onWantChanged: { tries = 0; if (want !== "") source = want; recountTimer.restart() }
      onStatusChanged: {
        recountTimer.restart()
        // Rate-limited (429) or dropped: try again a little later.
        if (status === Image.Error && tries < 3) { tries++; retry.restart() }
      }
      property int tries: 0
      Timer {
        id: retry
        interval: 1500 * parent.tries
        onTriggered: { var u = parent.want; parent.source = ""; parent.source = u }
      }
      Component.onCompleted: if (want !== "") source = want
      visible: inside && status === Image.Ready && source == want
      opacity: tiles.tileOpacity
      asynchronous: true
      cache: true
      smooth: true
      mipmap: true
    }
  }
}
