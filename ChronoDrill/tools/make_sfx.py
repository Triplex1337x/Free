#!/usr/bin/env python3
"""Синтез собственных звуков и музыки Chrono-Drill (без чужих сэмплов).

Пишет .ogg (и .wav) в build/SFX:
  * звуки интерфейса и игры — мягкие, «мультяшные», без взрывов и резких щелчков;
  * 3 зацикленных фоновых трека: Music_Hub (база), Music_Mine (шахта), Music_Deep (Магма и Бездна).

Запуск: python3 tools/make_sfx.py
"""
import os
import subprocess
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "SFX")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def secs(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.25, curve=4.0, hold=0.0):
    x = np.arange(n) / SR
    att = np.clip(x / max(a, 1e-4), 0, 1)
    dec = np.exp(-curve * np.clip(x - a - hold, 0, None) / max(d, 1e-4))
    return att * dec


def lowpass(x, f, order=2):
    b, a = butter(order, min(f, SR / 2 - 100) / (SR / 2), btype="low")
    return lfilter(b, a, x)


def highpass(x, f, order=2):
    b, a = butter(order, f / (SR / 2), btype="high")
    return lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return lfilter(b, a, x)


def osc(freq, d, kind="sine"):
    tt = secs(d)
    if callable(freq):
        ph = 2 * np.pi * np.cumsum(freq(tt)) / SR
    else:
        ph = 2 * np.pi * freq * tt
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == "soft":  # мягкий «органчик»
        return np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    return np.sin(ph)


def bell(f, d=0.6, a=0.003, dec=0.35, bright=0.5):
    """Колокольчик / маримба: несколько гармоник с разным затуханием."""
    tt = secs(d)
    s = np.sin(2 * np.pi * f * tt) * np.exp(-tt / dec)
    s += bright * 0.5 * np.sin(2 * np.pi * f * 2.0 * tt) * np.exp(-tt / (dec * 0.5))
    s += bright * 0.25 * np.sin(2 * np.pi * f * 3.01 * tt) * np.exp(-tt / (dec * 0.3))
    s += bright * 0.12 * np.sin(2 * np.pi * f * 4.2 * tt) * np.exp(-tt / (dec * 0.2))
    return s * np.clip(tt / a, 0, 1)


def pluck(f, d=0.5, damp=0.996):
    """Karplus–Strong: мягкий щипок струны."""
    n = int(SR * d)
    period = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, period)
    buf = lowpass(buf, 3000)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damp * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def place(dst, sig, at, gain=1.0):
    i = int(at * SR)
    if i >= len(dst):
        return
    j = min(len(dst), i + len(sig))
    dst[i:j] += sig[: j - i] * gain


def reverb(x, wet=0.25, room=0.82, tail=1.2):
    """Простой Шрёдер: 4 гребенчатых + 2 всепропускающих фильтра."""
    n = len(x) + int(tail * SR)
    dry = np.concatenate([x, np.zeros(n - len(x))])
    out = np.zeros(n)
    for dl in (1557, 1617, 1491, 1422):
        buf = np.zeros(n)
        for i in range(dl, n):
            buf[i] = dry[i - dl] + room * buf[i - dl]
        out += buf
    out /= 4
    for dl, g in ((225, 0.5), (556, 0.5)):
        y = np.zeros(n)
        for i in range(n):
            xd = out[i - dl] if i >= dl else 0
            yd = y[i - dl] if i >= dl else 0
            y[i] = -g * out[i] + xd + g * yd
        out = y
    out = lowpass(out, 6000)
    return dry * (1 - wet) + out * wet


def fast_reverb(x, wet=0.25, decay=0.5, taps=((0.031, 0.7), (0.047, 0.6), (0.073, 0.5), (0.109, 0.4), (0.163, 0.3), (0.241, 0.22))):
    """Быстрый «мультитап» для длинных треков."""
    out = x.copy()
    for t_, g in taps:
        d = int(t_ * SR)
        out[d:] += x[:-d] * g * wet
    # второй проход для хвоста
    tail = out.copy()
    for t_, g in taps:
        d = int((t_ * 3.1) * SR)
        if d < len(out):
            out[d:] += tail[:-d] * g * wet * decay
    return lowpass(out, 9000)


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def fade(x, fin=0.002, fout=0.03):
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def save(name, x, peak=0.85, wav=True):
    x = norm(np.asarray(x, dtype=np.float64), peak)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    wavfile.write(path, SR, data)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".ogg")], check=True)
    if not wav:
        os.remove(path)
    print("saved", name, f"{len(x) / SR:.2f}s")


def note(n):
    """MIDI -> Гц"""
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------------------------------------------------------------------------------------------
# ЗВУКИ
# ---------------------------------------------------------------------------------------------
def sfx():
    # мягкий клик интерфейса
    c = bell(1800, 0.09, dec=0.025, bright=0.2) * 0.6
    place(c, lowpass(noise(0.02), 4000) * env(int(0.02 * SR), 0.001, 0.008), 0, 0.2)
    save("Click", fade(c), 0.6)
    save("Hover", fade(bell(2600, 0.06, dec=0.015, bright=0.1)), 0.35)

    # удар бура: глухой «ток» (низкий синус с падением + капля шума), без щелчка
    d = 0.11
    tt = secs(d)
    thump = np.sin(2 * np.pi * np.cumsum(180 * np.exp(-tt * 25) + 90) / SR) * env(len(tt), 0.002, 0.04)
    grit = bandpass(noise(d), 900, 2600) * env(len(tt), 0.001, 0.02) * 0.35
    save("DrillHit", fade(thump + grit), 0.55)

    # крит: звонкий «дзынь»
    cr = bell(1320, 0.5, dec=0.18, bright=0.8) + bell(1980, 0.5, dec=0.12, bright=0.4) * 0.5
    save("Crit", fade(reverb(cr, 0.2, tail=0.3)), 0.6)

    # разлом блока: мягкий «поп» + рассыпающиеся камушки (а не взрыв)
    d = 0.45
    pop = np.sin(2 * np.pi * np.cumsum(420 * np.exp(-secs(d) * 30) + 140) / SR) * env(int(d * SR), 0.002, 0.05)
    crumble = np.zeros(int(d * SR))
    for k in range(9):
        at = 0.02 + k * 0.035 + rng.uniform(0, 0.02)
        g = bandpass(noise(0.03), 1500 + rng.uniform(0, 1500), 5000) * env(int(0.03 * SR), 0.001, 0.01)
        place(crumble, g, at, 0.35 * (1 - k / 10))
    save("BlockBreak", fade(pop * 0.9 + crumble), 0.55)

    # руда в рюкзак: крошечный «блинк»
    save("OrePickup", fade(bell(1568, 0.18, dec=0.06, bright=0.3) + bell(2093, 0.18, dec=0.05, bright=0.2) * 0.6), 0.4)

    # монеты: короткий перезвон
    co = np.zeros(int(0.6 * SR))
    for i, n in enumerate([84, 88, 91, 96]):
        place(co, bell(note(n), 0.4, dec=0.12, bright=0.6), i * 0.055, 0.8)
    save("Coins", fade(reverb(co, 0.18, tail=0.25)), 0.6)

    # яйцо: тряска (деревянное постукивание) и мягкий треск скорлупы
    sh = np.zeros(int(0.4 * SR))
    for i in range(4):
        place(sh, bandpass(noise(0.04), 600, 1800) * env(int(0.04 * SR), 0.001, 0.015), i * 0.09, 0.7)
        place(sh, bell(520 + i * 40, 0.08, dec=0.03, bright=0.2), i * 0.09, 0.4)
    save("EggShake", fade(sh), 0.5)
    ck = np.zeros(int(0.5 * SR))
    for i in range(5):
        place(ck, highpass(noise(0.025), 2000) * env(int(0.025 * SR), 0.0005, 0.006), 0.02 + i * 0.03, 0.6 - i * 0.08)
    place(ck, bell(880, 0.4, dec=0.12, bright=0.3), 0.0, 0.3)
    save("EggCrack", fade(reverb(ck, 0.15, tail=0.2)), 0.55)

    # появление питомца: искристое арпеджио вверх
    rv = np.zeros(int(1.4 * SR))
    for i, n in enumerate([72, 76, 79, 84, 88, 91, 96]):
        place(rv, bell(note(n), 0.7, dec=0.25, bright=0.7), i * 0.06, 0.7)
    place(rv, osc(note(60), 1.2, "soft") * env(int(1.2 * SR), 0.05, 0.5, hold=0.2) * 0.25, 0)
    save("Reveal", fade(reverb(rv, 0.3, tail=0.6)), 0.7)

    # предупреждение и сирена вайпа — мягкие, но заметные
    wn = np.zeros(int(0.7 * SR))
    for i, n in enumerate([76, 72]):
        place(wn, osc(note(n), 0.28, "soft") * env(int(0.28 * SR), 0.01, 0.12, hold=0.08), i * 0.3, 0.7)
    save("Warning", fade(reverb(wn, 0.2, tail=0.3)), 0.6)
    d = 1.2
    sweep = osc(lambda x: 520 + 140 * np.sin(2 * np.pi * 1.6 * x), d, "tri") * env(int(d * SR), 0.05, 0.9, hold=0.4)
    save("Siren", fade(lowpass(sweep, 2500)), 0.55)

    # телепорт: воздушный «вжух» вверх + блёстки
    d = 0.7
    wh = bandpass(noise(d), 300, 3000)
    wh = lowpass(wh * np.linspace(0.2, 1, len(wh)), 4000) * env(len(wh), 0.25, 0.25)
    up = osc(lambda x: 300 + 900 * x / d, d, "sine") * env(int(d * SR), 0.05, 0.4) * 0.3
    tp = wh * 0.6 + up
    place(tp, bell(note(96), 0.4, dec=0.15), 0.42, 0.4)
    save("Teleport", fade(reverb(tp, 0.25, tail=0.4)), 0.6)

    # открытие / покупка: мажорный фанфар-аккорд
    un = np.zeros(int(1.3 * SR))
    for i, n in enumerate([67, 72, 76]):
        place(un, bell(note(n), 0.5, dec=0.18, bright=0.6), i * 0.08, 0.6)
    for n in (72, 76, 79, 84):
        place(un, osc(note(n), 0.9, "soft") * env(int(0.9 * SR), 0.01, 0.45, hold=0.15), 0.26, 0.22)
    save("Unlock", fade(reverb(un, 0.3, tail=0.5)), 0.7)

    # ошибка: мягкое «бум-бум» вниз
    er = np.zeros(int(0.35 * SR))
    for i, n in enumerate([60, 55]):
        place(er, osc(note(n), 0.14, "soft") * env(int(0.14 * SR), 0.005, 0.06), i * 0.12, 0.7)
    save("Error", fade(lowpass(er, 1800)), 0.45)

    # рюкзак полон: мягкий «бонк»
    d = 0.3
    bk = osc(lambda x: 330 * np.exp(-x * 4), d, "soft") * env(int(d * SR), 0.003, 0.12)
    save("Full", fade(lowpass(bk, 2000)), 0.5)

    # семя: волшебный перелив
    sd = np.zeros(int(1.0 * SR))
    for i, n in enumerate([79, 83, 86, 91, 95]):
        place(sd, bell(note(n), 0.5, dec=0.2, bright=0.4), i * 0.07, 0.6)
    save("Seed", fade(reverb(sd, 0.35, tail=0.5)), 0.6)

    # уровень питомца: бодрое арпеджио
    lv = np.zeros(int(0.9 * SR))
    for i, n in enumerate([72, 76, 79, 84]):
        place(lv, pluck(note(n), 0.5), i * 0.07, 0.64)
        place(lv, bell(note(n + 12), 0.4, dec=0.1, bright=0.2), i * 0.07, 0.24)
    save("LevelUp", fade(reverb(lv, 0.25, tail=0.4)), 0.6)

    # улучшение питомца (★): шиммер + аккорд
    ug = np.zeros(int(1.6 * SR))
    for i in range(12):
        place(ug, bell(note(84 + (i * 5) % 17), 0.4, dec=0.12, bright=0.5), i * 0.035, 0.35)
    for n in (60, 64, 67, 72):
        place(ug, osc(note(n), 1.2, "soft") * env(int(1.2 * SR), 0.02, 0.6, hold=0.2), 0.4, 0.2)
    save("Upgrade", fade(reverb(ug, 0.35, tail=0.6)), 0.7)


# ---------------------------------------------------------------------------------------------
# МУЗЫКА
# ---------------------------------------------------------------------------------------------
def kick(d=0.35):
    tt = secs(d)
    return np.sin(2 * np.pi * np.cumsum(60 + 110 * np.exp(-tt * 30)) / SR) * env(len(tt), 0.002, 0.12)


def hat(d=0.06):
    return highpass(noise(d), 7000) * env(int(d * SR), 0.0005, 0.02)


def shaker(d=0.08):
    return bandpass(noise(d), 4000, 9000) * env(int(d * SR), 0.01, 0.03)


def pad(freqs, d, bright=0.3):
    tt = secs(d)
    s = np.zeros(len(tt))
    for f in freqs:
        for det in (-0.12, 0.12):
            s += osc(f * (1 + det / 100), d, "soft")
    s = lowpass(s, 900 + 1500 * bright)
    e = np.clip(tt / 0.6, 0, 1) * np.clip((d - tt) / 0.6, 0, 1)
    return s * e / len(freqs)


def track(name, bpm, chords, bars_per_chord=2, loops=2, mood="bright"):
    """chords: список [(бас_midi, [аккорд_midi...]), ...]. Трек = loops x прогрессия, бесшовный."""
    beat = 60 / bpm
    bar = beat * 4
    total = bar * bars_per_chord * len(chords) * loops
    n = int(total * SR)
    mix = np.zeros(n + int(4 * SR))
    t0 = 0.0
    melody_scale = {
        "bright": [0, 2, 4, 7, 9, 12, 14, 16],
        "calm": [0, 3, 5, 7, 10, 12, 15],
        "deep": [0, 2, 3, 7, 8, 12, 14],
    }[mood]
    for lp in range(loops):
        for ci, (bass, chord) in enumerate(chords):
            dur = bar * bars_per_chord
            # пэд
            place(mix, pad([note(m) for m in chord], dur + 0.4, 0.25 if mood == "deep" else 0.45), t0, 0.32)
            # бас: на 1 и 3 долю
            for b in range(bars_per_chord * 4):
                if b % 2 == 0:
                    bs = osc(note(bass), beat * 1.6, "soft") * env(int(beat * 1.6 * SR), 0.01, beat * 0.9)
                    place(mix, lowpass(bs, 500), t0 + b * beat, 0.42)
            # арпеджио (маримба / щипок) восьмыми
            arp = chord + [chord[1] + 12, chord[2] + 12]
            for s8 in range(bars_per_chord * 8):
                if mood == "deep" and s8 % 2 == 1:
                    continue
                nn = arp[(s8 * 3 + ci) % len(arp)] + 12
                at = t0 + s8 * beat / 2
                if mood == "bright":
                    place(mix, bell(note(nn), 0.6, dec=0.22, bright=0.35), at, 0.16)
                else:
                    place(mix, pluck(note(nn), 0.7, 0.9965), at, 0.15)
            # мелодия: пара нот на такт, на второй половине цикла
            if lp == 1 or ci % 2 == 1:
                for b in range(bars_per_chord):
                    for k in range(2):
                        deg = melody_scale[(ci * 3 + b * 2 + k * 5 + lp) % len(melody_scale)]
                        nn = chord[0] + 12 + deg
                        at = t0 + b * bar + k * beat * 2 + (beat if k else 0) * 0.5
                        place(mix, bell(note(nn), 1.2, dec=0.5, bright=0.5), at, 0.13)
            # ритм
            for b in range(bars_per_chord * 4):
                at = t0 + b * beat
                if mood != "deep" or b % 4 == 0:
                    if b % 2 == 0:
                        place(mix, kick(), at, 0.35 if mood == "bright" else 0.3)
                place(mix, shaker(), at + beat / 2, 0.08)
                if mood == "bright":
                    place(mix, hat(), at + beat * 0.75, 0.05)
            t0 += dur
    mix = fast_reverb(mix, wet=0.35)
    # бесшовная петля: хвост после конца накладываем на начало
    body = mix[:n].copy()
    tail = mix[n:]
    body[: len(tail)] += tail[: len(body)]
    save(name, body, 0.8, wav=False)


def music():
    # База: светлый, тёплый (C - Am - F - G), 92 bpm
    track("Music_Hub", 92, [(48, [60, 64, 67, 71]), (45, [57, 60, 64, 67]), (41, [57, 60, 65, 69]), (43, [55, 59, 62, 67])], 2, 2, "bright")
    # Шахта: задумчивый грув (Am - F - C - G), 84 bpm
    track("Music_Mine", 84, [(45, [57, 60, 64, 67]), (41, [57, 60, 65, 69]), (48, [55, 60, 64, 67]), (43, [55, 59, 62, 67])], 2, 2, "calm")
    # Глубины: тёмный и загадочный (Dm - Bb - Gm - A), 70 bpm
    track("Music_Deep", 70, [(38, [50, 53, 57, 62]), (46, [50, 53, 58, 62]), (43, [50, 55, 58, 62]), (45, [49, 52, 57, 61])], 2, 2, "deep")


if __name__ == "__main__":
    sfx()
    music()
