import QtQuick

// One drifting cumulus sprite for Sky.qml. Every cloud shares the sky's
// slow `phase` clock and crosses a whole number of times per cycle, so the
// loop wraps without a jump.
Image {
  required property Item sky
  property real start: 0
  property int laps: 1
  property real depth: 1        // 0 far .. 1 near
  property real band: 0.5       // vertical placement, 0 top .. 1
  property int variant: 0
  source: "sky/cloud-" + (sky.darkClouds ? "dark" : "light") + "-" + variant + ".png"
  width: (sky.overcast ? 900 : 560) * (0.55 + depth * 0.65)
  height: width * 420 / 900
  x: ((start + sky.phase * laps) % 1) * (sky.width + width) - width
  y: -height * 0.35 + band * sky.height * (sky.overcast ? 0.55 : 0.45)
  smooth: true; mipmap: true
  asynchronous: true
}
