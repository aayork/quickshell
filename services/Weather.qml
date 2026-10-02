pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Current conditions and a short forecast from Open-Meteo. The place is the
// saved one if there is one, otherwise wherever wttr.in says this IP is.
Singleton {
  id: root

  readonly property string savedFile: Theme.stateDir + "/settings/weather.json"
  readonly property int staleMs: 15 * 60 * 1000

  // { name, latitude, longitude, country }
  property var place: null
  property var forecast: null
  property double fetchedAt: 0
  property bool failed: false
  readonly property bool loading: locate.running || fetch.running
  readonly property bool imperial: place !== null && /united states/i.test(place.country || "") || Qt.locale().measurementSystem === Locale.ImperialUSSystem
  readonly property bool ready: forecast !== null && forecast.current !== undefined

  readonly property string placeName: place ? place.name : ""
  readonly property string temperature: ready ? degrees(forecast.current.temperature_2m) : ""
  readonly property string condition: ready ? describe(forecast.current.weather_code) : ""
  readonly property string icon: ready ? glyph(forecast.current.weather_code, forecast.current.is_day === 1) : ""
  // [{ day, icon, high, low }], today first.
  readonly property var days: {
    if (!ready || !forecast.daily) return []
    var daily = forecast.daily
    var list = []
    for (var i = 0; i < daily.time.length; i++) {
      list.push({
        day: i === 0 ? "Today" : Qt.formatDate(new Date(daily.time[i] + "T12:00:00"), "ddd"),
        icon: glyph(daily.weather_code[i], true),
        high: degrees(daily.temperature_2m_max[i]),
        low: degrees(daily.temperature_2m_min[i])
      })
    }
    return list
  }

  function degrees(value) {
    return Math.round(value) + "°"
  }

  // WMO weather codes.
  function describe(code) {
    if (code === 0) return "Clear"
    if (code === 1) return "Mostly clear"
    if (code === 2) return "Partly cloudy"
    if (code === 3) return "Overcast"
    if (code === 45 || code === 48) return "Fog"
    if (code >= 51 && code <= 57) return "Drizzle"
    if (code >= 61 && code <= 67) return "Rain"
    if (code >= 71 && code <= 77) return "Snow"
    if (code >= 80 && code <= 82) return "Showers"
    if (code === 85 || code === 86) return "Snow showers"
    if (code >= 95) return "Thunderstorm"
    return "Unknown"
  }

  function glyph(code, day) {
    if (code === 0 || code === 1) return Icons.glyph(day ? 0xF0599 : 0xF0594)
    if (code === 2) return Icons.glyph(day ? 0xF0595 : 0xF0F31)
    if (code === 3) return Icons.glyph(0xF0590)
    if (code === 45 || code === 48) return Icons.glyph(0xF0591)
    if (code >= 71 && code <= 77 || code === 85 || code === 86) return Icons.glyph(0xF0598)
    if (code >= 95) return Icons.glyph(0xF0593)
    if (code >= 80 && code <= 82) return Icons.glyph(0xF0596)
    return Icons.glyph(0xF0597)
  }

  // Fetches unless what is here is still fresh.
  function refresh() {
    if (loading || (forecast !== null && Date.now() - fetchedAt < staleMs)) return
    if (place) fetchForecast()
    else locate.running = true
  }

  function fetchForecast() {
    fetch.command = ["curl", "-fsS", "--max-time", "8",
      "https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude
      + "&current=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min"
      + "&timezone=auto&forecast_days=7" + (imperial ? "&temperature_unit=fahrenheit" : "")]
    fetch.running = true
  }

  FileView {
    path: root.savedFile
    printErrors: false
    onLoaded: {
      try {
        var saved = JSON.parse(text())
        if (typeof saved.latitude === "number" && typeof saved.longitude === "number")
          root.place = { name: String(saved.name || ""), latitude: saved.latitude, longitude: saved.longitude, country: "" }
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
            latitude: Number(area.latitude),
            longitude: Number(area.longitude),
            country: area.country[0].value
          }
          root.fetchForecast()
        } catch (e) {
          root.failed = true
        }
      }
    }
  }

  Process {
    id: fetch
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.forecast = JSON.parse(text)
          root.fetchedAt = Date.now()
          root.failed = false
        } catch (e) {
          root.failed = true
        }
      }
    }
  }
}
