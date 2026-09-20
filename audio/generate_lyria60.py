"""Generate Aurora Lake, Tidal Origami and Pilgrim Tides as Lyria 3.5 scores whose own beat is the strict 60 BPM grid.

Lyria RealTime ignores its `bpm` setting (takes asked for 60 BPM measured about 72 BPM), so the previous scores laid a
synthesized pulse over beatless RealTime beds whose own motion kept its own tempo. Lyria 3.5 keeps a tempo written into
its prompt: a 178-second take asked for 60 BPM holds one beat phase, window after window, from its first second to its
last. Each score is now three Lyria 3.5 movements in one key and palette, each asked for a soft pulse on every beat and
for uninterrupted sustained openings and endings. For every take this script

- decodes the MP3 once, so the samples measured are the samples delivered;
- measures the beat period and phase from librosa onset strength folded over the beat in 16-second windows, rejecting
  takes whose phase wanders, and tells the beat from the off-beat over the whole take;
- finds the strongest beat of the bar, so bar lines continue through every crossfade;
- resamples to 48 kHz with the measured period folded into the rate, and places the take so every beat lands with the
  breath tick on a whole second of the session.

The movements are joined by 16-second equal-power crossfades that start and end on bar lines (on breath-cycle
boundaries where the cycle allows), the score is mastered, and the runtime file is replaced only after `audio.beat_grid`
confirms the lock. No pulse is added: the beat heard is the beat Lyria played.

    python -m audio.generate_lyria60 generate [ids] [--takes 2]
    python -m audio.generate_lyria60 measure [ids]
    python -m audio.generate_lyria60 master [ids]
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import itertools
import json
import os
import subprocess
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from scipy.io import wavfile

from audio import beat_grid
from audio.generate_music import probe
from audio.stitch_music import RATE, run

ROOT = Path(__file__).resolve().parents[1]
MASTERS = ROOT / 'audio/masters/lyria60'
ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/interactions'
MODEL = 'lyria-3.5'
BPM = 60
SECONDS = 480
CROSSFADE = 16
FADE_IN = 8
FADE_OUT = 8
# A crossfade may begin while the incoming take is still swelling in, and end while the outgoing one is dying away,
# by this many seconds (the other take then still carries at least 85% of the power).
SWELL = 4
# A take is usable while each second stays within this many dB of its median loudness (quiet endings stay usable).
PRESENT_DB = 18.0
# Largest wander of a take's beat phase between 16-second windows, after removing a steady period error.
WANDER_MS = 12.0
FINE_BINS = 1000
RULES = 'No vocals, no drum kit, no hi-hats, no tempo changes, no rubato, no ritardando, no silent gaps.'

TRACKS = {
    'aurora_lake': dict(
        file='assets/audio/music.ogg', provenance='audio/music_provenance.json', lufs=-18, true_peak=-1, lra=11, lowpass=None, quality=6,
        palette='Meditative ambient in D major at exactly 60 BPM in 4/4, with a steady tempo that never changes from the first second to the last. A soft felt-mallet note sounds on every beat, even quarter notes at 60 BPM like a calm slow heartbeat, continuing through every section. Warm rounded analog pads, a deep soft D and A drone, distant glass harmonics, generous warm reverb.',
        direction='Three Lyria 3.5 movements in D major (still water, curtains of light, return to stillness): warm analog pads, a D and A drone and distant glass harmonics over a soft felt-mallet note that Lyria plays on every beat at 60 BPM, joined on bar lines so the beat never breaks.',
        movements=[
            ('still_water', [
                ('0:00', '0:10', 'The felt-mallet pulse and a warm D and A drone begin together at once, with no silence.'),
                ('0:10', '1:30', 'Slowly breathing pad swells over the steady pulse, sparse luminous overtones, intimate and reassuring.'),
                ('1:30', '2:40', 'Gradually enrich the D major voicing with F sharp and A while the pulse stays even.'),
                ('2:40', '3:00', 'Sustain a full D major pad with the pulse continuing evenly to the very last second; no cadence and no fade-out.')]),
            ('curtains_of_light', [
                ('0:00', '0:10', 'The felt-mallet pulse and a sustained warm D major pad begin together at once, with no silence.'),
                ('0:10', '1:00', 'Gently widen the stereo image and introduce slowly moving suspended D major harmonies.'),
                ('1:00', '2:20', 'Richer upper glass harmonics shimmer like curtains of light over the steady pulse; floating attention.'),
                ('2:20', '3:00', 'Luminous and spacious: sustain a full D major texture with the pulse continuing evenly to the very last second; no cadence and no fade-out.')]),
            ('return_to_stillness', [
                ('0:00', '0:10', 'The felt-mallet pulse and the full luminous D major pad begin together at once, with no silence.'),
                ('0:10', '1:00', 'The richest gently enveloping texture, slowly blooming stereo pads, no sharp peaks.'),
                ('1:00', '2:00', 'Gradually remove the upper layers, returning toward the warm D and A drone.'),
                ('2:00', '3:00', 'Only the soft drone, a quiet warm pad and the pulse remain, settled and still, the pulse even to the very last second; no ritardando and no fade-out.')]),
        ],
    ),
    'tidal_origami': dict(
        file='assets/audio/tidal_origami.ogg', provenance='audio/suite_provenance.json', lufs=-20, true_peak=-2, lra=10, lowpass=7000, quality=5,
        palette='Tranquil aquatic chamber ambient in A major at exactly 60 BPM in 4/4, with a steady tempo that never changes from the first second to the last. Soft rounded felt-piano droplet notes fall precisely on every beat, even quarter notes at 60 BPM, continuing through every section, over low singing bowls, fluid bowed-glass resonances and a deep warm bass bed with long shimmering tails. Calm floating stillness with softened attacks.',
        direction='Three Lyria 3.5 movements in A major (a spacious welcome, deeper water, resolving into stillness): low singing bowls, fluid bowed-glass resonances and a deep warm bass under soft felt-piano droplets that Lyria plays on every beat at 60 BPM, joined on bar lines so the pulse never breaks.',
        movements=[
            ('welcome', [
                ('0:00', '0:10', 'The droplet pulse and a low singing-bowl drone begin together at once, with no silence.'),
                ('0:10', '1:30', 'A quiet, spacious welcome: a slowly opening watery A major chord beneath the steady droplets.'),
                ('1:30', '2:40', 'Fluid bowed-glass resonances rise and fall in long waves while the pulse stays even.'),
                ('2:40', '3:00', 'Sustain a warm A major chord with the droplets continuing evenly to the very last second; no cadence and no fade-out.')]),
            ('deeper_water', [
                ('0:00', '0:10', 'The droplet pulse and a sustained warm A major chord begin together at once, with no silence.'),
                ('0:10', '1:10', 'Deeper water: richer consonant overtones and a fuller warm bass, restrained and stable.'),
                ('1:10', '2:20', 'Slow shimmering glass harmonics circle overhead like light through water above the steady pulse.'),
                ('2:20', '3:00', 'Sustain the full watery A major texture with the droplets continuing evenly to the very last second; no cadence and no fade-out.')]),
            ('stillness', [
                ('0:00', '0:10', 'The droplet pulse and the full watery A major chord begin together at once, with no silence.'),
                ('0:10', '1:00', 'The deepest, most enveloping water texture, gently undulating, no sharp peaks.'),
                ('1:00', '2:00', 'Resolving into stillness: the texture slowly thins toward the singing bowls and the bass.'),
                ('2:00', '3:00', 'Only a long warm chord, the low bowls and the quiet droplet pulse remain, settled and still, the pulse even to the very last second; no ritardando and no fade-out.')]),
        ],
    ),
    'pilgrim_tides': dict(
        file='assets/audio/pilgrim_tides.ogg', provenance='audio/suite_provenance.json', lufs=-20, true_peak=-2, lra=10, lowpass=7000, quality=5,
        palette='Humanist chamber-minimalist ambient in F major at exactly 60 BPM in 4/4, with a steady tempo that never changes from the first second to the last. A soft low felt-piano note sounds on every beat, even quarter notes at 60 BPM like an unhurried walking pulse, continuing through every section, with warm chamber strings, a soft low clarinet and sustained, tender consonant harmony. Quiet companionship.',
        direction='Three Lyria 3.5 movements in F major (setting out, walking together, arriving): warm chamber strings and a soft low clarinet over an unhurried felt-piano walking pulse that Lyria plays on every beat at 60 BPM, joined on bar lines so the pulse never breaks.',
        movements=[
            ('setting_out', [
                ('0:00', '0:10', 'The felt-piano pulse and a quiet string drone begin together at once, with no silence.'),
                ('0:10', '1:30', 'Setting out: spacious and tender sustained strings over the steady walking pulse.'),
                ('1:30', '2:40', 'A soft low clarinet enters with long, patient phrases while the pulse stays even.'),
                ('2:40', '3:00', 'Sustain warm F major string harmony with the pulse continuing evenly to the very last second; no cadence and no fade-out.')]),
            ('walking_together', [
                ('0:00', '0:10', 'The felt-piano pulse and sustained warm F major strings begin together at once, with no silence.'),
                ('0:10', '1:20', 'Walking together: slow call-and-response between the clarinet and the strings.'),
                ('1:20', '2:30', 'Fuller communal harmony, gently rising and settling over the steady pulse.'),
                ('2:30', '3:00', 'Sustain the warm ensemble harmony with the pulse continuing evenly to the very last second; no cadence and no fade-out.')]),
            ('arriving', [
                ('0:00', '0:10', 'The felt-piano pulse and the warm ensemble harmony begin together at once, with no silence.'),
                ('0:10', '1:00', 'The ensemble at its warmest, sustained and tender, no sharp peaks.'),
                ('1:00', '2:00', 'Arriving: the clarinet falls silent and the strings settle into long sustained harmony.'),
                ('2:00', '3:00', 'Only quiet sustained strings and the soft pulse remain, settled and still, the pulse even to the very last second; no ritardando and no fade-out.')]),
        ],
    ),
}


def prompt(identifier: str, movement: int) -> str:
    track = TRACKS[identifier]
    sections = '\n'.join(f'[{start} - {end}] {text}' for start, end, text in track['movements'][movement][1])
    return f"Create a 3-minute instrumental track. {track['palette']} {RULES}\n{sections}"


def take_path(identifier: str, movement: int, take: int) -> Path:
    return MASTERS / f"{identifier}_{movement + 1}_{track_movement(identifier, movement)}_take{take}.mp3"


def track_movement(identifier: str, movement: int) -> str:
    return TRACKS[identifier]['movements'][movement][0]


def generate_take(identifier: str, movement: int, take: int) -> Path:
    """Request one movement take and keep the untouched MP3 with its prompt and interaction evidence (resumable)."""
    import requests

    path = take_path(identifier, movement, take)
    evidence_path = path.with_suffix('.json')
    text = prompt(identifier, movement)
    if path.exists() and evidence_path.exists():
        evidence = json.loads(evidence_path.read_text())
        if evidence['prompt'] == text and evidence['sha256'] == hashlib.sha256(path.read_bytes()).hexdigest():
            return path
    key = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
    if not key:
        raise SystemExit('GEMINI_API_KEY or GOOGLE_API_KEY is required to generate Lyria takes')
    MASTERS.mkdir(parents=True, exist_ok=True)
    started = time.time()
    for attempt in range(6):
        response = requests.post(ENDPOINT, headers={'x-goog-api-key': key}, json={'model': MODEL, 'input': text, 'response_format': {'type': 'audio'}}, timeout=900)
        # Blocks for an unspecified policy reason are not repeatable for the same text; retry them a few times too.
        if response.ok or response.status_code not in (400, 408, 409, 429, 500, 502, 503, 504):
            break
        print(f'{path.name}: HTTP {response.status_code}, retry {attempt + 1}', flush=True)
        time.sleep(min(60, 4 * 2 ** attempt))
    if not response.ok:
        raise RuntimeError(f'{path.name}: Lyria request failed with HTTP {response.status_code}: {response.text[:300]}')
    payload = response.json()
    blocks = [block for step in payload.get('steps', []) if step.get('type') == 'model_output' for block in step.get('content', [])]
    audio = [block for block in blocks if block.get('type') == 'audio']
    if len(audio) != 1:
        raise RuntimeError(f'{path.name}: expected one audio block, received {len(audio)}')
    raw = base64.b64decode(audio[0]['data'])
    pending = path.with_suffix('.mp3.tmp')
    pending.write_bytes(raw)
    details = probe(pending)
    pending.replace(path)
    evidence = dict(
        id=identifier, movement=track_movement(identifier, movement), take=take, model=MODEL, endpoint=ENDPOINT, interaction_id=payload.get('id'),
        generated_at=datetime.now(timezone.utc).isoformat(timespec='seconds'), prompt=text, file=path.name, mime_type=audio[0].get('mime_type'),
        sha256=hashlib.sha256(raw).hexdigest(), duration=float(details['format']['duration']), sample_rate=int(details['streams'][0]['sample_rate']),
        response_text=[block.get('text', '') for block in blocks if block.get('type') == 'text'], seconds_to_generate=round(time.time() - started, 1))
    evidence_path.write_text(json.dumps(evidence, indent=2) + '\n')
    print(f"{path.name}: {evidence['duration']:.1f} s in {evidence['seconds_to_generate']:.0f} s", flush=True)
    return path


def decode(path: Path) -> tuple[np.ndarray, int]:
    rate = int(probe(path)['streams'][0]['sample_rate'])
    result = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-ac', '2', '-f', 'f32le', '-'], check=True, capture_output=True)
    return np.frombuffer(result.stdout, dtype='<f4').reshape(-1, 2).copy(), rate


def fine_phase(envelope: np.ndarray, times: np.ndarray, period: float) -> tuple[float, np.ndarray]:
    """Beat phase to a fraction of a millisecond: onset strength folded over the period, smoothed over 15 ms.

    Returns the phase in [-period/2, period/2) and the smoothed folded histogram (FINE_BINS bins over one period).
    """
    weights = np.maximum(envelope - np.median(envelope), 0.0)
    fraction = np.mod(times, period) / period
    histogram = np.bincount(np.minimum((fraction * FINE_BINS).astype(int), FINE_BINS - 1), weights=weights, minlength=FINE_BINS)
    width = max(1, int(round(.015 / period * FINE_BINS)))
    kernel = np.hanning(2 * width + 3)[1:-1]
    smooth = np.convolve(np.concatenate([histogram[-width:], histogram, histogram[:width]]), kernel / kernel.sum(), mode='valid')
    peak = int(np.argmax(smooth))
    left, centre, right = smooth[peak - 1], smooth[peak], smooth[(peak + 1) % FINE_BINS]
    curvature = left - 2 * centre + right
    offset = .5 * (left - right) / curvature if curvature < 0 else 0.0
    phase = (peak + .5 + offset) / FINE_BINS * period
    return float((phase + period / 2) % period - period / 2), smooth


def strength_at(smooth: np.ndarray, phase: float, period: float) -> float:
    return float(smooth[int(np.floor(np.mod(phase, period) / period * FINE_BINS)) % FINE_BINS])


def tick_phase() -> float:
    """The breath tick's own measured onset phase: the position every beat is placed on."""
    import librosa
    import soundfile

    tick, rate = soundfile.read(ROOT / 'assets/audio/breath_tick.wav', always_2d=True)
    tick = librosa.resample(tick.mean(axis=1), orig_sr=rate, target_sr=beat_grid.SAMPLE_RATE)
    signal = np.zeros(60 * beat_grid.SAMPLE_RATE)
    for second in range(60):
        start = second * beat_grid.SAMPLE_RATE
        signal[start:start + len(tick)] += tick[:len(signal) - start]
    envelope, times = beat_grid.envelope_of(signal)
    return fine_phase(envelope, times, 1.0)[0]


def measure(audio: np.ndarray, rate: int) -> dict:
    """Beat period, beat phase, bar downbeat and the loudness-present span of one take, in take seconds."""
    import librosa

    mono = librosa.resample(audio.mean(axis=1), orig_sr=rate, target_sr=beat_grid.SAMPLE_RATE)
    envelope, times = beat_grid.envelope_of(mono)
    low = librosa.onset.onset_strength(y=mono, sr=beat_grid.SAMPLE_RATE, hop_length=beat_grid.HOP, lag=1, fmax=500.0, n_mels=32)
    duration = len(audio) / rate
    seconds = int(duration)
    loudness = np.array([10 * np.log10(np.mean(audio[s * rate:(s + 1) * rate] ** 2) + 1e-12) for s in range(seconds)])
    present = np.flatnonzero(loudness >= np.median(loudness) - PRESENT_DB)
    start, end = float(present[0]), float(present[-1] + 1)
    # Eighth-note phase in overlapping 16-second windows: folding over half a beat is immune to beats and off-beats
    # trading places, so the windows expose any period error (a steady slope) or tempo wander (the residual).
    centres, eighths = [], []
    for window in np.arange(start, end - 16 + 1e-6, 8.0):
        mask = (times >= window) & (times < window + 16)
        centres.append(window + 8)
        eighths.append(fine_phase(envelope[mask], times[mask], .5)[0])
    unwrapped = np.unwrap(np.array(eighths) * 4 * np.pi) / (4 * np.pi)
    slope, intercept = np.polyfit(centres, unwrapped, 1)
    residual = unwrapped - (slope * np.array(centres) + intercept)
    period = 1.0 + float(slope)
    # Over the whole take at the measured period, the beat is whichever of the two eighth positions is stronger.
    phase, smooth = fine_phase(envelope, times, period)
    other = phase + period / 2
    beat_strength, other_strength = strength_at(smooth, phase, period), strength_at(smooth, other, period)
    if other_strength > beat_strength:
        phase, beat_strength, other_strength = (other + period / 2) % period - period / 2, other_strength, beat_strength
    # Bar lines: the beat of the four whose low-frequency onsets are strongest.
    _, bar = fine_phase(low, times, 4 * period)
    beats = [strength_at(bar, phase + j * period, 4 * period) for j in range(4)]
    order = np.argsort(beats)[::-1]
    return dict(
        duration=round(duration, 3), present=[start, end], period=period, period_ppm=round((period - 1) * 1e6, 1), phase=phase,
        wander_ms=round(float(np.max(np.abs(residual))) * 1000, 2), beat_to_offbeat=round(beat_strength / max(other_strength, 1e-12), 2),
        downbeat=int(order[0]), downbeat_confidence=round(beats[order[0]] / max(beats[order[1]], 1e-12), 3),
        window_phases_ms=[round(float(p) * 1000, 1) for p in eighths], median_loudness_db=round(float(np.median(loudness)), 1))


def takes_of(identifier: str, movement: int) -> list[Path]:
    return sorted(MASTERS.glob(f"{identifier}_{movement + 1}_{track_movement(identifier, movement)}_take*.mp3"))


def session_time(take: dict, bar_line: float, tick: float) -> callable:
    """Session seconds of each take second when the take's downbeat onset lands with the tick on `bar_line`."""
    downbeat = take['phase'] + take['downbeat'] * take['period']
    return lambda seconds: (seconds - downbeat) / take['period'] + bar_line + tick


# ITU-R BS.1770 K-weighting at 48 kHz: a high shelf, then the revised low-frequency B-curve high-pass.
K_SHELF = ([1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585])
K_HIGHPASS = ([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621])
# A join's short-term loudness may sag this far below the quieter side, or move this much in two seconds.
JOIN_DIP_LU = 1.5
JOIN_STEP_LU = 3.0


def short_term_loudness(audio: np.ndarray) -> np.ndarray:
    """EBU R128 short-term loudness (3-second windows) centred on every whole second of 48 kHz stereo audio."""
    from scipy.signal import lfilter

    weighted = lfilter(*K_HIGHPASS, lfilter(*K_SHELF, audio.astype(np.float64), axis=0), axis=0)
    cumulative = np.concatenate([[0.0], np.cumsum(np.sum(weighted ** 2, axis=1))])
    centres = np.arange(len(audio) // RATE + 1) * RATE
    low, high = np.clip(centres - 3 * RATE // 2, 0, len(audio)), np.clip(centres + 3 * RATE // 2, 0, len(audio))
    power = (cumulative[high] - cumulative[low]) / np.maximum(high - low, 1)
    return np.maximum(-0.691 + 10 * np.log10(power + 1e-12), -70.0)


def integrated(curve: np.ndarray) -> float:
    """Gated integrated loudness estimated from short-term values (absolute -70 LUFS and relative -10 LU gates)."""
    energy = 10 ** (curve / 10)
    relative = 10 * np.log10(np.mean(energy[curve > -70.0])) - 10
    return float(10 * np.log10(np.mean(energy[curve > relative])))


def join_shape(outgoing: np.ndarray, incoming: np.ndarray, fade: int) -> dict:
    """Predicted short-term loudness through an equal-power crossfade starting at session second `fade`.

    `outgoing` and `incoming` hold each take's loudness at every session second (movements are normalized alike).
    """
    seconds = np.arange(fade - 4, fade + CROSSFADE + 5)
    progress = np.clip((seconds - fade) / CROSSFADE, 0, 1)
    power = 10 ** (outgoing[seconds] / 10) * np.cos(progress * np.pi / 2) ** 2 + 10 ** (incoming[seconds] / 10) * np.sin(progress * np.pi / 2) ** 2
    return profile(10 * np.log10(power + 1e-12), float(np.mean(outgoing[fade - 12:fade - 2])), float(np.mean(incoming[fade + CROSSFADE + 2:fade + CROSSFADE + 12])))


def profile(level: np.ndarray, before: float, after: float) -> dict:
    """Levels either side of a join, its deepest sag below the quieter side, and its largest two-second move.

    `level` is short-term loudness at each second from four seconds before the crossfade to four seconds after it.
    """
    inside = level[4:4 + CROSSFADE + 1]
    return dict(before=round(before, 2), after=round(after, 2), dip=round(float(inside.min() - min(before, after)), 2), step=round(float(np.max(np.abs(level[2:] - level[:-2]))), 2))


def measured_join(level: np.ndarray, fade: int) -> dict:
    """The join profile of a finished mix from its short-term loudness at every session second."""
    return profile(level[fade - 4:fade + CROSSFADE + 5], float(np.mean(level[fade - 12:fade - 2])), float(np.mean(level[fade + CROSSFADE + 2:fade + CROSSFADE + 12])))


def on_session(take: dict, bar_line: float, tick: float) -> np.ndarray:
    """A take's normalized short-term loudness looked up at every session second (silent outside the take)."""
    start = session_time(take, bar_line, tick)(0.0)
    index = np.round(np.arange(SECONDS + 1) - start).astype(int)
    inside = (index >= 0) & (index < len(take['loudness']))
    return np.where(inside, take['loudness'][np.clip(index, 0, len(take['loudness']) - 1)], -70.0)


def plan(takes: list[dict], cycle: int, tick: float) -> dict | None:
    """Place three measured takes on shared bar lines with two crossfades that each take fully covers."""
    first = session_time(takes[0], 0.0, tick)
    # The first take keeps its opening: its earliest bar line at or after its first second of audio, minus up to 2 s.
    opening = 4.0 * np.ceil((-first(0.0) - 2.0) / 4.0)
    first = session_time(takes[0], opening, tick)
    last_end = session_time(takes[2], 0.0, tick)(takes[2]['present'][1])
    # The last take ends with the session: the earliest bar line that still carries it into the final fade-out.
    closing = 4.0 * np.ceil((SECONDS - FADE_OUT + SWELL - last_end) / 4.0)
    last = session_time(takes[2], closing, tick)
    grid = 16 if cycle % 16 == 0 else 4
    first_level, last_level = on_session(takes[0], opening, tick), on_session(takes[2], closing, tick)

    def cost(shape: dict) -> float:
        # A sagging or lurching join costs as much as moving a crossfade tens of seconds from an even split.
        return 40 * max(0.0, -shape['dip'] - JOIN_DIP_LU) + 20 * max(0.0, shape['step'] - JOIN_STEP_LU)

    best = None
    for middle_bar in np.arange(96.0, 320.0, 4.0):
        middle = session_time(takes[1], middle_bar, tick)
        middle_level = on_session(takes[1], middle_bar, tick)
        firsts = {fade: join_shape(first_level, middle_level, fade) for fade in range(100, 260, 4)
                  if fade + CROSSFADE - SWELL <= first(takes[0]['present'][1]) and middle(takes[1]['present'][0]) <= fade + SWELL}
        seconds = {fade: join_shape(middle_level, last_level, fade) for fade in range(200, SECONDS - 100, 4)
                   if fade + CROSSFADE - SWELL <= middle(takes[1]['present'][1]) and last(takes[2]['present'][0]) <= fade + SWELL}
        for first_fade, first_shape in firsts.items():
            for second_fade, second_shape in seconds.items():
                if second_fade < first_fade + 100:
                    continue
                # Prefer smooth joins, then an even split, then crossfades on breath-cycle boundaries.
                score = cost(first_shape) + cost(second_shape) + abs(first_fade - 160) + abs(second_fade - 320) + (0 if first_fade % grid == 0 else 24) + (0 if second_fade % grid == 0 else 24)
                if best is None or score < best['score']:
                    best = dict(score=score, bars=[float(opening), float(middle_bar), float(closing)], crossfades=[first_fade, second_fade], predicted_joins=[first_shape, second_shape])
    return best


def bridge(mix: np.ndarray, fades: list[int]) -> list[dict]:
    """Ride the gain through each join so its loudness moves smoothly from the outgoing level to the incoming one.

    The correction is at most +6/-4 dB, smoothed over three seconds and confined to the crossfade and two seconds either
    side; it fills a sag where both takes are quiet at once and softens an entry that arrives too suddenly.
    """
    records = []
    for fade in fades:
        applied = np.zeros(SECONDS + 1)
        for _ in range(3):
            level = short_term_loudness(mix)
            before, after = float(np.mean(level[fade - 12:fade - 2])), float(np.mean(level[fade + CROSSFADE + 2:fade + CROSSFADE + 12]))
            seconds = np.arange(SECONDS + 1)
            ramp = np.clip((seconds - (fade - 2)) / (CROSSFADE + 4), 0, 1)
            target = before + (after - before) * ramp * ramp * (3 - 2 * ramp)
            window = np.clip(np.minimum(seconds - (fade - 4), fade + CROSSFADE + 4 - seconds) / 2, 0, 1)
            correction = np.convolve(np.clip(target - level, -4, 6) * window, np.ones(3) / 3, mode='same') * window
            correction = np.clip(applied + correction, -4, 6) - applied
            applied += correction
            gain = 10 ** (np.interp(np.arange(len(mix)) / RATE, seconds, correction) / 20)
            mix *= gain.astype(np.float32)[:, None]
        records.append(dict(fade=fade, largest_lift_db=round(float(applied.max()), 2), largest_cut_db=round(float(applied.min()), 2)))
    return records


def place(audio: np.ndarray, rate: int, take: dict, bar_line: float, tick: float) -> np.ndarray:
    """Resample a take to 48 kHz with its beat period folded into the rate and lay it on the session timeline."""
    import soxr

    resampled = soxr.resample(audio, rate, RATE / take['period'], quality='VHQ').astype(np.float32)
    start = int(round(session_time(take, bar_line, tick)(0.0) * RATE))
    placed = np.zeros((SECONDS * RATE, 2), dtype=np.float32)
    source = resampled[max(0, -start):]
    placed[max(0, start):max(0, start) + len(source)] = source[:SECONDS * RATE - max(0, start)]
    return placed


def loudness_of(audio: np.ndarray) -> float:
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / 'part.wav'
        wavfile.write(path, RATE, audio)
        result = run(['ffmpeg', '-hide_banner', '-i', str(path), '-af', 'loudnorm=print_format=json', '-f', 'null', '-'])
    return float(json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind('{'):])[0]['input_i'])


def master(identifier: str) -> dict:
    track = TRACKS[identifier]
    entry = next(e for e in json.loads((ROOT / 'experiences/catalog.json').read_text()) if e['id'] == identifier)
    cycle = int(sum(entry['rhythm']))
    tick = tick_phase()
    candidates = []
    for movement in range(3):
        measured = []
        for path in takes_of(identifier, movement):
            audio, rate = decode(path)
            report = dict(measure(audio, rate), file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
            stable = report['wander_ms'] <= WANDER_MS and abs(report['period_ppm']) <= 2000 and report['beat_to_offbeat'] >= 1.05
            print(f"{path.name}: {report['duration']:.1f} s present {report['present']} period {report['period_ppm']:+.0f} ppm wander {report['wander_ms']} ms beat/off-beat {report['beat_to_offbeat']} downbeat {report['downbeat']} ({report['downbeat_confidence']}) {'stable' if stable else 'REJECTED'}", flush=True)
            if stable:
                import soxr

                # Loudness on the session clock, relative to the take's own integrated loudness (movements are normalized alike).
                curve = short_term_loudness(soxr.resample(audio, rate, RATE / report['period'], quality='HQ'))
                report['loudness'] = curve - integrated(curve)
                measured.append(report)
        if not measured:
            raise RuntimeError(f'{identifier}: no stable take for movement {track_movement(identifier, movement)}; generate more takes')
        candidates.append(measured)
    # Every combination of stable takes that can be placed: the smoothest joins and most even split, then the steadiest beat.
    plans = []
    for combination in itertools.product(*candidates):
        layout = plan(list(combination), cycle, tick)
        if layout:
            plans.append((layout['score'] + 2 * sum(t['wander_ms'] for t in combination), combination, layout))
    if not plans:
        raise RuntimeError(f'{identifier}: no combination of takes covers {SECONDS} s with bar-aligned crossfades')
    _, chosen, layout = min(plans, key=lambda item: item[0])
    mix = np.zeros((SECONDS * RATE, 2), dtype=np.float32)
    for movement, take in enumerate(chosen):
        audio, rate = decode(MASTERS / take['file'])
        part = place(audio, rate, take, layout['bars'][movement], tick)
        envelope = np.ones(SECONDS * RATE, dtype=np.float32)
        ramp = np.sin(np.linspace(0, np.pi / 2, CROSSFADE * RATE, dtype=np.float32))
        if movement > 0:
            fade = layout['crossfades'][movement - 1] * RATE
            envelope[:fade] = 0
            envelope[fade:fade + CROSSFADE * RATE] = ramp
        if movement < 2:
            fade = layout['crossfades'][movement] * RATE
            envelope[fade:fade + CROSSFADE * RATE] = ramp[::-1]
            envelope[fade + CROSSFADE * RATE:] = 0
        part *= envelope[:, None]
        # Movements meet at one loudness; the master normalizes the whole score afterwards.
        gain_db = -23.0 - loudness_of(part[envelope > 0])
        mix += part * np.float32(10 ** (gain_db / 20))
        del part
        take['session_bar_line'] = layout['bars'][movement]
        take['gain_db'] = round(gain_db, 2)
        take['session_start'] = round(session_time(take, layout['bars'][movement], tick)(0.0), 4)
    ramp_in = np.sin(np.linspace(0, np.pi / 2, FADE_IN * RATE, dtype=np.float32)) ** 2
    mix[:FADE_IN * RATE] *= ramp_in[:, None]
    mix[-FADE_OUT * RATE:] *= ramp_in[::-1, None]
    first, second = layout['crossfades']
    rides = bridge(mix, layout['crossfades'])
    level = short_term_loudness(mix)
    joins = [dict(ride, predicted=layout['predicted_joins'][index], after_ride=measured_join(level, ride['fade'])) for index, ride in enumerate(rides)]
    for join in joins:
        print(f"{identifier}: join at {join['fade']} s predicted {join['predicted']}, ride {join['largest_lift_db']:+.1f}/{join['largest_cut_db']:+.1f} dB, now {join['after_ride']}", flush=True)
    transitions = [float(t) for t in (first, first + CROSSFADE / 2, first + CROSSFADE, second, second + CROSSFADE / 2, second + CROSSFADE)]
    MASTERS.mkdir(parents=True, exist_ok=True)
    master_path = MASTERS / f'{identifier}_60bpm_master.wav'
    wavfile.write(master_path, RATE, mix)
    target = ROOT / track['file']
    tick_ms = beat_grid.tick_reference_ms()
    with tempfile.TemporaryDirectory() as directory:
        loudness = f"loudnorm=I={track['lufs']}:TP={track['true_peak']}:LRA={track['lra']}"
        first_pass = run(['ffmpeg', '-hide_banner', '-i', str(master_path), '-af', loudness + ':print_format=json', '-f', 'null', '-']).stderr
        measured = json.JSONDecoder().raw_decode(first_pass[first_pass.rfind('{'):])[0]
        normalization = f"{loudness}:measured_I={measured['input_i']}:measured_TP={measured['input_tp']}:measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}:offset={measured['target_offset']}:linear=true"
        if track['lowpass']:
            normalization += f",lowpass=f={track['lowpass']}"
        normalized = Path(directory) / 'normalized.wav'
        run(['ffmpeg', '-v', 'error', '-y', '-i', str(master_path), '-af', normalization, '-ar', str(RATE), '-c:a', 'pcm_s24le', '-t', str(SECONDS), str(normalized)])
        pending = target.with_suffix('.pending.ogg')
        run(['oggenc', '-Q', '-q', str(track['quality']), '-o', str(pending), str(normalized)])
        if abs(float(probe(pending)['format']['duration']) - SECONDS) > .01:
            raise RuntimeError(f'{identifier}: delivery must be exactly {SECONDS} seconds')
        report = beat_grid.analyze(pending, transitions, tick_ms)
        problems = beat_grid.verdict(report)
        if problems:
            raise RuntimeError(f'{identifier}: delivery is off the 60 BPM grid: ' + '; '.join(problems))
        pending.replace(target)
    return dict(
        id=identifier, title=entry['title'], artist='Breathwork VR / Google Lyria', model=MODEL, endpoint=ENDPOINT, duration=SECONDS, file=track['file'],
        sha256=hashlib.sha256(target.read_bytes()).hexdigest(), delivery_bytes=target.stat().st_size, target_lufs=track['lufs'], tempo_bpm=BPM, beat_frames=RATE,
        transitions=transitions, crossfades=[[first, first + CROSSFADE], [second, second + CROSSFADE]], crossfade_seconds=CROSSFADE, fade_in_seconds=FADE_IN, fade_out_seconds=FADE_OUT, joins=joins,
        tick_phase_ms=round(tick * 1000, 2), synthesized_pulse=False,
        beat_grid=dict(tick_reference_ms=tick_ms, librosa_tempo_bpm=report['librosa_tempo_bpm'], best_fold_period_s=report['best_fold_period_s'], beat_phase_ms=report['beat_phase_ms'], beat_peak=report['beat_peak'], beats_within_50ms=report['beats_within_50ms'], on_grid_fraction=report['on_grid_fraction'], transitions=report['transitions']),
        note='Lyria 3.5 keeps the 60 BPM written into its prompt on a steady grid, so each movement is only resampled by its measured period error and placed so its own beats land with the breath ticks; no pulse is synthesized. Lyria RealTime ignored its bpm setting (about 72 BPM when asked for 60) and is no longer used.',
        movements=[dict(name=track_movement(identifier, index), prompt=prompt(identifier, index), **{k: take[k] for k in ('file', 'sha256', 'duration', 'present', 'period_ppm', 'wander_ms', 'beat_to_offbeat', 'downbeat', 'downbeat_confidence', 'session_bar_line', 'session_start', 'gain_db')}, phase_ms=round(take['phase'] * 1000, 2)) for index, take in enumerate(chosen)],
        sources=[dict(file=take['file'], sha256=take['sha256'], interaction_id=json.loads((MASTERS / take['file']).with_suffix('.json').read_text())['interaction_id'], origin='Untouched Lyria 3.5 MP3 response') for take in chosen] + [dict(file=master_path.name, sha256=hashlib.sha256(master_path.read_bytes()).hexdigest(), origin='Placed and crossfaded movements before loudness normalization')],
    )


def publish(report: dict) -> None:
    track = TRACKS[report['id']]
    path = ROOT / track['provenance']
    if track['provenance'] == 'audio/music_provenance.json':
        path.write_text(json.dumps(dict(report, placeholder=False, vorbis_quality=track['quality']), indent=2) + '\n')
    else:
        provenance = json.loads(path.read_text())
        provenance['tracks'] = [report if item['id'] == report['id'] else item for item in provenance['tracks']]
        provenance['delivery_bytes'] = sum(item['delivery_bytes'] for item in provenance['tracks'])
        path.write_text(json.dumps(provenance, indent=2) + '\n')
    catalog_path = ROOT / 'experiences/catalog.json'
    catalog = json.loads(catalog_path.read_text())
    for entry in catalog:
        if entry['id'] == report['id']:
            entry['artist'] = report['artist']
            entry['music_direction'] = track['direction']
    catalog_path.write_text(json.dumps(catalog, indent=2) + '\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    generating = commands.add_parser('generate', help='request missing movement takes, several at once')
    generating.add_argument('ids', nargs='*')
    generating.add_argument('--takes', type=int, default=2)
    measuring = commands.add_parser('measure', help='print the beat measurements of every take')
    measuring.add_argument('ids', nargs='*')
    mastering = commands.add_parser('master', help='choose takes, place them on the grid, master, verify and publish')
    mastering.add_argument('ids', nargs='*')
    args = parser.parse_args()
    identifiers = args.ids or list(TRACKS)
    if args.command == 'generate':
        jobs = [(identifier, movement, take) for identifier in identifiers for movement in range(3) for take in range(1, args.takes + 1)]
        with ThreadPoolExecutor(max_workers=6) as pool:
            failures = [error for error in pool.map(lambda job: _attempt(*job), jobs) if error]
        if failures:
            raise SystemExit('\n'.join(failures))
    elif args.command == 'measure':
        for identifier in identifiers:
            for movement in range(3):
                for path in takes_of(identifier, movement):
                    audio, rate = decode(path)
                    print(path.name, json.dumps(measure(audio, rate)), flush=True)
    else:
        for identifier in identifiers:
            report = master(identifier)
            publish(report)
            print(f"{identifier}: mastered and verified, crossfades {report['crossfades']}, beat {report['beat_grid']['beat_phase_ms']} ms (tick {report['beat_grid']['tick_reference_ms']} ms), tracked {report['beat_grid']['beats_within_50ms']:.0%}", flush=True)


def _attempt(identifier: str, movement: int, take: int) -> str | None:
    try:
        generate_take(identifier, movement, take)
    except Exception as error:  # Keep the other takes going; report every failure at the end.
        return f'{identifier} movement {movement + 1} take {take}: {error}'
    return None


if __name__ == '__main__':
    main()
