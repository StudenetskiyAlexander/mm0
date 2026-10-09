"""Create original procedural music and sound effects for the battle prototype.

Run with: python3 tools/generate_audio.py
Requires NumPy. All melodies and waveforms below are made for this project.
"""

from __future__ import annotations

from pathlib import Path
import math
import wave

import numpy as np


RATE = 24_000
BPM = 96
BEAT = 60.0 / BPM
BAR = 4.0 * BEAT
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RNG = np.random.default_rng(74821)


def frequency(midi: int) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def envelope(length: int, attack: float, release: float) -> np.ndarray:
    times = np.arange(length, dtype=np.float32) / RATE
    duration = length / RATE
    return np.minimum(1.0, times / max(attack, 0.001)) * np.minimum(
        1.0, (duration - times) / max(release, 0.001)
    ).clip(0.0, 1.0)


def tone(midi: int, duration: float, instrument: str) -> np.ndarray:
    count = max(1, int(duration * RATE))
    t = np.arange(count, dtype=np.float32) / RATE
    hz = frequency(midi)
    if instrument == "strings":
        phase = 2.0 * np.pi * hz * t + 0.05 * np.sin(2.0 * np.pi * 5.1 * t)
        value = sum(
            strength * np.sin(phase * harmonic + harmonic * 0.2)
            for harmonic, strength in ((1, 0.65), (2, 0.28), (3, 0.19), (4, 0.10), (5, 0.06))
        )
        value += 0.21 * np.sin(2.0 * np.pi * hz * 1.004 * t)
        value *= envelope(count, 0.21, 0.30) * (0.91 + 0.09 * np.sin(2.0 * np.pi * 3.8 * t))
    elif instrument == "horn":
        phase = 2.0 * np.pi * hz * t + 0.035 * np.sin(2.0 * np.pi * 4.6 * t)
        value = sum(
            strength * np.sin(phase * harmonic)
            for harmonic, strength in ((1, 0.68), (2, 0.36), (3, 0.25), (4, 0.10), (5, 0.05))
        )
        value *= envelope(count, 0.075, 0.20)
    elif instrument == "flute":
        phase = 2.0 * np.pi * hz * t + 0.035 * np.sin(2.0 * np.pi * 5.5 * t)
        value = np.sin(phase) + 0.16 * np.sin(2.0 * phase) + 0.045 * np.sin(3.0 * phase)
        value += 0.012 * RNG.standard_normal(count)
        value *= envelope(count, 0.07, 0.17)
    elif instrument == "harp":
        phase = 2.0 * np.pi * hz * t
        value = sum(
            strength * np.sin(phase * harmonic)
            for harmonic, strength in ((1, 0.74), (2, 0.29), (3, 0.21), (4, 0.10), (5, 0.05))
        )
        value *= (1.0 - np.exp(-t * 140.0)) * np.exp(-t * 3.2)
        value *= envelope(count, 0.002, 0.065)
    elif instrument == "bass":
        phase = 2.0 * np.pi * hz * t
        value = np.sin(phase) + 0.21 * np.sin(2.0 * phase) + 0.09 * np.sin(3.0 * phase)
        value *= envelope(count, 0.065, 0.22)
    elif instrument == "oboe":
        phase = 2.0 * np.pi * hz * t + 0.022 * np.sin(2.0 * np.pi * 4.8 * t)
        value = np.sin(phase) + 0.36 * np.sin(2.0 * phase) + 0.23 * np.sin(3.0 * phase)
        value += 0.09 * np.sin(4.0 * phase)
        value *= envelope(count, 0.11, 0.19)
    elif instrument == "choir":
        phase = 2.0 * np.pi * hz * t + 0.018 * np.sin(2.0 * np.pi * 4.3 * t)
        value = 0.70 * np.sin(phase) + 0.20 * np.sin(2.0 * phase)
        value += 0.16 * np.sin(2.0 * np.pi * hz * 1.006 * t)
        value *= envelope(count, 0.28, 0.40)
    elif instrument == "short_strings":
        phase = 2.0 * np.pi * hz * t
        value = sum(
            strength * np.sin(phase * harmonic + harmonic * 0.17)
            for harmonic, strength in ((1, .57), (2, .31), (3, .20), (4, .12), (5, .07))
        )
        value *= envelope(count, .012, .065) * np.exp(-t * 1.45)
    else:
        raise ValueError(instrument)
    return value.astype(np.float32)


def place(track: np.ndarray, sound: np.ndarray, at: float, level: float, pan: float = 0.0) -> None:
    start = int(at * RATE)
    if start < 0 or start >= len(track):
        return
    size = min(len(sound), len(track) - start)
    left = math.sqrt((1.0 - pan) * 0.5)
    right = math.sqrt((1.0 + pan) * 0.5)
    track[start : start + size, 0] += sound[:size] * level * left
    track[start : start + size, 1] += sound[:size] * level * right


def timpani() -> np.ndarray:
    duration = 0.85
    t = np.arange(int(duration * RATE), dtype=np.float32) / RATE
    phase = 2.0 * np.pi * (82.0 * t + 42.0 * (1.0 - np.exp(-t * 17.0)) / 17.0)
    body = np.sin(phase) * np.exp(-t * 5.1)
    strike = RNG.standard_normal(len(t)) * np.exp(-t * 28.0)
    return (body * 0.86 + strike * 0.11).astype(np.float32)


def snare() -> np.ndarray:
    duration = 0.28
    t = np.arange(int(duration * RATE), dtype=np.float32) / RATE
    noise = RNG.standard_normal(len(t))
    bright = noise - np.convolve(noise, np.ones(11) / 11, mode="same")
    body = np.sin(2.0 * np.pi * 176.0 * t)
    return (bright * 0.28 + body * 0.18).astype(np.float32) * np.exp(-t * 18.0)


def cymbal() -> np.ndarray:
    duration = .55
    t = np.arange(int(duration * RATE), dtype=np.float32) / RATE
    noise = RNG.standard_normal(len(t))
    bright = noise - np.convolve(noise, np.ones(21) / 21, mode="same")
    return (bright * np.exp(-t * 10.0) * .27).astype(np.float32)


def battle_theme() -> np.ndarray:
    bars = 16
    track = np.zeros((int(bars * BAR * RATE), 2), dtype=np.float32)
    # A new sixteen-bar D-minor theme, with harp ostinato and a horn melody.
    chords = [
        (50, 53, 57), (46, 50, 53), (53, 57, 60), (48, 52, 55),
        (50, 53, 57), (46, 50, 53), (43, 46, 50), (45, 49, 52),
        (50, 53, 57), (43, 46, 50), (46, 50, 53), (45, 49, 52),
        (53, 57, 60), (48, 52, 55), (45, 49, 52), (50, 53, 57),
    ]
    # Each entry: beat offset, MIDI pitch, length in beats.
    melody = [
        [(0, 74, 1), (1, 77, .5), (1.5, 76, .5), (2, 74, 1), (3, 69, 1)],
        [(0, 70, 1), (1, 74, 1), (2, 72, 1), (3, 69, 1)],
        [(0, 69, .5), (.5, 72, .5), (1, 77, 1), (2, 76, 1), (3, 72, 1)],
        [(0, 72, 1.5), (1.5, 71, .5), (2, 72, 1), (3, 67, 1)],
        [(0, 74, 1), (1, 77, .5), (1.5, 81, .5), (2, 79, 1), (3, 77, 1)],
        [(0, 74, 1), (1, 70, 1), (2, 72, .5), (2.5, 74, .5), (3, 77, 1)],
        [(0, 79, 1.5), (1.5, 77, .5), (2, 74, 1), (3, 70, 1)],
        [(0, 73, 1), (1, 76, 1), (2, 81, 1), (3, 76, 1)],
        [(0, 77, 1), (1, 81, .5), (1.5, 79, .5), (2, 77, 1), (3, 74, 1)],
        [(0, 70, 1), (1, 74, 1), (2, 79, 1), (3, 77, 1)],
        [(0, 74, .5), (.5, 77, .5), (1, 82, 1), (2, 81, 1), (3, 77, 1)],
        [(0, 76, 1), (1, 73, 1), (2, 69, 1), (3, 73, 1)],
        [(0, 72, 1), (1, 77, .5), (1.5, 81, .5), (2, 84, 1), (3, 81, 1)],
        [(0, 79, 1), (1, 76, 1), (2, 72, 1), (3, 76, 1)],
        [(0, 81, 1), (1, 76, .5), (1.5, 73, .5), (2, 69, 1), (3, 73, 1)],
        [(0, 74, 2), (2, 69, 1), (3, 74, 1)],
    ]
    drum = timpani()
    for bar_index, chord in enumerate(chords):
        start = bar_index * BAR
        root, third, fifth = chord
        for pitch, level, pan in ((root, .105, -.55), (third, .095, .45), (fifth, .095, -.25), (root + 12, .045, .35)):
            place(track, tone(pitch, BAR + .23, "strings"), start, level, pan)
        place(track, tone(root - 12, 2.2 * BEAT, "bass"), start, .18, -.12)
        place(track, tone(root - 12, 1.7 * BEAT, "bass"), start + 2 * BEAT, .11, .12)
        arp = (root + 12, fifth + 12, third + 12, fifth + 12, root + 24, fifth + 12, third + 12, fifth + 12)
        for step, pitch in enumerate(arp):
            place(track, tone(pitch, .48, "harp"), start + step * BEAT / 2, .095, -.35 if step % 2 else .35)
        for offset, pitch, length in melody[bar_index]:
            place(track, tone(pitch, max(.19, length * BEAT * .94), "horn"), start + offset * BEAT, .185, .05)
        if bar_index % 2 == 1:
            for offset, pitch in ((1.5, fifth + 24), (2.5, third + 24)):
                place(track, tone(pitch, .5 * BEAT, "flute"), start + offset * BEAT, .065, .55)
        place(track, drum, start, .12 if bar_index % 4 else .18)
        place(track, drum, start + 2 * BEAT, .07)
    # A small stereo room tail, then crossfade the loop boundary.
    dry = track.copy()
    for seconds, gain in ((.13, .15), (.23, .10), (.38, .065)):
        shift = int(seconds * RATE)
        track[shift:, 0] += dry[:-shift, 1] * gain
        track[shift:, 1] += dry[:-shift, 0] * gain
    fade = int(.22 * RATE)
    weight = np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
    track[-fade:] = track[-fade:] * (1.0 - weight) + track[:fade] * weight
    return track


def finish_loop(track: np.ndarray, fade_seconds: float = .28) -> np.ndarray:
    dry = track.copy()
    for seconds, gain in ((.15, .14), (.29, .085), (.47, .045)):
        shift = int(seconds * RATE)
        track[shift:, 0] += dry[:-shift, 1] * gain
        track[shift:, 1] += dry[:-shift, 0] * gain
    fade = int(fade_seconds * RATE)
    weight = np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
    track[-fade:] = track[-fade:] * (1.0 - weight) + track[:fade] * weight
    return track


def misty_pass_theme() -> np.ndarray:
    """Lyrical A-Dorian battle theme with woodwind call and harp answer."""
    beat = 60.0 / 88.0
    bar = 4.0 * beat
    chords = [
        (45, 48, 52), (43, 47, 50), (50, 54, 57), (52, 55, 59),
        (45, 48, 52), (48, 52, 55), (43, 47, 50), (52, 56, 59),
        (41, 45, 48), (48, 52, 55), (50, 54, 57), (45, 48, 52),
        (43, 47, 50), (50, 54, 57), (52, 56, 59), (45, 48, 52),
    ]
    melody = [
        [(0, 76, 1.5), (1.5, 78, .5), (2, 79, 1), (3, 76, 1)],
        [(0, 74, 1), (1, 72, .5), (1.5, 74, .5), (2, 76, 2)],
        [(0, 78, 1.5), (1.5, 81, .5), (2, 79, 1), (3, 78, 1)],
        [(0, 76, 2), (2, 74, 1), (3, 71, 1)],
        [(0, 72, 1), (1, 76, 1), (2, 79, 1.5), (3.5, 81, .5)],
        [(0, 79, 1), (1, 76, 1), (2, 72, 1), (3, 76, 1)],
        [(0, 74, 1.5), (1.5, 79, .5), (2, 83, 1), (3, 79, 1)],
        [(0, 80, 1), (1, 76, 1), (2, 71, 1), (3, 68, 1)],
        [(0, 77, 1.5), (1.5, 81, .5), (2, 84, 1), (3, 81, 1)],
        [(0, 79, 1), (1, 76, 1), (2, 72, 1.5), (3.5, 74, .5)],
        [(0, 78, 1), (1, 81, 1), (2, 86, 1), (3, 81, 1)],
        [(0, 84, 2), (2, 81, 1), (3, 76, 1)],
        [(0, 79, 1.5), (1.5, 83, .5), (2, 86, 1), (3, 83, 1)],
        [(0, 81, 1), (1, 78, 1), (2, 74, 1), (3, 78, 1)],
        [(0, 80, 1), (1, 76, 1), (2, 71, 1), (3, 68, 1)],
        [(0, 69, 2), (2, 72, 1), (3, 69, 1)],
    ]
    track = np.zeros((int(len(chords) * bar * RATE), 2), dtype=np.float32)
    drum = timpani()
    for index, (root, third, fifth) in enumerate(chords):
        start = index * bar
        for pitch, level, pan in ((root, .085, -.5), (third, .075, .5), (fifth, .075, -.2)):
            place(track, tone(pitch, bar + .25, "strings"), start, level, pan)
        place(track, tone(root - 12, 2.1 * beat, "bass"), start, .14, -.15)
        place(track, tone(root - 12, 1.8 * beat, "bass"), start + 2 * beat, .09, .15)
        if index in (0, 4, 8, 12):
            place(track, tone(root + 12, 3.7 * beat, "choir"), start, .055, 0)
        arpeggio = (root + 12, fifth + 12, third + 12, fifth + 12,
                    root + 24, fifth + 12, third + 12, fifth + 12)
        for step, pitch in enumerate(arpeggio):
            place(track, tone(pitch, .47 * beat, "harp"), start + step * beat / 2,
                  .082, -.4 if step % 2 else .4)
        for offset, pitch, length in melody[index]:
            place(track, tone(pitch, max(.20, length * beat * .93), "oboe"),
                  start + offset * beat, .17, -.05)
        if index % 2 == 1:
            place(track, tone(fifth + 24, .9 * beat, "flute"), start + 2.5 * beat, .075, .55)
        if index % 4 == 0:
            place(track, drum, start, .11)
        place(track, drum, start + 2 * beat, .052)
    return finish_loop(track)


def iron_march_theme() -> np.ndarray:
    """Urgent C-minor march with brass phrases and measured percussion."""
    beat = 60.0 / 110.0
    bar = 4.0 * beat
    chords = [
        (48, 51, 55), (44, 48, 51), (46, 50, 53), (43, 47, 50),
        (48, 51, 55), (41, 44, 48), (43, 47, 50), (48, 51, 55),
        (51, 55, 58), (46, 50, 53), (44, 48, 51), (43, 47, 50),
        (48, 51, 55), (41, 44, 48), (43, 47, 50), (48, 51, 55),
    ]
    melody = [
        [(0, 72, .75), (1, 75, .75), (2, 79, 1), (3, 75, 1)],
        [(0, 72, 1.5), (1.5, 68, .5), (2, 72, 1), (3, 75, 1)],
        [(0, 77, 1), (1, 74, 1), (2, 70, .5), (2.5, 74, .5), (3, 77, 1)],
        [(0, 79, 1.5), (1.5, 74, .5), (2, 71, 1), (3, 74, 1)],
        [(0, 72, .5), (.5, 75, .5), (1, 79, 1), (2, 84, 1), (3, 79, 1)],
        [(0, 80, 1), (1, 77, 1), (2, 72, 1), (3, 68, 1)],
        [(0, 74, 1), (1, 79, 1), (2, 83, .75), (3, 79, 1)],
        [(0, 84, 2), (2, 79, 1), (3, 75, 1)],
        [(0, 75, .75), (1, 79, .75), (2, 82, 1), (3, 79, 1)],
        [(0, 77, 1), (1, 74, 1), (2, 70, 1), (3, 74, 1)],
        [(0, 80, 1.5), (1.5, 84, .5), (2, 80, 1), (3, 75, 1)],
        [(0, 79, 1), (1, 83, 1), (2, 86, 1), (3, 83, 1)],
        [(0, 84, 1), (1, 79, .5), (1.5, 75, .5), (2, 72, 1), (3, 75, 1)],
        [(0, 80, 1), (1, 77, 1), (2, 72, 1), (3, 68, 1)],
        [(0, 79, 1), (1, 74, 1), (2, 71, 1), (3, 74, 1)],
        [(0, 72, 2), (2, 67, 1), (3, 72, 1)],
    ]
    track = np.zeros((int(len(chords) * bar * RATE), 2), dtype=np.float32)
    drum = timpani()
    snare_hit = snare()
    for index, (root, third, fifth) in enumerate(chords):
        start = index * bar
        for pitch, level, pan in ((root, .105, -.45), (third, .09, .45), (fifth, .09, -.1)):
            place(track, tone(pitch, bar + .18, "strings"), start, level, pan)
        place(track, tone(root - 12, 1.8 * beat, "bass"), start, .21, -.1)
        place(track, tone(root - 12, 1.8 * beat, "bass"), start + 2 * beat, .15, .1)
        for step, pitch in enumerate((root + 12, fifth + 12, root + 12, third + 12,
                                      fifth + 12, root + 24, fifth + 12, third + 12)):
            place(track, tone(pitch, .45 * beat, "harp"), start + step * beat / 2,
                  .075, -.35 if step % 2 else .35)
        for offset, pitch, length in melody[index]:
            place(track, tone(pitch, max(.18, length * beat * .91), "horn"),
                  start + offset * beat, .21, .08)
        if index in (0, 4, 8, 12):
            place(track, tone(root + 12, 3.7 * beat, "choir"), start, .065, -.3)
            place(track, tone(fifth + 12, 3.7 * beat, "choir"), start, .055, .3)
        place(track, drum, start, .17 if index % 4 == 0 else .11)
        place(track, drum, start + 2 * beat, .085)
        place(track, snare_hit, start + beat, .12, .08)
        place(track, snare_hit, start + 3 * beat, .13, -.08)
    return finish_loop(track, .22)


def dawn_assault_theme() -> np.ndarray:
    """Fast, bright D-major charge with a driving string pulse and brass calls."""
    beat = 60.0 / 138.0
    bar = 4.0 * beat
    chords = [
        (50, 54, 57), (55, 59, 62), (47, 50, 54), (45, 49, 52),
        (50, 54, 57), (55, 59, 62), (52, 55, 59), (45, 49, 52),
        (47, 50, 54), (55, 59, 62), (50, 54, 57), (45, 49, 52),
        (52, 55, 59), (55, 59, 62), (45, 49, 52), (50, 54, 57),
    ]
    melody = [
        [(0, 74, .5), (.5, 78, .5), (1, 81, 1), (2, 78, .5), (2.5, 76, .5), (3, 74, 1)],
        [(0, 79, .5), (.5, 83, .5), (1, 86, 1), (2, 83, 1), (3, 79, 1)],
        [(0, 78, .75), (1, 74, .5), (1.5, 71, .5), (2, 74, 1), (3, 78, 1)],
        [(0, 76, .5), (.5, 73, .5), (1, 69, 1), (2, 73, .5), (2.5, 76, .5), (3, 81, 1)],
        [(0, 86, 1), (1, 81, .5), (1.5, 78, .5), (2, 74, 1), (3, 78, 1)],
        [(0, 83, .5), (.5, 79, .5), (1, 74, 1), (2, 79, .5), (2.5, 83, .5), (3, 86, 1)],
        [(0, 83, 1), (1, 79, .5), (1.5, 76, .5), (2, 71, 1), (3, 76, 1)],
        [(0, 81, .75), (1, 76, .5), (1.5, 73, .5), (2, 76, 1), (3, 81, 1)],
        [(0, 83, .5), (.5, 86, .5), (1, 90, 1), (2, 86, .5), (2.5, 83, .5), (3, 78, 1)],
        [(0, 79, .5), (.5, 83, .5), (1, 86, 1), (2, 79, 1), (3, 74, 1)],
        [(0, 78, 1), (1, 81, .5), (1.5, 86, .5), (2, 90, 1), (3, 86, 1)],
        [(0, 88, .75), (1, 85, .5), (1.5, 81, .5), (2, 76, 1), (3, 73, 1)],
        [(0, 79, .5), (.5, 83, .5), (1, 86, 1), (2, 83, .5), (2.5, 79, .5), (3, 76, 1)],
        [(0, 83, 1), (1, 86, .5), (1.5, 91, .5), (2, 86, 1), (3, 83, 1)],
        [(0, 81, .5), (.5, 85, .5), (1, 88, 1), (2, 85, .5), (2.5, 81, .5), (3, 76, 1)],
        [(0, 86, 1.5), (1.5, 81, .5), (2, 78, 1), (3, 74, 1)],
    ]
    track = np.zeros((int(len(chords) * bar * RATE), 2), dtype=np.float32)
    drum, snare_hit, crash = timpani(), snare(), cymbal()
    for index, (root, third, fifth) in enumerate(chords):
        start = index * bar
        for pitch, pan in ((root, -.5), (third, .45), (fifth, -.12)):
            place(track, tone(pitch, bar + .12, "strings"), start, .065, pan)
        for step, pitch in enumerate((root + 12, fifth + 12, root + 12, fifth + 12,
                                      third + 12, fifth + 12, root + 24, fifth + 12)):
            place(track, tone(pitch, .37 * beat, "short_strings"), start + step * beat / 2,
                  .155 if step in (0, 4) else .105, -.35 if step % 2 else .35)
        for offset in (0, 1.5, 2, 3.5):
            place(track, tone(root - 12, .39 * beat, "bass"), start + offset * beat,
                  .19 if offset in (0, 2) else .11, -.1)
        for offset, pitch, length in melody[index]:
            place(track, tone(pitch, max(.14, length * beat * .88), "horn"),
                  start + offset * beat, .22, .07)
        place(track, drum, start, .18 if index % 4 == 0 else .13)
        place(track, drum, start + 2 * beat, .12)
        for offset in (1, 3):
            place(track, snare_hit, start + offset * beat, .18, .10 if offset == 1 else -.10)
        if index % 4 == 0:
            place(track, crash, start, .17, .2)
    return finish_loop(track, .18)


def last_bastion_theme() -> np.ndarray:
    """Darker G-minor battle theme with syncopated low strings and fast drums."""
    beat = 60.0 / 148.0
    bar = 4.0 * beat
    chords = [
        (43, 46, 50), (51, 55, 58), (53, 57, 60), (50, 53, 57),
        (43, 46, 50), (48, 51, 55), (51, 55, 58), (50, 54, 57),
        (46, 50, 53), (53, 57, 60), (48, 51, 55), (50, 54, 57),
        (43, 46, 50), (51, 55, 58), (50, 54, 57), (43, 46, 50),
    ]
    melody = [
        [(0, 67, .5), (.5, 70, .5), (1, 74, .5), (1.5, 70, .5), (2, 67, 1), (3, 74, 1)],
        [(0, 75, .75), (1, 79, .5), (1.5, 82, .5), (2, 79, 1), (3, 75, 1)],
        [(0, 77, .5), (.5, 81, .5), (1, 84, .5), (1.5, 81, .5), (2, 77, 1), (3, 72, 1)],
        [(0, 74, 1), (1, 77, .5), (1.5, 81, .5), (2, 77, 1), (3, 74, 1)],
        [(0, 79, .5), (.5, 74, .5), (1, 70, .5), (1.5, 67, .5), (2, 70, 1), (3, 74, 1)],
        [(0, 72, .5), (.5, 75, .5), (1, 79, 1), (2, 75, .5), (2.5, 72, .5), (3, 67, 1)],
        [(0, 75, 1), (1, 79, .5), (1.5, 82, .5), (2, 87, 1), (3, 82, 1)],
        [(0, 78, .5), (.5, 81, .5), (1, 86, 1), (2, 81, .5), (2.5, 78, .5), (3, 74, 1)],
        [(0, 82, .5), (.5, 86, .5), (1, 89, 1), (2, 86, .5), (2.5, 82, .5), (3, 77, 1)],
        [(0, 84, .5), (.5, 81, .5), (1, 77, 1), (2, 72, .5), (2.5, 77, .5), (3, 81, 1)],
        [(0, 79, .75), (1, 75, .5), (1.5, 72, .5), (2, 75, 1), (3, 79, 1)],
        [(0, 86, 1), (1, 81, .5), (1.5, 78, .5), (2, 74, 1), (3, 78, 1)],
        [(0, 82, .5), (.5, 79, .5), (1, 74, .5), (1.5, 70, .5), (2, 67, 1), (3, 74, 1)],
        [(0, 87, 1), (1, 82, .5), (1.5, 79, .5), (2, 75, 1), (3, 79, 1)],
        [(0, 86, .5), (.5, 81, .5), (1, 78, 1), (2, 74, .5), (2.5, 78, .5), (3, 81, 1)],
        [(0, 79, 1.5), (1.5, 74, .5), (2, 70, 1), (3, 67, 1)],
    ]
    track = np.zeros((int(len(chords) * bar * RATE), 2), dtype=np.float32)
    drum, snare_hit, crash = timpani(), snare(), cymbal()
    for index, (root, third, fifth) in enumerate(chords):
        start = index * bar
        for pitch, pan in ((root + 12, -.5), (third + 12, .4), (fifth + 12, -.1)):
            place(track, tone(pitch, bar + .13, "strings"), start, .058, pan)
        for step, pitch in enumerate((root + 12, root + 12, fifth + 12, root + 12,
                                      third + 12, root + 12, fifth + 12, third + 12)):
            if step in (3, 7):
                continue
            place(track, tone(pitch, .34 * beat, "short_strings"), start + step * beat / 2,
                  .17 if step in (0, 4) else .12, -.45 if step % 2 else .4)
        for offset in (0, .75, 1.5, 2, 2.75, 3.5):
            place(track, tone(root - 12, .32 * beat, "bass"), start + offset * beat,
                  .23 if offset in (0, 2) else .13, -.1)
        for offset, pitch, length in melody[index]:
            place(track, tone(pitch, max(.13, length * beat * .87), "horn"),
                  start + offset * beat, .205, .04)
        for offset, level in ((0, .17), (1.5, .075), (2, .16), (3.5, .075)):
            place(track, drum, start + offset * beat, level)
        for offset, level in ((1, .20), (2.5, .12), (3, .21)):
            place(track, snare_hit, start + offset * beat, level, .13 if offset == 2.5 else -.08)
        if index % 4 == 0:
            place(track, crash, start, .14, -.2)
    return finish_loop(track, .16)


def sweep(duration: float, start_hz: float, end_hz: float) -> tuple[np.ndarray, np.ndarray]:
    t = np.arange(int(duration * RATE), dtype=np.float32) / RATE
    phase = 2.0 * np.pi * (start_hz * t + (end_hz - start_hz) * t * t / (2.0 * duration))
    return t, phase


def stereo(signal: np.ndarray, spread: float = .13) -> np.ndarray:
    delay = max(1, int(.009 * RATE))
    other = np.zeros_like(signal)
    other[delay:] = signal[:-delay]
    return np.stack((signal, signal * (1.0 - spread) + other * spread), axis=1)


def sound_effects() -> dict[str, np.ndarray]:
    effects: dict[str, np.ndarray] = {}
    t, phase = sweep(.35, 1000, 180)
    noise = RNG.standard_normal(len(t))
    moving = np.convolve(noise, np.ones(9) / 9, mode="same")
    effects["sword_swing"] = stereo((moving * .7 + np.sin(phase) * .22) * np.sin(np.pi * t / .35) ** 2)

    t, phase = sweep(.44, 170, 55)
    crack = RNG.standard_normal(len(t)) * np.exp(-t * 27)
    effects["hit"] = stereo(np.sin(phase) * np.exp(-t * 12) * .75 + crack * .42)

    t, phase = sweep(.40, 820, 260)
    hiss = RNG.standard_normal(len(t))
    hiss -= np.convolve(hiss, np.ones(13) / 13, mode="same")
    effects["miss"] = stereo((hiss * .27 + np.sin(phase) * .08) * np.sin(np.pi * t / .4) ** 2)

    t, phase = sweep(.50, 350, 90)
    effects["bow"] = stereo((np.sin(phase) + .4 * np.sin(2 * phase)) * np.exp(-t * 13) * .48)

    t, phase = sweep(.63, 180, 1160)
    flame = RNG.standard_normal(len(t)) * np.sin(np.pi * t / .63) ** 2
    effects["fire_cast"] = stereo(np.sin(phase) * np.exp(-t * 3.2) * .20 + flame * .19, .20)

    t, phase = sweep(.59, 220, 42)
    crackle = RNG.standard_normal(len(t)) * np.exp(-t * 10)
    effects["fire_hit"] = stereo(np.sin(phase) * np.exp(-t * 6) * .43 + crackle * .27, .21)

    healing = np.zeros(int(.98 * RATE), dtype=np.float32)
    for offset, pitch in ((0.0, 74), (.15, 77), (.32, 81), (.49, 86)):
        note = tone(pitch, .48, "harp")
        start = int(offset * RATE)
        healing[start:start + len(note)] += note * .36
    effects["heal"] = stereo(healing, .28)

    potion = np.zeros(int(.64 * RATE), dtype=np.float32)
    potion[: int(.35 * RATE)] += tone(81, .35, "harp") * .36
    potion[int(.12 * RATE): int(.46 * RATE)] += tone(88, .34, "harp") * .24
    t = np.arange(len(potion), dtype=np.float32) / RATE
    potion += RNG.standard_normal(len(t)) * np.exp(-((t - .36) / .06) ** 2) * .07
    effects["potion"] = stereo(potion, .25)

    t, phase = sweep(.57, 72, 195)
    effects["spawn"] = stereo((np.sin(phase) * .33 + RNG.standard_normal(len(t)) * .055) * np.sin(np.pi * t / .57) ** 2)

    t, phase = sweep(.68, 190, 49)
    effects["fall"] = stereo(np.sin(phase) * np.exp(-t * 5) * .33 + RNG.standard_normal(len(t)) * np.exp(-t * 13) * .13)

    t, phase = sweep(.20, 180, 95)
    effects["step"] = stereo(np.sin(phase) * np.exp(-t * 24) * .28 + RNG.standard_normal(len(t)) * np.exp(-t * 35) * .10)

    t, phase = sweep(.42, 550, 105)
    growl = np.sin(phase) * .30 + np.sin(2.3 * phase) * .16
    effects["bite"] = stereo((growl + RNG.standard_normal(len(t)) * .22) * np.sin(np.pi * t / .42) ** 2)

    t, phase = sweep(.48, 430, 76)
    heavy_air = RNG.standard_normal(len(t))
    heavy_air = np.convolve(heavy_air, np.ones(11) / 11, mode="same")
    effects["axe_swing"] = stereo((heavy_air * .58 + np.sin(phase) * .28) * np.sin(np.pi * t / .48) ** 2)

    t, phase = sweep(.44, 900, 130)
    effects["magic_miss"] = stereo((np.sin(phase) * .19 + RNG.standard_normal(len(t)) * .16) * np.exp(-t * 5.0))
    return effects


def write_wav(path: Path, samples: np.ndarray, peak: float) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    samples = samples / max(float(np.max(np.abs(samples))), 1e-6) * peak
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


if __name__ == "__main__":
    write_wav(OUT / "battle-theme.wav", battle_theme(), .78)
    for name, sound in sound_effects().items():
        write_wav(OUT / f"{name}.wav", sound, .72)
    write_wav(OUT / "battle-misty-pass.wav", misty_pass_theme(), .78)
    write_wav(OUT / "battle-iron-march.wav", iron_march_theme(), .78)
    write_wav(OUT / "battle-dawn-assault.wav", dawn_assault_theme(), .78)
    write_wav(OUT / "battle-last-bastion.wav", last_bastion_theme(), .78)
    print(f"Created original battle audio in {OUT}")
