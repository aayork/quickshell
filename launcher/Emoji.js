.pragma library

// Search for the emoji picker. Pure functions over launcher/data/emoji.json,
// so they can be checked with node as well as run in the shell.

// What a person types when they are after a feeling rather than a name. Each
// entry lists names to put first; they go through the same search, so a
// rename upstream still lands on the right emoji.
var intents = {
  "love": ["red heart", "smiling face with hearts", "heart hands"],
  "heart": ["red heart"],
  "hearts": ["red heart"],
  "smile": ["slightly smiling face", "grinning face with smiling eyes"],
  "happy": ["grinning face", "smiling face with smiling eyes"],
  "joy": ["face with tears of joy", "grinning face"],
  "sad": ["crying face", "pensive face"],
  "cry": ["crying face", "loudly crying face"],
  "crying laughing": ["face with tears of joy", "rolling on the floor laughing"],
  "laughing crying": ["face with tears of joy", "rolling on the floor laughing"],
  "lol": ["rolling on the floor laughing", "face with tears of joy"],
  "lmao": ["rolling on the floor laughing"],
  "laugh": ["face with tears of joy", "grinning squinting face"],
  "party": ["party popper", "partying face", "confetti ball"],
  "congrats": ["party popper", "clinking glasses", "trophy"],
  "congratulations": ["party popper", "clinking glasses", "trophy"],
  "celebrate": ["party popper", "partying face"],
  "thanks": ["folded hands"],
  "thank you": ["folded hands"],
  "ty": ["folded hands"],
  "thx": ["folded hands"],
  "please": ["pleading face", "folded hands"],
  "sorry": ["pleading face", "folded hands"],
  "yes": ["check mark button", "thumbs up"],
  "no": ["cross mark", "thumbs down"],
  "nope": ["cross mark", "thumbs down"],
  "x": ["cross mark"],
  "ily": ["love-you gesture"],
  "i love you": ["love-you gesture", "red heart"],
  "wrong": ["cross mark"],
  "tick": ["check mark button"],
  "done": ["check mark button"],
  "good": ["thumbs up"],
  "bad": ["thumbs down"],
  "lgtm": ["thumbs up", "check mark button"],
  "brasil": ["flag brazil"],
  "usa": ["flag united states"],
  "america": ["flag united states"],
  "uk": ["flag united kingdom"],
  "idea": ["light bulb"],
  "wow": ["astonished face"],
  "shocked": ["astonished face", "face screaming in fear"],
  "surprised": ["astonished face"],
  "scared": ["fearful face"],
  "tired": ["sleepy face", "yawning face"],
  "bored": ["expressionless face", "unamused face"],
  "meh": ["neutral face", "unamused face"],
  "annoyed": ["unamused face", "face with rolling eyes"],
  "eyeroll": ["face with rolling eyes"],
  "cringe": ["grimacing face"],
  "oops": ["grimacing face"],
  "angry": ["angry face", "enraged face"],
  "mad": ["angry face", "enraged face"],
  "cheers": ["clinking glasses", "clinking beer mugs"],
  "hi": ["waving hand"],
  "hello": ["waving hand"],
  "bye": ["waving hand"],
  "winner": ["trophy", "1st place medal"],
  "ship": ["rocket"],
  "shipit": ["rocket"],
  "deploy": ["rocket"],
  "launch": ["rocket"],
  "lit": ["fire"],
  "confused": ["confused face", "thinking face"],
  "strong": ["flexed biceps"],
  "deal": ["handshake"],
  "agree": ["handshake", "thumbs up"],
  "money": ["money bag", "dollar banknote"],
  "work": ["briefcase", "laptop"],
  "code": ["laptop", "technologist"],
  "deadline": ["alarm clock"],
  "night": ["crescent moon"],
  "morning": ["sunrise"],
  "food": ["fork and knife", "pizza"],
  "dead": ["skull"],
  "cool": ["smiling face with sunglasses"],
  "nice": ["thumbs up", "ok hand"],
  "up": ["thumbs up", "up arrow"],
  "down": ["thumbs down", "down arrow"]
}

// Shown when nothing has been used yet.
var popular = ["red heart", "face with tears of joy", "thumbs up", "fire", "party popper",
  "folded hands", "sparkles", "smiling face with heart-eyes", "loudly crying face", "rolling on the floor laughing",
  "smiling face with smiling eyes", "thinking face", "clapping hands", "rocket", "check mark button",
  "eyes", "skull", "hundred points", "waving hand", "smiling face with sunglasses"]

// Lowercased words once, rather than on every keystroke.
function prepare(data) {
  var list = data.emoji || []
  var groups = data.groups || []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    var name = item.n.toLowerCase()
    var keys = (item.k || "").toLowerCase()
    var text = (name + " " + keys).replace(/[:,]/g, "").replace(/[_-]/g, " ")
    out.push({
      e: item.e,
      name: item.n,
      group: groups[item.g] || "",
      tones: item.t || null,
      nameText: name.replace(/[:,]/g, "").replace(/[_-]/g, " "),
      text: text,
      words: text.split(" ").filter(w => w !== "")
    })
  }
  return out
}

// A whole-word hit beats a prefix beats a substring; a hit in the name beats
// one in the extra keywords; earlier and shorter break ties. 0 is no match.
function rankWord(entry, needle) {
  var band = 0
  if (entry.words.indexOf(needle) !== -1) band = 3000
  else if (entry.words.some(w => w.indexOf(needle) === 0)) band = 2000
  else if (entry.text.indexOf(needle) !== -1) band = 1000
  if (band === 0) return 0
  var at = entry.text.indexOf(needle)
  var inName = entry.nameText.indexOf(needle) !== -1 ? 400 : 0
  return band + inName + (200 - Math.min(at, 200)) + (100 - Math.min(entry.nameText.length, 100))
}

// Every word has to land somewhere; the whole phrase in order is worth more.
function rank(entry, tokens, phrase) {
  if (tokens.length === 1) return rankWord(entry, tokens[0])
  var total = 0
  for (var i = 0; i < tokens.length; i++) {
    var r = rankWord(entry, tokens[i])
    if (r === 0) return 0
    total += r
  }
  return total + (entry.text.indexOf(phrase) !== -1 ? 1500 : 0)
}

function tokenize(text) {
  return text.toLowerCase().replace(/[_-]/g, " ").split(/\s+/).filter(w => w !== "")
}

function best(entries, phrase) {
  var tokens = tokenize(phrase)
  if (tokens.length === 0) return null
  var top = null
  var topScore = 0
  for (var i = 0; i < entries.length; i++) {
    if (entries[i].text.indexOf(tokens[0]) === -1) continue
    var s = rank(entries[i], tokens, tokens.join(" "))
    if (s > topScore) { top = entries[i]; topScore = s }
  }
  return top
}

// The emoji for a query, best first. Feelings first, then names; if nothing
// matches every word, whatever matches some of them.
function search(entries, query, limit) {
  var tokens = tokenize(query)
  if (tokens.length === 0) return []
  var phrase = tokens.join(" ")
  var seen = {}
  var out = []
  function add(entry) {
    if (!entry || seen[entry.e]) return
    seen[entry.e] = true
    out.push(entry)
  }

  var keys = [phrase, phrase.replace(/ (face|emoji|emojis|sign|symbol|icon)$/, "")]
  for (var k = 0; k < keys.length; k++) {
    var names = intents[keys[k]] || []
    for (var n = 0; n < names.length; n++) add(best(entries, names[n]))
  }

  var scored = []
  for (var i = 0; i < entries.length; i++) {
    if (entries[i].text.indexOf(tokens[0]) === -1) continue
    var s = rank(entries[i], tokens, phrase)
    if (s > 0) scored.push([s, i])
  }
  if (scored.length === 0 && tokens.length > 1) {
    for (var j = 0; j < entries.length; j++) {
      var sum = 0
      for (var t = 0; t < tokens.length; t++) sum += rankWord(entries[j], tokens[t])
      if (sum > 0) scored.push([sum, j])
    }
  }
  scored.sort((a, b) => b[0] - a[0] || a[1] - b[1])
  for (var m = 0; m < scored.length && out.length < limit; m++) add(entries[scored[m][1]])
  return out.slice(0, limit)
}

// "face with tears of joy" -> "Face with Tears of Joy"
function title(name) {
  var small = ["a", "an", "and", "as", "at", "by", "for", "in", "of", "on", "or", "the", "to", "with"]
  return name.split(" ").map(function(word, i) {
    if (i > 0 && small.indexOf(word) !== -1) return word
    return word.charAt(0).toUpperCase() + word.slice(1)
  }).join(" ")
}
