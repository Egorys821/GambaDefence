"""Generates all sound effects and music for Gamba Defence (chiptune style).

Usage (from the project root, plain Python 3, no extra packages):
    python tools/generate_audio.py

Every sound is a small function built from oscillators, noise and envelopes.
Tweak a function, re-run the script, and Godot re-imports the WAV files.
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
TAU = 2 * math.pi
ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"
rng = random.Random(1234)

NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
              "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


# --------------------------------------------------------------------------
# Synth building blocks
# --------------------------------------------------------------------------
def freq(note) -> float:
    if isinstance(note, (int, float)):
        return float(note)
    midi = 12 * (int(note[-1]) + 1) + NOTE_INDEX[note[:-1]]
    return 440.0 * 2 ** ((midi - 69) / 12)


def _wave(kind: str, phase: float, duty: float) -> float:
    if kind == "square":
        return 1.0 if phase < duty else -1.0
    if kind == "triangle":
        return 4 * phase - 1 if phase < 0.5 else 3 - 4 * phase
    if kind == "saw":
        return 2 * phase - 1
    return math.sin(TAU * phase)


def tone(note, dur, kind="square", vol=0.5, attack=0.004, decay=0.0, sustain=1.0,
         release=0.02, duty=0.5, slide_to=None, vibrato_rate=0.0, vibrato_depth=0.0):
    """One oscillator note. decay = time constant of the exponential fall to `sustain`."""
    f0 = freq(note)
    f1 = freq(slide_to) if slide_to is not None else f0
    n = max(1, int(dur * SR))
    att = max(1, int(attack * SR))
    rel = max(1, int(release * SR))
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = f0 * (f1 / f0) ** (i / n) if f1 != f0 else f0
        if vibrato_depth:
            f *= 1 + vibrato_depth * math.sin(TAU * vibrato_rate * t)
        phase = (phase + f / SR) % 1.0
        if i < att:
            env = i / att
        elif decay > 0:
            env = sustain + (1 - sustain) * math.exp(-(t - attack) / decay)
        else:
            env = 1.0
        if i > n - rel:
            env *= (n - i) / rel
        out[i] = _wave(kind, phase, duty) * env * vol
    return out


def noise(dur, vol=0.5, decay=0.0, hold=1, attack=0.001, release=0.01):
    """White noise. `hold` > 1 repeats samples for a lower, crunchier sound."""
    n = max(1, int(dur * SR))
    att = max(1, int(attack * SR))
    rel = max(1, int(release * SR))
    out = [0.0] * n
    value = 0.0
    for i in range(n):
        if i % hold == 0:
            value = rng.uniform(-1, 1)
        env = min(1.0, i / att)
        if decay > 0:
            env *= math.exp(-(i / SR) / decay)
        if i > n - rel:
            env *= (n - i) / rel
        out[i] = value * env * vol
    return out


def lowpass(x, cutoff):
    rc = 1 / (TAU * cutoff)
    alpha = (1 / SR) / (rc + 1 / SR)
    out, y = [0.0] * len(x), 0.0
    for i, s in enumerate(x):
        y += alpha * (s - y)
        out[i] = y
    return out


def highpass(x, cutoff):
    rc = 1 / (TAU * cutoff)
    alpha = rc / (rc + 1 / SR)
    out, prev_x, y = [0.0] * len(x), 0.0, 0.0
    for i, s in enumerate(x):
        y = alpha * (y + s - prev_x)
        prev_x = s
        out[i] = y
    return out


def mix_into(buf, x, start_sec, gain=1.0):
    start = int(start_sec * SR)
    if start + len(x) > len(buf):
        buf.extend([0.0] * (start + len(x) - len(buf)))
    for i, s in enumerate(x):
        buf[start + i] += s * gain
    return buf


def layer(*parts):
    """Plays parts at the same time. Each part is samples or (samples, start_sec)."""
    buf = []
    for part in parts:
        samples, start = part if isinstance(part, tuple) else (part, 0.0)
        mix_into(buf, samples, start)
    return buf


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def echo(x, delay, feedback, repeats=3):
    buf = list(x)
    for r in range(1, repeats + 1):
        mix_into(buf, x, delay * r, feedback ** r)
    return buf


def normalize(x, peak=0.9):
    m = max((abs(s) for s in x), default=0.0)
    return x if m == 0 else [s * peak / m for s in x]


def save(path: Path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in x))
    print(f"wrote {path.relative_to(ROOT)}")


def arpeggio(notes, step, kind="square", vol=0.4, duty=0.25, last_hold=0.25):
    parts = []
    for i, note in enumerate(notes):
        hold = last_hold if i == len(notes) - 1 else step
        parts.append((tone(note, hold + 0.05, kind, vol, decay=hold * 0.6, sustain=0.2, duty=duty), i * step))
    return layer(*parts)


# --------------------------------------------------------------------------
# Sound effects
# --------------------------------------------------------------------------
def sfx_click():
    return tone(1100, 0.035, "square", 0.3, decay=0.012, sustain=0.0, duty=0.25)


def sfx_spin():
    return layer(tone(260, 0.16, "square", 0.3, slide_to=720, duty=0.25, decay=0.1, sustain=0.3),
                 (noise(0.08, 0.15, decay=0.03), 0.0))


def sfx_reel_stop():
    thump = tone(150, 0.13, "sine", 0.8, slide_to=55, decay=0.05, sustain=0.0)
    click = highpass(noise(0.025, 0.4, decay=0.008), 2000)
    return layer(thump, click)


def sfx_tease():
    return tone(380, 0.7, "square", 0.25, slide_to=1050, duty=0.25, vibrato_rate=14, vibrato_depth=0.03, release=0.08)


def sfx_win():
    return arpeggio(["C5", "E5", "G5", "C6"], 0.055, vol=0.35, last_hold=0.22)


def sfx_big_win():
    run = arpeggio(["C5", "E5", "G5", "C6", "E6", "G6"], 0.06, vol=0.3, last_hold=0.1)
    chord = layer(*(tone(n, 0.9, "square", 0.16, duty=0.25, decay=0.4, sustain=0.3,
                         vibrato_rate=6, vibrato_depth=0.006, release=0.2) for n in ["C6", "E6", "G6", "C5"]))
    sparkle = layer(*((tone(rng.choice([2093, 2637, 3136]), 0.05, "square", 0.08, decay=0.02, sustain=0), 0.4 + i * 0.07)
                      for i in range(8)))
    return layer(run, (chord, 0.36), sparkle)


def sfx_coin():
    return concat(tone("B5", 0.055, "square", 0.3), tone("E6", 0.28, "square", 0.3, decay=0.08, sustain=0.0))


def sfx_buy():
    return layer(arpeggio(["G5", "C6", "E6"], 0.05, "triangle", 0.5, last_hold=0.2),
                 (sfx_coin(), 0.1))


def sfx_denied():
    return concat(tone(160, 0.08, "square", 0.25, duty=0.5), [0.0] * int(0.03 * SR), tone(130, 0.12, "square", 0.25))


def sfx_spawn():
    horn = lambda n, d: lowpass(tone(n, d, "saw", 0.5, attack=0.02, decay=0.3, sustain=0.6,
                                     vibrato_rate=5, vibrato_depth=0.008, release=0.05), 1800)
    return concat(horn("G3", 0.1), horn("D4", 0.28))


def sfx_sword():
    clang = tone(1700, 0.12, "square", 0.15, decay=0.03, sustain=0.0, duty=0.3)
    hit = highpass(noise(0.06, 0.4, decay=0.015), 1500)
    return layer(hit, clang)


def sfx_arrow():
    twang = tone(620, 0.09, "triangle", 0.35, slide_to=300, decay=0.04, sustain=0)
    whoosh = lowpass(noise(0.12, 0.25, decay=0.05), 2500)
    return layer(twang, whoosh)


def sfx_bolt():
    twang = tone(320, 0.12, "triangle", 0.45, slide_to=140, decay=0.05, sustain=0)
    whoosh = lowpass(noise(0.14, 0.25, decay=0.06), 1500)
    return layer(twang, whoosh)


def sfx_magic():
    sweep = tone(700, 0.22, "sine", 0.35, slide_to=1600, decay=0.12, sustain=0.2)
    sparkle = layer(*((tone(rng.choice([1800, 2400, 3000]), 0.04, "square", 0.08, decay=0.015, sustain=0), i * 0.04)
                      for i in range(5)))
    return layer(sweep, sparkle)


def sfx_burst():
    return layer(lowpass(noise(0.25, 0.5, decay=0.08, hold=2), 1200),
                 tone(200, 0.2, "sine", 0.4, slide_to=60, decay=0.08, sustain=0))


def sfx_spirit_death():
    wail = tone(720, 0.45, "sine", 0.35, slide_to=180, vibrato_rate=9, vibrato_depth=0.04, release=0.1)
    return layer(wail, lowpass(noise(0.3, 0.1, decay=0.15), 3000))


def sfx_troop_death():
    return tone(420, 0.16, "square", 0.25, slide_to=140, duty=0.25, decay=0.08, sustain=0.2)


def sfx_castle_hit():
    return layer(lowpass(noise(0.22, 0.7, decay=0.07, hold=3), 600),
                 tone(90, 0.22, "sine", 0.6, slide_to=45, decay=0.08, sustain=0))


def sfx_night_start():
    """A low bell toll with a dark drone."""
    partials = [(1.0, 0.5), (2.0, 0.25), (2.76, 0.2), (5.4, 0.08), (0.5, 0.3)]
    base = 196.0
    bell = layer(*(tone(base * ratio, 3.0, "sine", vol, attack=0.005, decay=0.9 / ratio ** 0.5, sustain=0.0, release=0.3)
                   for ratio, vol in partials))
    drone = tone(49, 3.0, "sine", 0.3, attack=0.5, release=1.0)
    return normalize(layer(bell, drone, (bell, 1.4)), 0.8)


def sfx_dawn():
    notes = ["D5", "F#5", "A5", "D6"]
    run = arpeggio(notes, 0.09, "triangle", 0.5, last_hold=0.6)
    chord = layer(*(tone(n, 0.8, "square", 0.08, duty=0.25, attack=0.05, decay=0.4, sustain=0.4, release=0.3)
                    for n in ["D5", "F#5", "A5"]))
    return normalize(layer(run, (chord, 0.27)), 0.8)


def sfx_victory():
    melody = [("C5", 0.15), ("C5", 0.15), ("C5", 0.15), ("C5", 0.45), ("Ab4", 0.45), ("Bb4", 0.45),
              ("C5", 0.3), ("Bb4", 0.15), ("C5", 1.2)]
    parts, t = [], 0.0
    for note, d in melody:
        parts.append((tone(note, d + 0.05, "square", 0.3, duty=0.25, decay=d, sustain=0.5, release=0.05), t))
        parts.append((tone(freq(note) / 2, d + 0.05, "triangle", 0.3, decay=d, sustain=0.5), t))
        t += d
    return normalize(layer(*parts), 0.85)


def sfx_game_over():
    parts = []
    for i, note in enumerate(["A4", "F4", "D4", "A3"]):
        parts.append((tone(note, 0.6, "triangle", 0.5, decay=0.3, sustain=0.4, release=0.15), i * 0.32))
        parts.append((tone(freq(note) / 2, 0.6, "square", 0.12, duty=0.25, decay=0.3, sustain=0.4), i * 0.32))
    return normalize(layer(*parts), 0.85)


# --------------------------------------------------------------------------
# Music
# --------------------------------------------------------------------------
def lute(note, dur):
    return layer(tone(note, dur + 0.25, "triangle", 0.32, attack=0.003, decay=0.22, sustain=0.15, release=0.1),
                 tone(note, dur + 0.1, "square", 0.05, duty=0.125, decay=0.08, sustain=0.0))


def lead(note, dur):
    return tone(note, dur + 0.05, "square", 0.09, duty=0.25, attack=0.01, decay=0.3, sustain=0.6,
                vibrato_rate=5.5, vibrato_depth=0.005, release=0.05)


def bass(note, dur):
    return tone(note, dur, "square", 0.13, duty=0.25, decay=0.15, sustain=0.45, release=0.03)


def kick(_note, _dur):
    return tone(150, 0.14, "sine", 0.55, slide_to=45, decay=0.06, sustain=0.0)


def hat(_note, _dur):
    return highpass(noise(0.04, 0.12, decay=0.012), 5000)


def tamb(_note, _dur):
    return highpass(noise(0.1, 0.12, decay=0.04, hold=2), 3000)


def render(bpm, bars, events, tail=2.5):
    """events: (start_beat, note, length_beats, instrument). Tail wraps around so the loop is seamless."""
    beat = 60.0 / bpm
    length = int(bars * 4 * beat * SR)
    buf = [0.0] * (length + int(tail * SR))
    for start, note, beats, inst in events:
        mix_into(buf, inst(note, beats * beat), start * beat)
    for i in range(length, len(buf)):
        buf[i - length] += buf[i]
    return buf[:length]


def phrase(notes, start_beat, inst):
    """notes: [(note or 'R', beats)] -> events starting at start_beat."""
    events, t = [], start_beat
    for note, beats in notes:
        if note != "R":
            events.append((t, note, beats, inst))
        t += beats
    return events


def music_day():
    melody = [
        ("D5", .5), ("F5", .5), ("A5", 1), ("G5", .5), ("F5", .5), ("E5", .5), ("F5", .5),
        ("E5", .5), ("G5", .5), ("C6", 1), ("B5", .5), ("A5", .5), ("G5", 1),
        ("D5", .5), ("G5", .5), ("B5", 1), ("A5", .5), ("G5", .5), ("F5", .5), ("E5", .5),
        ("D5", 1.5), ("E5", .5), ("F5", 1), ("A5", 1),
        ("A5", .5), ("A5", .5), ("G5", .5), ("F5", .5), ("G5", 1), ("A5", 1),
        ("G5", .5), ("E5", .5), ("C5", 1), ("D5", .5), ("E5", .5), ("G5", 1),
        ("A5", .5), ("C6", .5), ("B5", .5), ("A5", .5), ("G5", .5), ("E5", .5), ("A5", 1),
        ("F5", .5), ("E5", .5), ("D5", 3),
    ]
    chords = [("D3", "A3"), ("C3", "G3"), ("G2", "D3"), ("D3", "A3"),
              ("D3", "A3"), ("C3", "G3"), ("A2", "E3"), ("D3", "A3")]
    events = []
    for half in range(2):
        offset = half * 32
        events += phrase(melody, offset, lute)
        if half == 1:  # second time round a bowed lead doubles the tune an octave down
            events += phrase([(n[:-1] + str(int(n[-1]) - 1), b) for n, b in melody], offset, lead)
        for bar, (root, fifth) in enumerate(chords):
            b = offset + bar * 4
            events += phrase([(root, 1), (fifth, 1), (root, 1), (fifth, 1)], b, bass)
            events += [(b, None, 1, kick), (b + 2, None, 1, kick)]
            events += [(b + x + 0.5, None, 0.5, hat) for x in range(4)]
            if half == 1:
                events += [(b + 1, None, 1, tamb), (b + 3, None, 1, tamb)]
    return normalize(render(112, 16, events), 0.75)


def arp_voice(note, dur):
    return tone(note, dur + 0.05, "square", 0.08, duty=0.125, decay=0.18, sustain=0.1)


def night_lead(note, dur):
    return tone(note, dur, "triangle", 0.22, attack=0.08, decay=0.8, sustain=0.5,
                vibrato_rate=4.5, vibrato_depth=0.01, release=0.2)


def drone(note, dur):
    return tone(note, dur, "sine", 0.18, attack=1.0, release=1.0, vibrato_rate=0.3, vibrato_depth=0.004)


def heartbeat(_note, _dur):
    return tone(110, 0.16, "sine", 0.5, slide_to=40, decay=0.05, sustain=0.0)


def music_night():
    arps = {
        "Dm": ["D4", "F4", "A4", "D5", "A4", "F4", "D4", "F4"],
        "Bb": ["Bb3", "D4", "F4", "Bb4", "F4", "D4", "Bb3", "D4"],
        "Gm": ["G3", "Bb3", "D4", "G4", "D4", "Bb3", "G3", "Bb3"],
        "A": ["A3", "C#4", "E4", "A4", "E4", "C#4", "A3", "C#4"],
    }
    roots = {"Dm": "D2", "Bb": "Bb1", "Gm": "G1", "A": "A1"}
    progression = ["Dm", "Bb", "Gm", "A", "Dm", "Bb", "Gm", "A"]
    events = []
    for bar, chord in enumerate(progression):
        b = bar * 4
        events += phrase([(n, 0.5) for n in arps[chord]], b, arp_voice)
        events.append((b, roots[chord], 4, drone))
        events += [(b, None, 1, heartbeat), (b + 0.4, None, 1, heartbeat)]
    lead_line = [("A4", 2), ("G4", 1), ("F4", 1), ("F4", 2), ("E4", 1), ("D4", 1),
                 ("D4", 2), ("E4", 1), ("F4", 1), ("E4", 3), ("R", 1)]
    events += phrase(lead_line, 16, night_lead)
    return normalize(echo(render(80, 8, events), 0.56, 0.3, 2)[: int(8 * 4 * 0.75 * SR)], 0.7)


SFX = {
    "click": sfx_click, "spin": sfx_spin, "reel_stop": sfx_reel_stop, "tease": sfx_tease,
    "win": sfx_win, "big_win": sfx_big_win, "coin": sfx_coin, "buy": sfx_buy, "denied": sfx_denied,
    "spawn": sfx_spawn, "sword": sfx_sword, "arrow": sfx_arrow, "bolt": sfx_bolt, "magic": sfx_magic,
    "burst": sfx_burst, "spirit_death": sfx_spirit_death, "troop_death": sfx_troop_death,
    "castle_hit": sfx_castle_hit, "night_start": sfx_night_start, "dawn": sfx_dawn,
    "victory": sfx_victory, "game_over": sfx_game_over,
}


def main() -> None:
    for name, fn in SFX.items():
        save(SFX_DIR / f"{name}.wav", normalize(fn(), 0.85) if name not in ("night_start", "dawn") else fn())
    save(MUSIC_DIR / "day.wav", music_day())
    save(MUSIC_DIR / "night.wav", music_night())


if __name__ == "__main__":
    main()
