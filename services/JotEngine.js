.pragma library

// Jot's text logic, without any UI: note keywords, timer commands, links and
// the math engine (contextual sums, variables, units, currency). Ported from
// the GTK Jot's mathengine.py. QML's JavaScript has no regex lookbehind or
// named groups (they fail silently), so none are used here.

// ------------------------------------------------------------------ keywords

var DEFAULT_KEYWORDS = {
  math: "math, calc, calcs",
  list: "list, todo",
  sum: "sum, total",
  avg: "avg, average",
  count: "count",
  timer: "timer",
  stopwatch: "stopwatch",
  pomodoro: "pomodoro, pomo"
}

var KEYWORDS = {}      // word -> feature
var TIMER_WORDS = {}   // feature -> [words]
var headerRe = /^$/

function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\\/]/g, "\\$&") }

function alternation(words) {
  return words.slice().sort((a, b) => b.length - a.length).map(escapeRe).join("|")
}

function words(list) {
  return String(list).split(",").map(w => w.trim().toLowerCase()).filter(w => w !== "")
}

// cfg: { feature: "word, word" }; missing features keep their defaults.
function setKeywords(cfg) {
  KEYWORDS = {}
  TIMER_WORDS = {}
  for (var canon in DEFAULT_KEYWORDS) {
    var list = words(cfg && cfg[canon] !== undefined && String(cfg[canon]).trim() !== "" ? cfg[canon] : DEFAULT_KEYWORDS[canon])
    if (list.length === 0) list = [canon]
    if (canon === "timer" || canon === "stopwatch" || canon === "pomodoro") TIMER_WORDS[canon] = list
    else for (var i = 0; i < list.length; i++) if (!(list[i] in KEYWORDS)) KEYWORDS[list[i]] = canon
  }
  headerRe = new RegExp("^(\\s*)(" + alternation(Object.keys(KEYWORDS)) + ")\\s*(:.*)?$", "i")
}
setKeywords({})

// The keyword line: { feature, start, end, colon } or null.
function header(line) {
  var m = headerRe.exec(line)
  if (!m) return null
  var start = m[1].length
  var end = start + m[2].length
  var colon = m[3] !== undefined ? line.length - m[3].length : -1
  return { feature: KEYWORDS[m[2].toLowerCase()], start: start, end: end, colon: colon }
}

function modeOf(text) {
  var h = header(String(text).split("\n", 1)[0])
  return h ? h.feature : ""
}

// ------------------------------------------------------------------ timers

// "5m", "1h30m", "90s", "1:30", "25" (minutes). Seconds, or 0.
function parseDuration(s) {
  s = String(s).trim().toLowerCase().replace(/ /g, "")
  if (/^\d+(:\d{1,2}){1,2}$/.test(s)) return s.split(":").reduce((acc, p) => acc * 60 + Number(p), 0)
  var re = /(\d+(?:\.\d+)?)([hms]?)/g
  var total = 0, matched = false, m
  while ((m = re.exec(s)) !== null) {
    matched = true
    total += Number(m[1]) * ({ h: 3600, m: 60, s: 1, "": 60 })[m[2]]
  }
  if (!matched || s.replace(/\d+(?:\.\d+)?[hms]?/g, "") !== "") return 0
  return Math.round(total)
}

// A timer command on its own line: {kind: "stop"|"stopwatch"|"countdown"|"pomodoro", ...} or null.
function parseTimer(line) {
  var s = String(line).trim().toLowerCase()
  if (s === "") return null
  var all = alternation(TIMER_WORDS.timer.concat(TIMER_WORDS.stopwatch, TIMER_WORDS.pomodoro))
  if (new RegExp("^(?:(?:" + all + ")\\s+stop|stop\\s+(?:" + all + "))$").test(s)) return { kind: "stop" }
  if (TIMER_WORDS.stopwatch.indexOf(s) !== -1 || TIMER_WORDS.timer.indexOf(s) !== -1) return { kind: "stopwatch" }
  var m = new RegExp("^(?:" + alternation(TIMER_WORDS.timer) + ")\\s+([\\d:.hms ]+)$").exec(s)
  if (m) {
    var secs = parseDuration(m[1])
    return secs ? { kind: "countdown", seconds: secs } : null
  }
  m = new RegExp("^(?:" + alternation(TIMER_WORDS.pomodoro) + ")(?:\\s+(\\d+)\\s*/\\s*(\\d+))?$").exec(s)
  if (m) return { kind: "pomodoro", work: Number(m[1] || 25), rest: Number(m[2] || 5) }
  return null
}

function formatSeconds(secs) {
  var h = Math.floor(secs / 3600), m = Math.floor(secs % 3600 / 60), s = secs % 60
  return ((h ? h + "h" : "") + (m ? m + "m" : "") + (s ? s + "s" : "")) || "0s"
}

// ------------------------------------------------------------------ links

var URL_RE = /https?:\/\/[^\s<>"']+[^\s<>"'.,;:!?)\]]/g
var TOKEN_RE = /\+[^\s+]+\/\.\.\.[^\s+]*\+/g

// A long link as a short token, as Antinote writes them: +host/...tail+
function shortenUrl(url) {
  var m = /^https?:\/\/([^\/?#]+)([^#]*)/.exec(url)
  if (!m) return url
  var rest = m[2].replace(/\/+$/, "")
  var tail = rest.slice(-6).replace(/^\/+/, "")
  return tail ? "+" + m[1] + "/..." + tail + "+" : "+" + m[1] + "/...+"
}

function expandLinks(text, links) {
  return String(text).replace(TOKEN_RE, t => links && links[t] !== undefined ? links[t] : t)
}

// [start, end] spans of links and link tokens in one line.
function linkSpans(line) {
  var spans = []
  ;[URL_RE, TOKEN_RE].forEach(function(re) {
    re.lastIndex = 0
    var m
    while ((m = re.exec(line)) !== null) spans.push([m.index, m.index + m[0].length])
  })
  return spans
}

// ------------------------------------------------------------------ units

var UNIT_TABLE = {
  length: [
    ["mm millimeter millimeters millimetre millimetres", 0.001],
    ["cm centimeter centimeters centimetre centimetres", 0.01],
    ["m meter meters metre metres", 1],
    ["km kilometer kilometers kilometre kilometres", 1000],
    ["in inch inches", 0.0254],
    ["ft foot feet", 0.3048],
    ["yd yard yards", 0.9144],
    ["mi mile miles", 1609.344],
    ["nmi", 1852]
  ],
  mass: [
    ["mg milligram milligrams", 0.001],
    ["g gram grams", 1],
    ["kg kilogram kilograms kilo kilos", 1000],
    ["oz ounce ounces", 28.349523125],
    ["lb lbs pound pounds", 453.59237],
    ["st stone stones", 6350.29318],
    ["t tonne tonnes", 1e6]
  ],
  volume: [
    ["ml milliliter milliliters millilitre millilitres", 0.001],
    ["cl", 0.01],
    ["dl", 0.1],
    ["l liter liters litre litres", 1],
    ["tsp teaspoon teaspoons", 0.00492892159375],
    ["tbsp tablespoon tablespoons", 0.01478676478125],
    ["fl oz|floz|fluid ounce|fluid ounces", 0.0295735295625],
    ["cup cups", 0.2365882365],
    ["pt pint pints", 0.473176473],
    ["qt quart quarts", 0.946352946],
    ["gal gallon gallons", 3.785411784]
  ],
  time: [
    ["ms millisecond milliseconds", 0.001],
    ["s sec secs second seconds", 1],
    ["min mins minute minutes", 60],
    ["h hr hrs hour hours", 3600],
    ["day days", 86400],
    ["wk week weeks", 604800],
    ["yr year years", 31557600]
  ],
  data: [
    ["bit bits", 0.125],
    ["b byte bytes", 1],
    ["kb", 1e3], ["mb", 1e6], ["gb", 1e9], ["tb", 1e12],
    ["kib", 1024], ["mib", Math.pow(1024, 2)], ["gib", Math.pow(1024, 3)], ["tib", Math.pow(1024, 4)]
  ],
  speed: [
    ["m/s mps", 1],
    ["km/h kmh kph", 1 / 3.6],
    ["mph", 0.44704],
    ["kn knot knots", 0.514444]
  ],
  area: [
    ["m2|m²|sqm|sq m", 1],
    ["km2 km²", 1e6],
    ["ft2|ft²|sqft|sq ft", 0.09290304],
    ["acre acres", 4046.8564224],
    ["ha hectare hectares", 10000]
  ],
  temperature: [
    ["c °c celsius", null],
    ["f °f fahrenheit", null],
    ["k kelvin", null]
  ]
}

var UNITS = {}   // alias -> { dim, factor, canon }
;(function() {
  for (var dim in UNIT_TABLE) {
    UNIT_TABLE[dim].forEach(function(row) {
      var aliases = row[0].indexOf("|") !== -1 ? row[0].split("|") : row[0].split(" ")
      aliases.forEach(a => UNITS[a] = { dim: dim, factor: row[1], canon: aliases[0] })
    })
  }
})()

var UNIT_ALT = alternation(Object.keys(UNITS))
// "<expr> <unit> to <unit>". The character before the first unit must not be
// a letter or slash, so "trees to km" does not read as "tree" + "s".
var CONVERT_RE = new RegExp("^(.*?[^A-Za-z/]|)\\s*(" + UNIT_ALT + ")\\s+(?:to|in|as|into|->|→)\\s+(" + UNIT_ALT + ")\\s*$", "i")

function toBase(value, u) {
  if (u.dim !== "temperature") return value * u.factor
  if (u.canon === "c") return value + 273.15
  if (u.canon === "f") return (value - 32) * 5 / 9 + 273.15
  return value
}

function fromBase(value, u) {
  if (u.dim !== "temperature") return value / u.factor
  if (u.canon === "c") return value - 273.15
  if (u.canon === "f") return (value - 273.15) * 9 / 5 + 32
  return value
}

function unitLabel(typed) {
  var t = typed.trim(), low = t.toLowerCase()
  if (low === "l") return "L"
  if (low === "c" || low === "°c") return "°C"
  if (low === "f" || low === "°f") return "°F"
  if (low === "k") return "K"
  return t
}

// ------------------------------------------------------------------ expressions

var FUNCS = {
  sqrt: Math.sqrt, abs: Math.abs, floor: Math.floor, ceil: Math.ceil,
  log: Math.log10, ln: Math.log, sin: Math.sin, cos: Math.cos, tan: Math.tan,
  min: Math.min, max: Math.max,
  // Python's round: halves go to the even neighbour.
  round: function(x, n) {
    var f = Math.pow(10, n || 0), v = x * f, r = Math.round(v)
    if (Math.abs(v % 1) === 0.5 && r % 2 !== 0) r -= 1
    return r / f
  }
}
var CONSTS = { pi: Math.PI, "π": Math.PI, tau: 2 * Math.PI }
var KEEP_WORDS = { pi: 1, tau: 1 }
for (var fname in FUNCS) KEEP_WORDS[fname] = 1

var NUM = "\\d+(?:\\.\\d+)?|\\.\\d+"
var WORDCHAR = /[A-Za-z0-9_'’À-￿]/

function tokenize(src) {
  var tokens = [], rest = src, m
  var re = /^\s*(\d+(?:\.\d+)?|\.\d+|\*\*|\/\/|[-+*\/%(),]|[A-Za-z_π][A-Za-z0-9_]*)/
  while (!/^\s*$/.test(rest)) {
    m = re.exec(rest)
    if (!m) throw new Error("bad token")
    tokens.push(m[1])
    rest = rest.slice(m[0].length)
  }
  return tokens
}

// A small parser with Python's precedence: unary minus binds looser than **.
function parse(src, names) {
  var tokens = tokenize(src), pos = 0
  function peek() { return tokens[pos] }
  function take(t) { if (tokens[pos] !== t) throw new Error("expected " + t); pos++ }

  function expr() {
    var v = term()
    while (peek() === "+" || peek() === "-") {
      var op = tokens[pos++], r = term()
      v = op === "+" ? v + r : v - r
    }
    return v
  }
  function term() {
    var v = unary()
    while (peek() === "*" || peek() === "/" || peek() === "//" || peek() === "%") {
      var op = tokens[pos++], r = unary()
      if ((op === "/" || op === "//" || op === "%") && r === 0) throw new Error("division by zero")
      if (op === "*") v = v * r
      else if (op === "/") v = v / r
      else if (op === "//") v = Math.floor(v / r)
      else v = v - r * Math.floor(v / r)
    }
    return v
  }
  function unary() {
    if (peek() === "-") { pos++; return -unary() }
    if (peek() === "+") { pos++; return unary() }
    return power()
  }
  function power() {
    var base = atom()
    if (peek() === "**") {
      pos++
      var exp = unary()
      if (Math.abs(exp) > 1000) throw new Error("exponent too large")
      return Math.pow(base, exp)
    }
    return base
  }
  function atom() {
    var t = tokens[pos++]
    if (t === undefined) throw new Error("unexpected end")
    if (t === "(") { var v = expr(); take(")"); return v }
    if (/^(\d|\.)/.test(t)) return Number(t)
    if (/^[A-Za-z_π]/.test(t)) {
      if (peek() === "(" && FUNCS[t]) {
        pos++
        var args = []
        if (peek() !== ")") {
          args.push(expr())
          while (peek() === ",") { pos++; args.push(expr()) }
        }
        take(")")
        return FUNCS[t].apply(null, args)
      }
      if (names[t] !== undefined) return names[t]
      if (CONSTS[t] !== undefined) return CONSTS[t]
      throw new Error("unknown name " + t)
    }
    throw new Error("unexpected " + t)
  }

  var value = expr()
  if (pos !== tokens.length) throw new Error("trailing input")
  return value
}

// Where `name` appears in `text` as a whole word, ignoring case.
function findWord(text, name) {
  var out = [], low = text.toLowerCase(), key = name.toLowerCase(), from = 0, at
  if (key === "") return out
  while ((at = low.indexOf(key, from)) !== -1) {
    var before = at > 0 ? text[at - 1] : ""
    var after = text[at + key.length] || ""
    if (!(before && WORDCHAR.test(before)) && !(after && WORDCHAR.test(after))) out.push([at, at + key.length])
    from = at + 1
  }
  return out
}

// Turn a contextual expression into plain arithmetic.
// Returns { src, names, refs, pctTail } or null when there is nothing to compute.
function prepare(expr, variables) {
  var names = {}, taken = []
  Object.keys(variables).sort((a, b) => b.length - a.length).forEach(function(name, i) {
    findWord(expr, name).forEach(function(span) {
      if (taken.every(t => span[1] <= t[0] || span[0] >= t[1])) {
        taken.push([span[0], span[1], "V" + i + "_"])
        names["V" + i + "_"] = variables[name]
      }
    })
  })
  taken.sort((a, b) => a[0] - b[0])
  var refs = taken.map(t => [t[0], t[1]])
  var s = expr
  for (var k = taken.length - 1; k >= 0; k--) s = s.slice(0, taken[k][0]) + " " + taken[k][2] + " " + s.slice(taken[k][1])

  s = s.replace(/[$€£¥₹]/g, "")
  s = s.replace(/(\d),(?=\d{3}(?!\d))/g, "$1")
  s = s.replace(/×/g, "*").replace(/·/g, "*").replace(/÷/g, "/").replace(/−/g, "-").replace(/\^/g, "**")
  s = s.replace(/\bdivided by\b/gi, "/")
  s = s.replace(/\b(times|multiplied by)\b/gi, "*")
  s = s.replace(/\bplus\b/gi, "+")
  s = s.replace(/\bminus\b/gi, "-")
  // `x` between two operands is multiplication: "12 beds x 8 plants".
  s = s.replace(/([A-Za-z0-9_)\s])\s*\bx\b\s*(?=[A-Za-z0-9_(\s.$])/gi, "$1 * ")
  s = s.replace(new RegExp("(" + NUM + ")\\s*%\\s*of\\b", "gi"), "($1/100)*")
  s = s.replace(/\bof\b/gi, "*")

  // "a + 15%" adds 15% of a; other percentages are plain fractions.
  var pctTail = null
  var m = new RegExp("^(.*?)([+\\-])\\s*(" + NUM + ")\\s*%\\s*$").exec(s)
  if (m && /[\dV]/.test(m[1])) {
    s = m[1]
    pctTail = { sign: m[2], pct: Number(m[3]) }
  }
  s = s.replace(new RegExp("(" + NUM + ")\\s*%", "g"), "($1/100)")

  // Remaining words are context, not maths.
  s = s.replace(/[A-Za-z_À-￿][A-Za-z0-9_'’À-￿]*/g, function(w) {
    if (/^V\d+_$/.test(w)) return w
    if (KEEP_WORDS[w.toLowerCase()]) return w.toLowerCase()
    if (w === "π") return w
    return " "
  })
  s = s.replace(/[:;?!"“”]/g, " ").trim()
  if (!/\d|V\d+_|pi|tau|π/.test(s)) return null
  // Implicit multiplication: "2(3)", "a b".
  s = s.replace(/(\d|\))\s*\(/g, "$1*(")
  s = s.replace(/(V\d+_|\))\s+(?=\d|V\d+_)/g, "$1*")
  return { src: s, names: names, refs: refs, pctTail: pctTail }
}

// Currency rates per 1 EUR (lower-case codes). Empty: no currency maths.
var RATES = {}
var CURRENCY_SYMBOLS = { "$": "usd", "€": "eur", "£": "gbp", "¥": "jpy", "₹": "inr" }

function setRates(rates) { RATES = rates || {} }

function currency(expr, variables) {
  var codes = Object.keys(RATES)
  if (codes.length === 0) return null
  var alt = alternation(codes)
  var src, dst, inner
  var m = new RegExp("^(.*?)\\s*\\b(" + alt + ")\\s+(?:to|in|as|into|->|→)\\s+(" + alt + ")\\s*$", "i").exec(expr)
  if (m) {
    inner = m[1]; src = m[2].toLowerCase(); dst = m[3].toLowerCase()
  } else {
    var m2 = new RegExp("^\\s*([$€£¥₹])(.*?)\\s+(?:to|in|as|into)\\s+(" + alt + ")\\s*$", "i").exec(expr)
    if (!m2 || !(CURRENCY_SYMBOLS[m2[1]] in RATES)) return null
    src = CURRENCY_SYMBOLS[m2[1]]; inner = m2[2]; dst = m2[3].toLowerCase()
  }
  if (inner.trim() === "") return null
  var r = evaluate(inner, variables)
  if (r === null) return null
  return { value: r.value / RATES[src] * RATES[dst], unit: dst.toUpperCase(), op: false, refs: r.refs }
}

// One contextual expression: { value, unit, op, refs } or null if it is not maths.
function evaluate(expr, variables) {
  variables = variables || {}
  expr = String(expr).trim()
  if (expr === "") return null
  var cur = currency(expr, variables)
  if (cur !== null) return cur

  var conv = CONVERT_RE.exec(expr)
  if (conv && conv[1].trim() !== "") {
    var su = UNITS[conv[2].toLowerCase()], du = UNITS[conv[3].toLowerCase()]
    if (su.dim !== du.dim) return null
    var inner = evaluate(conv[1], variables)
    if (inner === null) return null
    return { value: fromBase(toBase(inner.value, su), du), unit: unitLabel(conv[3]), op: false, refs: inner.refs }
  }

  var p = prepare(expr, variables)
  if (p === null) return null
  var value
  try {
    value = parse(p.src, p.names)
  } catch (e) {
    return null
  }
  if (p.pctTail) value = p.pctTail.sign === "+" ? value * (1 + p.pctTail.pct / 100) : value * (1 - p.pctTail.pct / 100)
  if (typeof value !== "number" || !isFinite(value)) return null
  var op = p.pctTail !== null || /[-+*\/%(]/.test(p.src.replace(/^[-+]+/, ""))
  return { value: value, unit: "", op: op, refs: p.refs }
}

// ------------------------------------------------------------------ formatting

function groupThousands(digits) {
  return digits.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

// Python's "{:.6g}".
function generalFormat(v) {
  var exp = Math.floor(Math.log10(Math.abs(v)))
  if (exp < -4 || exp >= 6) {
    var parts = v.toExponential(5).split("e")
    var mant = parts[0].replace(/\.?0+$/, "")
    var e = Number(parts[1])
    return mant + "e" + (e < 0 ? "-" : "+") + String(Math.abs(e)).padStart(2, "0")
  }
  return v.toPrecision(6).replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "")
}

function formatNumber(v) {
  if (v === 0) return "0.00"
  if (Math.abs(v) >= 1e15 || Math.abs(v) < 0.005) return generalFormat(v)
  var fixed = Math.abs(v).toFixed(2).split(".")
  return (v < 0 ? "-" : "") + groupThousands(fixed[0]) + "." + fixed[1]
}

function fraction(value, denom) {
  denom = denom || 16
  var whole = Math.trunc(value)
  var n = Math.round((value - whole) * denom)
  if (n === denom) { whole += 1; n = 0 }
  if (n === 0) return groupThousands(String(whole))
  var d = denom
  while (n % 2 === 0) { n /= 2; d /= 2 }
  return whole ? groupThousands(String(whole)) + " " + n + "/" + d : n + "/" + d
}

// Inches and feet read like a tape measure: 68 7/8", 2' 6 11/16".
function formatUnit(value, unit) {
  var low = unit.toLowerCase()
  if ((low === "in" || low === "inch" || low === "inches") && Math.abs(value) > 0 && Math.abs(value) < 1e6)
    return fraction(value) + "\""
  if ((low === "ft" || low === "foot" || low === "feet") && Math.abs(value) > 0 && Math.abs(value) < 1e6) {
    var feet = Math.trunc(value), inches = (value - feet) * 12
    if (Math.round(inches * 16) >= 192) { feet += 1; inches = 0 }
    return Math.round(inches * 16) ? feet + "' " + fraction(inches) + "\"" : feet + "'"
  }
  return formatNumber(value) + " " + unit
}

// ------------------------------------------------------------------ math notes

var ASSIGN_RE = /^(\s*)([^:=\d\s][^:=]*?)\s*:\s*(.*)$/

// Read a math note top to bottom; line 0 is the keyword line. Per line:
// { name: [a, b] | null, colon, refs: [[a, b]], result: [a, b] | null,
//   newText: string | null }, plus the variables found.
function analyse(lines) {
  var variables = {}
  var infos = lines.map(() => ({ name: null, colon: -1, refs: [], result: null, newText: null }))
  for (var i = 1; i < lines.length; i++) {
    var line = lines[i], info = infos[i]
    var eq = line.lastIndexOf("=")
    var lhs = eq < 0 ? line : line.slice(0, eq)
    var expr = lhs, offset = 0, name = null
    var m = ASSIGN_RE.exec(lhs)
    if (m && /[A-Za-z_À-￿]/.test(m[2]) && lhs.indexOf("//") === -1) {
      name = m[2].trim()
      info.name = [m[1].length, m[1].length + m[2].length]
      info.colon = lhs.indexOf(":", info.name[1])
      expr = m[3]
      offset = lhs.length - m[3].length
    }
    var result = evaluate(expr, variables)
    if (result !== null) {
      info.refs = result.refs.map(r => [r[0] + offset, r[1] + offset])
      if (name) variables[name.toLowerCase()] = result.value
    }
    if (eq >= 0) {
      var head = line.slice(0, eq).replace(/\s+$/, "")
      var desired
      if (result !== null && (result.refs.length || result.op || result.unit)) {
        var text = result.unit ? formatUnit(result.value, result.unit) : formatNumber(result.value)
        desired = head + " = " + text
        info.result = [head.length + 3, desired.length]
      } else {
        desired = head + " ="
      }
      if (desired !== line) info.newText = desired
    }
  }
  return { infos: infos, variables: variables }
}

// Names defined in a math note, for Tab completion.
function variableNames(lines, infos) {
  var out = []
  infos.forEach((info, i) => { if (info.name) out.push(lines[i].slice(info.name[0], info.name[1]).trim()) })
  return out
}

// ------------------------------------------------------------------ lists and stats

var DONE_RE = /\s\/x\s*$/
var NUMBER_RE = /-?\$?\d[\d,]*(?:\.\d+)?/g

function isDone(line) { return DONE_RE.test(line) }

// The line with its done mark added or taken off.
function toggleDone(line) {
  var m = DONE_RE.exec(line)
  if (m) return line.slice(0, m.index)
  return line.replace(/\s+$/, "") + " /x"
}

// Summary for sum, avg and count notes; "" for others.
function stats(text) {
  var mode = modeOf(text)
  var body = String(text).split("\n").slice(1)
  if (mode === "sum" || mode === "avg") {
    var nums = []
    body.forEach(function(line) {
      var m
      NUMBER_RE.lastIndex = 0
      while ((m = NUMBER_RE.exec(line)) !== null) {
        var n = Number(m[0].replace(/[$,]/g, ""))
        if (!isNaN(n)) nums.push(n)
      }
    })
    if (nums.length === 0) return ""
    var total = nums.reduce((a, b) => a + b, 0)
    return (mode === "sum" ? "sum " + formatNumber(total) : "avg " + formatNumber(total / nums.length))
      + " · " + nums.length + " items"
  }
  if (mode === "count") {
    var items = body.filter(l => l.trim() !== "").length
    var wordCount = body.reduce((a, l) => a + l.split(/\s+/).filter(w => w !== "").length, 0)
    var chars = body.reduce((a, l) => a + l.length, 0)
    return items + " lines · " + wordCount + " words · " + chars + " chars"
  }
  return ""
}

// ------------------------------------------------------------------ highlighting

function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// The note as rich text in the theme's colours, laid out exactly like the
// editor over it: one paragraph in `blockStyle`, a line break per line,
// whitespace kept. colors: { keyword, colon, variable, reference, result,
// link, done, doneMark }.
function highlight(text, colors, blockStyle) {
  var lines = String(text).split("\n")
  var mode = modeOf(text)
  var spans = lines.map(() => [])   // per line: [a, b, css]
  function add(i, a, b, css) { if (b > a) spans[i].push([a, b, css]) }
  function color(c) { return "color:" + c + ";" }

  var h = header(lines[0])
  if (h) {
    add(0, h.start, h.end, color(colors.keyword))
    if (h.colon >= 0) add(0, h.colon, h.colon + 1, color(colors.colon))
  }
  if (mode === "math") {
    analyse(lines).infos.forEach(function(info, i) {
      if (info.name) add(i, info.name[0], info.name[1], color(colors.variable))
      if (info.colon >= 0) add(i, info.colon, info.colon + 1, color(colors.colon))
      info.refs.forEach(r => add(i, r[0], r[1], color(colors.reference)))
      if (info.result) add(i, info.result[0], info.result[1], color(colors.result))
    })
  }
  if (mode === "list") {
    for (var i = 1; i < lines.length; i++) {
      var dm = DONE_RE.exec(lines[i])
      if (dm && lines[i].trim() !== "") {
        add(i, 0, dm.index, color(colors.done) + "text-decoration:line-through;")
        add(i, dm.index, lines[i].length, color(colors.doneMark))
      }
    }
  }
  lines.forEach(function(line, i) {
    linkSpans(line).forEach(s => add(i, s[0], s[1], color(colors.link) + "text-decoration:underline;"))
  })

  var out = lines.map(function(line, i) {
    var list = spans[i].sort((a, b) => a[0] - b[0])
    var html = "", at = 0
    list.forEach(function(s) {
      if (s[0] < at) return            // overlapping: the first one wins
      html += escapeHtml(line.slice(at, s[0])) + "<span style=\"" + s[2] + "\">" + escapeHtml(line.slice(s[0], s[1])) + "</span>"
      at = s[1]
    })
    return html + escapeHtml(line.slice(at))
  })
  return "<p style=\"" + (blockStyle || "margin:0; white-space:pre-wrap") + "\">" + out.join("<br>") + "</p>"
}

// The completion for the word being typed at `cursor` in a math note:
// { insert, name } or null.
function completion(text, cursor, names) {
  if (modeOf(text) !== "math" || names.length === 0) return null
  var lineStart = text.lastIndexOf("\n", cursor - 1) + 1
  if (lineStart === 0) return null
  var next = text[cursor] || ""
  if (next !== "" && next !== "\n" && /[A-Za-z0-9]/.test(next)) return null
  var before = text.slice(lineStart, cursor)
  if (before.indexOf("=") !== -1) return null
  // The words since the last operator or standalone number ("O2" is a word).
  var run = before.replace(/(^|[^A-Za-z])\d[\d.,]*(?![A-Za-z])/g, "$1|").split(/[|+\-*\/()=:,$%^×÷]/).pop()
  var parts = run.split(" ")
  for (var k = 0; k < parts.length; k++) {
    var frag = parts.slice(k).join(" ").replace(/^\s+/, "")
    if (frag.length < 2 || !/[A-Za-zÀ-￿]/.test(frag[0])) continue
    var low = frag.toLowerCase()
    var match = names.find(n => n.toLowerCase().indexOf(low) === 0 && n.length > frag.length)
    if (match) return { insert: match.slice(frag.length), name: match }
  }
  return null
}

// Pasted text: tabs as spaces, common indent and trailing spaces gone.
function cleanPaste(text) {
  var lines = String(text).replace(/\r\n/g, "\n").replace(/\t/g, "    ").split("\n").map(l => l.replace(/\s+$/, ""))
  var indent = Infinity
  lines.forEach(function(l) { if (l.trim() !== "") indent = Math.min(indent, l.match(/^ */)[0].length) })
  if (indent !== Infinity && indent > 0) lines = lines.map(l => l.slice(Math.min(indent, l.length)))
  return lines.join("\n")
}

// Words for an export file name: the title after a keyword, or the first line.
function exportName(text) {
  var lines = String(text).split("\n").filter(l => l.trim() !== "")
  var first = lines.length ? lines[0] : "note"
  var h = header(first)
  if (h) {
    var title = h.colon >= 0 ? first.slice(h.colon + 1).trim() : ""
    first = title || first.slice(h.start, h.end)
  }
  return first.replace(/[^A-Za-z0-9_\- À-￿]+/g, "").trim().slice(0, 40).trim() || "note"
}
