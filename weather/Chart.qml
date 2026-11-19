import QtQuick
import qs.theme
import qs.ui
import "../services/WeatherLib.js" as Lib

// An hourly chart: lines (the first one shaded underneath) and optional
// bars on their own 0..barMax scale, hour labels along the bottom, a band
// per day, and a readout of every value under the pointer.
Item {
  id: root

  property var times: []          // ISO hours, already sliced
  property var series: []         // [{ label, values, color, fill, dashed }]
  property var bars: null         // { label, values, color, max, suffix }
  property string unit: ""
  property int decimals: 0
  property var fixedMin: null
  property var fixedMax: null

  readonly property real padLeft: 40
  readonly property real padRight: 10
  readonly property real padTop: 22
  readonly property real padBottom: 22
  readonly property real plotW: width - padLeft - padRight
  readonly property real plotH: height - padTop - padBottom
  readonly property int count: times.length

  readonly property var range: {
    var lo = Infinity, hi = -Infinity
    for (var s = 0; s < series.length; s++)
      for (var i = 0; i < series[s].values.length; i++) {
        var v = series[s].values[i]
        if (v === null || v === undefined) continue
        lo = Math.min(lo, v); hi = Math.max(hi, v)
      }
    if (!isFinite(lo)) { lo = 0; hi = 1 }
    if (fixedMin !== null) lo = Math.min(lo, fixedMin)
    if (fixedMax !== null) hi = Math.max(hi, fixedMax)
    var pad = Math.max((hi - lo) * 0.12, decimals > 0 ? 0.05 : 1)
    return { lo: fixedMin !== null ? fixedMin : lo - pad, hi: fixedMax !== null ? fixedMax : hi + pad }
  }

  function xAt(i) { return padLeft + (count <= 1 ? 0 : i / (count - 1) * plotW) }
  function yAt(v) { return padTop + plotH - (v - range.lo) / (range.hi - range.lo) * plotH }
  // Canvas wants CSS colour strings.
  function css(c, a) {
    var q = Qt.color(c)
    return "rgba(" + Math.round(q.r * 255) + "," + Math.round(q.g * 255) + "," + Math.round(q.b * 255) + "," + (a * q.a) + ")"
  }
  function fmt(v) { return v === null || v === undefined ? "–" : Number(v).toFixed(decimals) }

  property int hover: -1

  onSeriesChanged: canvas.requestPaint()
  onBarsChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onHoverChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      if (root.count < 2) return
      var fg = Theme.foreground

      // Day bands and names.
      ctx.font = "10px " + Theme.fontFamily
      ctx.textBaseline = "middle"
      for (var i = 0; i < root.count; i++) {
        var d = Lib.parse(root.times[i])
        if (i === 0 || d.getHours() === 0) {
          var x0 = root.xAt(i)
          if (i > 0) {
            ctx.strokeStyle = root.css(fg, 0.18)
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(Math.round(x0) + 0.5, root.padTop - 14); ctx.lineTo(Math.round(x0) + 0.5, root.padTop + root.plotH); ctx.stroke()
          }
          ctx.fillStyle = root.css(fg, 0.7)
          ctx.textAlign = "left"
          ctx.fillText(i === 0 ? "Now" : Lib.dayName(root.times[i], false), x0 + 4, root.padTop - 12)
        }
      }

      // Grid + left scale.
      ctx.textAlign = "right"
      for (var g = 0; g <= 4; g++) {
        var v = root.range.lo + (root.range.hi - root.range.lo) * g / 4
        var y = Math.round(root.yAt(v)) + 0.5
        ctx.strokeStyle = root.css(fg, 0.07)
        ctx.beginPath(); ctx.moveTo(root.padLeft, y); ctx.lineTo(root.padLeft + root.plotW, y); ctx.stroke()
        ctx.fillStyle = root.css(fg, 0.5)
        ctx.fillText(root.fmt(v) + root.unit, root.padLeft - 6, y)
      }

      // Hour labels.
      ctx.textAlign = "center"
      ctx.textBaseline = "top"
      for (var h = 0; h < root.count; h++) {
        var hr = Lib.parse(root.times[h]).getHours()
        if (hr % 3 !== 0) continue
        ctx.fillStyle = root.css(fg, 0.5)
        ctx.fillText(Lib.hourLabel(root.times[h]), root.xAt(h), root.padTop + root.plotH + 6)
      }

      // Bars.
      if (root.bars) {
        var bw = Math.max(2, root.plotW / root.count - 2)
        for (var b = 0; b < root.count; b++) {
          var bv = root.bars.values[b] || 0
          if (bv <= 0) continue
          var bh = Math.min(1, bv / root.bars.max) * root.plotH
          ctx.fillStyle = root.css(root.bars.color, b === root.hover ? 0.75 : 0.45)
          ctx.fillRect(root.xAt(b) - bw / 2, root.padTop + root.plotH - bh, bw, bh)
        }
      }

      // Lines; the first is shaded down to the bottom.
      for (var s = root.series.length - 1; s >= 0; s--) {
        var ser = root.series[s]
        ctx.beginPath()
        var started = false
        for (var k = 0; k < root.count; k++) {
          var sv = ser.values[k]
          if (sv === null || sv === undefined) continue
          if (!started) { ctx.moveTo(root.xAt(k), root.yAt(sv)); started = true }
          else ctx.lineTo(root.xAt(k), root.yAt(sv))
        }
        if (!started) continue
        ctx.lineWidth = ser.dashed ? 1.25 : 2
        ctx.lineJoin = "round"
        ctx.strokeStyle = root.css(ser.color, 1)
        if (ser.dashed) ctx.setLineDash([4, 3]); else ctx.setLineDash([])
        ctx.stroke()
        ctx.setLineDash([])
        if (ser.fill) {
          ctx.lineTo(root.xAt(root.count - 1), root.padTop + root.plotH)
          ctx.lineTo(root.xAt(0), root.padTop + root.plotH)
          ctx.closePath()
          var grad = ctx.createLinearGradient(0, root.padTop, 0, root.padTop + root.plotH)
          grad.addColorStop(0, root.css(ser.color, 0.28))
          grad.addColorStop(1, root.css(ser.color, 0.02))
          ctx.fillStyle = grad
          ctx.fill()
        }
      }

      // Pointer.
      if (root.hover >= 0) {
        var hx = Math.round(root.xAt(root.hover)) + 0.5
        ctx.strokeStyle = root.css(fg, 0.35)
        ctx.lineWidth = 1
        ctx.beginPath(); ctx.moveTo(hx, root.padTop); ctx.lineTo(hx, root.padTop + root.plotH); ctx.stroke()
        for (var p = 0; p < root.series.length; p++) {
          var pv = root.series[p].values[root.hover]
          if (pv === null || pv === undefined) continue
          ctx.fillStyle = root.css(root.series[p].color, 1)
          ctx.beginPath(); ctx.arc(hx, root.yAt(pv), 3.5, 0, Math.PI * 2); ctx.fill()
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onPositionChanged: function(e) {
      if (root.count < 2) return
      var i = Math.round((e.x - root.padLeft) / root.plotW * (root.count - 1))
      root.hover = Math.max(0, Math.min(root.count - 1, i))
    }
    onExited: root.hover = -1
  }

  // Readout for the hour under the pointer.
  Rectangle {
    visible: root.hover >= 0
    readonly property real wantX: root.xAt(Math.max(0, root.hover)) + 10
    x: wantX + width > root.width ? root.xAt(Math.max(0, root.hover)) - width - 10 : wantX
    y: root.padTop
    width: readout.implicitWidth + 16
    height: readout.implicitHeight + 10
    radius: Theme.controlRadius
    color: Theme.alpha(Theme.background, 0.94)
    border.width: 1; border.color: Theme.alpha(Theme.foreground, 0.12)
    Column {
      id: readout
      anchors.centerIn: parent
      spacing: 2
      Label {
        text: root.hover >= 0 ? Lib.dayName(root.times[root.hover], true) + " " + Lib.hourLong(root.times[root.hover]) : ""
        font.pixelSize: Theme.fontSmall; color: Theme.dim
      }
      Repeater {
        model: root.series
        Label {
          required property var modelData
          text: modelData.label + "  " + (root.hover >= 0 ? root.fmt(modelData.values[root.hover]) + root.unit : "")
          font.pixelSize: Theme.fontSmall; color: modelData.color
        }
      }
      Label {
        visible: !!root.bars
        text: root.bars && root.hover >= 0 ? root.bars.label + "  " + Math.round(root.bars.values[root.hover] || 0) + (root.bars.suffix || "") : ""
        font.pixelSize: Theme.fontSmall; color: root.bars ? root.bars.color : Theme.foreground
      }
    }
  }
}
