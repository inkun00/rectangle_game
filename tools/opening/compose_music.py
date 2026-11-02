"""Compose the original 55-second Quadrilateral World opening score locally.

Only NumPy synthesis is used: no samples, recordings, network, or music APIs.
FFmpeg is used only for measured loudness normalization and verification.
Run: python tools/opening/compose_music.py
"""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import wave
from pathlib import Path

import imageio_ffmpeg
import numpy as np


RATE: int = 48_000
DURATION: float = 55.0
BPM: int = 120
BEAT: float = 60.0 / BPM
FRAME_COUNT: int = round(DURATION * RATE)
ROOT: Path = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT: Path = ROOT / "output" / "opening" / "soundtrack.wav"
RNG: np.random.Generator = np.random.default_rng(441104)
MIX: np.ndarray = np.zeros((FRAME_COUNT, 2), dtype=np.float64)


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def timeline(seconds: float) -> np.ndarray:
    return np.arange(max(1, round(seconds * RATE)), dtype=np.float64) / RATE


def envelope(t: np.ndarray, attack: float, release: float) -> np.ndarray:
    attack_ramp = np.minimum(1.0, t / max(attack, 1.0 / RATE))
    remaining = t[-1] - t
    release_ramp = np.minimum(1.0, remaining / max(release, 1.0 / RATE))
    return np.sin(attack_ramp * math.pi / 2) ** 2 * np.sin(release_ramp * math.pi / 2) ** 2


def place(signal: np.ndarray, when: float, gain: float = 1.0, pan: float = 0.0) -> None:
    start = round(when * RATE)
    skip = max(0, -start)
    start = max(0, start)
    count = min(len(signal) - skip, FRAME_COUNT - start)
    if count <= 0:
        return
    angle = (max(-1.0, min(1.0, pan)) + 1.0) * math.pi / 4.0
    stereo_gain = np.array([math.cos(angle), math.sin(angle)])
    MIX[start : start + count] += signal[skip : skip + count, None] * stereo_gain[None, :] * gain


def marimba(midi: float, seconds: float = 0.65, bright: float = 1.0) -> np.ndarray:
    t = timeline(seconds)
    frequency = hz(midi)
    body = np.sin(2 * math.pi * frequency * t) * np.exp(-t / 0.31)
    body += 0.31 * bright * np.sin(2 * math.pi * frequency * 3.98 * t) * np.exp(-t / 0.065)
    body += 0.085 * bright * np.sin(2 * math.pi * frequency * 9.93 * t) * np.exp(-t / 0.022)
    return body * envelope(t, 0.004, 0.05)


def pluck(midi: float, seconds: float = 1.1) -> np.ndarray:
    t = timeline(seconds)
    frequency = hz(midi)
    body = np.zeros_like(t)
    for partial in range(1, 7):
        body += np.sin(2 * math.pi * frequency * partial * t) * np.exp(-t * (2.8 + partial * 0.7)) / partial**1.65
    return body * envelope(t, 0.007, 0.09)


def celeste(midi: float, seconds: float = 2.2) -> np.ndarray:
    t = timeline(seconds)
    frequency = hz(midi)
    body = np.sin(2 * math.pi * frequency * t) * np.exp(-t / 0.9)
    body += 0.25 * np.sin(2 * math.pi * frequency * 2.001 * t) * np.exp(-t / 0.42)
    body += 0.09 * np.sin(2 * math.pi * frequency * 4.007 * t) * np.exp(-t / 0.18)
    return body * envelope(t, 0.006, 0.18)


def pad(midi: float, seconds: float, warm: bool = False) -> np.ndarray:
    t = timeline(seconds)
    frequency = hz(midi)
    body = np.zeros_like(t)
    harmonics = [1.0, 0.16, 0.075, 0.025] if warm else [1.0, 0.065, 0.022]
    for partial, amplitude in enumerate(harmonics, 1):
        for detune, phase in [(-0.0012, 0.0), (0.0015, 0.8)]:
            body += amplitude * np.sin(2 * math.pi * frequency * partial * (1 + detune) * t + phase) / 2
    body *= 0.94 + 0.06 * np.sin(2 * math.pi * 0.34 * t)
    return body * envelope(t, min(0.7, seconds / 4), min(0.85, seconds / 3))


def bass(midi: float, seconds: float = 0.48) -> np.ndarray:
    t = timeline(seconds)
    frequency = hz(midi)
    body = np.sin(2 * math.pi * frequency * t)
    body += 0.22 * np.sin(4 * math.pi * frequency * t)
    body += 0.055 * np.sin(6 * math.pi * frequency * t)
    return body * np.exp(-t / 0.32) * envelope(t, 0.012, 0.10)


def kick() -> np.ndarray:
    t = timeline(0.21)
    phase = 2 * math.pi * (48 * t + 42 * 0.028 * (1 - np.exp(-t / 0.028)))
    return np.sin(phase) * np.exp(-t / 0.065) * envelope(t, 0.003, 0.03)


def wood(high: bool = False) -> np.ndarray:
    t = timeline(0.095)
    noise = RNG.normal(0, 1, len(t))
    low_noise = np.convolve(noise, np.ones(7) / 7, mode="same")
    frequency = 840 if high else 560
    body = np.sin(2 * math.pi * frequency * t) * np.exp(-t / 0.015)
    body += 0.3 * np.sin(2 * math.pi * frequency * 1.47 * t) * np.exp(-t / 0.009)
    body += 0.15 * low_noise * np.exp(-t / 0.012)
    return body * envelope(t, 0.001, 0.012)


def shaker() -> np.ndarray:
    t = timeline(0.065)
    noise = RNG.normal(0, 0.5, len(t))
    high_noise = noise - np.convolve(noise, np.ones(9) / 9, mode="same")
    softened = np.convolve(high_noise, np.ones(3) / 3, mode="same")
    return softened * np.exp(-t / 0.022) * envelope(t, 0.005, 0.016)


def glide(start_midi: float, end_midi: float, seconds: float) -> np.ndarray:
    t = timeline(seconds)
    midi = start_midi + (end_midi - start_midi) * np.minimum(1, t / seconds)
    phase = 2 * math.pi * np.cumsum(440 * 2 ** ((midi - 69) / 12)) / RATE
    return (np.sin(phase) + 0.11 * np.sin(phase * 2)) * envelope(t, 0.035, 0.15)


def chime(when: float, notes: list[int], gain: float = 0.16) -> None:
    for index, note in enumerate(notes):
        place(celeste(note, 1.65), when + index * 0.085, gain, -0.22 + index * 0.13)


def space_and_crash() -> None:
    for note, pan in [(48, -0.45), (55, 0.4), (64, -0.15), (71, 0.2)]:
        place(pad(note, 7.8), 0, 0.055, pan)
    for when, note, pan in [(0.45, 84, -0.5), (1.4, 79, 0.45), (2.15, 88, -0.18),
                            (3.0, 86, 0.38), (4.15, 83, -0.4), (5.15, 79, 0.3),
                            (6.25, 88, -0.1)]:
        place(celeste(note), when, 0.072, pan)
    for index, note in enumerate([72, 76, 79, 83]):
        place(pluck(note, 1.4), 3.65 + index * 0.5, 0.074, -0.3 + index * 0.2)
    place(glide(85, 43, 1.65), 7.15, 0.11, -0.25)
    t = timeline(1.25)
    noise = RNG.normal(0, 0.5, len(t))
    airy = np.convolve(noise, np.ones(37) / 37, mode="same")
    place(airy * np.sin(math.pi * t / 1.25) ** 2, 7.95, 0.36, 0.18)
    t = timeline(0.8)
    phase = 2 * math.pi * (34 * t + 41 * 0.036 * (1 - np.exp(-t / 0.036)))
    thump = np.sin(phase) * np.exp(-t / 0.16) * envelope(t, 0.004, 0.16)
    place(thump, 9.1, 0.37)
    place(wood(), 9.13, 0.11, -0.2)
    for when, note, gain in [(9.55, 55, 0.10), (10.0, 52, 0.08), (10.5, 48, 0.06)]:
        place(marimba(note, 0.5), when, gain, 0.18)
    place(wood(), 11.58, 0.07, -0.15)
    place(pluck(48, 0.8), 11.72, 0.09, -0.12)
    place(pluck(43, 0.8), 12.15, 0.065, 0.1)
    for index, note in enumerate([67, 72, 76]):
        place(marimba(note), 13.25 + index * 0.25, 0.07, -0.2 + index * 0.2)


CHORDS: list[tuple[list[int], int]] = [
    ([60, 64, 67, 71], 36), ([57, 60, 64, 67], 33),
    ([53, 57, 60, 64], 29), ([55, 59, 62, 67], 31),
    ([52, 55, 59, 62], 28), ([57, 60, 64, 67], 33),
    ([50, 53, 57, 60], 26), ([55, 59, 62, 64], 31),
    ([53, 57, 60, 65], 29), ([60, 64, 67, 72], 36),
    ([57, 60, 64, 69], 33), ([55, 59, 62, 67], 31),
    ([53, 57, 60, 64], 29), ([55, 59, 62, 67], 31),
    ([52, 55, 59, 64], 28), ([57, 60, 64, 67], 33),
    ([50, 53, 57, 62], 26), ([55, 59, 62, 67], 31),
    ([60, 64, 67, 72], 36), ([60, 64, 67, 72], 36),
]

# Original melody: each tuple is beat offset, MIDI note, held duration in beats.
MELODY: list[list[tuple[float, int, float]]] = [
    [(0.5, 76, 0.5), (1.25, 79, 0.5), (2.0, 81, 0.75), (3.0, 79, 0.75)],
    [(0.0, 76, 0.75), (1.0, 72, 0.5), (1.75, 74, 0.5), (2.5, 76, 1.0)],
    [(0.5, 77, 0.75), (1.5, 76, 0.5), (2.25, 72, 0.5), (3.0, 69, 0.75)],
    [(0.0, 71, 0.75), (1.0, 74, 0.5), (2.0, 79, 1.25)],
    [(0.5, 79, 0.5), (1.25, 76, 0.5), (2.0, 74, 0.5), (3.0, 71, 0.75)],
    [(0.0, 72, 0.5), (0.75, 76, 0.5), (1.5, 81, 0.75), (2.75, 79, 0.75)],
    [(0.5, 77, 0.75), (1.75, 74, 0.5), (2.5, 72, 0.5), (3.25, 69, 0.5)],
    [(0.0, 71, 0.5), (1.0, 74, 0.75), (2.0, 76, 0.5), (3.0, 74, 0.75)],
    [(0.25, 77, 0.5), (1.0, 81, 0.5), (2.0, 84, 0.75), (3.0, 81, 0.5)],
    [(0.0, 79, 0.75), (1.0, 76, 0.5), (2.0, 72, 1.0)],
    [(0.5, 76, 0.5), (1.25, 79, 0.5), (2.0, 81, 0.5), (3.0, 84, 0.75)],
    [(0.0, 83, 0.75), (1.0, 79, 0.5), (2.0, 74, 0.5), (3.0, 79, 0.75)],
    [(0.0, 81, 1.5), (2.0, 79, 0.75), (3.0, 77, 0.75)],
    [(0.0, 79, 1.25), (1.5, 83, 0.75), (2.75, 86, 1.0)],
    [(0.0, 83, 1.25), (1.5, 79, 0.75), (3.0, 76, 0.75)],
    [(0.0, 81, 1.5), (2.0, 79, 0.5), (3.0, 76, 0.75)],
    [(0.0, 77, 1.5), (2.0, 81, 1.0)],
    [(0.0, 79, 1.0), (1.5, 83, 0.75), (2.5, 86, 0.5), (3.25, 83, 0.5)],
    [(0.0, 84, 2.0), (2.5, 79, 1.0)],
    [(0.0, 76, 0.75), (1.0, 79, 0.75), (2.0, 84, 3.2)],
]


def adventure() -> None:
    for bar, ((chord, root), phrase) in enumerate(zip(CHORDS, MELODY)):
        when = 14.0 + bar * 4 * BEAT
        warm = bar >= 12
        final = bar >= 18
        energy = 0.76 if bar < 2 else (1.02 if warm else 0.90)
        for index, note in enumerate(chord):
            place(pad(note, 2.65 if not final else 3.5, warm), when - 0.08,
                  (0.026 if warm else 0.017) * energy, -0.65 + index * 0.43)
        bass_notes = [(0.0, root), (2.0, root + 7), (3.5, root + 12)]
        if final:
            bass_notes = [(0.0, root), (2.0, root + 12)]
        for beat, note in bass_notes:
            place(bass(note, 0.65 if final else 0.48), when + beat * BEAT, 0.15 * energy)
        if bar < 19:
            for step in range(8):
                if step == 6 or (bar % 4 == 3 and step == 7):
                    continue
                note = chord[[0, 2, 1, 3, 2, 1, 0, 2][step]] + 12
                gain = (0.039 if warm else 0.046) * energy * (1 if step % 2 == 0 else 0.72)
                place(marimba(note, 0.48, 0.75), when + step * BEAT / 2, gain,
                      -0.45 if step % 2 == 0 else 0.38)
        for beat, note, held in phrase:
            body = celeste(note, max(1.1, held * BEAT + 0.4)) if warm else marimba(note, max(0.6, held * BEAT + 0.25))
            place(body, when + beat * BEAT, (0.075 if warm else 0.105) * energy,
                  math.sin(bar * 0.9) * 0.18)
            if bar >= 16:
                place(pluck(note - 12, 1.3), when + beat * BEAT + 0.012, 0.027, -0.32)
        if bar < 19:
            for beat in [0.0, 2.0]:
                place(kick(), when + beat * BEAT, 0.105 * energy)
            for beat in [1.0, 3.0]:
                place(wood(bar % 2 == 0), when + beat * BEAT, 0.057 * energy, 0.22)
            for step in range(8):
                gain = 0.037 if step % 2 else 0.022
                place(shaker(), when + step * BEAT / 2 + 0.014, gain * energy, -0.40)
    chime(14.6, [84, 88, 91], 0.105)
    chime(24.0, [84, 88, 91, 96], 0.105)
    for index in range(11):
        place(wood(index % 3 == 0), 31.0 + index * 0.5, 0.075, -0.35 + (index % 4) * 0.23)
    chime(37.4, [79, 84, 88, 91], 0.11)
    for index, note in enumerate([72, 76, 79, 84, 88, 91]):
        place(celeste(note, 2.4), 47.0 + index * 0.25, 0.055, -0.55 + index * 0.22)
    for index, note in enumerate([48, 60, 64, 67, 72]):
        place(pad(note, 3.0, True), 52.0, 0.035, -0.6 + index * 0.3)


def finish_mix() -> np.ndarray:
    # Short, quiet diffuse reflections retain the wooden attacks and speech-free clarity.
    dry = MIX.copy()
    for delay, gain, swap in [(0.071, 0.075, False), (0.113, 0.065, True),
                              (0.191, 0.050, True), (0.307, 0.033, False),
                              (0.463, 0.022, True)]:
        offset = round(delay * RATE)
        echo = dry[:-offset, ::-1] if swap else dry[:-offset]
        MIX[offset:] += echo * gain
    t = np.arange(FRAME_COUNT) / RATE
    fade_in = np.sin(np.minimum(1, t / 0.4) * math.pi / 2) ** 2
    fade_out = np.sin(np.minimum(1, np.maximum(0, DURATION - t) / 1.0) * math.pi / 2) ** 2
    MIX[:] *= (fade_in * fade_out)[:, None]
    MIX[:] -= np.mean(MIX, axis=0, keepdims=True)
    MIX[-1] = 0.0
    peak = np.max(np.abs(MIX))
    return (MIX * (0.70 / max(peak, 1e-12))).astype("<f4")


def loudness_json(stderr: str) -> dict[str, str]:
    blocks = re.findall(r'\{\s*"input_i"[^}]+\}', stderr, re.DOTALL)
    if not blocks:
        raise RuntimeError("FFmpeg did not provide a loudness measurement: " + stderr[-1000:])
    return json.loads(blocks[-1])


def export_audio(output: Path, mix: np.ndarray) -> None:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    raw = mix.tobytes()
    base = [ffmpeg, "-hide_banner", "-nostdin", "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "pipe:0"]
    measured = subprocess.run(base + ["-af", "loudnorm=I=-18:TP=-2:LRA=11:print_format=json", "-f", "null", "-"],
                              input=raw, capture_output=True, check=True)
    stats = loudness_json(measured.stderr.decode("utf-8", errors="replace"))
    normalizer = (f"loudnorm=I=-18:TP=-2:LRA=11:measured_I={stats['input_i']}:"
                  f"measured_TP={stats['input_tp']}:measured_LRA={stats['input_lra']}:"
                  f"measured_thresh={stats['input_thresh']}:offset={stats['target_offset']}:"
                  "linear=true:print_format=json")
    output.parent.mkdir(parents=True, exist_ok=True)
    encoded = subprocess.run(base + ["-af", normalizer, "-ar", str(RATE), "-ac", "2", "-c:a", "pcm_s16le", "-y", str(output)],
                             input=raw, capture_output=True, check=True)
    normalized = loudness_json(encoded.stderr.decode("utf-8", errors="replace"))
    with wave.open(str(output), "rb") as audio:
        if (audio.getnchannels(), audio.getframerate(), audio.getnframes()) != (2, RATE, FRAME_COUNT):
            raise RuntimeError("Unexpected output channels, rate, or duration")
        pcm = np.frombuffer(audio.readframes(FRAME_COUNT), dtype="<i2").astype(np.float64) / 32768
    peak = float(np.max(np.abs(pcm)))
    if peak >= 0.90 or not np.all(np.isfinite(pcm)):
        raise RuntimeError("Invalid or excessive output peak")
    checked = subprocess.run([ffmpeg, "-hide_banner", "-nostdin", "-i", str(output), "-af",
                              "loudnorm=I=-18:TP=-2:LRA=11:print_format=json", "-f", "null", "-"],
                             capture_output=True, check=True)
    actual = loudness_json(checked.stderr.decode("utf-8", errors="replace"))
    print(json.dumps({"output": str(output), "duration_seconds": DURATION, "sample_rate": RATE,
                      "channels": 2, "samples_per_channel": FRAME_COUNT,
                      "peak_dbfs": round(20 * math.log10(peak), 3),
                      "integrated_lufs": actual["input_i"], "true_peak_dbtp": actual["input_tp"],
                      "loudness_range_lu": actual["input_lra"],
                      "normalization_type": normalized["normalization_type"],
                      "clipped_samples": int(np.count_nonzero(np.abs(pcm) >= 1)),
                      "original_procedural_score": True}, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    space_and_crash()
    adventure()
    export_audio(args.output.resolve(), finish_mix())


if __name__ == "__main__":
    main()
