"""Turns the AI-painted VFX sheets into game-ready textures.

The source sheets (assets/textures/source/*.png) were generated in Figma as
2x2 grids of white effects on pure black. For each quadrant this script:
  1. converts black -> transparent (alpha = brightness, colour = white),
     so Roblox can tint the texture with the element colour;
  2. removes faint background noise and fades the quadrant borders;
  3. trims to the effect, centres it with a margin and resizes.

    python3 roblox/tools/process_textures.py
"""

from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
SRC = os.path.join(ROOT, "source")

# sheet -> (top-left, top-right, bottom-left, bottom-right)
SHEETS = {
    "sheet_hits.png": ("flash_star", "impact_burst", "shockwave_ring", "slash_arc"),
    "sheet_elements.png": ("flame", "smoke_puff", "water_splash", "wind_swirl"),
    "sheet_energy.png": ("ground_crack", "lightning_strip", "energy_orb", "sunburst"),
    "sheet_particles.png": ("petal", "spark_streak", "ember_cluster", "flash_soft"),
}

# name -> (output width, output height, rotate degrees, margin)
OUTPUT = {
    "lightning_strip": (1024, 256, 0, 0.02),  # horizontal: Beams stretch X along their length
    "spark_streak": (128, 512, 90, 0.04),  # vertical: VelocityParallel particles face their Y axis along motion
    "petal": (256, 256, 0, 0.08),
    "ember_cluster": (256, 256, 0, 0.06),
}
DEFAULT = (512, 512, 0, 0.06)

NOISE_FLOOR = 0.035  # brightness below this becomes fully transparent


def to_alpha(tile: Image.Image) -> Image.Image:
    rgb = np.asarray(tile.convert("RGB"), np.float32) / 255
    lum = rgb.max(axis=2)
    alpha = np.clip((lum - NOISE_FLOOR) / (1 - NOISE_FLOOR), 0, 1)

    # Fade towards the tile border so neighbouring sprites never bleed in.
    h, w = alpha.shape
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy]) / (0.04 * min(w, h))
    alpha *= np.clip(edge, 0, 1)

    # Keep a hint of the painted shading in the colour channel, mostly white.
    shade = np.clip(0.75 + 0.25 * lum, 0, 1)
    out = np.dstack([shade, shade, shade, alpha])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def fit(img: Image.Image, width: int, height: int, margin: float) -> Image.Image:
    a = np.asarray(img.split()[3])
    ys, xs = np.nonzero(a > 6)
    if len(xs) == 0:
        return img.resize((width, height), Image.LANCZOS)
    crop = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    inner_w, inner_h = width * (1 - 2 * margin), height * (1 - 2 * margin)
    scale = min(inner_w / crop.width, inner_h / crop.height)
    crop = crop.resize((max(1, round(crop.width * scale)), max(1, round(crop.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    canvas.paste(crop, ((width - crop.width) // 2, (height - crop.height) // 2), crop)
    return canvas


def preview(images: dict[str, Image.Image]) -> Image.Image:
    tints = [(255, 120, 60), (255, 230, 120), (90, 200, 255), (255, 80, 150),
             (255, 140, 40), (200, 190, 230), (60, 170, 255), (140, 255, 190),
             (255, 90, 60), (255, 230, 70), (150, 70, 255), (255, 245, 200),
             (255, 170, 200), (255, 230, 90), (255, 150, 60), (255, 240, 220)]
    cell, cols = 256, 4
    rows = math.ceil(len(images) / cols)
    sheet = Image.new("RGB", (cols * cell, rows * cell), (14, 12, 22))
    for i, (name, img) in enumerate(images.items()):
        thumb = img.copy()
        thumb.thumbnail((cell - 20, cell - 20), Image.LANCZOS)
        r, g, b, a = thumb.split()
        tr, tg, tb = tints[i % len(tints)]
        colored = Image.merge("RGB", (r.point(lambda v: v * tr // 255), g.point(lambda v: v * tg // 255), b.point(lambda v: v * tb // 255)))
        sheet.paste(colored, ((i % cols) * cell + (cell - thumb.width) // 2, (i // cols) * cell + (cell - thumb.height) // 2), a)
    return sheet


def main():
    images = {}
    for sheet_name, names in SHEETS.items():
        sheet = Image.open(os.path.join(SRC, sheet_name)).convert("RGB")
        w, h = sheet.size
        boxes = [(0, 0, w // 2, h // 2), (w // 2, 0, w, h // 2), (0, h // 2, w // 2, h), (w // 2, h // 2, w, h)]
        for name, box in zip(names, boxes):
            width, height, rotate, margin = OUTPUT.get(name, DEFAULT)
            tile = to_alpha(sheet.crop(box))
            if rotate:
                tile = tile.rotate(rotate, expand=True)
            out = fit(tile, width, height, margin)
            out.save(os.path.join(ROOT, f"{name}.png"), optimize=True)
            images[name] = out
            print(f"{name:16s} {width}x{height}")
    preview(images).save(os.path.join(ROOT, "preview.png"), optimize=True)
    print("preview.png")


if __name__ == "__main__":
    main()
