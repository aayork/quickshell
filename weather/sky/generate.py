#!/usr/bin/env python3
"""Generate the sky textures Sky.qml uses: soft cloud sprites (light and
dark), a horizontally tileable fog band, radial glows and a grain tile.
Spectral (FFT) noise, so everything is smooth and tiles cleanly.
Run: python3 weather/sky/generate.py  (needs numpy + Pillow)."""
import os
import numpy as np
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)


def noise(h, w, beta=2.4, seed=None):
    r = np.random.default_rng(seed) if seed is not None else rng
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    spec = (r.normal(size=(h, w)) + 1j * r.normal(size=(h, w))) / f ** (beta / 2)
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec))
    return (n - n.min()) / (n.max() - n.min())


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def save(name, rgb, a):
    # A touch of noise before quantising keeps 8-bit alpha from banding.
    d = rng.uniform(-0.5, 0.5, a.shape) / 255
    img = np.dstack([np.clip(rgb, 0, 1)] + [np.clip(a + d, 0, 1)])
    if rgb.ndim == 2:
        img = np.dstack([rgb, rgb, rgb, np.clip(a + d, 0, 1)])
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, name), optimize=True)


def cloud(i, w=900, h=420):
    r = np.random.default_rng(400 + i)
    y, x = np.mgrid[0:h, 0:w].astype(float)
    # A cumulus heap: overlapping round puffs along a flat base, biggest
    # in the middle.
    acc = np.zeros((h, w))
    base = h * 0.70
    span = r.uniform(0.22, 0.32)
    for k in range(r.integers(8, 12)):
        cx = w * (0.5 + r.uniform(-span, span))
        mid = 1 - abs(cx / w - 0.5) * 1.6
        rad = h * r.uniform(0.16, 0.26) * (0.6 + 0.6 * mid)
        cy = base - rad * r.uniform(0.35, 0.9)
        acc += np.exp(8 * (1 - np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / rad))
    # Smooth union, so neighbouring puffs merge without a seam.
    d = np.log(acc + 1e-9) / 8
    # Flat underside.
    d *= smoothstep(base + h * 0.06, base - h * 0.08, y)
    n = noise(h, w, 3.2, seed=100 + i)
    fine = noise(h, w, 2.2, seed=200 + i)
    body = smoothstep(-0.05, 0.2, d)
    d = d + ((n - 0.5) * 0.55 + (fine - 0.5) * 0.12) * body
    a = smoothstep(0.02, 0.45, d)
    # Lit from above: brighter where density rises toward the top.
    shade = np.clip(0.5 + (d - np.roll(d, 18, axis=0)) * 2.2, 0, 1)
    vert = 1 - np.clip((y - base * 0.3) / (base * 0.8), 0, 1)
    return a, shade, vert


for i in range(5):
    a, shade, vert = cloud(i)
    light = 0.74 + 0.16 * shade + 0.10 * vert
    save(f"cloud-light-{i}.png", np.dstack([light * 0.98, light * 0.99, light]), a)
    dark = 0.30 + 0.16 * shade + 0.08 * vert
    save(f"cloud-dark-{i}.png", np.dstack([dark * 0.96, dark * 0.98, dark * 1.04]), a * 0.95)

# Fog: wide soft band, tiles left to right.
h, w = 300, 1600
n = noise(h, w, 3.6, seed=300)
y = np.mgrid[0:h, 0:w][0] / h
band = np.exp(-((y - 0.5) / 0.28) ** 2)
a = smoothstep(0.2, 0.8, n) * band
save("fog.png", np.ones((h, w)) * 0.96, a)

# Stratus: an overcast ceiling, tiles left to right; lit from above.
h, w = 600, 1600
n = noise(h, w, 3.3, seed=500)
fine = noise(h, w, 2.4, seed=501)
y = np.mgrid[0:h, 0:w][0] / h
d = n * 0.85 + fine * 0.15
fade = smoothstep(1.0, 0.55, y) * smoothstep(0.0, 0.08, y)
a = smoothstep(0.25, 0.7, d) * fade
shade = np.clip(0.5 + (d - np.roll(d, 20, axis=0)) * 4, 0, 1)
light = 0.62 + 0.16 * shade + 0.06 * (1 - y)
save("stratus-light.png", np.dstack([light * 0.98, light * 0.99, light]), a)
dark = 0.30 + 0.14 * shade + 0.06 * (1 - y)
save("stratus-dark.png", np.dstack([dark * 0.96, dark * 0.98, dark * 1.04]), a)

# Radial glows (white; tinted by opacity over the sky).
for name, size, power in (("glow.png", 512, 2.2), ("glow-soft.png", 512, 1.3)):
    y, x = np.mgrid[0:size, 0:size]
    r = np.sqrt((x - size / 2 + 0.5) ** 2 + (y - size / 2 + 0.5) ** 2) / (size / 2)
    a = np.clip(1 - r, 0, 1) ** power
    save(name, np.ones((size, size)), a)

# Grain: mid-grey noise; laid over the gradient at a low opacity to dither it.
g = rng.uniform(0, 1, (256, 256))
save("grain.png", g, np.ones_like(g))
print("ok")
