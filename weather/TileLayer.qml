import QtQuick

// One layer of map tiles. The grid of slots is fixed for the view's size;
// panning only moves the slots, and a slot's image changes only when the
// view crosses a tile edge, so dragging never rebuilds or reloads anything.
Item {
  id: layer

  required property real cx        // view centre in world px at the display zoom
  required property real cy
  property int tileZoom: 0         // tile zoom
  property real size: 256          // on-screen size of one tile
  property var url: function(z, x, y) { return "" }
  property real tileOpacity: 1

  readonly property int n: Math.pow(2, tileZoom)
  readonly property real viewLeft: cx - width / 2
  readonly property real viewTop: cy - height / 2
  readonly property int col0: Math.floor(viewLeft / size)
  readonly property int row0: Math.floor(viewTop / size)
  readonly property int cols: Math.ceil(width / size) + 1
  readonly property int rows: Math.ceil(height / size) + 1

  Repeater {
    model: layer.width > 0 ? layer.cols * layer.rows : 0
    Image {
      required property int index
      readonly property int tx: layer.col0 + index % layer.cols
      readonly property int ty: layer.row0 + Math.floor(index / layer.cols)
      readonly property bool inside: ty >= 0 && ty < layer.n
      x: tx * layer.size - layer.viewLeft
      y: ty * layer.size - layer.viewTop
      width: layer.size; height: layer.size
      visible: inside
      opacity: layer.tileOpacity
      source: inside ? layer.url(layer.tileZoom, ((tx % layer.n) + layer.n) % layer.n, ty) : ""
      asynchronous: true
      cache: true
      smooth: true
      retainWhileLoading: true
    }
  }
}
