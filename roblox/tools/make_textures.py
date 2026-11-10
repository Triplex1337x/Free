"""Procedural VFX texture generator for Rift Battlegrounds.

Produces white/greyscale PNGs with alpha so Roblox can tint them with the
ParticleEmitter / Decal / Beam colour of each element. Everything is drawn
from math and noise: no third-party art is used.

    python3 roblox/tools/make_textures.py

Output: roblox/assets/textures/*.png plus preview.png (contact sheet).
"""

from __future__ import annotations

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
SS = 2  # supersampling factor
rng = np.random.default_rng(1337)
random.seed(1337)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def grid(size: int):
    """Normalised coordinates in [-1, 1], y pointing up."""
    s = size * SS
    ax = (np.arange(s) + 0.5) / s * 2 - 1
    x, y = np.meshgrid(ax, -ax)
    return x, y


def noise(size: int, scale: int, seed: int, offset=(0.0, 0.0)) -> np.ndarray:
    """Smooth value noise in [0, 1] via bicubic upscaling of a random grid."""
    s = size * SS
    g = np.random.default_rng(seed).random((scale * 3, scale * 3)).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((s * 3, s * 3), Image.BICUBIC)
    arr = np.asarray(img, dtype=np.float32) / 255
    ox = int(offset[0] * s) % (s * 2)
    oy = int(offset[1] * s) % (s * 2)
    return arr[oy:oy + s, ox:ox + s]


def fbm(size: int, seed: int, octaves=5, base=4, offset=(0.0, 0.0)) -> np.ndarray:
    total = np.zeros((size * SS, size * SS), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += amp * noise(size, base * 2 ** o, seed + o * 17, (offset[0] * 2 ** o, offset[1] * 2 ** o))
        norm += amp
        amp *= 0.5
    return total / norm


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def to_image(alpha: np.ndarray, value: np.ndarray | None = None, size: int | None = None) -> Image.Image:
    """Builds an RGBA image: RGB = value (greyscale, tinted in-engine), A = alpha."""
    alpha = np.clip(alpha, 0, 1)
    value = np.ones_like(alpha) if value is None else np.clip(value, 0, 1)
    rgb = (value * 255).astype(np.uint8)
    a = (alpha * 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([rgb, rgb, rgb, a]), "RGBA")
    if size:
        img = img.resize((size, size), Image.LANCZOS)
    return img


def layered(core: Image.Image, glow_radius: float, glow_strength=1.0) -> Image.Image:
    """Adds a soft bloom around a hard-edged RGBA drawing."""
    a = np.asarray(core.split()[3], np.float32) / 255
    glow = np.asarray(core.split()[3].filter(ImageFilter.GaussianBlur(glow_radius)), np.float32) / 255
    alpha = np.clip(a + glow * glow_strength, 0, 1)
    value = np.clip(0.55 + 0.45 * a + 0.2 * glow, 0, 1)
    return to_image(alpha, value)


# --------------------------------------------------------------------------
# Textures
# --------------------------------------------------------------------------

def flash_star(size=512):
    """Anime hit flash: 4 long rays + 4 short diagonals + hot core."""
    x, y = grid(size)
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    out = np.exp(-(r / 0.12) ** 2) * 1.2 + np.exp(-r / 0.35) * 0.35
    for k in range(8):
        theta = k * math.pi / 4
        long = k % 2 == 0
        d = np.abs(np.sin(a - theta)) * r  # distance from the ray line
        along = np.cos(a - theta) * r
        width = 0.035 if long else 0.02
        length = 0.95 if long else 0.5
        ray = np.exp(-(d / (width * (1 - np.clip(along / length, 0, 1)) + 1e-4)) ** 2)
        ray *= (along > 0) * np.clip(1 - along / length, 0, 1) ** 1.5
        out += ray * (1.0 if long else 0.7)
    return to_image(np.clip(out, 0, 1), np.clip(0.7 + out * 0.3, 0, 1), size)


def flash_soft(size=256):
    x, y = grid(size)
    r = np.hypot(x, y)
    alpha = np.exp(-(r / 0.45) ** 2) * smoothstep(1.0, 0.7, r)
    return to_image(alpha, None, size)


def impact_burst(size=512):
    """Spiky radial burst: wedges of random length + core."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    n = 14
    for i in range(n):
        ang = i / n * 2 * math.pi + random.uniform(-0.12, 0.12)
        length = s * random.uniform(0.2, 0.49)
        half = random.uniform(0.12, 0.2)
        base = s * 0.05
        pts = [
            (c + math.cos(ang - half) * base, c + math.sin(ang - half) * base),
            (c + math.cos(ang) * length, c + math.sin(ang) * length),
            (c + math.cos(ang + half) * base, c + math.sin(ang + half) * base),
        ]
        d.polygon(pts, fill=(255, 255, 255, 255))
    d.ellipse([c - s * 0.07, c - s * 0.07, c + s * 0.07, c + s * 0.07], fill=(255, 255, 255, 255))
    return layered(img, s * 0.02, 0.8).resize((size, size), Image.LANCZOS)


def flame_flipbook(frame=256, cols=4):
    """4x4 flipbook of a licking flame tongue (use FlipbookLayout Grid4x4)."""
    sheet = Image.new("RGBA", (frame * cols, frame * cols), (0, 0, 0, 0))
    for i in range(cols * cols):
        t = i / (cols * cols)
        x, y = grid(frame)
        v = (y + 1) / 2  # 0 bottom .. 1 top
        n1 = fbm(frame, 101, octaves=4, base=3, offset=(0.0, -t * 0.5))
        n2 = fbm(frame, 202, octaves=4, base=5, offset=(t * 0.2, -t * 1.0))
        sway = (n1 - 0.5) * 0.8 * v ** 1.1 + math.sin(t * math.pi * 2) * 0.12 * v
        xd = x - sway
        width = 0.95 * (1 - v) ** 0.9 * (1 - np.exp(-v * 7)) + 0.03
        body = np.clip(1 - np.abs(xd) / width, 0, 1)
        erosion = n2 * (0.25 + 0.9 * v)
        alpha = smoothstep(0.02, 0.3, body - erosion * 0.5) * smoothstep(0.0, 0.06, v) * smoothstep(1.0, 0.85, v)
        core = smoothstep(0.35, 0.9, body - erosion * 0.3) * (1 - v * 0.6)
        img = to_image(alpha, 0.55 + 0.45 * core, frame)
        sheet.paste(img, ((i % cols) * frame, (i // cols) * frame))
    return sheet


def smoke_puff(size=256):
    x, y = grid(size)
    r = np.hypot(x, y)
    n = fbm(size, 303, octaves=5, base=3)
    alpha = smoothstep(0.9, 0.15, r + (n - 0.5) * 0.35) * (0.45 + 0.55 * n)
    value = 0.75 + 0.25 * n
    return to_image(alpha, value, size)


def ground_crack(size=512):
    """Branching cracks radiating from the centre (white, glow-ready)."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2

    def branch(x0, y0, ang, length, width, depth):
        steps = int(length / (s * 0.025)) + 1
        x, y = x0, y0
        for step in range(steps):
            ang += random.uniform(-0.45, 0.45)
            seg = length / steps
            nx, ny = x + math.cos(ang) * seg, y + math.sin(ang) * seg
            w = max(1, int(width * (1 - step / steps)))
            d.line([(x, y), (nx, ny)], fill=(255, 255, 255, 255), width=w)
            if depth < 2 and random.random() < 0.18:
                branch(nx, ny, ang + random.choice([-1, 1]) * random.uniform(0.5, 1.0), length * 0.45, w * 0.7, depth + 1)
            x, y = nx, ny

    for i in range(9):
        ang = i / 9 * 2 * math.pi + random.uniform(-0.2, 0.2)
        branch(c, c, ang, s * random.uniform(0.34, 0.48), s * 0.026, 0)
    d.ellipse([c - s * 0.04, c - s * 0.04, c + s * 0.04, c + s * 0.04], fill=(255, 255, 255, 255))
    return layered(img, s * 0.008, 0.9).resize((size, size), Image.LANCZOS)


def shockwave_ring(size=512):
    x, y = grid(size)
    r = np.hypot(x, y)
    n = fbm(size, 404, octaves=3, base=6)
    ring = np.exp(-((r - 0.78) / 0.07) ** 2) + np.exp(-((r - 0.72) / 0.18) ** 2) * 0.35
    alpha = np.clip(ring * (0.75 + 0.5 * n), 0, 1)
    return to_image(alpha, 0.8 + 0.2 * ring, size)


def slash_arc(size=512):
    """Crescent slash: sharp outer edge, tapering tips, glowing inside."""
    x, y = grid(size)
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    arc_start, arc_len = math.radians(20), math.radians(200)
    t = np.mod(a - arc_start, 2 * math.pi) / arc_len
    inside = (t >= 0) & (t <= 1)
    taper = np.sin(np.clip(t, 0, 1) * math.pi) ** 0.8
    outer = 0.86
    thickness = 0.32 * taper
    band = np.clip((outer - r) / (thickness + 1e-4), 0, 1) * (r <= outer)
    edge = smoothstep(0.0, 0.08, band) * smoothstep(1.0, 0.3, band)
    alpha = edge * inside * smoothstep(0.0, 0.15, t) ** 0.5
    alpha += np.exp(-((r - outer) / 0.02) ** 2) * taper * inside * 0.9
    value = 0.6 + 0.4 * smoothstep(0.5, 0.0, band)
    return to_image(np.clip(alpha, 0, 1), value, size)


def spark_streak(size=256):
    x, y = grid(size)
    alpha = np.exp(-(x / 0.75) ** 2 - (y / 0.06) ** 2) + np.exp(-(x / 0.3) ** 2 - (y / 0.12) ** 2) * 0.5
    return to_image(np.clip(alpha, 0, 1), None, size)


def lightning_strip(width=256, height=1024):
    """Jagged bolt with side branches, laid out horizontally for Beams."""
    w, h = width * SS, height * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def bolt(p0, p1, disp, depth):
        if depth == 0:
            d.line([p0, p1], fill=(255, 255, 255, 255), width=int(w * 0.07))
            return
        mx = (p0[0] + p1[0]) / 2 + random.uniform(-disp, disp)
        my = (p0[1] + p1[1]) / 2
        bolt(p0, (mx, my), disp / 2, depth - 1)
        bolt((mx, my), p1, disp / 2, depth - 1)
        if depth > 3 and random.random() < 0.5:
            end = (mx + random.uniform(-w * 0.35, w * 0.35), my + random.uniform(h * 0.04, h * 0.12))
            d.line([(mx, my), end], fill=(255, 255, 255, 220), width=int(w * 0.03))

    bolt((w / 2, 0), (w / 2, h), w * 0.42, 7)
    # Horizontal so it maps along a Beam (Beams stretch texture X along their length).
    return layered(img, w * 0.06, 1.6).resize((width, height), Image.LANCZOS).rotate(90, expand=True)


def energy_orb(size=256):
    x, y = grid(size)
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    swirl = fbm(size, 505, octaves=4, base=4)
    bands = 0.5 + 0.5 * np.sin(a * 3 + r * 10 + swirl * 6)
    alpha = smoothstep(0.95, 0.55, r) * (0.55 + 0.45 * bands) + np.exp(-(r / 0.25) ** 2)
    return to_image(np.clip(alpha, 0, 1), 0.7 + 0.3 * np.exp(-(r / 0.4) ** 2), size)


def petal(size=128):
    x, y = grid(size)
    # Teardrop petal with a small notch at the tip.
    v = (y + 1) / 2
    width = 0.75 * np.sin(np.clip(v, 0, 1) * math.pi) ** 0.8 * (1 - 0.35 * v)
    body = np.clip(1 - np.abs(x) / (width + 1e-4), 0, 1)
    notch = 1 - np.exp(-((x / 0.12) ** 2) - ((v - 0.97) / 0.06) ** 2)
    alpha = smoothstep(0.0, 0.25, body) * notch * (v > 0.02)
    value = 0.85 + 0.15 * body
    return to_image(alpha, value, size)


TEXTURES = {
    "flash_star": flash_star,
    "flash_soft": flash_soft,
    "impact_burst": impact_burst,
    "flame_flipbook_4x4": flame_flipbook,
    "smoke_puff": smoke_puff,
    "ground_crack": ground_crack,
    "shockwave_ring": shockwave_ring,
    "slash_arc": slash_arc,
    "spark_streak": spark_streak,
    "lightning_strip": lightning_strip,
    "energy_orb": energy_orb,
    "petal": petal,
}


def preview(images: dict[str, Image.Image]):
    """Contact sheet on a dark background, each texture tinted for readability."""
    tints = [(255, 120, 60), (255, 240, 200), (90, 200, 255), (255, 140, 40), (200, 190, 230), (255, 90, 60),
             (120, 230, 255), (255, 80, 150), (255, 230, 90), (180, 140, 255), (150, 70, 255), (255, 170, 200)]
    cell = 256
    cols = 4
    rows = math.ceil(len(images) / cols)
    sheet = Image.new("RGB", (cols * cell, rows * cell), (14, 12, 22))
    for i, (name, img) in enumerate(images.items()):
        thumb = img.copy()
        thumb.thumbnail((cell - 24, cell - 24), Image.LANCZOS)
        r, g, b, a = thumb.split()
        tr, tg, tb = tints[i % len(tints)]
        colored = Image.merge("RGB", (r.point(lambda v: v * tr // 255), g.point(lambda v: v * tg // 255), b.point(lambda v: v * tb // 255)))
        ox = (i % cols) * cell + (cell - thumb.width) // 2
        oy = (i // cols) * cell + (cell - thumb.height) // 2
        sheet.paste(colored, (ox, oy), a)
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    images = {}
    for name, fn in TEXTURES.items():
        img = fn()
        img.save(os.path.join(OUT, f"{name}.png"), optimize=True)
        images[name] = img
        print(f"{name:22s} {img.size[0]}x{img.size[1]}")
    preview(images).save(os.path.join(OUT, "preview.png"), optimize=True)
    print("preview.png")


if __name__ == "__main__":
    main()
