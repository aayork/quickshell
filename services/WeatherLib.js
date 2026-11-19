.pragma library

// Weather helpers shared by services/Weather.qml and the weather window:
// WMO codes to words and glyphs, and every technical number paired with a
// plain-English reading. All values arrive in the units the forecast was
// asked for (imperial: °F, mph, inch, ft; metric: °C, km/h, mm, m).

// ------------------------------------------------------------ conditions
function describe(code) {
  if (code === 0) return "Clear"
  if (code === 1) return "Mostly clear"
  if (code === 2) return "Partly cloudy"
  if (code === 3) return "Overcast"
  if (code === 45) return "Fog"
  if (code === 48) return "Freezing fog"
  if (code === 51) return "Light drizzle"
  if (code === 53) return "Drizzle"
  if (code === 55) return "Heavy drizzle"
  if (code === 56 || code === 57) return "Freezing drizzle"
  if (code === 61) return "Light rain"
  if (code === 63) return "Rain"
  if (code === 65) return "Heavy rain"
  if (code === 66 || code === 67) return "Freezing rain"
  if (code === 71) return "Light snow"
  if (code === 73) return "Snow"
  if (code === 75) return "Heavy snow"
  if (code === 77) return "Snow grains"
  if (code === 80) return "Light showers"
  if (code === 81) return "Showers"
  if (code === 82) return "Heavy showers"
  if (code === 85 || code === 86) return "Snow showers"
  if (code === 95) return "Thunderstorm"
  if (code === 96 || code === 99) return "Thunderstorm with hail"
  return "Unknown"
}

// Material Design glyph codepoints (checked against nerd-fonts glyphnames).
function glyphCode(code, day) {
  if (code === 0 || code === 1) return day ? 0xF0599 : 0xF0594
  if (code === 2) return day ? 0xF0595 : 0xF0F31
  if (code === 3) return 0xF0590
  if (code === 45 || code === 48) return 0xF0591
  if (code === 56 || code === 57 || code === 66 || code === 67) return 0xF067F
  if (code === 75 || code === 86) return 0xF0F36
  if (code >= 71 && code <= 77 || code === 85) return 0xF0598
  if (code >= 95) return code === 95 ? 0xF0593 : 0xF067E
  if (code === 65 || code === 82) return 0xF0596
  return 0xF0597
}

function glyph(code, day) { return String.fromCodePoint(glyphCode(code, day)) }

// What the animated sky should show.
function kind(code) {
  if (code === 0 || code === 1) return "clear"
  if (code === 2) return "partly"
  if (code === 3) return "cloudy"
  if (code === 45 || code === 48) return "fog"
  if (code >= 95) return "storm"
  if (code >= 71 && code <= 77 || code === 85 || code === 86) return "snow"
  if (code >= 51 && code <= 57) return "drizzle"
  return "rain"
}

// 0..1, how hard it is coming down.
function intensity(code) {
  if ([51, 61, 71, 80, 85, 56, 66].indexOf(code) >= 0) return 0.35
  if ([53, 63, 73, 81, 95, 77].indexOf(code) >= 0) return 0.65
  if ([55, 65, 75, 82, 86, 96, 99, 57, 67].indexOf(code) >= 0) return 1
  return 0
}

function isWet(code) { return code >= 51 }

// ------------------------------------------------------------ time
// "2026-11-19T07:34" (already local to the place) → Date with those fields.
function parse(iso) {
  var m = /^(\d+)-(\d+)-(\d+)(?:T(\d+):(\d+))?/.exec(iso || "")
  if (!m) return new Date(NaN)
  return new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0))
}

function clock(iso) {
  var d = parse(iso)
  var h = d.getHours(), m = d.getMinutes()
  return (h % 12 || 12) + ":" + (m < 10 ? "0" : "") + m + (h < 12 ? " AM" : " PM")
}

function hourLabel(iso) {
  var h = parse(iso).getHours()
  return (h % 12 || 12) + (h < 12 ? "a" : "p")
}

function hourLong(iso) {
  var h = parse(iso).getHours()
  if (h === 0) return "midnight"
  if (h === 12) return "noon"
  return (h % 12 || 12) + (h < 12 ? " AM" : " PM")
}

var dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
function dayName(iso, short) {
  var n = dayNames[parse(iso).getDay()] || ""
  return short ? n.slice(0, 3) : n
}

function duration(seconds) {
  var m = Math.round(Math.abs(seconds) / 60)
  return Math.floor(m / 60) + "h " + (m % 60) + "m"
}

// Index of the current hour in hourly.time, and of today in daily.time.
function hourIndex(f) {
  if (!f || !f.hourly || !f.current) return 0
  var key = f.current.time.slice(0, 13) + ":00"
  var i = f.hourly.time.indexOf(key)
  return i < 0 ? 0 : i
}

function dayIndex(f) {
  if (!f || !f.daily || !f.current) return 0
  var i = f.daily.time.indexOf(f.current.time.slice(0, 10))
  return i < 0 ? 0 : i
}

// ------------------------------------------------------------ units
function deg(v) { return v === null || v === undefined || isNaN(v) ? "–" : Math.round(v) + "°" }

function speedUnit(imperial) { return imperial ? "mph" : "km/h" }

function precip(v, imperial) {
  if (v === null || v === undefined) return "–"
  if (imperial) return (v < 0.01 && v > 0 ? "<0.01" : v.toFixed(2)) + " in"
  return (v < 0.1 && v > 0 ? "<0.1" : v.toFixed(1)) + " mm"
}

// Visibility comes in ft (imperial) or m.
function distance(v, imperial) {
  if (v === null || v === undefined) return "–"
  if (imperial) {
    var mi = v / 5280
    return (mi >= 10 ? Math.round(mi) : mi.toFixed(1)) + " mi"
  }
  var km = v / 1000
  return (km >= 10 ? Math.round(km) : km.toFixed(1)) + " km"
}

function height(v, imperial) {
  if (v === null || v === undefined) return "–"
  return Math.round(v / (imperial ? 100 : 10)) * (imperial ? 100 : 10) + (imperial ? " ft" : " m")
}

function pressure(hpa, imperial) {
  return imperial ? (hpa * 0.02953).toFixed(2) + " inHg" : Math.round(hpa) + " hPa"
}

// ------------------------------------------------------------ readings
var points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
var pointNames = { N: "north", S: "south", E: "east", W: "west" }
function compass(degrees) { return points[Math.round(((degrees % 360) + 360) % 360 / 22.5) % 16] }
function compassWords(degrees) {
  var c = compass(degrees)
  return c.split("").map(function(ch) { return pointNames[ch] }).join("-").replace("north-north", "north").replace("south-south", "south")
}

// Beaufort scale from mph or km/h.
function beaufort(speed, imperial) {
  var mph = imperial ? speed : speed / 1.609
  var scale = [[1, "Calm", "Smoke rises straight up"], [4, "Light air", "Barely noticeable"],
    [8, "Light breeze", "Felt on the face, leaves rustle"], [13, "Gentle breeze", "Leaves and twigs in constant motion"],
    [19, "Moderate breeze", "Raises dust and loose paper"], [25, "Fresh breeze", "Small trees sway"],
    [32, "Strong breeze", "Umbrellas hard to use"], [39, "Near gale", "Whole trees move; walking is harder"],
    [47, "Gale", "Twigs break off trees"], [55, "Strong gale", "Light structural damage possible"],
    [64, "Storm", "Trees uprooted"], [73, "Violent storm", "Widespread damage"], [9999, "Hurricane force", "Devastating"]]
  for (var i = 0; i < scale.length; i++)
    if (mph < scale[i][0]) return { force: i, word: scale[i][1], note: scale[i][2] }
  return { force: 12, word: "Hurricane force", note: "Devastating" }
}

function feelsNote(temp, feels, imperial, humidity) {
  var d = feels - temp
  var big = imperial ? 3 : 2
  if (d <= -big) return "Wind makes it feel colder than it is."
  if (d >= big) return humidity >= 50 ? "Humidity makes it feel warmer than it is." : "Sun and still air make it feel warmer."
  return "Close to the actual temperature."
}

// Dew point: the best single measure of how muggy it feels.
function dewComfort(dew, imperial) {
  var f = imperial ? dew : dew * 9 / 5 + 32
  if (f < 40) return { word: "Very dry", note: "Dry air; skin and lips may feel it." }
  if (f < 55) return { word: "Comfortable", note: "Pleasant, not humid." }
  if (f < 60) return { word: "Slightly humid", note: "Noticeable but fine." }
  if (f < 65) return { word: "Sticky", note: "Starting to feel humid." }
  if (f < 70) return { word: "Muggy", note: "Uncomfortable for most people." }
  return { word: "Oppressive", note: "Very humid; sweat won't evaporate." }
}

function uvLevel(uv) {
  if (uv < 3) return { word: "Low", level: 0, note: "No protection needed." }
  if (uv < 6) return { word: "Moderate", level: 1, note: "Sunscreen if you're out for a while." }
  if (uv < 8) return { word: "High", level: 2, note: "Burns in ~25 min; use sunscreen and shade." }
  if (uv < 11) return { word: "Very high", level: 3, note: "Burns in ~15 min; avoid midday sun." }
  return { word: "Extreme", level: 4, note: "Burns in minutes; stay in the shade." }
}

function aqiLevel(aqi) {
  if (aqi <= 50) return { word: "Good", level: 0, note: "Air is clean." }
  if (aqi <= 100) return { word: "Moderate", level: 1, note: "Fine for most; very sensitive people may notice it." }
  if (aqi <= 150) return { word: "Unhealthy for sensitive groups", level: 2, note: "Asthma or heart conditions: take it easy outside." }
  if (aqi <= 200) return { word: "Unhealthy", level: 3, note: "Everyone may feel effects; limit long exertion outdoors." }
  if (aqi <= 300) return { word: "Very unhealthy", level: 4, note: "Health alert; stay inside if you can." }
  return { word: "Hazardous", level: 5, note: "Emergency conditions." }
}

// CAPE: energy available to rising air, i.e. thunderstorm fuel.
function capeLevel(cape) {
  if (cape < 100) return { word: "Stable", level: 0, note: "No fuel for thunderstorms." }
  if (cape < 1000) return { word: "Marginal", level: 1, note: "Weak storms possible if something sets them off." }
  if (cape < 2500) return { word: "Moderate", level: 2, note: "Enough fuel for real thunderstorms." }
  if (cape < 4000) return { word: "High", level: 3, note: "Strong storms possible; watch for alerts." }
  return { word: "Extreme", level: 4, note: "Severe storms possible." }
}

// Change in hPa over the last three hours.
function pressureTrend(delta) {
  if (delta <= -3) return { word: "Falling fast", arrow: 0xF0533, note: "Unsettled weather likely on the way." }
  if (delta <= -1) return { word: "Falling", arrow: 0xF0533, note: "Clouds or rain becoming more likely." }
  if (delta >= 3) return { word: "Rising fast", arrow: 0xF0535, note: "Clearing, often with wind." }
  if (delta >= 1) return { word: "Rising", arrow: 0xF0535, note: "Weather settling or improving." }
  return { word: "Steady", arrow: 0xF0534, note: "No big change expected soon." }
}

function visibilityWord(v, imperial) {
  var km = imperial ? v / 3281 : v / 1000
  if (km >= 20) return { word: "Excellent", note: "Very clear air." }
  if (km >= 10) return { word: "Good", note: "Clear view into the distance." }
  if (km >= 4) return { word: "Moderate", note: "A little haze or precipitation." }
  if (km >= 1) return { word: "Poor", note: "Mist, rain or haze cutting the view." }
  return { word: "Very poor", note: "Fog; drive with care." }
}

function cloudNote(low, mid, high) {
  if (low >= 60) return "Low clouds: grey, overcast sky."
  if (mid >= 60) return "Mid-level clouds: a dull, layered sky."
  if (high >= 60) return "High clouds only: thin wisps, sun still gets through."
  if (low + mid + high < 30) return "Hardly any cloud at any height."
  return "Scattered clouds at several heights."
}

function snowLineNote(level, temp, imperial) {
  var cold = imperial ? temp <= 36 : temp <= 2
  var low = imperial ? level < 1500 : level < 450
  if (low && cold) return "Close to the ground: anything falling could be snow or sleet."
  if (low) return "Freezing air not far overhead."
  return "Where rain would turn to snow higher up."
}

// ------------------------------------------------------------ moon
// Age in days since the 2000-01-06 18:14 UTC new moon.
function moon(date) {
  var synodic = 29.530588853
  var age = ((date.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000) % synodic
  if (age < 0) age += synodic
  var illumination = (1 - Math.cos(2 * Math.PI * age / synodic)) / 2
  var phases = [[1.84, "New moon", 0xF0F64], [5.53, "Waxing crescent", 0xF0F67], [9.22, "First quarter", 0xF0F61],
    [12.91, "Waxing gibbous", 0xF0F68], [16.61, "Full moon", 0xF0F62], [20.30, "Waning gibbous", 0xF0F66],
    [23.99, "Last quarter", 0xF0F63], [27.68, "Waning crescent", 0xF0F65], [99, "New moon", 0xF0F64]]
  for (var i = 0; i < phases.length; i++)
    if (age < phases[i][0]) {
      var toFull = (14.77 - age + synodic) % synodic
      return { name: phases[i][1], glyph: phases[i][2], illumination: illumination, age: age, daysToFull: toFull }
    }
}

// ------------------------------------------------------------ summary
// One plain sentence for the next 12 hours.
function summary(f, imperial) {
  if (!f || !f.hourly) return ""
  var h = f.hourly, now = hourIndex(f)
  var end = Math.min(h.time.length, now + 12)
  var wetNow = isWet(f.current.weather_code)
  var parts = []

  if (wetNow) {
    var stop = -1
    for (var i = now + 1; i < end; i++) if (!isWet(h.weather_code[i]) && h.precipitation_probability[i] < 40) { stop = i; break }
    parts.push(describe(f.current.weather_code) + (stop >= 0 ? " easing around " + hourLong(h.time[stop]) : " for the next several hours"))
  } else {
    var start = -1
    for (var j = now + 1; j < end; j++) if (h.precipitation_probability[j] >= 50 && isWet(h.weather_code[j])) { start = j; break }
    if (start >= 0) parts.push(describe(h.weather_code[start]) + " likely from around " + hourLong(h.time[start]))
    else {
      var maxP = 0
      for (var k = now; k < end; k++) maxP = Math.max(maxP, h.precipitation_probability[k] || 0)
      parts.push(maxP >= 25 ? "A chance of " + (f.current.temperature_2m <= (imperial ? 34 : 1) ? "snow" : "rain") + " later (" + maxP + "%)" : "Dry for the next 12 hours")
    }
  }

  var t0 = h.temperature_2m[now], tMax = t0, tMin = t0
  for (var m = now; m < end; m++) { tMax = Math.max(tMax, h.temperature_2m[m]); tMin = Math.min(tMin, h.temperature_2m[m]) }
  var swing = imperial ? 6 : 3
  if (tMax - t0 >= swing) parts.push("warming to " + deg(tMax))
  else if (t0 - tMin >= swing) parts.push("cooling to " + deg(tMin))

  var gust = 0
  for (var n = now; n < end; n++) gust = Math.max(gust, h.wind_gusts_10m[n] || 0)
  if (gust >= (imperial ? 30 : 50)) parts.push("gusts up to " + Math.round(gust) + " " + speedUnit(imperial))

  return parts.join(", ") + "."
}
