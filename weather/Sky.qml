import QtQuick
import qs.theme

// The window's backdrop: a sky for the conditions outside right now. A
// three-stop gradient for the time of day and weather (dithered with a grain
// tile so it never bands), then whatever is in it: sun or moon glow, stars,
// two depths of drifting cloud, fog banks, rain, snow, lightning.
// Textures live in weather/sky/ (made by weather/sky/generate.py); nothing
// here is blurred at run time.
Item {
  id: root

  property string kind: "clear"   // clear partly cloudy fog drizzle rain snow storm
  property bool day: true
  property real intensity: 0.5    // 0..1 for rain/snow
  property real cloudCover: 0     // 0..100
  property bool running: true

  // top, middle, horizon
  readonly property var palette: {
    var p = {
      clear:   day ? ["#1f5fae", "#4f8fd0", "#a9d0ee"] : ["#050914", "#0d1630", "#24335a"],
      partly:  day ? ["#2a64a3", "#5d93c6", "#b3cfe6"] : ["#070b18", "#111a33", "#2a3657"],
      cloudy:  day ? ["#4d5966", "#6f7b88", "#a3adb7"] : ["#0d1015", "#181d25", "#2c333d"],
      fog:     day ? ["#737b83", "#959ca3", "#c3c7cb"] : ["#15181c", "#22262b", "#3a3f45"],
      drizzle: day ? ["#43505d", "#5f6c79", "#8995a0"] : ["#0b0f14", "#151b22", "#29313b"],
      rain:    day ? ["#323e4a", "#4a5764", "#6f7c88"] : ["#080b10", "#11161d", "#222a33"],
      snow:    day ? ["#6d7e90", "#93a3b3", "#d3dbe3"] : ["#121826", "#1f2738", "#3c4659"],
      storm:   day ? ["#1d222a", "#2f3640", "#535c67"] : ["#040507", "#0b0e13", "#1a1f27"]
    }
    return p[kind] || p.clear
  }
  function blend(c) { return Qt.tint(c, Theme.alpha(Theme.background, 0.22)) }

  readonly property bool clearish: kind === "clear" || kind === "partly"
  readonly property bool overcast: !clearish && kind !== "fog"
  readonly property bool wet: kind === "rain" || kind === "drizzle" || kind === "storm"
  readonly property bool darkClouds: !day || kind === "rain" || kind === "storm" || kind === "drizzle"
  // 0..1: how much of the sky the clouds take.
  readonly property real cover: kind === "clear" ? Math.min(1, cloudCover / 100) * 0.5
                              : kind === "partly" ? 0.55
                              : kind === "fog" ? 0 : 0.5

  clip: true

  // ---------------------------------------------------------------- sky
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.blend(root.palette[0]); Behavior on color { ColorAnimation { duration: 800 } } }
      GradientStop { position: 0.55; color: root.blend(root.palette[1]); Behavior on color { ColorAnimation { duration: 800 } } }
      GradientStop { position: 1.0; color: root.blend(root.palette[2]); Behavior on color { ColorAnimation { duration: 800 } } }
    }
  }

  // ---------------------------------------------------------------- sun
  Item {
    id: sun
    anchors.fill: parent
    visible: root.day && root.clearish
    readonly property real sx: root.width - 170
    readonly property real sy: 40
    // Wide warm wash, then a tighter bright core.
    Image {
      source: "sky/glow-soft.png"
      width: 1300; height: 1300
      x: sun.sx - width / 2; y: sun.sy - height / 2
      opacity: root.kind === "clear" ? 0.32 : 0.2
      smooth: true; mipmap: true
    }
    Image {
      id: core
      source: "sky/glow.png"
      width: 420; height: 420
      x: sun.sx - width / 2; y: sun.sy - height / 2
      opacity: root.kind === "clear" ? 0.85 : 0.55
      smooth: true; mipmap: true
      SequentialAnimation on scale {
        running: root.running && sun.visible
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 1.06; duration: 6000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.06; to: 1; duration: 6000; easing.type: Easing.InOutSine }
      }
    }
  }

  // ---------------------------------------------------------------- stars + moon
  Item {
    id: night
    anchors.fill: parent
    visible: !root.day && root.clearish
    Repeater {
      model: night.visible ? 140 : 0
      Rectangle {
        required property int index
        readonly property real seed: Math.random()
        x: Math.random() * root.width
        y: Math.pow(Math.random(), 1.4) * root.height * 0.8
        width: seed > 0.92 ? 2.4 : seed > 0.6 ? 1.6 : 1.1
        height: width; radius: width / 2
        antialiasing: true
        color: seed > 0.95 ? "#ffe9c9" : seed < 0.08 ? "#cfe0ff" : "#ffffff"
        opacity: (0.2 + seed * 0.7) * (1 - y / root.height * 0.6)
        SequentialAnimation on opacity {
          running: root.running && night.visible && seed > 0.45
          loops: Animation.Infinite
          PauseAnimation { duration: Math.random() * 4000 }
          NumberAnimation { to: 0.12; duration: 1400 + Math.random() * 1600; easing.type: Easing.InOutSine }
          NumberAnimation { to: 0.85; duration: 1400 + Math.random() * 1600; easing.type: Easing.InOutSine }
        }
      }
    }
    Image {
      source: "sky/glow-soft.png"
      width: 520; height: 520
      x: root.width - 190 - width / 2; y: 90 - height / 2
      opacity: 0.22
      smooth: true; mipmap: true
    }
    Rectangle {
      width: 46; height: 46; radius: 23
      x: root.width - 190 - 23; y: 90 - 23
      antialiasing: true
      gradient: Gradient {
        GradientStop { position: 0; color: "#f4f1e6" }
        GradientStop { position: 1; color: "#cfcab9" }
      }
      opacity: 0.92
    }
  }

  // ---------------------------------------------------------------- clouds
  // One slow clock for every cloud; each crosses a whole number of times
  // per cycle, so the loop wraps without a jump. Far clouds are smaller,
  // fainter and slower; near ones big and faster.
  property real phase: 0
  NumberAnimation on phase {
    running: root.running && root.cover > 0
    loops: Animation.Infinite
    from: 0; to: 1; duration: 600000
  }



  // Overcast skies: a continuous ceiling of stratus, three layers drifting
  // at different speeds, darker for rain.
  Repeater {
    model: root.overcast ? 3 : 0
    Item {
      id: deck
      required property int index
      width: root.width
      height: root.height * (0.75 - index * 0.12)
      y: -root.height * 0.05 + index * root.height * 0.06
      opacity: [0.9, 0.7, 0.55][index] * (root.day ? 1 : 0.8)
      property real shift: 0
      NumberAnimation on shift {
        running: root.running
        loops: Animation.Infinite
        from: 0; to: 1600; duration: 240000 - deck.index * 60000
      }
      Image {
        x: -(deck.shift + deck.index * 530) % 1600
        width: root.width + 1600; height: parent.height
        source: "sky/stratus-" + (root.darkClouds ? "dark" : "light") + ".png"
        fillMode: Image.TileHorizontally
        smooth: true
      }
    }
  }
  Repeater {
    model: Math.round(root.cover * 7)
    SkyCloud {
      sky: root
      required property int index
      variant: (index * 3 + 1) % 5
      start: (index * 0.618) % 1
      laps: 1 + index % 2
      depth: 0.1 + (index % 3) * 0.12
      band: ((index * 0.37) % 1) * 0.8 + 0.1
      opacity: (root.darkClouds ? 0.55 : 0.5) * (root.day ? 1 : 0.7)
    }
  }
  Repeater {
    model: Math.round(root.cover * 5)
    SkyCloud {
      sky: root
      required property int index
      variant: index % 5
      start: (index * 0.381 + 0.2) % 1
      laps: 2 + index % 2
      depth: 0.7 + (index % 2) * 0.3
      band: ((index * 0.53) % 1) * 0.6
      opacity: (root.darkClouds ? 0.85 : 0.92) * (root.day ? 1 : 0.75)
    }
  }

  // ---------------------------------------------------------------- fog
  Repeater {
    model: root.kind === "fog" || root.kind === "drizzle" ? 4 : 0
    Item {
      id: bank
      required property int index
      width: root.width; height: 300
      y: root.height * (0.12 + index * 0.22) - 120
      opacity: (root.kind === "fog" ? 0.55 : 0.25) * (root.day ? 1 : 0.45)
      property real shift: 0
      NumberAnimation on shift {
        running: root.running
        loops: Animation.Infinite
        from: 0; to: 1600; duration: 90000 + bank.index * 30000
      }
      Image {
        x: -(bank.shift + bank.index * 400) % 1600
        width: root.width + 1600; height: parent.height
        source: "sky/fog.png"
        fillMode: Image.TileHorizontally
        smooth: true
      }
    }
  }

  // ---------------------------------------------------------------- rain
  Item {
    anchors.fill: parent
    visible: root.wet
    Repeater {
      model: root.wet ? Math.round((root.kind === "drizzle" ? 60 : 90) + root.intensity * 140) : 0
      Rectangle {
        required property int index
        readonly property real near: Math.random()
        readonly property real len: root.kind === "drizzle" ? 10 + near * 10 : 22 + near * 34
        width: root.kind === "drizzle" ? 1 : 1 + near * 1.2
        height: len
        rotation: 12
        antialiasing: true
        gradient: Gradient {
          GradientStop { position: 0; color: "transparent" }
          GradientStop { position: 1; color: "#e4eef8" }
        }
        opacity: 0.12 + near * 0.35
        x: Math.random() * (root.width + 160) - 40
        NumberAnimation on y {
          running: root.running && root.wet
          loops: Animation.Infinite
          from: -80 - Math.random() * root.height; to: root.height + 40
          duration: (root.kind === "drizzle" ? 1800 : 560) + (1 - near) * 500
        }
      }
    }
  }

  // ---------------------------------------------------------------- snow
  Item {
    anchors.fill: parent
    visible: root.kind === "snow"
    Repeater {
      model: root.kind === "snow" ? Math.round(60 + root.intensity * 110) : 0
      Item {
        id: flake
        required property int index
        readonly property real near: Math.pow(Math.random(), 2)
        readonly property real size: 3 + near * 12
        readonly property real baseX: Math.random() * root.width
        readonly property real sway: 10 + near * 30
        width: size; height: size
        x: baseX
        opacity: 0.35 + near * 0.5
        // Near flakes are soft out-of-focus discs, far ones crisp dots.
        Image {
          anchors.fill: parent
          visible: flake.near > 0.35
          source: "sky/glow.png"
          smooth: true; mipmap: true
        }
        Rectangle {
          anchors.centerIn: parent
          visible: flake.near <= 0.35
          width: 2 + flake.near * 5; height: width; radius: width / 2
          antialiasing: true
          color: "#ffffff"
        }
        NumberAnimation on y {
          running: root.running && root.kind === "snow"
          loops: Animation.Infinite
          from: -30 - Math.random() * root.height; to: root.height + 20
          duration: 16000 - flake.near * 8000 + Math.random() * 3000
        }
        SequentialAnimation on x {
          running: root.running && root.kind === "snow"
          loops: Animation.Infinite
          NumberAnimation { from: flake.baseX - flake.sway; to: flake.baseX + flake.sway; duration: 2600 + Math.random() * 2000; easing.type: Easing.InOutSine }
          NumberAnimation { from: flake.baseX + flake.sway; to: flake.baseX - flake.sway; duration: 2600 + Math.random() * 2000; easing.type: Easing.InOutSine }
        }
      }
    }
  }

  // ---------------------------------------------------------------- lightning
  Rectangle {
    id: flash
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: "#f2f5ff" }
      GradientStop { position: 1; color: "#8090b0" }
    }
    opacity: 0
    SequentialAnimation {
      id: strike
      NumberAnimation { target: flash; property: "opacity"; to: 0.5; duration: 60 }
      NumberAnimation { target: flash; property: "opacity"; to: 0.06; duration: 90 }
      NumberAnimation { target: flash; property: "opacity"; to: 0.32; duration: 50 }
      NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 600; easing.type: Easing.OutQuad }
    }
    Timer {
      running: root.running && root.kind === "storm"
      repeat: true
      interval: 6000
      onTriggered: { interval = 4000 + Math.random() * 9000; strike.start() }
    }
  }

  // ---------------------------------------------------------------- grain
  // Dithers the gradients and glows so they never show 8-bit bands.
  Image {
    anchors.fill: parent
    source: "sky/grain.png"
    fillMode: Image.Tile
    opacity: 0.035
    smooth: false
  }
}
