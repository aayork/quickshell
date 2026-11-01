#!/usr/bin/env python3
"""Build fluent-icons.otf: Microsoft's Fluent System Icons (MIT) placed at the
Nerd Font codepoints the shell already uses, so no QML has to change.

map.json says which Fluent icon stands in for each codepoint; a name ending in
"!" uses the filled style. svgs/ holds SVGs from @fluentui/svg-icons: the 24px
drawings, whose lines are heavier for their size than the 20px ones (those
looked thin on the bar), with the 20px drawing where there is no 24.
Brand logos (Spotify, GitHub, Linux...) are left out on purpose: Fluent has
none, so those keep falling through to the Nerd Font.

Sizing copies BlexMono Nerd Font's md-* glyphs: advance 600, centred on
y=375, SCALE tuned so the icons come out the same size as the Nerd ones on
average (check with compare.py). Like Nerd Fonts, an icon wider
than its 600 advance starts at x=0 and spills right; a narrower one is centred
in the advance. That keeps every icon where the Nerd one it replaces sat.

U+E000 is the control center's two-switch glyph (assets/control-center.otf);
here it becomes Fluent's "options" sliders, centred in a 1000 advance like
that font so the bar button keeps its spacing.

Fluent's lines are thinner than the Material ones they replace (about 1.5
units in 24 against 2), which made them read as smaller and lighter than the
solid shapes beside them. Every outline is grown by WEIGHT so the lines match.

Install with bin/icons-set fluent. Requires fonttools and skia-pathops.
"""
import json
import os
import re

import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import SVGPath

HERE = os.path.dirname(os.path.abspath(__file__))
FAMILY = "aayork Fluent Icons"

SCALE = 40.5  # font units per unit of a 24px drawing
CENTER_Y, ADVANCE = 375, 600
WEIGHT = 21  # font units added across each line (0.5 of a 24px drawing's units)

SPACES = (0x0020, 0x00A0, 0x2007, 0x2009, 0x202F)

CONTROL_CENTER = 0xE000
CC_SCALE = 41.5  # tuned so the sliders match control-center.otf's switches
CC_ADVANCE = 1000


def draw(svg_file, box, advance, scale, centred):
    # SVG y runs down; font y runs up. The box is centred on CENTER_Y.
    shape = RecordingPen()
    SVGPath(svg_file).draw(TransformPen(shape, (scale, 0, 0, -scale, 0, CENTER_Y + box / 2 * scale)))
    shape = heavier(shape)
    bounds = BoundsPen(None)
    shape.replay(bounds)
    x0, _, x1, _ = bounds.bounds
    width = x1 - x0
    shift = (advance - width) / 2 - x0 if centred or width <= advance else -x0
    pen = T2CharStringPen(advance, None)
    shape.replay(TransformPen(pen, (1, 0, 0, 1, shift, 0)))
    return pen.getCharString()


def heavier(shape):
    """The shape with every edge pushed out by WEIGHT / 2: an outline of the
    edges, merged back in. Holes shrink by the same amount, so lines thicken
    evenly on both sides."""
    fill = pathops.Path()
    shape.replay(fill.getPen())
    edge = pathops.Path()
    shape.replay(edge.getPen())
    edge.stroke(WEIGHT, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
    edge.convertConicsToQuads()
    out = RecordingPen()
    pathops.op(fill, edge, pathops.PathOp.UNION).draw(out)
    return out


def svg_path(name):
    """The drawing for a map.json name, and its box size."""
    style = "filled" if name.endswith("!") else "regular"
    for box in (24, 20):
        path = os.path.join(HERE, "svgs", f"{name.rstrip('!')}_{box}_{style}.svg")
        if os.path.exists(path):
            return path, box
    raise FileNotFoundError(name)


def main():
    mapping = json.load(open(os.path.join(HERE, "map.json")))
    mapping = {int(code, 16): name for code, name in mapping.items()}
    mapping[CONTROL_CENTER] = "options"

    order = [".notdef"]
    cmap, strings, metrics = {}, {}, {}
    empty = T2CharStringPen(ADVANCE, None).getCharString()
    strings[".notdef"], metrics[".notdef"] = empty, (ADVANCE, 0)

    # Being first in the shell's font list, this font is asked for spaces
    # too; without them Qt squeezes the gaps in text like the clock. Give
    # them BlexMono's 600 width.
    for code in SPACES:
        glyph = f"u{code:04X}"
        strings[glyph], metrics[glyph] = empty, (ADVANCE, 0)
        order.append(glyph)
        cmap[code] = glyph

    for code, name in sorted(mapping.items()):
        glyph = f"u{code:X}"
        cc = code == CONTROL_CENTER
        path, box = svg_path(name)
        scale = CC_SCALE if cc else SCALE
        strings[glyph] = draw(path, box,
                              CC_ADVANCE if cc else ADVANCE,
                              scale * (1.2 if box == 20 else 1),  # a 20 fills its box like a 24
                              cc)
        metrics[glyph] = (CC_ADVANCE if cc else ADVANCE, 0)
        order.append(glyph)
        cmap[code] = glyph

    fb = FontBuilder(1000, isTTF=False)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupCFF(re.sub(r"\W", "", FAMILY), {"FullName": FAMILY}, strings, {})
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=1025, descent=-275)
    fb.setupNameTable({"familyName": FAMILY, "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=1025, sTypoDescender=-275, sTypoLineGap=0,
                usWinAscent=1025, usWinDescent=275)
    fb.setupPost()
    out = os.path.join(HERE, "fluent-icons.otf")
    fb.save(out)
    print(f"{out}: {len(cmap)} glyphs")


if __name__ == "__main__":
    main()
