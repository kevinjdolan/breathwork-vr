"""Compose a deterministic 60 BPM transcendental psybient journey shaped by the 4/4/6/2 breath."""

import hashlib
import json
from pathlib import Path
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

from audio.generate_prismatic_trance import add_note
from audio.generate_suite import MASTERS
from audio.stitch_music import RATE, run
from audio.generate_music import probe

ROOT = Path(__file__).resolve().parents[1]
BEAT_FRAMES = RATE            # 60 BPM: one beat per second, 480 beats in eight minutes.
CYCLE_BEATS = 16              # 4 s in, 4 s hold, 6 s out, 2 s rest.
PASSAGE_SECONDS = 120
DIRECTION = 'A single deterministic 60 BPM psybient journey aligned to the sixteen-second breath: tanpura-like drone, sub-bass heartbeat, breath-shaped sixteenth-note plucked arpeggios, glass shimmer and wordless formant pads, moving through four harmonic passages that mirror the tunnel.'


def hz(note: float) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def envelope(t: np.ndarray, attack: float, release: float, duration: float) -> np.ndarray:
    """Rounded sine-squared attack and release without clicks."""
    e = np.sin(np.clip(t / attack, 0, 1) * np.pi / 2) ** 2
    return e * np.sin(np.clip((duration - t) / release, 0, 1) * np.pi / 2) ** 2


def passage_weights(seconds: np.ndarray) -> np.ndarray:
    """Four overlapping movement weights with the same 24-second dissolves as the tunnel."""
    progress = seconds / PASSAGE_SECONDS
    index = np.clip(np.floor(progress), 0, 3)
    frac = progress - index
    t = np.clip((frac - .8) / .2, 0, 1)
    mix = np.where(index < 3, t * t * (3 - 2 * t), 0.0)
    weights = np.zeros((len(seconds), 4))
    for k in range(4):
        weights[:, k] += np.where(index == k, 1 - mix, 0.0)
        weights[:, k] += np.where(np.minimum(index + 1, 3) == k, mix, 0.0) * (index < 3)
    return weights


def breath_shape(seconds: np.ndarray) -> np.ndarray:
    """0→1 through the inhale, 1 through the hold, back to 0 through the exhale, 0 in rest."""
    p = np.mod(seconds, 16.0)
    fill = np.where(p < 4, p / 4, np.where(p < 8, 1.0, np.where(p < 14, 1 - (p - 8) / 6, 0.0)))
    return fill * fill * (3 - 2 * fill)


def drone() -> np.ndarray:
    """A tanpura-like D drone whose buzzing partials slowly wander across the whole session."""
    frames = 480 * RATE
    t = np.arange(frames) / RATE
    out = np.zeros((frames, 2), dtype=np.float32)
    weights = passage_weights(t)
    for note, gain in ((38, .55), (45, .34), (50, .30), (57, .16)):
        base = hz(note)
        for channel in range(2):
            detune = 1 + (.0011 if channel else -.0011)
            phase = 2 * np.pi * base * detune * t + channel * .9
            tone = np.zeros(frames)
            for harmonic in range(1, 9):
                jawari = .6 + .4 * np.sin(t * (.043 + harmonic * .017) + harmonic * 1.3 + channel)
                tone += np.sin(phase * harmonic + .08 * np.sin(t * .21 * harmonic)) * jawari * (.45 if harmonic == 1 else 1.0) / harmonic ** 1.05
            # The rings passage brightens the drone; the temple deepens it.
            brightness = .8 + .35 * weights[:, 2] - .15 * weights[:, 3]
            out[:, channel] += (tone * gain * .011 * brightness * (.9 + .1 * np.sin(t * .11 + note))).astype(np.float32)
    return out


def heartbeat() -> np.ndarray:
    """A soft sub kick each second, present in the middle passages and resting at the ends."""
    frames = 480 * RATE
    out = np.zeros((frames, 2), dtype=np.float32)
    kick_t = np.arange(int(.40 * RATE)) / RATE
    kick = np.sin(2 * np.pi * (40 * kick_t + 6.0 * (1 - np.exp(-kick_t / .04))))
    kick *= (1 - np.exp(-kick_t / .010)) * np.exp(-kick_t / .13)
    seconds = np.arange(480)
    weights = passage_weights(seconds.astype(float))
    presence = .25 * weights[:, 0] + 1.0 * weights[:, 1] + .85 * weights[:, 2] + .40 * weights[:, 3]
    for beat in range(480):
        phase = beat % CYCLE_BEATS
        # The heartbeat rests during the empty pause and softens through the hold.
        gate = 0.0 if phase >= 14 else (.55 if 4 <= phase < 8 else 1.0)
        add_note(out, beat * BEAT_FRAMES, kick * .15 * presence[beat] * gate)
    return out


def arpeggio() -> np.ndarray:
    """Breath-shaped sixteenth-note plucks: rising through the inhale, settling through the exhale."""
    frames = 480 * RATE
    out = np.zeros((frames, 2), dtype=np.float32)
    rng = np.random.default_rng(1108)
    # D Aeolian → D Dorian brightening → D major resolution across the passages.
    scales = [[62, 65, 69, 72, 74, 77, 81], [62, 65, 69, 72, 76, 77, 81], [62, 66, 69, 71, 74, 78, 81], [62, 66, 69, 74, 78, 81, 86]]
    patterns = [[0, 2, 4, 6, 4, 2], [0, 3, 5, 6, 5, 3, 1], [0, 1, 3, 5, 6, 5, 3], [0, 2, 3, 5, 6, 5]]
    steps = 480 * 4
    for step in range(steps):
        second = step / 4.0
        cycle_phase = second % 16.0
        passage = min(int(second // PASSAGE_SECONDS), 3)
        blend = passage_weights(np.array([second]))[0]
        # Density: sparse bells in the first passage, full sixteenths in the middle, thinning at the end.
        density = .35 * blend[0] + 1.0 * blend[1] + .95 * blend[2] + .5 * blend[3]
        if rng.random() > density:
            continue
        fill = breath_shape(np.array([second]))[0]
        if cycle_phase >= 14.0 and rng.random() < .8:
            continue
        pattern = patterns[passage]
        scale = scales[passage]
        degree = pattern[step % len(pattern)]
        # The inhale climbs the scale; the exhale lets the line settle downward.
        octave = 12 if (cycle_phase < 8.0 and step % 8 in (3, 7)) else 0
        note = scale[(degree + int(fill * 3)) % len(scale)] + octave
        if cycle_phase >= 8.0:
            note -= 12 * (step % 4 == 2)
        duration = .9 + 1.4 * (1 - fill)
        tt = np.arange(int(duration * RATE)) / RATE
        f = hz(note)
        pluck = np.sin(2 * np.pi * f * tt + 1.6 * np.exp(-tt * 9) * np.sin(2 * np.pi * f * 2.01 * tt))
        pluck += .18 * np.sin(2 * np.pi * f * 3 * tt) * np.exp(-tt * 6)
        pluck *= np.sin(np.clip(tt / .012, 0, 1) * np.pi / 2) ** 2 * np.exp(-tt / (.16 + .45 * (1 - fill)))
        gain = .048 * (.55 + .45 * fill) * (.75 if octave else 1.0)
        pan = np.sin(step * .37) * .5
        add_note(out, int(second * RATE), (pluck * gain).astype(np.float32), pan)
    return out


def pads() -> np.ndarray:
    """Slow detuned chords that change with each breath cycle inside a passage's harmony."""
    frames = 480 * RATE
    out = np.zeros((frames, 2), dtype=np.float32)
    progressions = [
        [(50, 57, 62, 65), (46, 53, 62, 65), (48, 55, 60, 64), (45, 52, 60, 64)],
        [(50, 57, 60, 65), (53, 57, 60, 65), (48, 55, 60, 64), (50, 57, 62, 64)],
        [(50, 57, 62, 66), (52, 57, 62, 66), (55, 59, 62, 66), (50, 57, 62, 64)],
        [(50, 57, 62, 66), (43, 55, 59, 62), (45, 57, 62, 64), (50, 57, 62, 69)],
    ]
    overlap = 3 * RATE
    for cycle in range(30):
        start = cycle * 16 * RATE
        second = float(cycle * 16)
        passage = min(int(second // PASSAGE_SECONDS), 3)
        chord = progressions[passage][cycle % 4]
        count = min(16 * RATE + overlap, frames - start)
        t = np.arange(count) / RATE
        voice_mix = np.zeros((count, 2), dtype=np.float32)
        for voice, note in enumerate(chord):
            f = hz(note)
            for channel in range(2):
                detune = 1 + (.0014 if channel else -.0014) * (1 + voice * .3)
                phase = 2 * np.pi * f * detune * t + voice * 1.1 + channel * .4
                tone = np.sin(phase) + .30 * np.sin(phase * 2 + .15 * np.sin(t * .5 + voice)) + .10 * np.sin(phase * 3) + .05 * np.sin(phase * 4)
                # Wordless formant hint in the later passages: a slow "oh" shimmer above the chord.
                formant = np.sin(phase * 5 + .3 * np.sin(t * .27)) * (.05 if passage >= 2 else .015)
                motion = .86 + .14 * np.sin(t * .29 + voice + cycle)
                voice_mix[:, channel] += ((tone + formant) * motion * .019).astype(np.float32)
        ramp = envelope(t, 3.0, 3.0, count / RATE)
        # The pad swells gently with the inhale and softens through the exhale.
        breath = .75 + .25 * breath_shape(t + second)
        out[start:start + count] += voice_mix * (ramp * breath)[:, None]
    return out


def shimmer() -> np.ndarray:
    """High glass partials that bloom during each full hold, brightest in the rings passage."""
    frames = 480 * RATE
    out = np.zeros((frames, 2), dtype=np.float32)
    rng = np.random.default_rng(2204)
    for cycle in range(30):
        second = float(cycle * 16 + 4)
        passage = min(int(second // PASSAGE_SECONDS), 3)
        blend = passage_weights(np.array([second]))[0]
        level = .022 * (.5 * blend[0] + .8 * blend[1] + 1.0 * blend[2] + .7 * blend[3])
        for k in range(5):
            note = [86, 89, 93, 98, 101][k] + (2 if passage >= 2 else 0) * (k % 2)
            f = hz(note)
            duration = 6.5
            tt = np.arange(int(duration * RATE)) / RATE
            tone = np.sin(2 * np.pi * f * tt + .2 * np.sin(tt * 3.0 + k)) * (1 + .3 * np.sin(2 * np.pi * 5.2 * tt + k))
            tone *= envelope(tt, 1.2 + k * .25, 3.5, duration) * level * (.6 + .4 * rng.random())
            add_note(out, int((second + k * .35) * RATE), tone.astype(np.float32), np.sin(k * 2.1) * .6)
    return out


def sub_bass() -> np.ndarray:
    """A sine root that follows each cycle's chord, dipping under every heartbeat."""
    frames = 480 * RATE
    out = np.zeros((frames, 2), dtype=np.float32)
    roots = [[38, 34, 36, 33], [38, 41, 36, 38], [38, 40, 43, 38], [38, 31, 33, 38]]
    t = np.arange(16 * RATE) / RATE
    for cycle in range(30):
        second = float(cycle * 16)
        passage = min(int(second // PASSAGE_SECONDS), 3)
        f = hz(roots[passage][cycle % 4])
        tone = np.sin(2 * np.pi * f * t) + .12 * np.sin(2 * np.pi * f * 2 * t)
        duck = 1 - .35 * np.exp(-np.mod(t, 1.0) / .12)
        tone *= envelope(t, .8, 1.5, 16.0) * duck * .028 * (.6 + .4 * breath_shape(t + second))
        add_note(out, cycle * 16 * RATE, tone.astype(np.float32))
    return out


def reverb(mix: np.ndarray, seconds: float = 3.2, wet: float = .28) -> np.ndarray:
    """A synthetic decorrelated hall impulse response applied by FFT convolution."""
    rng = np.random.default_rng(77)
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    ir = rng.normal(size=(n, 2)) * np.exp(-t / (seconds * .32))[:, None]
    ir = sosfilt(butter(2, [180, 5200], btype='bandpass', fs=RATE, output='sos'), ir, axis=0)
    ir /= np.sqrt(np.sum(ir ** 2, axis=0))[None, :] * 3.0
    result = mix.copy()
    for channel in range(2):
        tail = fftconvolve(mix[:, channel], ir[:, channel])[:len(mix)]
        result[:, channel] += (tail * wet).astype(np.float32)
        result[:, 1 - channel] += (tail * wet * .35).astype(np.float32)
    return result


def compose() -> np.ndarray:
    """Sum the movements, apply hall reverb, gentle bus filtering and eight-second fades."""
    mix = drone() + heartbeat() + arpeggio() + pads() + shimmer() + sub_bass()
    mix = reverb(mix)
    mix = sosfilt(butter(2, 34, btype='highpass', fs=RATE, output='sos'), mix, axis=0).astype(np.float32)
    mix[:8 * RATE] *= np.linspace(0, 1, 8 * RATE)[:, None] ** 2
    mix[-8 * RATE:] *= np.linspace(1, 0, 8 * RATE)[:, None] ** 2
    return mix


def score(entry: dict) -> dict:
    """Master one coherent arrangement to approximately −20 LUFS and publish provenance."""
    MASTERS.mkdir(parents=True, exist_ok=True)
    mix = compose()
    target = ROOT / entry['music']
    with tempfile.TemporaryDirectory() as directory:
        wav = Path(directory) / 'mix.wav'
        wavfile.write(wav, RATE, mix)
        first = run(['ffmpeg', '-hide_banner', '-i', str(wav), '-af', 'loudnorm=I=-20:TP=-2:LRA=9:print_format=json', '-f', 'null', '-'])
        measured = json.JSONDecoder().raw_decode(first.stderr[first.stderr.rfind('{'):])[0]
        normalization = f"loudnorm=I=-20:TP=-2:LRA=9:measured_I={measured['input_i']}:measured_TP={measured['input_tp']}:measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}:offset={measured['target_offset']}:linear=true,lowpass=f=7000"
        normalized = Path(directory) / 'normalized.wav'
        run(['ffmpeg', '-v', 'error', '-y', '-i', str(wav), '-af', normalization, '-ar', str(RATE), '-c:a', 'pcm_s24le', str(normalized)])
        pending = target.with_suffix('.pending.ogg')
        run(['oggenc', '-Q', '-q', '5', '-o', str(pending), str(normalized)])
        assert abs(float(probe(pending)['format']['duration']) - 480) < .01
        pending.replace(target)
    master = MASTERS / 'visionary_journey60_v26.wav'
    wavfile.write(master, RATE, mix)
    sources = [dict(file=master.name, sha256=hashlib.sha256(master.read_bytes()).hexdigest(), origin='Authored deterministic synthesis, no sampled or generated backing recording')]
    result = dict(id=entry['id'], title=entry['title'], artist='Breathwork VR', model='authored electronic synthesis', duration=480, file=entry['music'], sha256=hashlib.sha256(target.read_bytes()).hexdigest(), delivery_bytes=target.stat().st_size, target_lufs=-20, tempo_bpm=60, beat_frames=BEAT_FRAMES, beat_count=480, cycle_beats=CYCLE_BEATS, passages=['eye lattice', 'flame mandala', 'kaleidoscope rings', 'painted temple'], arrangement=DIRECTION, sources=sources)
    (ROOT / 'audio/visionary_journey_provenance.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Mastered eight-minute 60 BPM visionary journey', flush=True)
    return result


def main() -> None:
    """Deliver only Visionary Temple and update the public suite provenance."""
    entry = next(e for e in json.loads((ROOT / 'experiences/catalog.json').read_text()) if e['id'] == 'visionary_temple')
    result = score(entry)
    path = ROOT / 'audio/suite_provenance.json'
    catalog = json.loads(path.read_text())
    tracks = [item for item in catalog['tracks'] if item['id'] != entry['id']]
    tracks.append(result)
    catalog['tracks'] = tracks
    catalog['generated_tracks'] = len(tracks)
    catalog['delivery_bytes'] = sum(item['delivery_bytes'] for item in tracks)
    catalog['master_bytes'] = sum((MASTERS / source['file']).stat().st_size for item in tracks for source in item['sources'] if (MASTERS / source['file']).exists())
    path.write_text(json.dumps(catalog, indent=2) + '\n')


if __name__ == '__main__':
    main()
