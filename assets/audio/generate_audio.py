#!/usr/bin/env python3
"""Generate Blob Duels' deterministic, original procedural audio pack."""

from __future__ import annotations

import math
import random
import wave
from pathlib import Path
from typing import Callable, Iterable

RATE = 44100
ROOT = Path(__file__).resolve().parent
TAU = math.tau


def clamp(value: float, minimum: float = -1.0, maximum: float = 1.0) -> float:
    return max(minimum, min(maximum, value))


def sine(frequency: float, time_value: float, phase: float = 0.0) -> float:
    return math.sin(TAU * frequency * time_value + phase)


def triangle(frequency: float, time_value: float) -> float:
    phase = (frequency * time_value) % 1.0
    return 1.0 - 4.0 * abs(phase - 0.5)


def midi(note: int) -> float:
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def edge_fade(samples: list[float], seconds: float = 0.008) -> list[float]:
    count = min(int(seconds * RATE), len(samples) // 2)
    if count <= 0:
        return samples
    result = samples.copy()
    for index in range(count):
        gain = math.sin((index / count) * math.pi * 0.5) ** 2
        result[index] *= gain
        result[-index - 1] *= gain
    return result


def normalize(samples: list[float], peak: float = 0.86) -> list[float]:
    maximum = max((abs(sample) for sample in samples), default=1.0)
    gain = peak / maximum if maximum > peak else 1.0
    return [clamp(math.tanh(sample * gain * 1.08) / math.tanh(1.08)) for sample in samples]


def save_mono(name: str, samples: list[float], peak: float = 0.86) -> None:
    prepared = normalize(edge_fade(samples), peak)
    _save_wave(name, (prepared,), 1)


def save_stereo(name: str, left: list[float], right: list[float], peak: float = 0.82) -> None:
    interleaved = normalize(edge_fade([value for pair in zip(left, right) for value in pair]), peak)
    _save_wave(name, (interleaved,), 2, already_interleaved=True)


def _save_wave(
    name: str,
    channels: tuple[list[float], ...],
    channel_count: int,
    already_interleaved: bool = False,
) -> None:
    with wave.open(str(ROOT / name), "wb") as target:
        target.setnchannels(channel_count)
        target.setsampwidth(2)
        target.setframerate(RATE)
        frames = bytearray()
        source = channels[0] if already_interleaved else [value for row in zip(*channels) for value in row]
        for sample in source:
            value = int(clamp(sample) * 32767)
            frames.extend(value.to_bytes(2, "little", signed=True))
        target.writeframes(frames)


def make_tone(
    name: str,
    duration: float,
    start_frequency: float,
    end_frequency: float,
    harmonics: tuple[float, ...] = (1.0,),
    attack: float = 0.015,
    release: float = 0.2,
) -> None:
    length = int(duration * RATE)
    phase = 0.0
    samples: list[float] = []
    for index in range(length):
        progress = index / max(length - 1, 1)
        frequency = start_frequency + (end_frequency - start_frequency) * progress
        phase += TAU * frequency / RATE
        attack_gain = min(progress / max(attack, 0.001), 1.0)
        release_gain = min((1.0 - progress) / max(release, 0.001), 1.0)
        value = sum(math.sin(phase * (harmonic + 1)) * gain for harmonic, gain in enumerate(harmonics))
        samples.append(value * min(attack_gain, release_gain) * 0.52)
    save_mono(name, samples)


def make_noise_impact(
    name: str,
    duration: float,
    bass_frequency: float,
    brightness: float,
    rubber: float = 0.0,
    seed: int = 0,
) -> None:
    rng = random.Random(9100 + seed)
    length = int(duration * RATE)
    filtered = 0.0
    samples: list[float] = []
    for index in range(length):
        time_value = index / RATE
        progress = index / max(length - 1, 1)
        filtered += (rng.uniform(-1.0, 1.0) - filtered) * brightness
        thud = sine(bass_frequency * (1.0 - progress * 0.42), time_value)
        wobble = sine(bass_frequency * (2.3 + rubber * progress), time_value) * rubber
        gain = math.exp(-progress * (7.0 - rubber * 1.8))
        samples.append((filtered * 0.46 + thud * 0.7 + wobble * 0.28) * gain)
    save_mono(name, samples)


def make_loop_noise(
    name: str,
    duration: float,
    color: float,
    tone_frequency: float,
    pulse_rate: float,
    seed: int,
) -> None:
    rng = random.Random(seed)
    length = int(duration * RATE)
    raw = [rng.uniform(-1.0, 1.0) for _ in range(length)]
    filtered = 0.0
    samples: list[float] = []
    for index, noise in enumerate(raw):
        time_value = index / RATE
        filtered += (noise - filtered) * color
        pulse = 0.72 + 0.28 * sine(pulse_rate, time_value)
        tone = sine(tone_frequency, time_value) * 0.22 + sine(tone_frequency * 1.5, time_value) * 0.08
        samples.append((filtered * 0.55 + tone) * pulse * 0.55)
    save_mono(name, samples, 0.72)


def make_charge_pack() -> None:
    make_tone("charge_low.wav", 0.22, 145.0, 230.0, (1.0, 0.24), release=0.28)
    make_tone("fling_charge.wav", 0.72, 180.0, 760.0, (1.0, 0.22), release=0.32)
    make_tone("charge_max.wav", 0.5, 620.0, 1120.0, (1.0, 0.35, 0.12), release=0.38)

    duration = 1.2
    length = int(duration * RATE)
    samples = []
    for index in range(length):
        time_value = index / RATE
        pulse = 0.7 + 0.3 * sine(2.5, time_value)
        shimmer = sine(190.0, time_value) + sine(380.0, time_value) * 0.24 + sine(570.0, time_value) * 0.08
        samples.append(shimmer * pulse * 0.34)
    save_mono("charge_loop.wav", samples, 0.7)


def make_air_rush() -> None:
    make_loop_noise("air_rush_loop.wav", 1.6, 0.19, 52.0, 1.25, 7341)


def make_respawn() -> None:
    duration = 0.78
    length = int(duration * RATE)
    notes = (392.0, 523.25, 659.25, 783.99)
    samples: list[float] = []
    for index in range(length):
        time_value = index / RATE
        progress = index / max(length - 1, 1)
        value = 0.0
        for note_index, note in enumerate(notes):
            local = progress * len(notes) - note_index
            if 0.0 <= local <= 1.4:
                value += sine(note, time_value) * math.exp(-local * 2.3)
        samples.append(value * 0.3)
    save_mono("respawn.wav", samples)


def make_result_cue(name: str, notes: Iterable[int], duration: float = 1.25) -> None:
    note_list = list(notes)
    length = int(duration * RATE)
    slot_duration = duration / (len(note_list) + 0.6)
    samples: list[float] = []
    for index in range(length):
        time_value = index / RATE
        value = 0.0
        for note_index, note in enumerate(note_list):
            local = time_value - note_index * slot_duration
            if 0.0 <= local <= slot_duration * 1.8:
                gain = math.exp(-local * 4.2)
                frequency = midi(note)
                value += (sine(frequency, local) + sine(frequency * 2.0, local) * 0.22) * gain
        samples.append(value * 0.35)
    save_mono(name, samples)


def make_heartbeat() -> None:
    duration = 1.6
    length = int(duration * RATE)
    samples: list[float] = []
    for index in range(length):
        time_value = index / RATE
        value = 0.0
        for onset, gain in ((0.0, 1.0), (0.24, 0.72), (0.8, 1.0), (1.04, 0.72)):
            local = time_value - onset
            if 0.0 <= local <= 0.2:
                value += sine(58.0 - local * 80.0, local) * math.exp(-local * 22.0) * gain
        samples.append(value * 0.8)
    save_mono("low_health_loop.wav", samples, 0.76)


def make_music_track(
    name: str,
    bpm: float,
    bars: int,
    progression: tuple[int, ...],
    melody: tuple[int, ...],
    energy: float,
    seed: int,
    bright: bool = True,
) -> None:
    rng = random.Random(seed)
    beat = 60.0 / bpm
    duration = bars * beat * 4.0
    length = int(duration * RATE)
    left: list[float] = []
    right: list[float] = []
    noise = [rng.uniform(-1.0, 1.0) for _ in range(length)]
    for index in range(length):
        time_value = index / RATE
        beat_position = time_value / beat
        beat_phase = beat_position % 1.0
        eighth_phase = (beat_position * 2.0) % 1.0
        sixteenth_phase = (beat_position * 4.0) % 1.0
        bar = int(beat_position / 4.0) % len(progression)
        beat_number = int(beat_position) % 4
        root_note = progression[bar]

        kick = sine(78.0 - beat_phase * 42.0, time_value) * math.exp(-beat_phase * 10.0)
        snare_gate = 1.0 if beat_number in (1, 3) else 0.0
        snare = noise[index] * math.exp(-beat_phase * 15.0) * snare_gate
        hat = noise[index] * math.exp(-eighth_phase * 27.0)

        bass_frequency = midi(root_note - 24)
        bass_gate = math.exp(-beat_phase * (2.8 if energy > 0.6 else 1.7))
        bass = (sine(bass_frequency, time_value) + triangle(bass_frequency, time_value) * 0.2) * bass_gate

        step = int(beat_position * 2.0) % len(melody)
        lead_frequency = midi(root_note + melody[step])
        lead_gate = math.exp(-eighth_phase * (4.0 if bright else 2.6))
        lead = (sine(lead_frequency, time_value) + sine(lead_frequency * 2.0, time_value) * 0.15) * lead_gate

        chord = 0.0
        for interval in ((0, 4, 7) if bright else (0, 3, 7)):
            chord += sine(midi(root_note + interval), time_value, interval * 0.17)
        chord = chord / 3.0 * (0.66 + 0.34 * sine(0.25 / beat, time_value))

        sync = sine(midi(root_note + 12), time_value) * math.exp(-sixteenth_phase * 8.0)
        drum = kick * (0.2 + energy * 0.16) + snare * energy * 0.12 + hat * (0.025 + energy * 0.07)
        center = bass * (0.16 + energy * 0.08) + chord * (0.1 + (1.0 - energy) * 0.06) + drum
        lead_gain = 0.035 + energy * 0.055
        sync_gain = max(0.0, energy - 0.52) * 0.055
        left.append(center + lead * lead_gain * 1.12 + sync * sync_gain * 0.72)
        right.append(center + lead * lead_gain * 0.82 + sync * sync_gain * 1.2)
    save_stereo(name, left, right)


def make_themed_music_track(
    name: str,
    bpm: float,
    progression: tuple[int, ...],
    melody: tuple[int, ...],
    theme: str,
    seed: int,
) -> None:
    """Build a map-specific eight-bar loop from deterministic synthesized voices."""
    rng = random.Random(seed)
    beat = 60.0 / bpm
    duration = 8.0 * beat * 4.0
    length = int(duration * RATE)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(length)]
    left: list[float] = []
    right: list[float] = []

    for index in range(length):
        time_value = index / RATE
        beat_position = time_value / beat
        beat_phase = beat_position % 1.0
        eighth_phase = (beat_position * 2.0) % 1.0
        sixteenth_phase = (beat_position * 4.0) % 1.0
        beat_number = int(beat_position) % 4
        bar = int(beat_position / 4.0) % len(progression)
        root_note = progression[bar]
        melody_step = int(beat_position * 2.0) % len(melody)
        lead_frequency = midi(root_note + melody[melody_step])
        bass_frequency = midi(root_note - 24)

        kick = sine(76.0 - beat_phase * 39.0, time_value) * math.exp(-beat_phase * 10.5)
        snare_gate = 1.0 if beat_number in (1, 3) else 0.0
        snare = noise[index] * math.exp(-beat_phase * 18.0) * snare_gate
        hat = noise[index] * math.exp(-eighth_phase * 30.0)
        bass = (sine(bass_frequency, time_value) + triangle(bass_frequency, time_value) * 0.18) * math.exp(-beat_phase * 2.6)
        center = kick * 0.31 + snare * 0.08 + hat * 0.035 + bass * 0.22
        themed_left = 0.0
        themed_right = 0.0

        if theme == "neon_arcade":
            chip = (
                sine(lead_frequency, time_value)
                + sine(lead_frequency * 3.0, time_value) / 3.0
                + sine(lead_frequency * 5.0, time_value) / 5.0
            ) * math.exp(-sixteenth_phase * 5.8)
            arpeggio_note = (0, 7, 12, 19)[int(beat_position * 4.0) % 4]
            arpeggio = triangle(midi(root_note + arpeggio_note), time_value) * math.exp(-sixteenth_phase * 8.0)
            laser = sine(midi(root_note + 24) * (1.0 + sixteenth_phase * 0.035), time_value) * math.exp(-sixteenth_phase * 13.0)
            themed_left = chip * 0.105 + arpeggio * 0.07 + laser * 0.024
            themed_right = chip * 0.075 + arpeggio * 0.105 + laser * 0.036
        elif theme == "backyard":
            pluck = (sine(lead_frequency, time_value) + triangle(lead_frequency * 0.5, time_value) * 0.28) * math.exp(-eighth_phase * 7.2)
            wood_gate = math.exp(-beat_phase * 38.0) if beat_number in (0, 2) else 0.0
            wood = (noise[index] * 0.36 + sine(188.0, time_value) * 0.64) * wood_gate
            breeze = (sine(midi(root_note), time_value) + sine(midi(root_note + 7), time_value)) * 0.5
            themed_left = pluck * 0.105 + wood * 0.06 + breeze * 0.035
            themed_right = pluck * 0.09 + wood * 0.035 + breeze * 0.05
            center = kick * 0.2 + snare * 0.045 + hat * 0.018 + bass * 0.16
        elif theme == "arena":
            saw = sum(sine(lead_frequency * harmonic, time_value) / harmonic for harmonic in range(1, 6))
            saw *= math.exp(-eighth_phase * 5.0)
            machine_gate = math.exp(-sixteenth_phase * 24.0)
            machine = (noise[index] * 0.3 + sine(112.0 + beat_number * 18.0, time_value) * 0.7) * machine_gate
            alarm = sine(midi(root_note + 19), time_value) * (0.55 + 0.45 * sine(0.5 / beat, time_value))
            themed_left = saw * 0.075 + machine * 0.09 + alarm * 0.026
            themed_right = saw * 0.055 + machine * 0.06 + alarm * 0.04
            center = kick * 0.38 + snare * 0.12 + hat * 0.055 + bass * 0.25
        elif theme == "sky_temple":
            bell = (
                sine(lead_frequency, time_value)
                + sine(lead_frequency * 2.01, time_value) * 0.42
                + sine(lead_frequency * 3.98, time_value) * 0.18
            ) * math.exp(-eighth_phase * 3.5)
            high_bell = sine(lead_frequency * 2.0, time_value) * math.exp(-sixteenth_phase * 10.0)
            pad = sum(sine(midi(root_note + interval), time_value, interval * 0.13) for interval in (0, 7, 14)) / 3.0
            themed_left = bell * 0.08 + high_bell * 0.025 + pad * 0.09
            themed_right = bell * 0.105 + high_bell * 0.045 + pad * 0.075
            center = kick * 0.17 + snare * 0.035 + hat * 0.022 + bass * 0.13
        else:  # toybox
            music_box = (
                triangle(lead_frequency, time_value)
                + sine(lead_frequency * 2.0, time_value) * 0.28
                + sine(lead_frequency * 4.0, time_value) * 0.1
            ) * math.exp(-eighth_phase * 6.2)
            toy_drum = sine(235.0 + beat_number * 44.0, time_value) * math.exp(-beat_phase * 24.0)
            winding = triangle(midi(root_note + 12), time_value) * (0.6 + 0.4 * sine(2.0 / beat, time_value))
            pan_left = 1.15 if melody_step % 2 == 0 else 0.72
            pan_right = 0.72 if melody_step % 2 == 0 else 1.15
            themed_left = music_box * 0.1 * pan_left + toy_drum * 0.04 + winding * 0.026
            themed_right = music_box * 0.1 * pan_right + toy_drum * 0.055 + winding * 0.038
            center = kick * 0.21 + snare * 0.04 + hat * 0.025 + bass * 0.16

        left.append(center + themed_left)
        right.append(center + themed_right)
    save_stereo(name, left, right)


def make_map_music_pack() -> None:
    make_themed_music_track(
        "music_match_neon_arcade.wav", 134.0, (57, 60, 64, 62),
        (0, 7, 12, 4, 16, 12, 7, 19), "neon_arcade", 2101,
    )
    make_themed_music_track(
        "music_match_backyard.wav", 106.0, (60, 65, 57, 67),
        (0, 4, 7, 9, 7, 4, 12, 9), "backyard", 2102,
    )
    make_themed_music_track(
        "music_match_arena.wav", 140.0, (50, 53, 57, 55),
        (0, 3, 7, 10, 12, 7, 5, 3), "arena", 2103,
    )
    make_themed_music_track(
        "music_match_sky_temple.wav", 114.0, (62, 67, 59, 64),
        (0, 7, 12, 16, 14, 9, 7, 19), "sky_temple", 2104,
    )
    make_themed_music_track(
        "music_match_toybox.wav", 124.0, (60, 64, 67, 65),
        (0, 4, 7, 12, 9, 7, 16, 12), "toybox", 2105,
    )


def make_music_pack() -> None:
    make_music_track("music_lobby.wav", 96.0, 8, (57, 62, 54, 59), (0, 4, 7, 11, 7, 4, 2, 7), 0.28, 1101)
    make_music_track("music_lobby_b.wav", 102.0, 8, (60, 55, 57, 64), (0, 7, 9, 4, 12, 9, 7, 4), 0.32, 1111)
    make_music_track("music_lobby_c.wav", 90.0, 8, (62, 57, 65, 60), (0, 4, 7, 2, 9, 7, 11, 4), 0.24, 1112, False)
    make_music_track("music_practice.wav", 112.0, 8, (60, 57, 65, 62), (0, 7, 4, 9, 7, 12, 9, 4), 0.48, 1102)
    make_music_track("music_match_a.wav", 126.0, 8, (57, 60, 64, 62), (0, 7, 12, 4, 9, 7, 2, 11), 0.68, 1103)
    make_music_track("music_match_b.wav", 132.0, 8, (62, 65, 57, 60), (0, 3, 7, 10, 12, 7, 5, 10), 0.72, 1104, False)
    make_music_track("music_intensity.wav", 148.0, 8, (57, 60, 62, 64), (0, 12, 7, 15, 12, 19, 7, 14), 0.98, 1105)
    make_music_track("music_victory.wav", 120.0, 4, (60, 65, 67, 72), (0, 4, 7, 12, 16, 12, 19, 24), 0.62, 1106)
    make_music_track("music_defeat.wav", 84.0, 4, (57, 53, 50, 45), (0, 3, 7, 5, 3, 0, -2, 0), 0.24, 1107, False)
    make_map_music_pack()


def make_world_sfx_pack() -> None:
    duration = 0.24
    length = int(duration * RATE)
    display: list[float] = []
    for index in range(length):
        time_value = index / RATE
        value = 0.0
        for onset, frequency in ((0.0, 880.0), (0.085, 1320.0)):
            local = time_value - onset
            if 0.0 <= local <= 0.14:
                value += (sine(frequency, local) + sine(frequency * 2.0, local) * 0.18) * math.exp(-local * 28.0)
        display.append(value * 0.42)
    save_mono("display_chirp.wav", display)

    rng = random.Random(3102)
    duration = 0.42
    length = int(duration * RATE)
    machinery: list[float] = []
    for index in range(length):
        time_value = index / RATE
        progress = index / max(length - 1, 1)
        pulse = math.exp(-progress * 7.0)
        gear = triangle(74.0 - progress * 18.0, time_value) + sine(148.0, time_value) * 0.28
        machinery.append((gear * 0.48 + rng.uniform(-1.0, 1.0) * 0.14) * pulse)
    save_mono("machinery_pulse.wav", machinery)

    rng = random.Random(3103)
    duration = 0.82
    length = int(duration * RATE)
    portal: list[float] = []
    filtered = 0.0
    phase = 0.0
    for index in range(length):
        progress = index / max(length - 1, 1)
        frequency = 210.0 + progress * progress * 1280.0
        phase += TAU * frequency / RATE
        filtered += (rng.uniform(-1.0, 1.0) - filtered) * 0.14
        envelope = math.sin(math.pi * progress) ** 0.65
        portal.append((math.sin(phase) * 0.5 + math.sin(phase * 1.51) * 0.18 + filtered * 0.16) * envelope)
    save_mono("portal_teleport.wav", portal)

    duration = 0.34
    length = int(duration * RATE)
    bumper: list[float] = []
    for index in range(length):
        time_value = index / RATE
        progress = index / max(length - 1, 1)
        frequency = 132.0 + progress * 420.0
        wobble = sine(frequency, time_value) + sine(frequency * 2.35, time_value) * 0.3
        bumper.append(wobble * math.exp(-progress * 5.6) * 0.62)
    save_mono("bumper_hit.wav", bumper)

    rng = random.Random(3105)
    duration = 0.58
    length = int(duration * RATE)
    conveyor: list[float] = []
    for index in range(length):
        time_value = index / RATE
        value = 0.0
        for onset in (0.0, 0.14, 0.28, 0.42):
            local = time_value - onset
            if 0.0 <= local <= 0.11:
                click = sine(280.0 - local * 900.0, local) * 0.55 + rng.uniform(-1.0, 1.0) * 0.22
                value += click * math.exp(-local * 38.0)
        conveyor.append(value * 0.62)
    save_mono("conveyor_rail.wav", conveyor)

    duration = 0.72
    length = int(duration * RATE)
    sparkle: list[float] = []
    for index in range(length):
        time_value = index / RATE
        value = 0.0
        for onset, note in ((0.0, 79), (0.11, 86), (0.28, 83), (0.43, 91)):
            local = time_value - onset
            if 0.0 <= local <= 0.28:
                frequency = midi(note)
                value += (sine(frequency, local) + sine(frequency * 2.01, local) * 0.32) * math.exp(-local * 12.0)
        sparkle.append(value * 0.22)
    save_mono("ambient_sparkle.wav", sparkle)


def make_legacy_ambience() -> None:
    make_loop_noise("city_ambience.wav", 8.0, 0.008, 42.0, 0.17, 7359)
    # Legacy match filename remains a complete track for old scene/resource references.
    make_music_track("city_duel_loop.wav", 126.0, 8, (57, 60, 64, 62), (0, 7, 12, 4, 9, 7, 2, 11), 0.68, 1103)


def main() -> None:
    make_tone("ui_hover.wav", 0.075, 720.0, 940.0, (1.0, 0.2), release=0.3)
    make_tone("ui_click.wav", 0.11, 540.0, 390.0, (1.0, 0.28), release=0.25)
    make_tone("ui_back.wav", 0.13, 520.0, 260.0, (1.0, 0.2), release=0.28)
    make_tone("ui_open.wav", 0.18, 360.0, 720.0, (1.0, 0.18), release=0.24)
    make_tone("ui_close.wav", 0.16, 680.0, 340.0, (1.0, 0.18), release=0.28)

    make_tone("projectile_fire.wav", 0.16, 1380.0, 230.0, (1.0, 0.42, 0.16), release=0.22)
    make_tone("shoot.wav", 0.16, 1380.0, 230.0, (1.0, 0.42, 0.16), release=0.22)
    make_noise_impact("projectile_impact.wav", 0.22, 86.0, 0.2, seed=1)
    make_tone("damage.wav", 0.28, 310.0, 92.0, (1.0, 0.31), release=0.34)

    make_tone("blob_bounce.wav", 0.2, 165.0, 345.0, (1.0, 0.28), release=0.3)
    make_noise_impact("blob_hard_impact.wav", 0.34, 58.0, 0.1, rubber=0.25, seed=2)
    make_noise_impact("wall_impact.wav", 0.3, 64.0, 0.16, seed=3)
    make_noise_impact("blob_collision.wav", 0.36, 72.0, 0.08, rubber=0.7, seed=4)

    make_charge_pack()
    make_tone("fling_release.wav", 0.29, 250.0, 1040.0, (1.0, 0.36), release=0.28)
    make_noise_impact("fling_full_launch.wav", 0.52, 48.0, 0.22, rubber=0.18, seed=5)
    make_air_rush()

    make_tone("launch_pad.wav", 0.46, 120.0, 920.0, (1.0, 0.32, 0.14), release=0.3)
    make_loop_noise("wind_loop.wav", 2.0, 0.06, 34.0, 0.5, 7401)
    make_loop_noise("machinery_loop.wav", 2.4, 0.012, 46.0, 2.5, 7402)
    make_world_sfx_pack()
    make_heartbeat()
    make_respawn()

    make_result_cue("round_start.wav", (60, 67, 72), 0.95)
    make_result_cue("round_end.wav", (72, 67, 60), 0.95)
    make_result_cue("victory.wav", (60, 64, 67, 72), 1.45)
    make_result_cue("defeat.wav", (60, 57, 53, 48), 1.5)
    make_music_pack()
    make_legacy_ambience()


if __name__ == "__main__":
    main()
