.pragma library

// How well `query` matches `text`: 0 for no match, higher for better.
// Exact, then prefix, then start of a word, then anywhere, then the letters
// in order with gaps.
function score(query, text) {
  var q = String(query || "").toLowerCase().trim()
  var t = String(text || "").toLowerCase()
  if (q === "") return 1
  if (t === "") return 0
  if (t === q) return 1000
  if (t.indexOf(q) === 0) return 800 - Math.min(t.length, 100)
  var at = t.indexOf(q)
  if (at > 0) return /[\s\-_.\/]/.test(t.charAt(at - 1)) ? 600 : 400

  // Initials: "vsc" for "Visual Studio Code".
  var initials = t.split(/[\s\-_.]+/).map(function(w) { return w.charAt(0) }).join("")
  if (initials.indexOf(q) === 0) return 500

  var position = 0
  var gaps = 0
  for (var i = 0; i < q.length; i++) {
    var found = t.indexOf(q.charAt(i), position)
    if (found === -1) return 0
    gaps += found - position
    position = found + 1
  }
  // Letters scattered across the whole name are a coincidence, not a match.
  if (gaps > q.length * 2) return 0
  return 300 - gaps * 10
}

// Best score across several fields, the later ones counting for less.
function best(query, primary, others) {
  var top = score(query, primary)
  for (var i = 0; i < others.length; i++) {
    var s = score(query, others[i]) * 0.6
    if (s > top) top = s
  }
  return top
}
