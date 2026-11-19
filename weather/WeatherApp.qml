import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import qs.theme
import qs.ui
import "../services/WeatherLib.js" as Lib

// The weather window (bar icon, `weather toggle` IPC, or the clock popup).
// An animated sky for the conditions sits behind everything; on top: saved
// places, the current conditions, NWS alerts, radar, the next 24 hours, a
// 48-hour chart, 10 days, air quality, sun and moon, and every technical
// reading Open-Meteo has, each with a line saying what it means.
Scope {
  id: root

  property bool open: false
  // For offscreen render checks.
  readonly property alias surface: surface

  function show() {
    open = true
    Weather.windowOpen = true
    Weather.refreshPlace(Weather.shown)
    Weather.refreshRadar()
    focusTimer.restart()
  }
  function hide() {
    open = false
    Weather.windowOpen = false
    adding = false
  }

  Connections {
    target: Weather
    function onWindowRequested(want) { if (want) root.show(); else root.hide() }
  }
  Connections {
    target: PopupState
    function onRequested(name) { if (name === "weather") root.show() }
  }
  IpcHandler {
    target: "weather"
    function toggle(): void { if (root.open) root.hide(); else root.show() }
    function open(): void { root.show() }
    function close(): void { root.hide() }
  }
  Timer {
    id: focusTimer
    interval: 60
    onTriggered: Hyprland.dispatch("hl.dsp.focus({ window = \"title:^Weather$\" })")
  }

  // ---------------------------------------------------------------- data
  readonly property var entry: Weather.shownEntry
  readonly property var f: entry ? entry.forecast || null : null
  readonly property var c: f ? f.current : null
  readonly property bool imperial: Weather.imperial
  readonly property int hi: Lib.hourIndex(f)
  readonly property int di: Lib.dayIndex(f)
  readonly property var air: entry && entry.air ? entry.air.current : null
  readonly property var alerts: entry && entry.alerts ? entry.alerts : []
  readonly property color blue: Theme.pick("blue", "#8499c2")
  readonly property color cyan: Theme.pick("cyan", "#73b0b5")
  readonly property color orange: Theme.pick("orange", "#c29b84")
  readonly property color magenta: Theme.pick("magenta", "#b384c2")

  function hours(field, n) { return f ? f.hourly[field].slice(hi, hi + n) : [] }
  function daily(field, i) { return f ? f.daily[field][i] : null }
  function sum(list) { var s = 0; for (var i = 0; i < list.length; i++) s += list[i] || 0; return s }
  function max(list) { var m = 0; for (var i = 0; i < list.length; i++) m = Math.max(m, list[i] || 0); return m }

  readonly property real pressureDelta: f && hi >= 3 ? c.pressure_msl - f.hourly.pressure_msl[hi - 3] : 0
  readonly property real daylightDelta: f && di >= 1 ? f.daily.daylight_duration[di] - f.daily.daylight_duration[di - 1] : 0
  // Hours today with UV 3+, as "11 AM–3 PM".
  readonly property string uvWindow: {
    if (!f) return ""
    var day = f.daily.time[di], first = "", last = ""
    for (var i = 0; i < f.hourly.time.length; i++) {
      if (f.hourly.time[i].slice(0, 10) !== day || (f.hourly.uv_index[i] || 0) < 3) continue
      if (first === "") first = f.hourly.time[i]
      last = f.hourly.time[i]
    }
    if (first === "") return ""
    var end = Lib.parse(last); end.setHours(end.getHours() + 1)
    return Lib.hourLong(first) + "–" + (end.getHours() === 12 ? "noon" : (end.getHours() % 12 || 12) + (end.getHours() < 12 ? " AM" : " PM"))
  }

  property double now: Date.now()
  Timer { interval: 30000; running: root.open; repeat: true; onTriggered: root.now = Date.now() }
  function ago(t) {
    if (!t) return ""
    var m = Math.round((now - t) / 60000)
    return m < 1 ? "Updated just now" : "Updated " + m + " min ago"
  }

  property bool adding: false
  property string chart: "temp"
  property var openAlert: -1

  // ---------------------------------------------------------------- pieces
  component Card: Rectangle {
    id: card
    property string title: ""
    property int glyph: 0
    default property alias content: body.data
    property alias body: body
    radius: Theme.controlRadius
    color: Theme.alpha(Theme.background, 0.62)
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.08)
    implicitHeight: body.implicitHeight + (card.title !== "" ? 40 : 24)
    Row {
      id: head
      visible: card.title !== ""
      x: 12; y: 10
      spacing: 6
      Label { visible: card.glyph !== 0; text: card.glyph ? Icons.glyph(card.glyph) : ""; color: Theme.dim; font.pixelSize: Theme.fontSmall }
      Label { text: card.title.toUpperCase(); color: Theme.dim; font.pixelSize: Theme.fontSmall; font.letterSpacing: 0.8 }
    }
    ColumnLayout {
      id: body
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.leftMargin: 12; anchors.rightMargin: 12
      anchors.topMargin: card.title !== "" ? 30 : 12
      spacing: 6
    }
  }

  // A reading: title, big value, a detail line, and what it means.
  component Tile: Card {
    id: tile
    property string value: ""
    property string detail: ""
    property string note: ""
    // Something drawn in the tile's top-right corner (the wind compass).
    property alias corner: cornerSlot.data
    Layout.fillWidth: true
    Layout.preferredHeight: 158
    Item { id: cornerSlot; parent: tile; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; width: childrenRect.width; height: childrenRect.height }
    Label { text: tile.value; font.pixelSize: 24; color: Theme.brightForeground; Layout.fillWidth: true }
    Label { visible: tile.detail !== ""; text: tile.detail; color: Theme.foreground; Layout.fillWidth: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; maximumLineCount: 2 }
    Label {
      text: tile.note
      color: Theme.dim
      font.pixelSize: Theme.fontSmall
      wrapMode: Text.WordWrap
      elide: Text.ElideNone
      maximumLineCount: 3
      Layout.fillWidth: true
    }
  }

  // A coloured scale with a marker at `position` (0..1).
  component Meter: Item {
    id: meter
    property real position: 0
    property var stops: [root.green, Theme.yellow, root.orange, Theme.red, root.magenta]
    Layout.fillWidth: true
    implicitHeight: 10
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width; height: 4; radius: 2
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: meter.stops[0] }
        GradientStop { position: 0.25; color: meter.stops[1] }
        GradientStop { position: 0.5; color: meter.stops[2] }
        GradientStop { position: 0.75; color: meter.stops[3] }
        GradientStop { position: 1; color: meter.stops[4] }
      }
      opacity: 0.85
    }
    Rectangle {
      x: Math.max(0, Math.min(1, meter.position)) * (meter.width - width)
      anchors.verticalCenter: parent.verticalCenter
      width: 10; height: 10; radius: 5
      color: Theme.brightForeground
      border.width: 2; border.color: Theme.background
    }
  }
  readonly property color green: Theme.green

  // ---------------------------------------------------------------- window
  FloatingWindow {
    id: win
    title: "Weather"
    visible: root.open
    implicitWidth: 1180
    implicitHeight: 840
    minimumSize: Qt.size(940, 600)
    color: Theme.background
    onClosed: root.hide()

    Shortcut {
      sequences: ["Escape"]
      context: Qt.WindowShortcut
      enabled: root.open
      onActivated: root.adding ? root.adding = false : root.hide()
    }
    Shortcut {
      sequences: ["Ctrl+R", "F5"]
      context: Qt.WindowShortcut
      onActivated: { Weather.refreshPlace(Weather.shown, true); Weather.radarAt = 0; Weather.refreshRadar() }
    }

    Item {
    id: surface
    anchors.fill: parent

    Sky {
      anchors.fill: parent
      running: root.open
      kind: root.c ? Lib.kind(root.c.weather_code) : "clear"
      day: root.c ? root.c.is_day === 1 : true
      intensity: root.c ? Lib.intensity(root.c.weather_code) : 0
      cloudCover: root.c ? root.c.cloud_cover : 0
    }

    Flickable {
      id: flick
      anchors.fill: parent
      contentWidth: width
      contentHeight: page.implicitHeight + 48
      boundsBehavior: Flickable.StopAtBounds
      clip: true

      ColumnLayout {
        id: page
        x: 24; y: 18
        width: flick.width - 48
        spacing: 14

        // -------------------------------------------------- places
        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Repeater {
            model: Weather.allPlaces
            Rectangle {
              id: chip
              required property var modelData
              required property int index
              readonly property string placeKey: Weather.key(modelData)
              readonly property bool current: placeKey === Weather.shownKey
              implicitWidth: chipRow.implicitWidth + 20
              implicitHeight: 30
              radius: Theme.controlRadius
              color: current ? Theme.alpha(Theme.background, 0.8) : Theme.alpha(Theme.background, chipMouse.containsMouse ? 0.55 : 0.32)
              border.width: 1
              border.color: current ? Theme.alpha(Theme.accent, 0.7) : Theme.alpha(Theme.foreground, 0.08)
              Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6
                Label {
                  visible: chip.index === 0
                  text: Icons.glyph(0xF02DC)
                  color: chip.current ? Theme.accent : Theme.dim
                }
                Label { text: chip.modelData.name; color: chip.current ? Theme.brightForeground : Theme.foreground }
                Label {
                  readonly property var e: Weather.store[chip.placeKey]
                  visible: !!(e && e.forecast)
                  text: e && e.forecast ? Lib.deg(e.forecast.current.temperature_2m) : ""
                  color: Theme.dim
                }
                Label {
                  visible: chip.index > 0 && chipMouse.containsMouse
                  text: Icons.close
                  color: closeMouse.containsMouse ? Theme.red : Theme.dim
                  MouseArea { id: closeMouse; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: Weather.removePlace(chip.placeKey) }
                }
              }
              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                z: -1
                onClicked: Weather.select(chip.placeKey)
              }
            }
          }

          // Add a place.
          Item {
            implicitWidth: root.adding ? 280 : 30
            implicitHeight: 30
            Rectangle {
              visible: !root.adding
              anchors.fill: parent
              radius: Theme.controlRadius
              color: Theme.alpha(Theme.background, addMouse.containsMouse ? 0.55 : 0.32)
              border.width: 1; border.color: Theme.alpha(Theme.foreground, 0.08)
              Label { anchors.centerIn: parent; text: Icons.glyph(0xF0415); color: Theme.foreground }
              MouseArea {
                id: addMouse; anchors.fill: parent; hoverEnabled: true
                onClicked: { root.adding = true; Weather.results = []; searchField.text = ""; searchField.focusInput() }
              }
            }
            Field {
              id: searchField
              visible: root.adding
              anchors.fill: parent
              placeholder: "Search for a city"
              color: Theme.alpha(Theme.background, 0.85)
              onTextChanged: Weather.search(text)
              onAccepted: if (Weather.results.length > 0) { Weather.addPlace(Weather.results[0]); root.adding = false }
              onCancelled: root.adding = false
            }
          }

          Item { Layout.fillWidth: true }

          Label {
            text: Weather.loading ? "Updating…" : root.entry && root.entry.failed ? "Couldn't reach the weather service" : root.ago(root.entry ? root.entry.fetchedAt : 0)
            color: root.entry && root.entry.failed ? Theme.red : Theme.alpha(Theme.brightForeground, 0.75)
            font.pixelSize: Theme.fontSmall
          }
          Rectangle {
            implicitWidth: 30; implicitHeight: 30
            radius: Theme.controlRadius
            color: Theme.alpha(Theme.background, refreshMouse.containsMouse ? 0.55 : 0.32)
            border.width: 1; border.color: Theme.alpha(Theme.foreground, 0.08)
            Label { anchors.centerIn: parent; text: Icons.glyph(0xF0450); color: Theme.foreground }
            MouseArea {
              id: refreshMouse; anchors.fill: parent; hoverEnabled: true
              onClicked: { Weather.refreshPlace(Weather.shown, true); Weather.radarAt = 0; Weather.refreshRadar() }
            }
          }
        }

        // -------------------------------------------------- nothing yet
        Label {
          visible: !root.c
          Layout.fillWidth: true
          Layout.topMargin: 160
          horizontalAlignment: Text.AlignHCenter
          text: Weather.failed || root.entry && root.entry.failed ? "Couldn't reach the weather service. It will try again shortly." : "Checking the weather…"
          color: Theme.brightForeground
          font.pixelSize: Theme.fontLarge
        }

        // -------------------------------------------------- alerts
        Repeater {
          model: root.alerts
          Rectangle {
            id: alertCard
            required property var modelData
            required property int index
            readonly property color tone: modelData.severity === "Extreme" || modelData.severity === "Severe" ? Theme.red
              : modelData.severity === "Moderate" ? root.orange : Theme.yellow
            readonly property bool expanded: root.openAlert === index
            Layout.fillWidth: true
            implicitHeight: alertCol.implicitHeight + 20
            radius: Theme.controlRadius
            color: Theme.alpha(Theme.background, 0.8)
            border.width: 1; border.color: Theme.alpha(tone, 0.7)
            Rectangle { width: 3; height: parent.height; color: alertCard.tone }
            ColumnLayout {
              id: alertCol
              x: 16; y: 10
              width: parent.width - 28
              spacing: 4
              RowLayout {
                Layout.fillWidth: true
                Label { text: Icons.glyph(0xF0026); color: alertCard.tone }
                Label { text: alertCard.modelData.event; color: alertCard.tone; font.bold: true }
                Label {
                  Layout.fillWidth: true
                  text: alertCard.modelData.expires ? "until " + Qt.formatDateTime(new Date(alertCard.modelData.ends || alertCard.modelData.expires), "ddd h:mm AP") : ""
                  color: Theme.dim; font.pixelSize: Theme.fontSmall
                }
                Label { text: alertCard.expanded ? Icons.chevronDown : Icons.chevronRight; color: Theme.dim }
              }
              Label {
                Layout.fillWidth: true
                text: alertCard.modelData.headline || ""
                wrapMode: Text.WordWrap; elide: Text.ElideNone
                color: Theme.foreground
              }
              Label {
                visible: alertCard.expanded
                Layout.fillWidth: true
                text: ((alertCard.modelData.description || "") + (alertCard.modelData.instruction ? "\n\n" + alertCard.modelData.instruction : "")).replace(/\n(?!\n)/g, " ")
                wrapMode: Text.WordWrap; elide: Text.ElideNone
                color: Theme.dim; font.pixelSize: Theme.fontSmall
              }
            }
            MouseArea { anchors.fill: parent; onClicked: root.openAlert = alertCard.expanded ? -1 : alertCard.index }
          }
        }

        // -------------------------------------------------- hero + radar
        RowLayout {
          visible: !!root.c
          Layout.fillWidth: true
          spacing: 14

          Item {
            Layout.preferredWidth: page.width * 0.38
            Layout.fillHeight: true
            implicitHeight: 400

            ColumnLayout {
              id: hero
              anchors.left: parent.left; anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Label {
                text: Weather.shown ? Weather.shown.name : ""
                font.pixelSize: 26
                color: "#ffffff"; style: Text.Raised; styleColor: "#55000000"
                Layout.fillWidth: true
              }
              Label {
                text: Weather.shown ? [Weather.shown.region, Weather.shown.country].filter(s => !!s).join(", ") : ""
                color: Theme.alpha("#ffffff", 0.7)
                Layout.fillWidth: true
              }
              Label {
                text: root.c ? Lib.deg(root.c.temperature_2m) : ""
                font.pixelSize: 108
                font.weight: Font.Light
                color: "#ffffff"; style: Text.Raised; styleColor: "#55000000"
                Layout.topMargin: 6
              }
              RowLayout {
                spacing: 8
                Label { text: root.c ? Lib.glyph(root.c.weather_code, root.c.is_day === 1) : ""; font.pixelSize: 26; color: "#ffffff"; style: Text.Raised; styleColor: "#55000000" }
                Label { text: root.c ? Lib.describe(root.c.weather_code) : ""; font.pixelSize: 20; color: "#ffffff"; style: Text.Raised; styleColor: "#55000000" }
              }
              Label {
                Layout.topMargin: 4
                text: root.c ? "Feels like " + Lib.deg(root.c.apparent_temperature) + "   H " + Lib.deg(root.daily("temperature_2m_max", root.di)) + "   L " + Lib.deg(root.daily("temperature_2m_min", root.di)) : ""
                color: Theme.alpha("#ffffff", 0.85)
                font.pixelSize: Theme.fontLarge
              }
              Label {
                Layout.topMargin: 14
                Layout.fillWidth: true
                text: Lib.summary(root.f, root.imperial)
                color: "#ffffff"; style: Text.Raised; styleColor: "#55000000"
                font.pixelSize: Theme.fontLarge
                wrapMode: Text.WordWrap; elide: Text.ElideNone
              }
            }
          }

          Card {
            title: "Radar"
            glyph: 0xF0437
            Layout.fillWidth: true
            Layout.preferredHeight: 400
            Radar {
              Layout.fillWidth: true
              Layout.preferredHeight: 352
              latitude: Weather.shown ? Weather.shown.latitude : 0
              longitude: Weather.shown ? Weather.shown.longitude : 0
              running: root.open
            }
          }
        }

        // -------------------------------------------------- next 24 hours
        Card {
          visible: !!root.c
          title: "Next 24 hours"
          glyph: 0xF0150
          Layout.fillWidth: true
          Row {
            id: strip
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            readonly property var times: root.hours("time", 25)
            Repeater {
              model: strip.times.length
              Column {
                required property int index
                readonly property int at: root.hi + index
                width: strip.width / Math.max(1, strip.times.length)
                spacing: 6
                Label {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: parent.index === 0 ? "Now" : Lib.hourLabel(strip.times[parent.index])
                  color: parent.index === 0 ? Theme.brightForeground : Theme.dim
                  font.pixelSize: Theme.fontSmall
                }
                Label {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Lib.glyph(root.f.hourly.weather_code[parent.at], root.f.hourly.is_day[parent.at] === 1)
                  font.pixelSize: 18
                  color: Theme.brightForeground
                }
                Label {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Lib.deg(parent.index === 0 ? root.c.temperature_2m : root.f.hourly.temperature_2m[parent.at])
                  color: Theme.foreground
                }
                Label {
                  anchors.horizontalCenter: parent.horizontalCenter
                  readonly property int p: root.f.hourly.precipitation_probability[parent.at] || 0
                  text: p >= 10 ? p + "%" : " "
                  color: root.cyan
                  font.pixelSize: Theme.fontSmall
                }
              }
            }
          }
        }

        // -------------------------------------------------- 48-hour chart
        Card {
          visible: !!root.c
          title: "Next 48 hours"
          glyph: 0xF012A
          Layout.fillWidth: true

          Row {
            spacing: 4
            Repeater {
              model: [
                { id: "temp", label: "Temperature" }, { id: "precip", label: "Rain & snow" }, { id: "wind", label: "Wind" },
                { id: "humidity", label: "Humidity" }, { id: "pressure", label: "Pressure" }, { id: "cloud", label: "Clouds" },
                { id: "uv", label: "UV" }
              ]
              Rectangle {
                required property var modelData
                readonly property bool on: root.chart === modelData.id
                implicitWidth: tabLabel.implicitWidth + 18
                implicitHeight: 24
                radius: Theme.controlRadius
                color: on ? Theme.alpha(Theme.accent, 0.2) : tabMouse.containsMouse ? Theme.hover : "transparent"
                border.width: on ? 1 : 0; border.color: Theme.alpha(Theme.accent, 0.5)
                Label { id: tabLabel; anchors.centerIn: parent; text: parent.modelData.label; color: parent.on ? Theme.accent : Theme.foreground; font.pixelSize: Theme.fontSmall }
                MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.chart = parent.modelData.id }
              }
            }
          }

          Chart {
            Layout.fillWidth: true
            Layout.preferredHeight: 230
            times: root.hours("time", 49)
            unit: root.chart === "temp" ? "°" : root.chart === "humidity" || root.chart === "cloud" ? "%" : root.chart === "wind" ? "" : ""
            decimals: root.chart === "pressure" && root.imperial ? 2 : 0
            fixedMin: root.chart === "humidity" || root.chart === "cloud" || root.chart === "uv" || root.chart === "wind" ? 0 : null
            fixedMax: root.chart === "humidity" || root.chart === "cloud" ? 100 : root.chart === "uv" ? 11 : null
            series: {
              var h = n => root.hours(n, 49)
              if (root.chart === "temp") return [
                { label: "Temperature", values: h("temperature_2m"), color: Theme.accent, fill: true },
                { label: "Feels like", values: h("apparent_temperature"), color: root.orange, dashed: true },
                { label: "Dew point", values: h("dew_point_2m"), color: root.cyan, dashed: true }]
              if (root.chart === "precip") return [
                { label: "Amount", values: h("precipitation"), color: root.blue, fill: true }]
              if (root.chart === "wind") return [
                { label: "Wind " + Lib.speedUnit(root.imperial), values: h("wind_speed_10m"), color: Theme.accent, fill: true },
                { label: "Gusts", values: h("wind_gusts_10m"), color: root.orange, dashed: true }]
              if (root.chart === "humidity") return [
                { label: "Humidity", values: h("relative_humidity_2m"), color: root.cyan, fill: true }]
              if (root.chart === "pressure") return [
                { label: "Pressure", values: h("pressure_msl").map(v => root.imperial ? v * 0.02953 : v), color: root.magenta, fill: true }]
              if (root.chart === "cloud") return [
                { label: "Cloud cover", values: h("cloud_cover"), color: Theme.foreground, fill: true }]
              return [{ label: "UV index", values: h("uv_index"), color: Theme.yellow, fill: true }]
            }
            bars: root.chart === "precip" || root.chart === "temp"
              ? { label: "Chance", values: root.hours("precipitation_probability", 49), color: root.blue, max: 100, suffix: "%" } : null
          }
          Label {
            Layout.fillWidth: true
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: ({
              temp: "Solid: air temperature. Dashed orange: what it feels like with wind and humidity. Dashed blue: dew point, which sets how muggy it feels. Bars: chance of rain or snow.",
              precip: "Line: how much falls each hour (" + (root.imperial ? "inches" : "mm") + "). Bars: the chance of any falling that hour.",
              wind: "Sustained wind at 10 m above ground, and gusts: the short bursts you actually feel.",
              humidity: "Relative humidity: how close the air is to saturated. High overnight is normal; the dew point says more about comfort.",
              pressure: "Air pressure at sea level (" + (root.imperial ? "inHg" : "hPa") + "). Falling usually brings clouds and rain; rising brings clearer, calmer weather.",
              cloud: "Share of the sky covered by cloud at any height.",
              uv: "Sunburn strength. 3+ means sunscreen; 8+ means burns in about 15 minutes."
            })[root.chart]
          }
        }

        // -------------------------------------------------- 10 days | air + sky
        RowLayout {
          visible: !!root.c
          Layout.fillWidth: true
          spacing: 14

          Card {
            id: tenDay
            title: "10-day forecast"
            glyph: 0xF00F0
            Layout.preferredWidth: page.width * 0.52
            Layout.alignment: Qt.AlignTop
            readonly property var idx: {
              if (!root.f) return []
              var out = []
              for (var i = root.di; i < root.f.daily.time.length; i++) out.push(i)
              return out
            }
            readonly property real lo: { var m = Infinity; for (var i = 0; i < idx.length; i++) m = Math.min(m, root.f.daily.temperature_2m_min[idx[i]]); return m }
            readonly property real hiT: { var m = -Infinity; for (var i = 0; i < idx.length; i++) m = Math.max(m, root.f.daily.temperature_2m_max[idx[i]]); return m }

            Repeater {
              model: tenDay.idx
              RowLayout {
                id: dayRow
                required property var modelData
                required property int index
                readonly property int i: modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 10
                Label { Layout.preferredWidth: 46; text: dayRow.index === 0 ? "Today" : Lib.dayName(root.f.daily.time[dayRow.i], true); color: dayRow.index === 0 ? Theme.brightForeground : Theme.foreground }
                Label { Layout.preferredWidth: 22; text: Lib.glyph(root.f.daily.weather_code[dayRow.i], true); font.pixelSize: 17; color: Theme.brightForeground; horizontalAlignment: Text.AlignHCenter }
                Label {
                  Layout.preferredWidth: 36
                  readonly property int p: root.f.daily.precipitation_probability_max[dayRow.i] || 0
                  text: p >= 10 ? p + "%" : ""
                  color: root.cyan; font.pixelSize: Theme.fontSmall
                }
                Label { Layout.preferredWidth: 34; text: Lib.deg(root.f.daily.temperature_2m_min[dayRow.i]); color: Theme.dim; horizontalAlignment: Text.AlignRight }
                // Range bar against the whole 10 days.
                Item {
                  Layout.fillWidth: true
                  implicitHeight: 6
                  readonly property real span: Math.max(1, tenDay.hiT - tenDay.lo)
                  readonly property real a: (root.f.daily.temperature_2m_min[dayRow.i] - tenDay.lo) / span
                  readonly property real b: (root.f.daily.temperature_2m_max[dayRow.i] - tenDay.lo) / span
                  Rectangle { anchors.fill: parent; radius: 3; color: Theme.alpha(Theme.foreground, 0.1) }
                  Rectangle {
                    x: parent.a * parent.width
                    width: Math.max(6, (parent.b - parent.a) * parent.width)
                    height: parent.height; radius: 3
                    gradient: Gradient {
                      orientation: Gradient.Horizontal
                      GradientStop { position: 0; color: root.cyan }
                      GradientStop { position: 1; color: root.orange }
                    }
                  }
                  Rectangle {
                    visible: dayRow.index === 0
                    x: (root.c.temperature_2m - tenDay.lo) / parent.span * parent.width - 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: Theme.brightForeground
                    border.width: 2; border.color: Theme.background
                  }
                }
                Label { Layout.preferredWidth: 34; text: Lib.deg(root.f.daily.temperature_2m_max[dayRow.i]); color: Theme.brightForeground }
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 14

            // Air quality.
            Card {
              id: airCard
              title: "Air quality"
              glyph: 0xF0D43
              Layout.fillWidth: true
              readonly property var level: root.air ? Lib.aqiLevel(root.air.us_aqi) : null
              RowLayout {
                visible: !!root.air
                spacing: 12
                Label { text: root.air ? Math.round(root.air.us_aqi) : ""; font.pixelSize: 30; color: Theme.brightForeground }
                ColumnLayout {
                  spacing: 0
                  Label { text: airCard.level ? airCard.level.word : ""; color: Theme.brightForeground }
                  Label { text: "US AQI"; color: Theme.dim; font.pixelSize: Theme.fontSmall }
                }
              }
              Meter {
                visible: !!root.air
                Layout.fillWidth: true
                position: root.air ? Math.min(1, root.air.us_aqi / 300) : 0
              }
              Label {
                visible: !!root.air
                Layout.fillWidth: true
                text: root.air ? Lib.aqiLevel(root.air.us_aqi).note : ""
                color: Theme.dim; font.pixelSize: Theme.fontSmall
                wrapMode: Text.WordWrap; elide: Text.ElideNone
              }
              GridLayout {
                visible: !!root.air
                Layout.fillWidth: true
                Layout.topMargin: 4
                columns: 3
                columnSpacing: 12; rowSpacing: 4
                Repeater {
                  model: [
                    { k: "pm2_5", n: "PM2.5", tip: "fine smoke/dust" },
                    { k: "pm10", n: "PM10", tip: "dust, pollen" },
                    { k: "ozone", n: "Ozone", tip: "sunny-day smog" },
                    { k: "nitrogen_dioxide", n: "NO₂", tip: "traffic" },
                    { k: "sulphur_dioxide", n: "SO₂", tip: "industry" },
                    { k: "carbon_monoxide", n: "CO", tip: "combustion" }
                  ]
                  ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: modelData.n + "  " + (root.air && root.air[modelData.k] !== null ? Math.round(root.air[modelData.k]) : "–"); color: Theme.foreground; font.pixelSize: Theme.fontSmall }
                    Label { text: modelData.tip + " · µg/m³"; color: Theme.dim; font.pixelSize: 10 }
                  }
                }
              }
              Label {
                readonly property var pollen: {
                  if (!root.air) return []
                  var names = { alder_pollen: "Alder", birch_pollen: "Birch", grass_pollen: "Grass", mugwort_pollen: "Mugwort", olive_pollen: "Olive", ragweed_pollen: "Ragweed" }
                  var out = []
                  for (var k in names) if (root.air[k] !== null && root.air[k] !== undefined) out.push(names[k] + " " + Math.round(root.air[k]))
                  return out
                }
                visible: pollen.length > 0
                Layout.fillWidth: true
                text: "Pollen (grains/m³): " + pollen.join(" · ")
                color: Theme.dim; font.pixelSize: Theme.fontSmall
                wrapMode: Text.WordWrap; elide: Text.ElideNone
              }
              Label {
                visible: !root.air
                text: "Air quality not available here yet."
                color: Theme.dim
              }
            }

            // Sun and moon.
            Card {
              id: skyCard
              title: "Sun & moon"
              glyph: 0xF059C
              Layout.fillWidth: true
              readonly property string rise: root.f ? root.f.daily.sunrise[root.di] : ""
              readonly property string set: root.f ? root.f.daily.sunset[root.di] : ""
              readonly property var moon: Lib.moon(new Date(root.now))

              // Sun's path today with where it is now.
              Canvas {
                id: arc
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                readonly property real progress: {
                  if (!root.c) return 0
                  var t = Lib.parse(root.c.time).getTime(), a = Lib.parse(skyCard.rise).getTime(), b = Lib.parse(skyCard.set).getTime()
                  return (t - a) / Math.max(1, b - a)
                }
                onProgressChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                  var ctx = getContext("2d")
                  ctx.reset()
                  var w = width, h = height, base = h - 8
                  ctx.strokeStyle = "rgba(255,255,255,0.12)"
                  ctx.lineWidth = 1
                  ctx.beginPath(); ctx.moveTo(0, base + 0.5); ctx.lineTo(w, base + 0.5); ctx.stroke()
                  ctx.setLineDash([3, 3])
                  ctx.strokeStyle = "rgba(255,255,255,0.3)"
                  ctx.beginPath()
                  for (var i = 0; i <= 60; i++) {
                    var p = i / 60, x = 20 + p * (w - 40), y = base - Math.sin(p * Math.PI) * (h - 18)
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                  }
                  ctx.stroke()
                  ctx.setLineDash([])
                  var q = Math.max(0, Math.min(1, progress))
                  if (progress > 0 && progress < 1) {
                    var sx = 20 + q * (w - 40), sy = base - Math.sin(q * Math.PI) * (h - 18)
                    ctx.fillStyle = "rgba(255,214,120,0.25)"
                    ctx.beginPath(); ctx.arc(sx, sy, 11, 0, Math.PI * 2); ctx.fill()
                    ctx.fillStyle = "#ffd678"
                    ctx.beginPath(); ctx.arc(sx, sy, 5, 0, Math.PI * 2); ctx.fill()
                  }
                }
              }
              RowLayout {
                Layout.fillWidth: true
                Label { text: Icons.glyph(0xF059C) + " " + Lib.clock(skyCard.rise); color: Theme.foreground }
                Item { Layout.fillWidth: true }
                Label {
                  text: root.f ? Lib.duration(root.daily("daylight_duration", root.di)) + " of daylight" : ""
                  color: Theme.dim; font.pixelSize: Theme.fontSmall
                }
                Item { Layout.fillWidth: true }
                Label { text: Lib.clock(skyCard.set) + " " + Icons.glyph(0xF059B); color: Theme.foreground }
              }
              Label {
                Layout.fillWidth: true
                text: root.daylightDelta === 0 ? "" : (root.daylightDelta > 0 ? "Days are getting longer: " : "Days are getting shorter: ")
                  + Math.round(Math.abs(root.daylightDelta) / 60) + " min " + (root.daylightDelta > 0 ? "more" : "less") + " than yesterday. "
                  + (root.f ? "About " + Lib.duration(root.daily("sunshine_duration", root.di)) + " of actual sunshine expected." : "")
                color: Theme.dim; font.pixelSize: Theme.fontSmall
                wrapMode: Text.WordWrap; elide: Text.ElideNone
              }
              Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.separator; Layout.topMargin: 4; Layout.bottomMargin: 4 }
              RowLayout {
                spacing: 12
                Label { text: Icons.glyph(skyCard.moon.glyph); font.pixelSize: 30; color: Theme.brightForeground }
                ColumnLayout {
                  spacing: 0
                  Label { text: skyCard.moon.name; color: Theme.brightForeground }
                  Label {
                    text: Math.round(skyCard.moon.illumination * 100) + "% lit · " + (skyCard.moon.name === "Full moon" ? "full now" : "full in " + Math.round(skyCard.moon.daysToFull) + " days")
                    color: Theme.dim; font.pixelSize: Theme.fontSmall
                  }
                }
              }
            }
          }
        }

        // -------------------------------------------------- details
        Label {
          visible: !!root.c
          text: "CONDITIONS IN DETAIL"
          color: Theme.alpha("#ffffff", 0.75)
          font.pixelSize: Theme.fontSmall
          font.letterSpacing: 0.8
          Layout.topMargin: 4
        }
        GridLayout {
          visible: !!root.c
          Layout.fillWidth: true
          columns: page.width > 1050 ? 4 : 3
          columnSpacing: 14
          rowSpacing: 14

          Tile {
            title: "Feels like"; glyph: 0xF050F
            value: root.c ? Lib.deg(root.c.apparent_temperature) : ""
            detail: root.c ? "Actual " + Lib.deg(root.c.temperature_2m) : ""
            note: root.c ? Lib.feelsNote(root.c.temperature_2m, root.c.apparent_temperature, root.imperial, root.c.relative_humidity_2m) : ""
          }
          Tile {
            id: windTile
            title: "Wind"; glyph: 0xF059D
            readonly property var bf: root.c ? Lib.beaufort(root.c.wind_speed_10m, root.imperial) : null
            value: root.c ? Math.round(root.c.wind_speed_10m) + " " + Lib.speedUnit(root.imperial) : ""
            detail: root.c ? "Gusts " + Math.round(root.c.wind_gusts_10m) + " · from the " + Lib.compassWords(root.c.wind_direction_10m) : ""
            note: bf ? bf.word + " (Beaufort " + bf.force + "): " + bf.note.toLowerCase() + "." : ""
            // Arrow points where the wind is going.
            corner: Item {
              width: 56; height: 56
              Rectangle { anchors.fill: parent; radius: 28; color: "transparent"; border.width: 1; border.color: Theme.alpha(Theme.foreground, 0.2) }
              Label { anchors.horizontalCenter: parent.horizontalCenter; y: 1; text: "N"; font.pixelSize: 9; color: Theme.dim }
              Canvas {
                anchors.fill: parent
                rotation: root.c ? root.c.wind_direction_10m + 180 : 0
                onPaint: {
                  var ctx = getContext("2d")
                  ctx.reset()
                  var q = Qt.color(Theme.accent)
                  ctx.fillStyle = ctx.strokeStyle = "rgb(" + Math.round(q.r * 255) + "," + Math.round(q.g * 255) + "," + Math.round(q.b * 255) + ")"
                  ctx.lineWidth = 2
                  ctx.beginPath(); ctx.moveTo(28, 40); ctx.lineTo(28, 20); ctx.stroke()
                  ctx.beginPath(); ctx.moveTo(28, 11); ctx.lineTo(34, 22); ctx.lineTo(22, 22); ctx.closePath(); ctx.fill()
                }
              }
            }
          }
          Tile {
            title: "Humidity"; glyph: 0xF058E
            value: root.c ? Math.round(root.c.relative_humidity_2m) + "%" : ""
            detail: root.c ? "Dew point " + Lib.deg(root.c.dew_point_2m) : ""
            note: root.c ? "Relative humidity is how full of moisture the air is for its temperature. Comfort: " + Lib.dewComfort(root.c.dew_point_2m, root.imperial).word.toLowerCase() + "." : ""
          }
          Tile {
            title: "Dew point"; glyph: 0xF058C
            readonly property var comfort: root.c ? Lib.dewComfort(root.c.dew_point_2m, root.imperial) : null
            value: root.c ? Lib.deg(root.c.dew_point_2m) : ""
            detail: comfort ? comfort.word : ""
            note: comfort ? comfort.note + " The temperature air must cool to for dew or fog to form." : ""
          }
          Tile {
            title: "Pressure"; glyph: 0xF029A
            readonly property var trend: Lib.pressureTrend(root.pressureDelta)
            value: root.c ? Lib.pressure(root.c.pressure_msl, root.imperial) : ""
            detail: trend.word + " (" + (root.pressureDelta >= 0 ? "+" : "") + root.pressureDelta.toFixed(1) + " hPa in 3 h)"
            note: trend.note + " 1013 hPa (29.92 inHg) is average."
          }
          Tile {
            title: "Visibility"; glyph: 0xF0208
            readonly property var vis: root.c ? Lib.visibilityWord(root.c.visibility, root.imperial) : null
            value: root.c ? Lib.distance(root.c.visibility, root.imperial) : ""
            detail: vis ? vis.word : ""
            note: vis ? vis.note : ""
          }
          Tile {
            title: "UV index"; glyph: 0xF0599
            readonly property var lvl: root.c ? Lib.uvLevel(root.c.uv_index) : null
            value: root.c ? root.c.uv_index.toFixed(1) + "  " + lvl.word : ""
            detail: "Today's peak " + (root.f ? root.daily("uv_index_max", root.di).toFixed(1) : "–") + (root.uvWindow ? " · protect " + root.uvWindow : "")
            note: lvl ? lvl.note : ""
            Meter { position: root.c ? root.c.uv_index / 11 : 0 }
          }
          Tile {
            id: cloudTile
            title: "Cloud layers"; glyph: 0xF0163
            value: root.c ? Math.round(root.c.cloud_cover) + "%" : ""
            note: root.c ? Lib.cloudNote(root.c.cloud_cover_low, root.c.cloud_cover_mid, root.c.cloud_cover_high) : ""
            Column {
              Layout.fillWidth: true
              spacing: 3
              Repeater {
                model: [{ k: "cloud_cover_high", n: "High" }, { k: "cloud_cover_mid", n: "Mid" }, { k: "cloud_cover_low", n: "Low" }]
                Row {
                  required property var modelData
                  spacing: 6
                  Label { width: 32; text: modelData.n; color: Theme.dim; font.pixelSize: 10 }
                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: cloudTile.width - 24 - 32 - 6 - 40; height: 4; radius: 2
                    color: Theme.alpha(Theme.foreground, 0.1)
                    Rectangle { width: parent.width * (root.c ? root.c[modelData.k] / 100 : 0); height: parent.height; radius: 2; color: Theme.foreground }
                  }
                  Label { text: root.c ? Math.round(root.c[modelData.k]) + "%" : ""; color: Theme.dim; font.pixelSize: 10 }
                }
              }
            }
          }
          Tile {
            title: "Precipitation"; glyph: 0xF054A
            readonly property real next24: root.sum(root.hours("precipitation", 24))
            readonly property int chance: root.max(root.hours("precipitation_probability", 24))
            value: root.c ? Lib.precip(next24, root.imperial) : ""
            detail: "next 24 h · " + chance + "% peak chance"
            note: root.c && root.c.precipitation > 0 ? Lib.precip(root.c.precipitation, root.imperial) + " fell in the last 15 minutes."
              : root.f && root.daily("precipitation_sum", root.di) > 0 ? "Today total " + Lib.precip(root.daily("precipitation_sum", root.di), root.imperial) + " over about " + Math.max(1, Math.round(root.daily("precipitation_hours", root.di))) + " h."
              : "No rain or snow expected today."
          }
          Tile {
            id: capeTile
            title: "Storm energy (CAPE)"; glyph: 0xF0593
            readonly property real peak: root.max(root.hours("cape", 24))
            readonly property var lvl: Lib.capeLevel(Math.max(root.c ? root.c.cape : 0, peak))
            value: root.c ? Math.round(root.c.cape) + " J/kg" : ""
            detail: "Peak next 24 h " + Math.round(peak) + " · " + lvl.word
            note: lvl.note + " It's the energy rising air can tap to build storms."
            Meter { position: Math.min(1, Math.max(root.c ? root.c.cape : 0, capeTile.peak) / 4000) }
          }
          Tile {
            title: "Snow line"; glyph: 0xF0717
            value: root.c ? Lib.height(root.c.freezing_level_height, root.imperial) : ""
            detail: "Freezing level above ground"
            note: root.c ? Lib.snowLineNote(root.c.freezing_level_height, root.c.temperature_2m, root.imperial) : ""
          }
          Tile {
            title: "Today"; glyph: 0xF00F0
            value: root.f ? Lib.deg(root.daily("temperature_2m_max", root.di)) + " / " + Lib.deg(root.daily("temperature_2m_min", root.di)) : ""
            detail: root.f ? "Feels " + Lib.deg(root.daily("apparent_temperature_max", root.di)) + " / " + Lib.deg(root.daily("apparent_temperature_min", root.di)) : ""
            note: root.f ? "Strongest gust " + Math.round(root.daily("wind_gusts_10m_max", root.di)) + " " + Lib.speedUnit(root.imperial)
              + ", mostly from the " + Lib.compassWords(root.daily("wind_direction_10m_dominant", root.di)) + "."
              + (root.c && root.c.snow_depth > 0 ? " Snow on the ground: " + Lib.height(root.c.snow_depth, root.imperial) + "." : "") : ""
          }
        }

        Label {
          visible: !!root.c
          Layout.fillWidth: true
          Layout.topMargin: 6
          horizontalAlignment: Text.AlignHCenter
          text: "Forecast and air quality: Open-Meteo" + (Weather.isUS(Weather.shown) ? " · Alerts: National Weather Service" : "") + " · Radar: RainViewer"
          color: Theme.alpha("#ffffff", 0.55)
          font.pixelSize: 10
        }
      }
    }

    Scrollbar {
      flickable: flick
      anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
      anchors.margins: 4
    }

    // Search results under the field.
    Rectangle {
      visible: root.adding && Weather.results.length > 0
      x: searchField.mapToItem(flick.contentItem, 0, 0).x
      y: searchField.mapToItem(flick.contentItem, 0, 0).y + 34 - flick.contentY
      width: 360
      height: results.implicitHeight + 8
      radius: Theme.controlRadius
      color: Theme.alpha(Theme.background, 0.97)
      border.width: 1; border.color: Theme.alpha(Theme.foreground, 0.12)
      z: 10
      Column {
        id: results
        x: 4; y: 4
        width: parent.width - 8
        Repeater {
          model: Weather.results
          Rectangle {
            required property var modelData
            width: results.width
            height: 40
            radius: Theme.controlRadius
            color: resMouse.containsMouse ? Theme.hover : "transparent"
            Column {
              anchors.verticalCenter: parent.verticalCenter
              x: 10
              Label { text: modelData.name; color: Theme.brightForeground }
              Label { text: [modelData.region, modelData.country].filter(s => !!s).join(", "); color: Theme.dim; font.pixelSize: Theme.fontSmall }
            }
            MouseArea {
              id: resMouse; anchors.fill: parent; hoverEnabled: true
              onClicked: { Weather.addPlace(modelData); root.adding = false }
            }
          }
        }
      }
    }
      }
  }
}
