pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import "WeatherLib.js" as Lib

// Weather for the bar, the clock popup and the weather window.
//
// Home is the saved place (settings/weather.json) or wherever wttr.in says
// this IP is; more places live in settings/weather-places.json. For each
// place it keeps an Open-Meteo forecast (current, 10 days hourly + daily,
// plus yesterday for trends), Open-Meteo air quality, and NWS alerts for US
// places. Radar frames come from RainViewer. Home refreshes every 10 min so
// the bar stays current; the window refreshes what it shows while open.
Singleton {
  id: root

  readonly property string savedFile: Theme.stateDir + "/settings/weather.json"
  readonly property string placesFile: Theme.stateDir + "/settings/weather-places.json"
  readonly property int staleMs: 10 * 60 * 1000
  readonly property var agent: ["-A", "aayork-quickshell-weather"]

  // { name, region, country, country_code, latitude, longitude }
  property var place: null
  property var places: []
  property string selectedKey: ""
  // key → { forecast, air, alerts, fetchedAt, airAt, alertsAt, failed }
  property var store: ({})
  property bool locateFailed: false

  // ---------------------------------------------------------------- window
  property bool windowOpen: false
  signal windowRequested(bool show)
  function toggleWindow() { windowRequested(!windowOpen) }
  function openWindow() { windowRequested(true) }

  // ---------------------------------------------------------------- places
  function key(p) { return p ? Number(p.latitude).toFixed(3) + "," + Number(p.longitude).toFixed(3) : "" }
  readonly property string homeKey: key(place)
  readonly property var allPlaces: place ? [place].concat(places) : places
  readonly property var shown: {
    for (var i = 0; i < allPlaces.length; i++) if (key(allPlaces[i]) === selectedKey) return allPlaces[i]
    return place
  }
  readonly property string shownKey: key(shown)
  readonly property var shownEntry: store[shownKey] || null
  readonly property bool shownIsHome: shownKey === homeKey

  function isUS(p) { return !!p && (p.country_code === "US" || /united states/i.test(p.country || "")) }

  function select(k) {
    selectedKey = k === homeKey ? "" : k
    refreshPlace(shown)
  }

  function addPlace(p) {
    var k = key(p)
    if (k === homeKey || places.some(x => key(x) === k)) { select(k); return }
    places = places.concat([p])
    placesView.setText(JSON.stringify(places, null, 2))
    select(k)
  }

  function removePlace(k) {
    places = places.filter(x => key(x) !== k)
    placesView.setText(JSON.stringify(places, null, 2))
    if (selectedKey === k) selectedKey = ""
  }

  // ---------------------------------------------------------------- home (bar, clock popup)
  readonly property var forecast: (store[homeKey] || {}).forecast || null
  readonly property bool imperial: place !== null && isUS(place) || Qt.locale().measurementSystem === Locale.ImperialUSSystem
  readonly property bool ready: forecast !== null && forecast.current !== undefined
  readonly property bool failed: locateFailed || !ready && !!(store[homeKey] || {}).failed
  readonly property bool loading: locate.running || runner.running || queue.length > 0
  readonly property double fetchedAt: (store[homeKey] || {}).fetchedAt || 0

  readonly property string placeName: place ? place.name : ""
  readonly property string temperature: ready ? Lib.deg(forecast.current.temperature_2m) : ""
  readonly property string condition: ready ? Lib.describe(forecast.current.weather_code) : ""
  readonly property string icon: ready ? Lib.glyph(forecast.current.weather_code, forecast.current.is_day === 1) : ""
  // [{ day, icon, high, low }], today first.
  readonly property var days: {
    if (!ready || !forecast.daily) return []
    var daily = forecast.daily
    var list = []
    for (var i = Lib.dayIndex(forecast); i < daily.time.length && list.length < 7; i++) {
      list.push({
        day: list.length === 0 ? "Today" : Lib.dayName(daily.time[i], true),
        icon: Lib.glyph(daily.weather_code[i], true),
        high: Lib.deg(daily.temperature_2m_max[i]),
        low: Lib.deg(daily.temperature_2m_min[i])
      })
    }
    return list
  }

  function degrees(value) { return Lib.deg(value) }
  function describe(code) { return Lib.describe(code) }
  function glyph(code, day) { return Lib.glyph(code, day) }

  // ---------------------------------------------------------------- fetching
  // Home, unless what is here is still fresh.
  function refresh() {
    if (!place) { if (!locate.running) locate.running = true; return }
    refreshPlace(place)
  }

  function refreshPlace(p, force) {
    if (!p) return
    var k = key(p), e = store[k] || {}, now = Date.now()
    if (force || !e.forecast || now - (e.fetchedAt || 0) > staleMs) enqueue({ id: k + ":forecast", key: k, kind: "forecast", command: forecastCommand(p) })
    if (force || now - (e.airAt || 0) > staleMs * 3) enqueue({ id: k + ":air", key: k, kind: "air", command: airCommand(p) })
    if (isUS(p) && (force || now - (e.alertsAt || 0) > staleMs)) enqueue({ id: k + ":alerts", key: k, kind: "alerts", command: alertsCommand(p) })
  }

  function forecastCommand(p) {
    var imp = imperial
    return ["curl", "-fsS", "--max-time", "10",
      "https://api.open-meteo.com/v1/forecast?latitude=" + p.latitude + "&longitude=" + p.longitude
      + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,weather_code,is_day,"
      + "cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,pressure_msl,surface_pressure,"
      + "wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,snowfall,visibility,uv_index,cape,"
      + "freezing_level_height,snow_depth"
      + "&hourly=temperature_2m,apparent_temperature,weather_code,precipitation_probability,precipitation,is_day,"
      + "relative_humidity_2m,dew_point_2m,wind_speed_10m,wind_gusts_10m,wind_direction_10m,pressure_msl,"
      + "cloud_cover,uv_index,visibility,cape"
      + "&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,"
      + "sunrise,sunset,daylight_duration,sunshine_duration,precipitation_sum,precipitation_hours,"
      + "precipitation_probability_max,uv_index_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant"
      + "&timezone=auto&past_days=1&forecast_days=10"
      + (imp ? "&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch" : "")]
  }

  function airCommand(p) {
    return ["curl", "-fsS", "--max-time", "10",
      "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=" + p.latitude + "&longitude=" + p.longitude
      + "&current=us_aqi,pm2_5,pm10,ozone,nitrogen_dioxide,sulphur_dioxide,carbon_monoxide,"
      + "alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"
      + "&hourly=us_aqi&timezone=auto&forecast_days=2"]
  }

  function alertsCommand(p) {
    return ["curl", "-fsS", "--max-time", "10"].concat(agent).concat(["-H", "Accept: application/geo+json",
      "https://api.weather.gov/alerts/active?point=" + Number(p.latitude).toFixed(4) + "," + Number(p.longitude).toFixed(4)])
  }

  function put(k, fields) {
    var s = Object.assign({}, store)
    s[k] = Object.assign({}, s[k] || {}, fields)
    store = s
  }

  // One request at a time.
  property var queue: []
  function enqueue(job) {
    if (queue.some(j => j.id === job.id) || runner.running && runner.job && runner.job.id === job.id) return
    queue = queue.concat([job])
    pump()
  }
  function pump() {
    if (runner.running || queue.length === 0) return
    var job = queue[0]
    queue = queue.slice(1)
    runner.job = job
    runner.handled = false
    runner.command = job.command
    runner.running = true
  }

  function finish(job, text) {
    var now = Date.now()
    try {
      var data = JSON.parse(text)
      if (job.kind === "forecast") {
        if (!data.current) throw "no current"
        put(job.key, { forecast: data, fetchedAt: now, failed: false })
      } else if (job.kind === "air") {
        put(job.key, { air: data.current ? data : null, airAt: now })
      } else if (job.kind === "alerts") {
        put(job.key, { alerts: (data.features || []).map(f => f.properties), alertsAt: now })
      }
    } catch (e) {
      fail(job)
    }
  }

  function fail(job) {
    var now = Date.now()
    if (job.kind === "forecast") put(job.key, { failed: true, fetchedAt: (store[job.key] || {}).forecast ? (store[job.key].fetchedAt || 0) : 0 })
    // Try air and alerts again later rather than hammering them.
    else if (job.kind === "air") put(job.key, { airAt: now - staleMs * 2 })
    else put(job.key, { alertsAt: now - staleMs / 2 })
  }

  Process {
    id: runner
    property var job: null
    property bool handled: false
    stdout: StdioCollector {
      onStreamFinished: {
        if (runner.handled || !runner.job) return
        runner.handled = true
        root.finish(runner.job, text)
      }
    }
    onExited: settle.restart()
  }
  // Exit can arrive before the output is read; give it a beat, then count
  // an unread job as failed and move on.
  Timer {
    id: settle
    interval: 60
    onTriggered: {
      if (runner.job && !runner.handled) { runner.handled = true; root.fail(runner.job) }
      root.pump()
    }
  }

  // ---------------------------------------------------------------- radar
  property string radarHost: ""
  property var radarFrames: []
  property double radarAt: 0
  function refreshRadar() {
    if (radarProc.running || Date.now() - radarAt < 5 * 60 * 1000) return
    radarProc.running = true
  }
  Process {
    id: radarProc
    command: ["curl", "-fsS", "--max-time", "10", "https://api.rainviewer.com/public/weather-maps.json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.radarHost = data.host
          root.radarFrames = (data.radar.past || []).concat(data.radar.nowcast || [])
          root.radarAt = Date.now()
        } catch (e) {}
      }
    }
  }

  // ---------------------------------------------------------------- search
  property var results: []
  property string searchText: ""
  function search(text) {
    searchText = text.trim()
    if (searchText.length < 2) { results = []; return }
    searchDelay.restart()
  }
  Timer {
    id: searchDelay
    interval: 300
    onTriggered: {
      if (searcher.running) { restart(); return }
      searcher.command = ["curl", "-fsS", "--max-time", "8", "-G", "https://geocoding-api.open-meteo.com/v1/search",
        "--data-urlencode", "name=" + root.searchText, "-d", "count=8", "-d", "language=en"]
      searcher.running = true
    }
  }
  Process {
    id: searcher
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.results = (JSON.parse(text).results || []).map(r => ({
            name: r.name, region: r.admin1 || "", country: r.country || "", country_code: r.country_code || "",
            latitude: r.latitude, longitude: r.longitude
          }))
        } catch (e) { root.results = [] }
      }
    }
  }

  // ---------------------------------------------------------------- startup
  FileView {
    path: root.savedFile
    printErrors: false
    onLoaded: {
      try {
        var saved = JSON.parse(text())
        if (typeof saved.latitude === "number" && typeof saved.longitude === "number")
          root.place = { name: String(saved.name || ""), region: String(saved.region || ""), country: String(saved.country || ""),
                         country_code: String(saved.country_code || ""), latitude: saved.latitude, longitude: saved.longitude }
      } catch (e) {}
    }
  }

  FileView {
    id: placesView
    path: root.placesFile
    printErrors: false
    onLoaded: {
      try {
        var list = JSON.parse(text())
        if (Array.isArray(list)) root.places = list.filter(p => typeof p.latitude === "number" && typeof p.longitude === "number")
      } catch (e) {}
    }
  }

  Process {
    id: locate
    command: ["curl", "-fsS", "--max-time", "8", "https://wttr.in/?format=j1"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var area = JSON.parse(text).nearest_area[0]
          root.place = {
            name: area.areaName[0].value,
            region: area.region[0].value,
            country: area.country[0].value,
            country_code: "",
            latitude: Number(area.latitude),
            longitude: Number(area.longitude)
          }
          root.locateFailed = false
          root.refreshPlace(root.place)
        } catch (e) {
          root.locateFailed = true
        }
      }
    }
  }

  // Keep home fresh for the bar; give the saved place a moment to load first.
  Timer {
    interval: root.staleMs
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.refresh()
  }
  Timer {
    interval: 1500
    running: true
    onTriggered: root.refresh()
  }
  // Retry sooner after a failure (offline at login, say).
  Timer {
    interval: 2 * 60 * 1000
    running: root.failed
    repeat: true
    onTriggered: { root.locateFailed = false; root.refreshPlace(root.place, true); if (!root.place) root.refresh() }
  }
  // While the window is up, keep what it shows and the radar current.
  Timer {
    interval: 60 * 1000
    running: root.windowOpen
    repeat: true
    triggeredOnStart: true
    onTriggered: { root.refreshPlace(root.shown); root.refreshRadar() }
  }
}
