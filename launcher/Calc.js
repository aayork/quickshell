.pragma library

// A small arithmetic evaluator: + - * / % ^, parentheses, a few functions
// and constants. Returns null for anything that is not a sum, so ordinary
// search text never turns into an answer.

var FUNCTIONS = {
  sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
  sin: Math.sin, cos: Math.cos, tan: Math.tan, ln: Math.log, log: function(x) { return Math.log(x) / Math.LN10 }
}
var CONSTANTS = { pi: Math.PI, e: Math.E }

function tokenize(text) {
  var tokens = []
  var pattern = /\s*(?:(\d+\.?\d*(?:e[+-]?\d+)?|\.\d+)|([a-z]+)|(\*\*|[-+*\/%^(),]))/gi
  var end = 0
  var match
  while ((match = pattern.exec(text)) !== null) {
    if (match.index !== end) return null
    end = pattern.lastIndex
    if (match[1] !== undefined) tokens.push({ type: "number", value: parseFloat(match[1]) })
    else if (match[2] !== undefined) tokens.push({ type: "name", value: match[2].toLowerCase() })
    else tokens.push({ type: "op", value: match[3] === "**" ? "^" : match[3] })
  }
  return text.slice(end).trim() === "" ? tokens : null
}

function evaluate(text) {
  var source = String(text || "").replace(/×/g, "*").replace(/÷/g, "/").replace(/,(?=\d{3})/g, "")
  // Needs a digit and something to do with it.
  if (!/\d/.test(source) || !/[-+*\/%^(]|[a-z]\s*\(/i.test(source.replace(/^\s*[-+]/, ""))) return null
  var tokens = tokenize(source)
  if (!tokens || tokens.length === 0) return null
  var position = 0

  function peek() { return tokens[position] }
  function take(value) {
    var token = tokens[position]
    if (token && token.type === "op" && token.value === value) { position++; return true }
    return false
  }

  function expression() {
    var left = term()
    while (true) {
      if (take("+")) left += term()
      else if (take("-")) left -= term()
      else return left
    }
  }
  function term() {
    var left = unary()
    while (true) {
      if (take("*")) left *= unary()
      else if (take("/")) left /= unary()
      else if (take("%")) left %= unary()
      else return left
    }
  }
  function unary() {
    if (take("-")) return -unary()
    if (take("+")) return unary()
    return power()
  }
  function power() {
    var base = atom()
    return take("^") ? Math.pow(base, unary()) : base
  }
  function atom() {
    var token = peek()
    if (!token) throw new Error("end")
    if (token.type === "number") { position++; return token.value }
    if (token.type === "name") {
      position++
      if (CONSTANTS[token.value] !== undefined) return CONSTANTS[token.value]
      var fn = FUNCTIONS[token.value]
      if (!fn || !take("(")) throw new Error("name")
      var argument = expression()
      if (!take(")")) throw new Error("paren")
      return fn(argument)
    }
    if (take("(")) {
      var inner = expression()
      if (!take(")")) throw new Error("paren")
      return inner
    }
    throw new Error("token")
  }

  try {
    var result = expression()
    if (position !== tokens.length || !isFinite(result)) return null
    return result
  } catch (e) {
    return null
  }
}

function format(value) {
  var rounded = Math.round(value * 1e10) / 1e10
  var parts = String(rounded).split(".")
  if (!/e/.test(parts[0])) parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  return parts.join(".")
}
