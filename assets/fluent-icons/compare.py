#!/usr/bin/env python3
"""How big fluent-icons.otf's glyphs are next to the Nerd Font ones they
replace: the median ratio of the larger side (aim for 1.00)."""
import json, os, sys
from fontTools.ttLib import TTFont
from fontTools.pens.boundsPen import BoundsPen
HERE = os.path.dirname(os.path.abspath(__file__))
nerd = TTFont(sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.local/share/fonts/BlexMono/BlexMonoNerdFont-Regular.ttf"))
ours = TTFont(os.path.join(HERE, "fluent-icons.otf"))
def side(font, cp):
    gs = font.getGlyphSet(); g = font.getBestCmap().get(cp)
    if not g: return None
    pen = BoundsPen(gs); gs[g].draw(pen); x0, y0, x1, y1 = pen.bounds
    return max(x1 - x0, y1 - y0)
ratios = sorted(a / b for a, b in ((side(nerd, int(c, 16)), side(ours, int(c, 16))) for c in json.load(open(os.path.join(HERE, "map.json")))) if a and b)
print(f"nerd/fluent: median {ratios[len(ratios)//2]:.2f}, middle half {ratios[len(ratios)//4]:.2f}-{ratios[3*len(ratios)//4]:.2f}")
