.pragma library

// Jot's colour themes: Antinote's default look and its eight themes, the
// colours sampled from antinote.io's screenshots of each. A theme only lists
// what differs from "antinote"; the rest comes from there.
//
// bg, fg, dim       the note, its text, quiet text (dates, hints)
// accent, caret     active controls; the text cursor
// selection         behind selected text
// keyword           the first-line keyword (math, sum ...); listKeyword in a list
// variable, colon   "name:" in a math note; reference: a name used later
// result            the answer after "="
// link              shortened links; check / checkDone: list boxes
// done, doneMark    a ticked line and its " /x"
// railOn, railOff   the timer's progress down the left edge
// edge              the flash at the side when switching notes
// icon, border      the hover bar's icons; the card's outline

var ORDER = ["antinote", "a24", "agrabah", "brave", "gundam", "mononoke", "piccolo", "tokyodrift", "vendetta"]

var NAMES = {
  antinote: "Antinote", a24: "A24", agrabah: "Agrabah", brave: "Brave", gundam: "Gundam",
  mononoke: "Mononoke", piccolo: "Piccolo", tokyodrift: "Tokyo Drift", vendetta: "Vendetta"
}

var THEMES = {
  antinote: {
    bg: "#fdfdfd", fg: "#36312e", dim: "#9a9a9a", accent: "#1e7e7a",
    caret: "#113b51", selection: "#cfe3f5",
    keyword: "#103345", listKeyword: "#b353e2",
    variable: "#1e7e7a", colon: "#9848bc", reference: "#3f9aa3", result: "#449921",
    link: "#004a8a", check: "#4f4c4b", checkDone: "#dab3ec", done: "#ababab", doneMark: "#d6d6d6",
    timer: "#9a9a9a", railOn: "#9848bc", railOff: "#e2e2e2",
    toastBg: "#302d26", toastFg: "#ffffff", badgeBg: "#2c2c2c", edge: "#fde9cc",
    clip: "#5cb85c", icon: "#8a8a8a", border: "#1a000000"
  },
  // Deep green-black, cream text, burnt orange answers, a red rail.
  a24: {
    bg: "#0e1511", fg: "#e4dabd", dim: "#6a6857", accent: "#c8663a",
    caret: "#e4dabd", selection: "#3a3a2a",
    keyword: "#83806e", listKeyword: "#b6633a",
    variable: "#cfc7b0", colon: "#83806e", reference: "#b6b09b", result: "#d0703f",
    link: "#c8663a", check: "#9c9884", checkDone: "#6c2327", done: "#5a5a4b", doneMark: "#3a3a2e",
    timer: "#6a6857", railOn: "#8a2b30", railOff: "#1e2620",
    toastBg: "#e4dabd", toastFg: "#0e1511", badgeBg: "#e4dabd", edge: "#3a2a18",
    icon: "#6a6857", border: "#22ffffff"
  },
  // Midnight navy, yellow names, teal answers, a raspberry highlight.
  agrabah: {
    bg: "#0b0b28", fg: "#fafafd", dim: "#6e6e7e", accent: "#23b0b6",
    caret: "#fbf683", selection: "#993156",
    keyword: "#fbf683", listKeyword: "#fbf683",
    variable: "#f0e66a", colon: "#c06bd0", reference: "#e8de5a", result: "#23b0b6",
    link: "#23b0b6", check: "#9f9fad", checkDone: "#993156", done: "#565667", doneMark: "#2e2e48",
    timer: "#6e6e7e", railOn: "#993156", railOff: "#1e1e34",
    toastBg: "#fafafd", toastFg: "#0b0b28", badgeBg: "#fafafd", edge: "#2a1d4a",
    icon: "#787d8c", border: "#30ffffff"
  },
  // Warm parchment, dark brown ink, a peach highlight.
  brave: {
    bg: "#f4f1eb", fg: "#3a260a", dim: "#a19685", accent: "#b4643c",
    caret: "#3a260a", selection: "#f5be9e",
    keyword: "#7d6d58", listKeyword: "#b4643c",
    variable: "#6b4a1e", colon: "#b4643c", reference: "#8a6d3c", result: "#4f7a2a",
    link: "#8a4a1e", check: "#5a4c36", checkDone: "#f5be9e", done: "#b2a594", doneMark: "#d8d0c4",
    timer: "#a19685", railOn: "#b4643c", railOff: "#e4ddd2",
    toastBg: "#3a260a", toastFg: "#f4f1eb", badgeBg: "#3a260a", edge: "#f5d6b8",
    icon: "#8a7e6b", border: "#1a3a260a"
  },
  // Clean light grey, navy names, red colons and links, amber answers.
  gundam: {
    bg: "#f6f6f6", fg: "#252626", dim: "#9a9b9c", accent: "#2a6db5",
    caret: "#0c376c", selection: "#cddcf0",
    keyword: "#2a6db5", listKeyword: "#b5203d",
    variable: "#0c376c", colon: "#d42a3c", reference: "#547fc6", result: "#f2b544",
    link: "#d42a3c", check: "#525252", checkDone: "#9ab6e1", done: "#b3b3b3", doneMark: "#dadada",
    timer: "#9a9b9c", railOn: "#b5203d", railOff: "#e2e2e2",
    toastBg: "#252626", toastFg: "#f6f6f6", badgeBg: "#252626", edge: "#f6ddb0",
    icon: "#818384", border: "#1a000000"
  },
  // Charcoal, sea-glass names, coral answers, an orange rail.
  mononoke: {
    bg: "#181818", fg: "#f2f2f2", dim: "#6b6b6b", accent: "#ee6445",
    caret: "#f2f2f2", selection: "#3f505a",
    keyword: "#516a6d", listKeyword: "#ee6445",
    variable: "#96ded3", colon: "#ee6445", reference: "#648285", result: "#f16445",
    link: "#96ded3", check: "#b3b3b3", checkDone: "#ee6445", done: "#6b6b6b", doneMark: "#333333",
    timer: "#6b6b6b", railOn: "#ee6445", railOff: "#262b2e",
    toastBg: "#f2f2f2", toastFg: "#181818", badgeBg: "#f2f2f2", edge: "#3a2420",
    icon: "#838383", border: "#26ffffff"
  },
  // Mint white, purple names, green references, lime highlight, pink answers.
  piccolo: {
    bg: "#f5fff5", fg: "#242523", dim: "#999d99", accent: "#4fb440",
    caret: "#242523", selection: "#b3f82c",
    keyword: "#885795", listKeyword: "#885795",
    variable: "#885795", colon: "#885795", reference: "#4fb440", result: "#e8336b",
    link: "#885795", check: "#525452", checkDone: "#b3f82c", done: "#b1b5b1", doneMark: "#d9dbc7",
    timer: "#999d99", railOn: "#4fb440", railOff: "#dfeedd",
    toastBg: "#242523", toastFg: "#f5fff5", badgeBg: "#242523", edge: "#d8fbb0",
    icon: "#828582", border: "#1a000000"
  },
  // Dark warm grey, sky-blue keyword, teal names, green answers.
  tokyodrift: {
    bg: "#2b2626", fg: "#f2ebe5", dim: "#87817e", accent: "#68c3f4",
    caret: "#f2ebe5", selection: "#256e6e",
    keyword: "#68c3f4", listKeyword: "#68c3f4",
    variable: "#2a9c9c", colon: "#7dafaf", reference: "#2a9c9c", result: "#4ecc6d",
    link: "#68c3f4", check: "#a09a97", checkDone: "#218484", done: "#6e6967", doneMark: "#3e3838",
    timer: "#87817e", railOn: "#2a9c9c", railOff: "#3a3434",
    toastBg: "#f2ebe5", toastFg: "#2b2626", badgeBg: "#f2ebe5", edge: "#1e3a3a",
    icon: "#87817e", border: "#26ffffff"
  },
  // Near black, pale grey text, blood red and old gold.
  vendetta: {
    bg: "#141414", fg: "#e3e3e3", dim: "#6b6b6b", accent: "#a01c1c",
    caret: "#b01e1e", selection: "#4a1414",
    keyword: "#9b9b9b", listKeyword: "#cba269",
    variable: "#cba269", colon: "#a01c1c", reference: "#cdac82", result: "#c9423a",
    link: "#cba269", check: "#b3b3b3", checkDone: "#781414", done: "#545454", doneMark: "#2c2c2c",
    timer: "#6b6b6b", railOn: "#a01c1c", railOff: "#262626",
    toastBg: "#e3e3e3", toastFg: "#141414", badgeBg: "#e3e3e3", edge: "#3a1010",
    icon: "#838383", border: "#26ffffff"
  }
}

// The full palette for a theme name; unknown names get Antinote's.
function palette(name) {
  var out = {}
  var base = THEMES.antinote, own = THEMES[name] || {}
  for (var k in base) out[k] = own[k] !== undefined ? own[k] : base[k]
  return out
}

// The theme after (step 1) or before (step -1) this one.
function next(name, step) {
  var i = ORDER.indexOf(name)
  if (i < 0) i = 0
  return ORDER[(i + step + ORDER.length) % ORDER.length]
}
