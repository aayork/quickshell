import QtQuick

// A pixel-art wallpaper brought to life. The art is drawn at its own size
// with a few things moving on its pixel grid (falling leaves, glints on
// water, a ripple, steam, drifting motes), then scaled up to the screen with
// hard edges, so the moving parts are made of the same big pixels as the art.
//
// Described by "<image>.live.json" next to the image:
//   width, height   the art's size in its own pixels
//   fps             how often things move (pixel art steps; 12-15 suits it)
//   focusX, focusY  which part stays in view when the screen crops it (0-1)
//   leaves          mid-ground leaves (see PixelLeaves.qml for the fields)
//   farLeaves       small faded ones behind; nearLeaves big dark ones in
//                   front, in pixels `pixel` times the art's
//   mist            { areas: [[x0,y0,x1,y1], ...], bands, color }
//   shafts          { beams: [[x, y, width, opacity], ...], angle, length,
//                     speed, color }
//   vignette        { color, strength }
//   shimmer         { areas: [[x0,y0,x1,y1], ...], amp, speed, wave } a
//                   reflection rippling, row by row
//   flow            [{ points, dir: [x,y], speed, count, length, life,
//                     colors }, ...] running water
//   birds           far off (see PixelBirds.qml); nearBirds close up, in
//                   pixels `nearPixel` times the art's
//   water           { glints, color, dim, points: [[x,y], ...] }
//   ripple          { at: [x,y], every, color }
//   steam           { from: [[x,y], ...], color }
//   motes           { count, area: [x0,y0,x1,y1], color }
// Any of the effects can be left out.
Item {
  id: root

  required property url source
  required property var spec
  // Stops the clock (the screen is locked, or covered).
  property bool running: true

  readonly property int artWidth: spec.width
  readonly property int artHeight: spec.height
  readonly property real zoom: Math.max(width / artWidth, height / artHeight)
  readonly property real dt: 1 / (spec.fps || 15)

  signal tick()

  function rand(a, b) { return a + Math.random() * (b - a) }
  function pick(list) { return list[Math.floor(Math.random() * list.length)] }

  clip: true

  Timer {
    interval: Math.round(1000 * root.dt)
    repeat: true
    running: root.running && root.visible
    onTriggered: root.tick()
  }

  Item {
    id: art
    width: root.artWidth
    height: root.artHeight
    transformOrigin: Item.TopLeft
    scale: root.zoom
    x: Math.round((root.width - root.artWidth * root.zoom) * (root.spec.focusX ?? 0.5))
    y: Math.round((root.height - root.artHeight * root.zoom) * (root.spec.focusY ?? 0.5))
    // Everything is drawn into a texture the art's own size, then scaled up
    // without smoothing: a moving leaf is as blocky as a painted one.
    layer.enabled: true
    layer.smooth: false
    layer.textureSize: Qt.size(root.artWidth, root.artHeight)

    Image {
      anchors.fill: parent
      source: root.source
      smooth: false
      mipmap: false
      cache: false
    }

    // A reflection rippling: each row of the water redrawn a pixel to the
    // left or right as slow waves pass, more strongly nearer the viewer.
    Repeater {
      model: root.spec.shimmer ? root.spec.shimmer.areas : []

      Item {
        id: pool
        required property var modelData
        readonly property var cfg: root.spec.shimmer
        property real t: 0

        Connections {
          target: root
          function onTick() { pool.t += root.dt }
        }

        Repeater {
          model: pool.modelData[3] - pool.modelData[1]

          Image {
            required property int index
            readonly property int row: pool.modelData[1] + index
            readonly property real depth: index / Math.max(1, pool.modelData[3] - pool.modelData[1])
            readonly property real amp: (pool.cfg.amp ?? 1) * (0.35 + 0.65 * depth)
            source: root.source
            smooth: false
            sourceClipRect: Qt.rect(pool.modelData[0], row, pool.modelData[2] - pool.modelData[0], 1)
            x: pool.modelData[0] + Math.round(amp * Math.sin(pool.t * (pool.cfg.speed ?? 1.4) + row * (pool.cfg.wave ?? 0.55))
              * Math.sin(pool.t * 0.37 + row * 0.11))
            y: row
          }
        }
      }
    }

    // Far away: small, faded leaves dropping behind the tree, towards the lake.
    PixelLeaves {
      clock: root
      cfg: root.spec.farLeaves ?? null
      size: "small"
    }

    // Mist drifting over the water, in thin bands kept to each stretch of lake.
    Repeater {
      model: root.spec.mist ? root.spec.mist.areas : []

      Item {
        id: lake
        required property var modelData
        readonly property var cfg: root.spec.mist
        x: modelData[0]
        y: modelData[1]
        width: modelData[2] - modelData[0]
        height: modelData[3] - modelData[1]
        clip: true

        Repeater {
          model: lake.cfg.bands ?? 5

          Rectangle {
            id: band
            property real fx: root.rand(-60, lake.width)
            property real speed: root.rand(1.5, 4)
            property real breath: root.rand(0, Math.PI * 2)
            property real t: 0
            width: Math.round(root.rand(24, 70))
            height: Math.random() < 0.4 ? 2 : 1
            x: Math.round(fx)
            y: Math.round(root.rand(0, lake.height - 2))
            color: lake.cfg.color
            // Thickens and thins in steps, like dithered haze.
            opacity: [0.12, 0.2, 0.28][Math.floor((Math.sin(t * 0.5 + breath) + 1) * 1.49)]

            Connections {
              target: root
              function onTick() {
                band.t += root.dt
                band.fx += band.speed * root.dt
                if (band.fx > lake.width) band.fx = -band.width
              }
            }
          }
        }
      }
    }

    // In the clearing: leaves come loose from the canopy, tumble and sway
    // down, and land in the grass.
    PixelLeaves {
      clock: root
      cfg: root.spec.leaves ?? null
      size: "medium"
    }

    // Birds crossing the scene, far off.
    PixelBirds {
      clock: root
      cfg: root.spec.birds ?? null
    }

    // Running water: short streaks sliding along it (down a waterfall, along
    // a river), starting anywhere on the water and fading after a moment.
    Repeater {
      model: root.spec.flow ? root.spec.flow : []

      Item {
        id: stream
        required property var modelData
        readonly property var cfg: modelData

        Repeater {
          model: stream.cfg.count

          Rectangle {
            id: streak
            property real fx: 0
            property real fy: 0
            property real age: 0
            property real life: 0.5
            readonly property var dir: stream.cfg.dir ?? [0, 1]
            readonly property bool upright: Math.abs(dir[1]) >= Math.abs(dir[0])
            property int length: 3
            x: Math.round(fx)
            y: Math.round(fy)
            width: upright ? 1 : length
            height: upright ? length : 1
            color: stream.cfg.colors[0]
            opacity: age < life * 0.2 || age > life * 0.8 ? 0.5 : 1

            function reset() {
              var p = root.pick(stream.cfg.points)
              fx = p[0]
              fy = p[1]
              age = 0
              life = root.rand(0.25, stream.cfg.life ?? 0.8)
              length = Math.round(root.rand(2, stream.cfg.length ?? 4))
              color = root.pick(stream.cfg.colors)
            }

            Component.onCompleted: { reset(); age = root.rand(0, life) }

            Connections {
              target: root
              function onTick() {
                var speed = stream.cfg.speed
                streak.fx += streak.dir[0] * speed * root.dt
                streak.fy += streak.dir[1] * speed * root.dt
                streak.age += root.dt
                if (streak.age > streak.life) streak.reset()
              }
            }
          }
        }
      }
    }

    // Sun glinting on the water: short bright streaks that come and go.
    Repeater {
      model: root.spec.water ? root.spec.water.glints : 0

      Rectangle {
        id: glint

        readonly property var cfg: root.spec.water
        property real age: 0
        property real life: 1
        property real wait: 0

        height: 1
        visible: wait <= 0
        // Dim at either end of its life, bright in the middle.
        color: age < life * 0.25 || age > life * 0.75 ? cfg.dim : cfg.color

        function reset() {
          var p = root.pick(cfg.points)
          x = p[0]
          y = p[1]
          width = Math.round(root.rand(3, 7))
          age = 0
          life = root.rand(0.6, 1.6)
          wait = root.rand(0, 1.5)
        }

        Component.onCompleted: reset()

        Connections {
          target: root
          function onTick() {
            if (glint.wait > 0) { glint.wait -= root.dt; return }
            glint.age += root.dt
            if (glint.age > glint.life) glint.reset()
          }
        }
      }
    }

    // Rings spreading from where the fishing line meets the water.
    Item {
      id: ripple

      readonly property var cfg: root.spec.ripple
      property real age: 0
      readonly property real duration: 1.8
      readonly property real radius: 1 + age / duration * 9

      visible: !!cfg && age < duration
      opacity: age < duration * 0.6 ? 1 : 0.55

      Connections {
        target: root
        enabled: !!ripple.cfg
        function onTick() {
          ripple.age += root.dt
          if (ripple.age > ripple.cfg.every) ripple.age = 0
        }
      }

      Repeater {
        model: 20
        Rectangle {
          required property int index
          readonly property real a: index / 20 * Math.PI * 2
          x: ripple.cfg ? Math.round(ripple.cfg.at[0] + Math.cos(a) * ripple.radius) : 0
          y: ripple.cfg ? Math.round(ripple.cfg.at[1] + Math.sin(a) * ripple.radius * 0.3) : 0
          width: 1
          height: 1
          color: ripple.cfg ? ripple.cfg.color : "white"
        }
      }
    }

    // Steam curling up from the teapot and cups.
    Repeater {
      model: root.spec.steam ? root.spec.steam.from.length * 4 : 0

      Rectangle {
        id: puff

        required property int index
        readonly property var cfg: root.spec.steam
        readonly property var origin: cfg.from[Math.floor(index / 4)]
        property real age: 0
        property real life: 2.6
        property real drift: 0

        width: 1
        height: 1
        color: cfg.color
        x: Math.round(origin[0] + Math.sin(age * 2.2 + drift) * 1.4 + age * 0.8)
        y: Math.round(origin[1] - age * 5)
        // Thins out in steps as it rises.
        opacity: age < life * 0.35 ? 0.8 : age < life * 0.7 ? 0.5 : 0.25

        function reset(first) {
          life = root.rand(2, 3.2)
          age = first ? (index % 4) / 4 * life : 0
          drift = root.rand(0, Math.PI * 2)
        }

        Component.onCompleted: reset(true)

        Connections {
          target: root
          function onTick() {
            puff.age += root.dt
            if (puff.age > puff.life) puff.reset(false)
          }
        }
      }
    }

    // Specks of dust or pollen drifting in the light, twinkling.
    Repeater {
      model: root.spec.motes ? root.spec.motes.count : 0

      Rectangle {
        id: mote

        readonly property var cfg: root.spec.motes
        property real fx: 0
        property real fy: 0
        property real vx: 0
        property real vy: 0
        property real age: 0
        property real life: 6

        width: 1
        height: 1
        color: cfg.color
        x: Math.round(fx)
        y: Math.round(fy)
        // Fades in and out, and twinkles between.
        opacity: age < 0.8 || age > life - 0.8 ? 0.45 : (Math.floor(age * 3 + fx) % 4 === 0 ? 0.55 : 1)

        function reset() {
          fx = root.rand(cfg.area[0], cfg.area[2])
          fy = root.rand(cfg.area[1], cfg.area[3])
          vx = root.rand(-1.5, 2.5)
          vy = root.rand(-2.5, 0.5)
          age = 0
          life = root.rand(4, 9)
        }

        Component.onCompleted: { reset(); age = root.rand(0, life) }

        Connections {
          target: root
          function onTick() {
            mote.age += root.dt
            mote.fx += mote.vx * root.dt
            mote.fy += mote.vy * root.dt
            if (mote.age > mote.life) mote.reset()
          }
        }
      }
    }

    // Sunbeams slanting down through gaps in the canopy, slowly brightening
    // and fading. Drawn on the art's grid, so their edges step like pixels.
    Repeater {
      model: root.spec.shafts ? root.spec.shafts.beams : []

      Rectangle {
        id: beam
        required property var modelData
        readonly property var cfg: root.spec.shafts
        property real t: root.rand(0, 20)
        x: modelData[0]
        y: modelData[1]
        width: modelData[2]
        height: cfg.length ?? 420
        rotation: cfg.angle ?? -24
        transformOrigin: Item.Top
        opacity: (modelData[3] ?? 0.14) * (0.55 + 0.45 * Math.sin(t * (cfg.speed ?? 0.35)))
        gradient: Gradient {
          GradientStop { position: 0; color: beam.cfg.color }
          GradientStop { position: 0.55; color: Qt.alpha(beam.cfg.color, 0.6) }
          GradientStop { position: 1; color: "transparent" }
        }

        Connections {
          target: root
          function onTick() { beam.t += root.dt }
        }
      }
    }
  }

  // Close to the viewer: a few big leaves falling past, dark against the
  // light, in pixels bigger than the art's, so they read as nearer.
  Item {
    id: near
    readonly property var cfg: root.spec.nearLeaves ?? null
    readonly property int pixel: root.spec.nearPixel ?? (cfg ? (cfg.pixel ?? 2) : 2)
    visible: cfg !== null || !!root.spec.nearBirds
    width: Math.ceil(root.artWidth / pixel)
    height: Math.ceil(root.artHeight / pixel)
    transformOrigin: Item.TopLeft
    scale: root.zoom * pixel
    x: art.x
    y: art.y
    layer.enabled: visible
    layer.smooth: false
    layer.textureSize: Qt.size(width, height)

    PixelLeaves {
      clock: root
      cfg: near.cfg
      size: "large"
    }

    PixelBirds {
      clock: root
      cfg: root.spec.nearBirds ?? null
    }
  }

  // The edges darken a little, like the trees closing in round the clearing.
  Item {
    id: vignette
    anchors.fill: parent
    visible: !!root.spec.vignette
    readonly property color shadow: root.spec.vignette ? root.spec.vignette.color : "black"
    readonly property real strength: root.spec.vignette ? root.spec.vignette.strength : 0

    Rectangle {
      width: parent.width
      height: parent.height * 0.22
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.alpha(vignette.shadow, vignette.strength * 0.8) }
        GradientStop { position: 1; color: "transparent" }
      }
    }
    Rectangle {
      width: parent.width
      height: parent.height * 0.25
      anchors.bottom: parent.bottom
      gradient: Gradient {
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: 1; color: Qt.alpha(vignette.shadow, vignette.strength) }
      }
    }
    Rectangle {
      width: parent.width * 0.18
      height: parent.height
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.alpha(vignette.shadow, vignette.strength) }
        GradientStop { position: 1; color: "transparent" }
      }
    }
    Rectangle {
      width: parent.width * 0.18
      height: parent.height
      anchors.right: parent.right
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: 1; color: Qt.alpha(vignette.shadow, vignette.strength) }
      }
    }
  }
}
