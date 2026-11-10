#!/usr/bin/env python3
"""Рисует набор цветных иконок Chrono-Drill (SVG) и атлас для Roblox.

Каждая иконка — 256x256: сочная градиентная заливка, единая толстая тёмная обводка вокруг всей фигуры,
мягкая тень снизу и глянцевые блики. Стиль совпадает с процедурными иконками UI/Icons2D, но в цвете.

Результат:
  Icons/svg/<Имя>.svg               — отдельные иконки (для правок и превью)
  Icons/atlas.svg                   — атлас 1024x1024, 7x7 ячеек по 146 px
  src/ReplicatedStorage/Configs/IconAtlas.lua — раскладка атласа для игры (Id вписывается руками)

Растеризация в PNG: node tools/render_icons.js (нужен Playwright + Chromium).
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Icons")
INK = "#1c162c"
SW = 26  # толщина внешней обводки (половина видна снаружи фигуры)
CELL = 146
COLS = 7

# ---------------------------------------------------------------------------------------------
# Палитра: вертикальные градиенты (верх -> низ)
# ---------------------------------------------------------------------------------------------
GRAD = {
    "gold": ("#ffe98a", "#ffb01f"),
    "goldIn": ("#ffb320", "#ffe27a"),
    "silver": ("#f4f7fc", "#a9b4c8"),
    "steel": ("#e6f2ff", "#8aa2c6"),
    "steelDark": ("#9fb0cc", "#5d6d8c"),
    "red": ("#ff8f8f", "#e2334a"),
    "green": ("#a6f57f", "#25b04a"),
    "greenDark": ("#5fd068", "#16843a"),
    "blue": ("#92d6ff", "#2c7fee"),
    "blueLight": ("#c4ebff", "#5fb2f7"),
    "purple": ("#d6a9ff", "#8645ef"),
    "violet": ("#c9a8ff", "#6236ea"),
    "pink": ("#ffb6d8", "#ee4f8e"),
    "orange": ("#ffc87a", "#ff7a1e"),
    "terracotta": ("#f6a46a", "#c2552b"),
    "teal": ("#8ef6e7", "#15b5a3"),
    "wood": ("#dc9a5c", "#94552b"),
    "woodDark": ("#a8683a", "#6a3a1c"),
    "cream": ("#fffdf3", "#ecdcb8"),
    "white": ("#ffffff", "#dfe5f1"),
    "glass": ("#f4fdff", "#a6e2f4"),
    "ice": ("#f3fdff", "#69c8f4"),
    "cyan": ("#bdf7ff", "#36b0f0"),
    "yellow": ("#fff27e", "#ffaf00"),
    "fire": ("#ffa04d", "#e3332a"),
    "brick": ("#d9775a", "#9c3f2c"),
}


def grad_defs():
    out = []
    for k, (a, b) in GRAD.items():
        out.append(
            '<linearGradient id="g-%s" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % (k, a, b)
        )
    return "".join(out)


def paint(c):
    return "url(#g-%s)" % c if c in GRAD else c


# ---------------------------------------------------------------------------------------------
# Примитивы. Базовые фигуры: ("fill", markup, цвет) или ("stroke", markup, цвет, ширина).
# markup — тег без fill/stroke; он рисуется трижды: тень, обводка, заливка.
# ---------------------------------------------------------------------------------------------
def circ(cx, cy, r):
    return '<circle cx="%g" cy="%g" r="%g"' % (cx, cy, r)


def ell(cx, cy, rx, ry, rot=0):
    return '<ellipse cx="%g" cy="%g" rx="%g" ry="%g" transform="rotate(%g %g %g)"' % (cx, cy, rx, ry, rot, cx, cy)


def rect(x, y, w, h, r=0, rot=0):
    t = ' transform="rotate(%g %g %g)"' % (rot, x + w / 2, y + h / 2) if rot else ""
    return '<rect x="%g" y="%g" width="%g" height="%g" rx="%g"%s' % (x, y, w, h, r, t)


def poly(*pts):
    return '<polygon points="%s"' % " ".join("%g,%g" % p for p in pts)


def path(d, extra=""):
    return '<path d="%s"%s' % (d, extra)


def F(markup, color):
    return ("fill", markup, color)


def S(markup, color, width):
    return ("stroke", markup, color, width)


def star_pts(cx, cy, R, r, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        rr = R if i % 2 == 0 else r
        pts.append((round(cx + rr * math.cos(a), 2), round(cy + rr * math.sin(a), 2)))
    return pts


def gear_path(cx, cy, R, r, n=8, tooth=0.42):
    d = []
    step = 2 * math.pi / n
    for i in range(n):
        a = i * step - math.pi / 2
        h = step * tooth / 2
        pts = [
            (a - step / 2 + h * 0.2, r),
            (a - h * 1.15, r),
            (a - h * 0.8, R),
            (a + h * 0.8, R),
            (a + h * 1.15, r),
        ]
        for j, (ang, rad) in enumerate(pts):
            x, y = cx + rad * math.cos(ang), cy + rad * math.sin(ang)
            d.append(("M" if i == 0 and j == 0 else "L") + "%.2f %.2f" % (x, y))
    return " ".join(d) + "Z"


def wedge(cx, cy, r, a0, a1):
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    return "M%g %g L%.2f %.2f A%g %g 0 0 1 %.2f %.2f Z" % (cx, cy, x0, y0, r, r, x1, y1)


# детали поверх (готовые теги)
def d_fill(markup, color, opacity=1, stroke=None, sw=0):
    s = ' stroke="%s" stroke-width="%g" stroke-linejoin="round"' % (paint(stroke), sw) if stroke else ""
    o = ' opacity="%g"' % opacity if opacity != 1 else ""
    return '%s fill="%s"%s%s/>' % (markup, paint(color), s, o)


def d_line(d, color, width, opacity=1):
    o = ' opacity="%g"' % opacity if opacity != 1 else ""
    return '<path d="%s" fill="none" stroke="%s" stroke-width="%g" stroke-linecap="round" stroke-linejoin="round"%s/>' % (
        d, paint(color), width, o)


def gloss(markup, opacity=0.5):
    return d_fill(markup, "#ffffff", opacity)


# ---------------------------------------------------------------------------------------------
# Иконки. base — фигуры с общей обводкой; clip — детали, обрезанные по заливке; top — детали поверх.
# ---------------------------------------------------------------------------------------------
ICONS = {}


def icon(name, base, clip=(), top=(), transform=None):
    ICONS[name] = dict(base=base, clip=list(clip), top=list(top), transform=transform)


icon("Coin",
     [F(circ(128, 128, 104), "gold")],
     top=[
         d_fill(circ(128, 128, 76), "goldIn", stroke="#d48a0a", sw=8),
         d_fill(rect(110, 80, 36, 96, 18), "#fff4c4", stroke="#d48a0a", sw=7),
         d_line("M58 100 A76 76 0 0 1 112 50", "#ffffff", 14, 0.75),
     ])

icon("Shard",
     [
         F(poly((30, 142), (54, 104), (86, 112), (92, 200), (70, 226), (44, 208)), "cyan"),
         F(poly((226, 142), (202, 104), (170, 112), (164, 200), (186, 226), (212, 208)), "cyan"),
         F(poly((128, 14), (172, 58), (172, 188), (128, 238), (84, 188), (84, 58)), "purple"),
     ],
     top=[
         d_fill(poly((128, 78), (172, 58), (172, 188), (128, 238)), "#3b1c8c", 0.18),
         d_line("M84 58 L128 78 L172 58", "#5b2bb5", 6),
         d_line("M128 78 L128 236", "#5b2bb5", 6, 0.55),
         gloss(poly((98, 66), (114, 74), (114, 182), (98, 176)), 0.55),
         gloss(poly((50, 116), (60, 112), (66, 188), (56, 190)), 0.5),
         gloss(poly((122, 30), (134, 30), (152, 50), (140, 56)), 0.7),
     ])

icon("Paw",
     [
         F(path("M128 120 C170 120 204 162 200 194 C196 224 162 226 128 214 C94 226 60 224 56 194 C52 162 86 120 128 120Z"), "pink"),
         F(ell(54, 110, 25, 32, -22), "pink"),
         F(ell(96, 62, 26, 34, -8), "pink"),
         F(ell(160, 62, 26, 34, 8), "pink"),
         F(ell(202, 110, 25, 32, 22), "pink"),
     ],
     top=[
         gloss(ell(98, 150, 22, 12, -24), 0.55),
         gloss(ell(46, 98, 7, 11, -22), 0.6),
         gloss(ell(88, 48, 8, 12, -8), 0.6),
         gloss(ell(152, 48, 8, 12, 8), 0.6),
         gloss(ell(196, 98, 7, 11, 22), 0.6),
     ])

icon("Chest",
     [
         F(path("M34 112 L34 94 C34 58 62 40 128 40 C194 40 222 58 222 94 L222 112Z"), "wood"),
         F(rect(34, 106, 188, 114, 14), "wood"),
     ],
     clip=[
         d_fill(rect(20, 100, 220, 18), "woodDark"),
         d_line("M34 166 L222 166", "#7a4421", 6, 0.7),
         d_line("M34 72 L222 72", "#7a4421", 6, 0.5),
         d_fill(rect(60, 30, 24, 200), "gold"),
         d_fill(rect(172, 30, 24, 200), "gold"),
         gloss(rect(40, 50, 176, 12, 6), 0.35),
     ],
     top=[
         d_fill(rect(104, 92, 48, 54, 10), "gold", stroke=INK, sw=7),
         d_fill(circ(128, 112, 7), INK),
         d_fill(rect(124, 114, 8, 18, 3), INK),
     ])

icon("ShopBag",
     [
         S(path('M86 98 L86 78 C86 34 170 34 170 78 L170 98', ' stroke-linecap="round"'), "silver", 18),
         F(path("M46 90 L210 90 L224 220 C225 228 220 234 212 234 L44 234 C36 234 31 228 32 220Z"), "orange"),
     ],
     clip=[
         gloss(rect(52, 102, 18, 112, 9), 0.35),
         d_fill(rect(30, 88, 200, 16), "#e8641a", 0.6),
     ],
     top=[
         d_fill(circ(128, 162, 36), "gold", stroke="#c67a00", sw=7),
         d_fill(rect(120, 140, 16, 44, 8), "#fff4c4"),
         d_fill(circ(86, 98, 7), INK),
         d_fill(circ(170, 98, 7), INK),
     ])

icon("Stats",
     [
         F(rect(28, 142, 52, 88, 14), "pink"),
         F(rect(102, 96, 52, 134, 14), "gold"),
         F(rect(176, 40, 52, 190, 14), "green"),
     ],
     top=[
         gloss(rect(38, 152, 11, 60, 5.5), 0.55),
         gloss(rect(112, 106, 11, 104, 5.5), 0.55),
         gloss(rect(186, 50, 11, 160, 5.5), 0.55),
     ])

icon("Gift",
     [
         F(ell(96, 60, 38, 25, 28), "gold"),
         F(ell(160, 60, 38, 25, -28), "gold"),
         F(rect(44, 114, 168, 116, 14), "blue"),
         F(rect(30, 80, 196, 48, 12), "blue"),
         F(circ(128, 76, 18), "gold"),
     ],
     clip=[
         d_fill(rect(112, 80, 32, 160), "gold"),
         d_line("M44 128 L212 128", "#1d5fbf", 7),
         gloss(rect(42, 88, 60, 11, 5.5), 0.5),
         gloss(rect(56, 140, 12, 70, 6), 0.35),
     ],
     top=[
         d_fill(ell(98, 60, 15, 8, 28), "#c67a00", 0.7),
         d_fill(ell(158, 60, 15, 8, -28), "#c67a00", 0.7),
     ])

_wheel_colors = ["#ff5a6e", "#ffc22e", "#4aa8ff", "#57d465", "#a66bff", "#ff8a2e", "#2fd3c0", "#ff6fb0"]
icon("Wheel",
     [F(circ(128, 136, 100), "gold"), F(poly((104, 14), (152, 14), (128, 54)), "red")],
     top=[d_fill(path(wedge(128, 136, 80, -90 + i * 45, -45 + i * 45)), c) for i, c in enumerate(_wheel_colors)]
     + [d_line("M128 136 L%.1f %.1f" % (128 + 80 * math.cos(math.radians(-90 + i * 45)), 136 + 80 * math.sin(math.radians(-90 + i * 45))), "#ffffff", 5)
        for i in range(8)]
     + [d_fill(circ(128 + 90 * math.cos(math.radians(-67.5 + i * 45)), 136 + 90 * math.sin(math.radians(-67.5 + i * 45)), 5), "#fff6cf") for i in range(8)]
     + [
         d_fill(circ(128, 136, 80), "none", stroke="#c67a00", sw=6),
         d_fill(circ(128, 136, 20), "gold", stroke=INK, sw=6),
         d_line("M58 96 A80 80 0 0 1 100 62", "#ffffff", 12, 0.55),
         gloss(poly((114, 20), (130, 20), (126, 30)), 0.6),
     ])

icon("Sprout",
     [
         S(path("M128 146 C128 122 128 104 126 86", ' stroke-linecap="round"'), "greenDark", 14),
         F(path("M124 106 C90 112 52 98 38 60 C80 48 118 64 124 106Z"), "green"),
         F(path("M130 90 C150 50 190 32 224 42 C216 84 172 102 130 90Z"), "green"),
         F(path("M62 152 L194 152 L178 226 C177 232 172 236 166 236 L90 236 C84 236 79 232 78 226Z"), "terracotta"),
         F(rect(48, 136, 160, 32, 10), "terracotta"),
     ],
     top=[
         d_line("M118 102 C96 92 74 80 52 66", "#1e8a3a", 6, 0.8),
         d_line("M138 88 C162 74 186 60 212 50", "#1e8a3a", 6, 0.8),
         gloss(rect(60, 142, 96, 8, 4), 0.45),
         gloss(rect(84, 176, 12, 42, 6), 0.35),
         gloss(ell(70, 70, 14, 6, 20), 0.5),
         gloss(ell(186, 52, 14, 6, -15), 0.5),
     ])

icon("Hourglass",
     [
         F(path("M66 46 L190 46 C190 96 146 112 146 128 C146 144 190 160 190 210 L66 210 C66 160 110 144 110 128 C110 112 66 96 66 46Z"), "glass"),
         F(rect(44, 18, 168, 32, 12), "wood"),
         F(rect(44, 206, 168, 32, 12), "wood"),
     ],
     top=[
         d_fill(path("M84 64 L172 64 C168 92 138 104 131 122 L125 122 C118 104 88 92 84 64Z"), "gold"),
         d_fill(path("M78 206 C88 170 118 162 128 158 C138 162 168 170 178 206Z"), "gold"),
         d_fill(rect(125, 120, 6, 40, 3), "gold"),
         d_line("M82 62 C84 86 100 100 110 112", "#ffffff", 8, 0.75),
         gloss(rect(56, 24, 120, 8, 4), 0.4),
         gloss(rect(56, 212, 120, 8, 4), 0.4),
     ])

icon("Globe",
     [F(circ(128, 128, 104), "blue")],
     clip=[
         d_fill(path("M66 58 C94 42 128 48 132 72 C136 94 112 98 108 118 C104 140 82 146 66 130 C52 116 34 102 40 84 C44 72 54 64 66 58Z"), "green"),
         d_fill(path("M152 118 C172 108 200 118 208 142 C216 168 198 200 172 208 C154 212 148 190 154 174 C158 158 140 140 152 118Z"), "green"),
         d_fill(path("M160 52 C174 44 194 54 190 70 C186 82 166 80 160 70Z"), "green"),
         d_fill(path("M60 170 C76 166 96 180 92 198 C88 214 64 206 56 190Z"), "green"),
         d_fill(circ(128, 128, 104), "none", stroke="#1a5fc0", sw=10),
     ],
     top=[gloss(ell(88, 76, 40, 20, -32), 0.4), gloss(ell(58, 120, 8, 14, 0), 0.3)])

icon("Quest",
     [F(rect(38, 34, 180, 202, 18), "wood"), F(rect(86, 16, 84, 42, 14), "steel")],
     top=[
         d_fill(rect(56, 56, 144, 164, 10), "white"),
         d_line("M72 98 L86 112 L110 84", "#25b04a", 12),
         d_line("M72 148 L86 162 L110 134", "#25b04a", 12),
         d_fill(rect(74, 180, 26, 26, 6), "none", stroke="#9aa3b8", sw=6),
         d_fill(rect(122, 92, 62, 13, 6.5), "#c6cee0"),
         d_fill(rect(122, 142, 62, 13, 6.5), "#c6cee0"),
         d_fill(rect(122, 187, 62, 13, 6.5), "#c6cee0"),
         d_fill(circ(128, 34, 8), INK),
         gloss(rect(96, 22, 64, 8, 4), 0.55),
     ])

icon("Pickaxe",
     [
         S(path("M58 230 L138 58", ' stroke-linecap="round"'), "wood", 26),
         F(path("M28 118 C52 62 108 34 164 36 C190 37 214 46 232 62 C204 56 176 58 150 70 C120 84 86 104 28 118Z"), "steel"),
         F(rect(118, 44, 40, 40, 8, 25), "steelDark"),
     ],
     top=[
         d_line("M52 98 C80 66 120 50 168 46", "#ffffff", 8, 0.65),
         d_line("M70 206 L120 96", "#ffffff", 6, 0.35),
         d_fill(rect(59, 191, 30, 10, 4, 25), "woodDark"),
         d_fill(rect(68, 172, 30, 10, 4, 25), "woodDark"),
     ])

icon("Home",
     [
         F(rect(168, 40, 28, 64, 4), "brick"),
         F(rect(56, 108, 144, 122, 10), "cream"),
         F(path("M28 118 L128 30 L228 118 C232 123 229 132 220 132 L36 132 C27 132 24 123 28 118Z"), "red"),
     ],
     top=[
         d_fill(rect(106, 160, 44, 70, 12), "wood", stroke="#6a3a1c", sw=6),
         d_fill(circ(138, 198, 5), "gold"),
         d_fill(rect(68, 152, 28, 28, 5), "blueLight", stroke="#6a3a1c", sw=6),
         d_fill(rect(160, 152, 28, 28, 5), "blueLight", stroke="#6a3a1c", sw=6),
         d_line("M58 108 L128 46", "#ffffff", 9, 0.5),
         gloss(rect(162, 36, 40, 8, 4), 0.35),
     ])

icon("Clock",
     [F(rect(110, 14, 36, 26, 9), "gold"), F(circ(128, 136, 100), "gold")],
     top=[
         d_fill(circ(128, 136, 80), "white", stroke="#c67a00", sw=6),
     ]
     + [d_line("M%.1f %.1f L%.1f %.1f" % (128 + 64 * math.cos(math.radians(a)), 136 + 64 * math.sin(math.radians(a)),
                                          128 + 72 * math.cos(math.radians(a)), 136 + 72 * math.sin(math.radians(a))), INK, 8)
        for a in range(0, 360, 30)]
     + [
         d_line("M128 136 L128 82", INK, 12),
         d_line("M128 136 L164 154", "#e2334a", 10),
         d_fill(circ(128, 136, 11), INK),
         d_line("M62 104 A74 74 0 0 1 104 66", "#ffffff", 12, 0.55),
     ])

icon("Star",
     [F(poly(*star_pts(128, 138, 112, 52)), "gold")],
     top=[
         gloss(poly(*[(128, 50), (114, 116), (74, 124), (128, 136)]), 0.35),
         d_fill(poly(*star_pts(128, 138, 54, 26)), "#fff4b0", 0.55),
     ])

icon("Lock",
     [
         S(path("M82 116 L82 86 C82 30 174 30 174 86 L174 116"), "steel", 26),
         F(rect(42, 104, 172, 128, 24), "gold"),
     ],
     top=[
         d_fill(circ(128, 154, 18), INK),
         d_fill(path("M118 160 L138 160 L144 202 L112 202Z"), INK),
         gloss(rect(56, 114, 144, 13, 6.5), 0.5),
         d_line("M70 70 C76 52 92 42 110 40", "#ffffff", 7, 0.6),
     ])

icon("Bolt",
     [F(poly((152, 14), (56, 142), (118, 142), (94, 242), (202, 106), (138, 106), (178, 14)), "yellow")],
     top=[gloss(poly((150, 30), (82, 128), (100, 128), (162, 34)), 0.5)])

icon("Clover",
     [
         S(path("M134 140 C148 180 160 212 190 236", ' stroke-linecap="round"'), "greenDark", 16),
         F(circ(84, 86, 48), "green"), F(circ(172, 86, 48), "green"),
         F(circ(84, 168, 48), "green"), F(circ(172, 168, 48), "green"),
     ],
     top=[
         d_line("M118 117 L84 86", "#1e8a3a", 7, 0.5), d_line("M138 117 L172 86", "#1e8a3a", 7, 0.5),
         d_line("M118 137 L84 168", "#1e8a3a", 7, 0.5), d_line("M138 137 L172 168", "#1e8a3a", 7, 0.5),
         gloss(ell(66, 66, 16, 9, -40), 0.55), gloss(ell(154, 66, 16, 9, -40), 0.55),
         gloss(ell(66, 148, 16, 9, -40), 0.45), gloss(ell(154, 148, 16, 9, -40), 0.45),
     ])

icon("Drop",
     [F(path("M128 18 C150 64 208 112 208 160 C208 206 172 238 128 238 C84 238 48 206 48 160 C48 112 106 64 128 18Z"), "teal")],
     top=[
         d_line("M84 156 C84 128 98 106 112 92", "#ffffff", 13, 0.65),
         gloss(circ(92, 190, 9), 0.55),
         d_fill(path("M128 140 C150 150 164 170 160 196 C138 198 124 180 128 140Z"), "#0f8a7c", 0.45),
     ])

icon("Flask",
     [F(rect(104, 46, 48, 84, 10), "glass"), F(circ(128, 166, 76), "glass"), F(rect(88, 26, 80, 28, 13), "wood")],
     clip=[
         d_fill(rect(30, 150, 200, 110), "gold"),
         d_fill(ell(128, 151, 74, 10), "#fff2a6"),
     ],
     top=[
         gloss(circ(106, 196, 9), 0.75), gloss(circ(140, 214, 6), 0.7), gloss(circ(152, 178, 5), 0.7),
         d_line("M74 140 A60 60 0 0 1 100 110", "#ffffff", 10, 0.75),
         d_line("M114 58 L114 104", "#ffffff", 7, 0.6),
         gloss(rect(98, 32, 50, 7, 3.5), 0.4),
     ])

icon("Backpack",
     [
         S(path("M98 48 C98 18 158 18 158 48"), "steelDark", 16),
         F(rect(46, 40, 164, 194, 42), "blue"),
     ],
     clip=[d_fill(rect(30, 90, 200, 22), "#2366c9", 0.75), gloss(rect(60, 56, 20, 64, 10), 0.4)],
     top=[
         d_fill(rect(72, 136, 112, 80, 22), "blueLight", stroke="#1d4f9e", sw=6),
         d_fill(rect(114, 128, 28, 22, 5), "gold", stroke="#c67a00", sw=5),
         d_line("M84 178 L172 178", "#1d4f9e", 6, 0.6),
     ])

icon("Egg",
     [F(path("M128 16 C186 16 222 104 222 154 C222 208 180 240 128 240 C76 240 34 208 34 154 C34 104 70 16 128 16Z"), "cream")],
     clip=[
         d_fill(circ(84, 132, 20), "pink"),
         d_fill(circ(168, 96, 15), "blue"),
         d_fill(circ(164, 180, 24), "green"),
         d_fill(circ(98, 200, 13), "purple"),
         d_fill(circ(196, 136, 10), "orange"),
         d_fill(circ(128, 70, 10), "teal"),
     ],
     top=[gloss(ell(92, 74, 16, 30, 22), 0.85)])

icon("Sword",
     [
         F(poly((128, 10), (152, 38), (152, 162), (104, 162), (104, 38)), "steel"),
         F(rect(118, 172, 20, 56, 8), "wood"),
         F(rect(66, 154, 124, 26, 13), "gold"),
         F(circ(128, 234, 15), "gold"),
     ],
     top=[
         gloss(poly((116, 40), (128, 24), (128, 154), (116, 154)), 0.55),
         d_line("M140 44 L140 150", "#5d6d8c", 5, 0.5),
         d_fill(circ(128, 167, 7), "red"),
     ],
     transform="rotate(45 128 128) translate(0 -6)")

icon("Crown",
     [
         F(path("M30 92 L84 140 L128 58 L172 140 L226 92 L206 210 L50 210Z"), "gold"),
         F(circ(30, 86, 16), "gold"), F(circ(128, 50, 18), "gold"), F(circ(226, 86, 16), "gold"),
     ],
     clip=[d_fill(rect(30, 186, 200, 30), "#ffa514"), d_line("M30 186 L226 186", "#c67a00", 6)],
     top=[
         d_fill(circ(128, 158, 17), "red", stroke="#a01f33", sw=5),
         d_fill(circ(78, 172, 11), "blue", stroke="#1d4f9e", sw=4),
         d_fill(circ(178, 172, 11), "green", stroke="#16843a", sw=4),
         gloss(poly((122, 76), (128, 66), (100, 128), (92, 128)), 0.55),
         gloss(circ(122, 44, 5), 0.8),
     ])

icon("Rocket",
     [
         F(path("M104 194 C104 226 128 252 128 252 C128 252 152 226 152 194Z"), "fire"),
         F(path("M88 128 L44 176 L50 212 L92 186Z"), "red"),
         F(path("M168 128 L212 176 L206 212 L164 186Z"), "red"),
         F(path("M128 12 C170 50 182 112 172 180 L84 180 C74 112 86 50 128 12Z"), "white"),
         F(rect(98, 174, 60, 22, 6), "steelDark"),
     ],
     clip=[d_fill(rect(60, 0, 140, 50), "red"), d_line("M84 50 L172 50", "#a01f33", 6)],
     top=[
         d_fill(circ(128, 98, 22), "blueLight", stroke="#5d6d8c", sw=8),
         gloss(circ(121, 91, 6), 0.8),
         d_line("M104 62 C98 92 98 130 102 162", "#ffffff", 8, 0.7),
         d_fill(path("M116 198 C116 216 128 232 128 232 C128 232 140 216 140 198Z"), "yellow"),
     ],
     transform="rotate(40 128 128) translate(0 6)")

icon("Gear",
     [F(path(gear_path(128, 128, 112, 84, 8)), "silver")],
     top=[
         d_fill(circ(128, 128, 40), "steelDark", stroke=INK, sw=7),
         d_fill(circ(128, 128, 16), INK),
         d_line("M62 92 A72 72 0 0 1 96 60", "#ffffff", 10, 0.6),
     ])

icon("Note",
     [
         F(ell(76, 196, 38, 28, -22), "violet"),
         F(ell(188, 170, 38, 28, -22), "violet"),
         F(rect(96, 54, 22, 144, 6), "violet"),
         F(rect(208, 30, 22, 142, 6), "violet"),
         F(poly((96, 54), (230, 26), (230, 72), (96, 100)), "violet"),
     ],
     top=[gloss(ell(66, 188, 13, 7, -22), 0.6), gloss(ell(178, 162, 13, 7, -22), 0.6), gloss(poly((106, 62), (220, 38), (220, 46), (106, 70)), 0.45)])

icon("Diamond",
     [F(poly((70, 46), (186, 46), (236, 102), (128, 236), (20, 102)), "cyan")],
     top=[
         d_fill(poly((70, 46), (186, 46), (236, 102), (20, 102)), "#ffffff", 0.3),
         d_line("M20 102 L236 102", "#1f7fb8", 6, 0.75),
         d_line("M70 46 L98 102 L128 46 L158 102 L186 46", "#1f7fb8", 6, 0.75),
         d_line("M98 102 L128 234 L158 102", "#1f7fb8", 6, 0.75),
         gloss(poly((80, 56), (112, 56), (90, 94), (56, 94)), 0.6),
     ])

icon("Bone",
     [
         S(path("M76 180 L180 76", ' stroke-linecap="round"'), "cream", 46),
         F(circ(56, 170, 30), "cream"), F(circ(86, 200, 30), "cream"),
         F(circ(170, 56, 30), "cream"), F(circ(200, 86, 30), "cream"),
     ],
     top=[gloss(ell(160, 46, 12, 7, -40), 0.8), gloss(ell(46, 160, 12, 7, -40), 0.8), d_line("M100 140 L140 100", "#ffffff", 8, 0.7)])

_snow = []
for a in (90, 30, 150):
    ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
    _snow.append(S(path("M%.1f %.1f L%.1f %.1f" % (128 - 104 * ca - 0.6, 128 - 104 * sa, 128 + 104 * ca + 0.6, 128 + 104 * sa), ' stroke-linecap="round"'), "ice", 24))
for a in range(-90, 270, 60):
    ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
    px, py = 128 + 66 * ca, 128 + 66 * sa
    for da in (-40, 40):
        b = math.radians(a + da)
        _snow.append(S(path("M%.1f %.1f L%.1f %.1f" % (px, py, px + 34 * math.cos(b), py + 34 * math.sin(b)), ' stroke-linecap="round"'), "ice", 18))
_snow.append(F(poly(*[(128 + 34 * math.cos(math.radians(a)), 128 + 34 * math.sin(math.radians(a))) for a in range(-90, 270, 60)]), "ice"))
icon("Snowflake", _snow, top=[d_fill(circ(128, 128, 12), "#ffffff", 0.9), d_line("M128 40 L128 92", "#ffffff", 7, 0.7)])

icon("Flame",
     [F(path("M128 14 C150 60 208 94 208 160 C208 208 172 240 128 240 C84 240 48 208 48 160 C48 120 72 98 86 68 C96 96 104 108 116 112 C112 80 116 44 128 14Z"), "fire")],
     top=[
         d_fill(path("M128 108 C140 140 174 156 174 190 C174 216 154 234 128 234 C102 234 82 216 82 190 C82 166 98 154 108 138 C114 154 120 160 126 160 C122 140 122 124 128 108Z"), "yellow"),
         d_fill(path("M128 172 C138 188 150 196 148 212 C146 224 138 230 128 230 C118 230 110 224 108 212 C106 196 120 188 128 172Z"), "#fffbe0"),
         d_line("M76 150 C76 130 84 116 94 104", "#ffffff", 9, 0.45),
     ])

icon("Saturn",
     [
         S(ell(128, 132, 118, 34, -18), "gold", 18),
         F(circ(128, 128, 76), "purple"),
     ],
     clip=[
         d_fill(ell(128, 104, 90, 10, -18), "#ffffff", 0.22),
         d_fill(ell(128, 150, 90, 12, -18), "#5b2bb5", 0.35),
         gloss(ell(98, 86, 26, 14, -35), 0.4),
     ],
     top=[
         '<path d="M10 132 A118 34 0 0 0 246 132" transform="rotate(-18 128 132)" fill="none" stroke="%s" stroke-width="%g" stroke-linecap="round"/>' % (INK, 18 + SW * 0.6),
         '<path d="M10 132 A118 34 0 0 0 246 132" transform="rotate(-18 128 132)" fill="none" stroke="url(#g-gold)" stroke-width="18" stroke-linecap="round"/>',
     ])

icon("Shield",
     [F(path("M128 16 L218 48 C218 140 188 202 128 240 C68 202 38 140 38 48Z"), "silver")],
     top=[
         d_fill(path("M128 42 L194 66 C192 136 170 184 128 214 C86 184 64 136 62 66Z"), "blue", stroke="#1d4f9e", sw=5),
         d_fill(poly(*star_pts(128, 128, 44, 20)), "#ffffff", stroke="#ffffff", sw=4),
         d_line("M60 60 L60 110", "#ffffff", 8, 0.6),
     ])

icon("Person",
     [F(circ(128, 80, 54), "blue"), F(path("M36 232 C36 168 78 140 128 140 C178 140 220 168 220 232Z"), "blue")],
     top=[gloss(ell(108, 58, 18, 11, -30), 0.55), gloss(ell(78, 178, 16, 9, -45), 0.45)])

icon("Flag",
     [
         S(path("M61 34 L63 238", ' stroke-linecap="round"'), "steel", 18),
         F(path("M70 42 C110 24 140 58 180 46 C198 40 212 36 222 40 L222 138 C200 130 180 142 160 146 C120 152 100 126 70 138Z"), "red"),
         F(circ(62, 28, 16), "gold"),
     ],
     top=[
         d_fill(poly(*star_pts(146, 92, 30, 13)), "#ffffff", stroke="#ffffff", sw=3),
         gloss(circ(56, 22, 5), 0.8),
         d_line("M84 58 C108 46 132 64 160 60", "#ffffff", 7, 0.45),
     ])

ORDER = [
    "Coin", "Shard", "Paw", "Chest", "ShopBag", "Stats", "Gift",
    "Wheel", "Sprout", "Hourglass", "Globe", "Quest", "Pickaxe", "Home",
    "Clock", "Star", "Lock", "Bolt", "Clover", "Drop", "Flask",
    "Backpack", "Egg", "Sword", "Crown", "Rocket", "Gear", "Note",
    "Diamond", "Bone", "Snowflake", "Flame", "Saturn", "Shield", "Person",
    "Flag",
]
assert set(ORDER) == set(ICONS), set(ICONS) ^ set(ORDER)


# ---------------------------------------------------------------------------------------------
# Сборка SVG
# ---------------------------------------------------------------------------------------------
def render_icon(name, uid):
    ic = ICONS[name]
    base = ic["base"]

    def shapes(mode, dy=0):
        out = []
        for sh in base:
            kind, markup = sh[0], sh[1]
            if mode == "fill":
                c = paint(sh[2])
                if kind == "fill":
                    # обводка тем же цветом скругляет острые углы заливки
                    out.append('%s fill="%s" stroke="%s" stroke-width="6" stroke-linejoin="round"/>' % (markup, c, c))
                else:
                    out.append('%s fill="none" stroke="%s" stroke-width="%g" stroke-linejoin="round"/>' % (markup, c, sh[3]))
            else:
                w = SW + 6 if kind == "fill" else sh[3] + SW
                fill = INK if kind == "fill" else "none"
                out.append('%s fill="%s" stroke="%s" stroke-width="%g" stroke-linejoin="round"/>' % (markup, fill, INK, w))
        g = "".join(out)
        if dy:
            return '<g transform="translate(0 %g)" opacity="0.38">%s</g>' % (dy, g)
        return g

    clip_id = "c%s" % uid
    clip_shapes = "".join('%s/>' % sh[1] for sh in base if sh[0] == "fill")
    parts = [
        '<clipPath id="%s">%s</clipPath>' % (clip_id, clip_shapes),
        shapes("outline", 11),
        shapes("outline"),
        shapes("fill"),
    ]
    if ic["clip"]:
        parts.append('<g clip-path="url(#%s)">%s</g>' % (clip_id, "".join(ic["clip"])))
    parts.extend(ic["top"])
    body = "".join(parts)
    if ic["transform"]:
        body = '<g transform="%s">%s</g>' % (ic["transform"], body)
    # общий отступ: фигуры рисуются в 16..240, ужимаем, чтобы обводка и тень влезли в ячейку
    return '<g transform="translate(128 124) scale(0.84) translate(-128 -128)">%s</g>' % body


def svg_doc(w, h, inner):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><defs>%s</defs>%s</svg>'
            % (w, h, w, h, grad_defs(), inner))


def main():
    os.makedirs(os.path.join(OUT, "svg"), exist_ok=True)
    for i, name in enumerate(ORDER):
        with open(os.path.join(OUT, "svg", name + ".svg"), "w", encoding="utf-8") as f:
            f.write(svg_doc(256, 256, render_icon(name, i)))
    cells = []
    k = CELL / 256
    for i, name in enumerate(ORDER):
        x, y = (i % COLS) * CELL, (i // COLS) * CELL
        cells.append('<g transform="translate(%g %g) scale(%g)">%s</g>' % (x, y, k, render_icon(name, i)))
    with open(os.path.join(OUT, "atlas.svg"), "w", encoding="utf-8") as f:
        f.write(svg_doc(1024, 1024, "".join(cells)))

    lua = [
        "-- IconAtlas: раскладка атласа цветных иконок (Icons/ChronoDrill_Icons.png).",
        "-- Файл собирает tools/make_icons.py — раскладку руками не править.",
        "--",
        "-- Как включить: в Studio View -> Asset Manager -> Bulk Import -> Icons/ChronoDrill_Icons.png,",
        "-- затем ПКМ по картинке -> Copy Asset ID и впиши его в Id ниже (можно просто число):",
        '--   Id = "rbxassetid://1234567890",',
        "-- Пока Id пустой, игра рисует прежние векторные иконки (UI/Icons2D).",
        "-- Важно: нужен ID картинки (Image), а не декали (Decal) — подробности в README.",
        "return {",
        '\tId = "",',
        "\tCell = %d," % CELL,
        "\tColumns = %d," % COLS,
        "\tIcons = {",
    ]
    for i, name in enumerate(ORDER):
        lua.append("\t\t%s = %d," % (name, i))
    lua += ["\t},", "}", ""]
    with open(os.path.join(ROOT, "src", "ReplicatedStorage", "Configs", "IconAtlas.lua"), "w", encoding="utf-8") as f:
        f.write("\n".join(lua))
    print("icons:", len(ORDER))


if __name__ == "__main__":
    main()
