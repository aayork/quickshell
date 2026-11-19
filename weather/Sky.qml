import QtQuick
import QtQuick.Effects
import qs.theme

// The window's backdrop: a sky for the conditions outside right now. A
// gradient for the time of day and weather, then whatever is happening in
// it: sun glow, stars, drifting cloud, rain, snow, fog banks, lightning.
// The gradient leans a little toward the theme's background so the window
// still sits with the rest of the desktop.
Item {
  id: root

  property string kind: "clear"   // clear partly cloudy fog drizzle rain snow storm
  property bool day: true
  property real intensity: 0.5    // 0..1 for rain/snow
  property real cloudCover: 0     // 0..100
  property bool running: true

  readonly property var palette: {
    var p = {
      clear:   day ? ["#2f6fb6", "#8fc1e8"] : ["#0a1024", "#1d2a4a"],
      partly:  day ? ["#3b6e9f", "#9cbbd6"] : ["#0d1428", "#263350"],
      cloudy:  day ? ["#5a6876", "#9aa6b1"] : ["#14181f", "#2b323c"],
      fog:     day ? ["#7d858c", "#b4b9bd"] : ["#1b1e22", "#373c42"],
      drizzle: day ? ["#4d5c6b", "#7f8d99"] : ["#11161d", "#27303a"],
      rain:    day ? ["#3a4855", "#66737f"] : ["#0c1117", "#212a33"],
      snow:    day ? ["#7e8fa1", "#c9d3dc"] : ["#1a2130", "#3a4558"],
      storm:   day ? ["#262c35", "#4c5560"] : ["#07090d", "#1a1f27"]
    }
    return p[kind] || p.clear
  }
  function blend(c) { return Qt.tint(c, Theme.alpha(Theme.background, 0.28)) }

  readonly property bool cloudy: kind !== "clear" || cloudCover > 30
  readonly property bool wet: kind === "rain" || kind === "drizzle" || kind === "storm"

  clip: true

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: root.blend(root.palette[0]); Behavior on color { ColorAnimation { duration: 800 } } }
      GradientStop { position: 1; color: root.blend(root.palette[1]); Behavior on color { ColorAnimation { duration: 800 } } }
    }
  }

  // ---------------------------------------------------------------- sun
  Item {
    id: sunLayer
    anchors.fill: parent
    visible: root.day && (root.kind === "clear" || root.kind === "partly")
    layer.enabled: visible
    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
    Rectangle {
      id: sun
      width: 300; height: 300; radius: 150
      x: parent.width - width * 0.75; y: -height * 0.35
      color: "#fff1c4"
      opacity: root.kind === "clear" ? 0.75 : 0.45
      SequentialAnimation on scale {
        running: root.running && sunLayer.visible
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 1.08; duration: 5000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.08; to: 1; duration: 5000; easing.type: Easing.InOutSine }
      }
    }
  }

  // ---------------------------------------------------------------- stars + moon glow
  Item {
    anchors.fill: parent
    visible: !root.day && (root.kind === "clear" || root.kind === "partly")
    Repeater {
      model: 90
      Rectangle {
        required property int index
        readonly property real seed: Math.random()
        x: Math.random() * root.width
        y: Math.random() * root.height * 0.75
        width: seed > 0.85 ? 2.5 : 1.5; height: width; radius: width / 2
        color: "#ffffff"
        opacity: 0.25 + seed * 0.6
        SequentialAnimation on opacity {
          running: root.running && parent.visible && seed > 0.4
          loops: Animation.Infinite
          PauseAnimation { duration: Math.random() * 4000 }
          NumberAnimation { to: 0.15; duration: 1400 + Math.random() * 1600; easing.type: Easing.InOutSine }
          NumberAnimation { to: 0.85; duration: 1400 + Math.random() * 1600; easing.type: Easing.InOutSine }
        }
      }
    }
  }
  Item {
    anchors.fill: parent
    visible: !root.day && (root.kind === "clear" || root.kind === "partly")
    layer.enabled: visible
    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 48 }
    Rectangle {
      width: 160; height: 160; radius: 80
      x: parent.width - 260; y: 30
      color: "#dfe8ff"; opacity: 0.35
    }
  }

  // ---------------------------------------------------------------- clouds
  Item {
    id: clouds
    anchors.fill: parent
    visible: root.cloudy
    opacity: root.kind === "partly" ? 0.5 : root.kind === "clear" ? root.cloudCover / 160 : 0.8
    layer.enabled: visible
    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
    // One slow clock for every cloud; each crosses a whole number of times
    // per cycle, so the loop wraps without a jump.
    property real phase: 0
    NumberAnimation on phase {
      running: root.running && clouds.visible
      loops: Animation.Infinite
      from: 0; to: 1; duration: 360000
    }
    Repeater {
      model: 8
      Rectangle {
        required property int index
        readonly property real start: Math.random()
        readonly property int laps: 1 + Math.floor(Math.random() * 3)
        width: 320 + Math.random() * 380
        height: 90 + Math.random() * 110
        radius: height / 2
        x: ((start + clouds.phase * laps) % 1) * (root.width + width) - width
        y: -40 + Math.random() * root.height * 0.55
        color: root.kind === "storm" || root.kind === "rain" ? "#59616b" : root.day ? "#eef2f6" : "#5a6474"
        opacity: 0.35 + Math.random() * 0.4
      }
    }
  }

  // ---------------------------------------------------------------- fog
  Item {
    anchors.fill: parent
    visible: root.kind === "fog"
    layer.enabled: visible
    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
    Repeater {
      model: 5
      Rectangle {
        required property int index
        width: root.width * 1.4
        height: 90 + index * 20
        radius: height / 2
        y: root.height * (0.25 + index * 0.15)
        color: "#ffffff"
        opacity: 0.12
        SequentialAnimation on x {
          running: root.running && parent.visible
          loops: Animation.Infinite
          NumberAnimation { from: -root.width * 0.3; to: 0; duration: 26000 + index * 5000; easing.type: Easing.InOutSine }
          NumberAnimation { from: 0; to: -root.width * 0.3; duration: 26000 + index * 5000; easing.type: Easing.InOutSine }
        }
      }
    }
  }

  // ---------------------------------------------------------------- rain
  Item {
    anchors.fill: parent
    visible: root.wet
    Repeater {
      model: root.wet ? Math.round((root.kind === "drizzle" ? 50 : 70) + root.intensity * 110) : 0
      Rectangle {
        required property int index
        readonly property real len: root.kind === "drizzle" ? 8 + Math.random() * 6 : 16 + Math.random() * 18
        width: root.kind === "drizzle" ? 1 : 1.5
        height: len
        rotation: 14
        color: "#dbe7f2"
        opacity: 0.18 + Math.random() * 0.3
        x: Math.random() * (root.width + 120) - 60
        NumberAnimation on y {
          running: root.running && root.wet
          loops: Animation.Infinite
          from: -60 - Math.random() * root.height; to: root.height + 40
          duration: (root.kind === "drizzle" ? 1500 : 650) + Math.random() * 450
        }
      }
    }
  }

  // ---------------------------------------------------------------- snow
  Item {
    anchors.fill: parent
    visible: root.kind === "snow"
    Repeater {
      model: root.kind === "snow" ? Math.round(50 + root.intensity * 90) : 0
      Rectangle {
        id: flake
        required property int index
        readonly property real size: 2 + Math.random() * 3.5
        readonly property real baseX: Math.random() * root.width
        readonly property real sway: 12 + Math.random() * 24
        width: size; height: size; radius: size / 2
        color: "#ffffff"
        opacity: 0.45 + Math.random() * 0.45
        x: baseX
        NumberAnimation on y {
          running: root.running && root.kind === "snow"
          loops: Animation.Infinite
          from: -20 - Math.random() * root.height; to: root.height + 10
          duration: 7000 + Math.random() * 7000 / flake.size * 3
        }
        SequentialAnimation on x {
          running: root.running && root.kind === "snow"
          loops: Animation.Infinite
          NumberAnimation { from: flake.baseX - flake.sway; to: flake.baseX + flake.sway; duration: 2200 + Math.random() * 1800; easing.type: Easing.InOutSine }
          NumberAnimation { from: flake.baseX + flake.sway; to: flake.baseX - flake.sway; duration: 2200 + Math.random() * 1800; easing.type: Easing.InOutSine }
        }
      }
    }
  }

  // ---------------------------------------------------------------- lightning
  Rectangle {
    id: flash
    anchors.fill: parent
    color: "#eef3ff"
    opacity: 0
    SequentialAnimation {
      id: strike
      NumberAnimation { target: flash; property: "opacity"; to: 0.45; duration: 60 }
      NumberAnimation { target: flash; property: "opacity"; to: 0.05; duration: 90 }
      NumberAnimation { target: flash; property: "opacity"; to: 0.3; duration: 50 }
      NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 500; easing.type: Easing.OutQuad }
    }
    Timer {
      running: root.running && root.kind === "storm"
      repeat: true
      interval: 6000
      onTriggered: { interval = 4000 + Math.random() * 9000; strike.start() }
    }
  }
}
