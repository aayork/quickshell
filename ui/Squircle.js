.pragma library

// macOS-style "continuous" rounded corners (a squircle): the curve eases
// into the straight edge instead of meeting it at a sharp change the way a
// circular corner does. Same maths as Figma's corner smoothing; Apple's
// corners are about smoothing 0.6.

// Points of one corner, relative to the top-right corner point, going from
// the top edge down to the right edge.
function corner(r, s) {
  var rad = Math.PI / 180
  var p = (1 + s) * r
  var arcMeasure = 90 * (1 - s)
  var arcLen = Math.sin(arcMeasure / 2 * rad) * r * Math.SQRT2
  var alpha = (90 - arcMeasure) / 2
  var p3p4 = r * Math.tan(alpha / 2 * rad)
  var beta = 45 * s * rad
  var c = p3p4 * Math.cos(beta)
  var d = c * Math.tan(beta)
  var b = (p - arcLen - c - d) / 3
  var a = 2 * b
  var out = []
  var steps = Math.max(6, Math.ceil(r / 2))

  function cubic(p0, p1, p2, p3) {
    for (var i = 1; i <= steps; i++) {
      var t = i / steps, u = 1 - t
      out.push({
        x: u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x,
        y: u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
      })
    }
  }

  var s0 = { x: -p, y: 0 }
  out.push(s0)
  var e1 = { x: -p + a + b + c, y: d }
  cubic(s0, { x: -p + a, y: 0 }, { x: -p + a + b, y: 0 }, e1)
  // The circular middle, on the circle a plain corner would use.
  if (arcMeasure > 0) {
    var from = (45 + arcMeasure / 2) * rad, to = (45 - arcMeasure / 2) * rad
    for (var i = 1; i <= steps; i++) {
      var phi = from + (to - from) * i / steps
      out.push({ x: -r + r * Math.cos(phi), y: r - r * Math.sin(phi) })
    }
  }
  var e2 = out[out.length - 1]
  cubic(e2, { x: e2.x + d, y: e2.y + c }, { x: e2.x + d, y: e2.y + b + c }, { x: 0, y: p })
  return out
}

// The outline of a w x h box with corner radius r, moved in by `inset`
// (for strokes), clockwise from the top edge.
function points(w, h, r, s, inset) {
  inset = inset || 0
  var W = w - 2 * inset, H = h - 2 * inset
  var rr = Math.max(0, r - inset)
  // Keep the smoothed corner inside half the shorter side.
  rr = Math.min(rr, Math.min(W, H) / 2 / (1 + s))
  var q = corner(rr, s)
  var corners = [{ x: W, y: 0 }, { x: W, y: H }, { x: 0, y: H }, { x: 0, y: 0 }]
  var out = []
  for (var k = 0; k < 4; k++) {
    for (var i = 0; i < q.length; i++) {
      var x = q[i].x, y = q[i].y
      // Turn the top-right corner a quarter turn clockwise per corner.
      for (var n = 0; n < k; n++) { var t = x; x = -y; y = t }
      out.push({ x: corners[k].x + x + inset, y: corners[k].y + y + inset })
    }
  }
  out.push(out[0])
  return out
}

// For Shape's PathPolyline.
function polyline(w, h, r, s, inset) {
  return points(w, h, r, s, inset).map(function(pt) { return Qt.point(pt.x, pt.y) })
}

// Adds the outline to a Canvas context as the current path.
function trace(ctx, w, h, r, s, inset) {
  var pts = points(w, h, r, s, inset)
  ctx.beginPath()
  ctx.moveTo(pts[0].x, pts[0].y)
  for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y)
  ctx.closePath()
}
