"""Compose a 60 BPM transcendental journey with slowly unfolding electronic harmony.

At 60 BPM every beat falls on a whole second with the breath ticks, and each sixteen-beat phrase spans exactly one
4/4/4/4 box-breath cycle.
"""

import hashlib
import json
from pathlib import Path
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

from audio.generate_music import probe
from audio.generate_suite import MASTERS
from audio.stitch_music import RATE, run

ROOT = Path(__file__).resolve().parents[1]
BPM = 60
SECONDS = 480
BEAT_FRAMES = RATE * 60 // BPM
BEAT_COUNT = SECONDS * RATE // BEAT_FRAMES
PHRASE_BEATS = 16
# Shared voicings guide the pads, bass and melody through five emotional movements.
CHORDS = {
    'dm9': (38, (50, 57, 60, 64, 69)),
    'bbmaj9': (34, (50, 53, 57, 60, 65)),
    'fmaj9': (41, (53, 57, 60, 64, 67)),
    'cadd9': (36, (52, 55, 60, 62, 67)),
    'gsus': (31, (50, 55, 57, 62, 67)),
    'gmaj9': (31, (50, 55, 59, 62, 69)),
    'dmaj9': (38, (50, 57, 61, 64, 66)),
    'asus': (33, (52, 57, 59, 62, 69)),
}
# Six sixteen-second phrases per 96-second movement.
PROGRESSION = [
    'dm9', 'dm9', 'bbmaj9', 'fmaj9', 'cadd9', 'dm9',
    'dm9', 'bbmaj9', 'fmaj9', 'cadd9', 'dm9', 'gsus',
    'bbmaj9', 'fmaj9', 'cadd9', 'gsus', 'gmaj9', 'asus',
    'dmaj9', 'gmaj9', 'dmaj9', 'asus', 'dmaj9', 'gmaj9',
    'gmaj9', 'dmaj9', 'asus', 'dmaj9', 'gmaj9', 'dmaj9',
]
PHRASES_PER_MOVEMENT = 6
MOVEMENTS = ['Awakening', 'Longing', 'Opening', 'Radiance', 'Homecoming']
ARRANGEMENT = (
    'One exact 60 BPM arrangement in five 96-second movements: Awakening, Longing, '
    'Opening, Radiance and Homecoming, every sixteen-beat phrase one 4/4/4/4 breath cycle. '
    'Warm bowed and choir-like synth pads, suspended ninths, a gradual minor-to-major opening, '
    'slow legato melodic responses, a rounded heartbeat kick on every beat with the breath ticks, '
    'sustained bass and quiet diffused echoes on whole beats. Long soft arrivals and a spacious final '
    'release; no speech, sampled voices, piano, plucked attacks or independent backing track.'
)


def add_note(mix: np.ndarray, start: int, samples: np.ndarray, pan: float = 0.0) -> None:
    """Place a mono voice on the exact beat grid with restrained stereo placement."""
    count = min(len(samples), len(mix) - start)
    if count <= 0:
        return
    mix[start:start + count, 0] += samples[:count] * np.sqrt((1 - pan) * .5)
    mix[start:start + count, 1] += samples[:count] * np.sqrt((1 + pan) * .5)


def emotional_arc(seconds: float) -> float:
    """Ease from intimacy into a broad luminous middle and back to stillness."""
    return float(np.interp(seconds, [0, 72, 168, 264, 336, 408, 480],
                           [.24, .38, .60, .90, 1.0, .65, .18]))


def voice(note: int, duration: float, color: str, seed: int) -> np.ndarray:
    """Synthesize a sustained, gently detuned voice with rounded attack and release."""
    t = np.arange(round(duration * RATE), dtype=np.float64) / RATE
    frequency = 440 * 2 ** ((note - 69) / 12)
    drift = .016 * np.sin(2 * np.pi * .17 * t + seed)
    phase = 2 * np.pi * frequency * t + drift
    if color == 'pad':
        tone = np.sin(phase) + .46 * np.sin(phase * 1.0013 + .5)
        tone += .25 * np.sin(phase * 2) + .12 * np.sin(phase * 3)
        tone += .045 * np.sin(phase * 5) + .02 * np.sin(phase * 7)
        attack, release = 5.4, 7.2
    elif color == 'lead':
        tone = np.sin(phase) + .16 * np.sin(phase * 2 + .12 * np.sin(t * .3))
        tone += .065 * np.sin(phase * 3)
        attack, release = 1.5, 4.2
    else:
        tone = np.sin(phase) + .15 * np.sin(phase * 2)
        attack, release = 1.2, 3.6
    envelope = np.sin(np.clip(t / attack, 0, 1) * np.pi / 2) ** 2
    envelope *= np.sin(np.clip((duration - t) / release, 0, 1) * np.pi / 2) ** 2
    envelope *= .94 + .06 * np.sin(t * .24 + seed)
    return (tone * envelope).astype(np.float32)


def rhythm() -> np.ndarray:
    """Lay down 480 soft heartbeat pulses on whole seconds with sparse, slowly swelling breath texture."""
    mix = np.zeros((SECONDS * RATE, 2), dtype=np.float32)
    rng = np.random.default_rng(5050)
    t = np.arange(round(.6 * RATE)) / RATE
    kick = np.sin(2 * np.pi * (43 * t + 1.5 * (1 - np.exp(-t / .055))))
    kick *= np.sin(np.clip(t / .010, 0, 1) * np.pi / 2) ** 2
    kick *= np.exp(-t / .16) * np.sin(np.clip((.6 - t) / .10, 0, 1) * np.pi / 2) ** 2
    for beat in range(BEAT_COUNT):
        seconds = beat * 60 / BPM
        # Firm enough to carry the beat under the pads, so every beat is heard with the breath tick.
        strength = .15 * (.6 + .4 * emotional_arc(seconds))
        strength *= 1.0 if beat % 4 == 0 else .82
        add_note(mix, beat * BEAT_FRAMES, (kick * strength).astype(np.float32))
        if beat % 8 == 4 and 76 <= beat < 412:
            t_air = np.arange(round(2.4 * RATE)) / RATE
            air = sosfilt(butter(2, [900, 2700], btype='bandpass', fs=RATE,
                                 output='sos'), rng.normal(size=len(t_air)))
            air *= np.sin(np.pi * t_air / 2.4) ** 2 * .0025 * emotional_arc(seconds)
            add_note(mix, beat * BEAT_FRAMES, air.astype(np.float32), .25 * (-1) ** (beat // 8))
    return mix


def sustained_harmony() -> np.ndarray:
    """Voice thirty phrases with shared bass roots and slow melodic responses."""
    mix = np.zeros((SECONDS * RATE, 2), dtype=np.float32)
    phrase_seconds = PHRASE_BEATS * 60 / BPM
    for index, chord_name in enumerate(PROGRESSION):
        start = index * PHRASE_BEATS * BEAT_FRAMES
        root, notes = CHORDS[chord_name]
        arc = emotional_arc(start / RATE)
        for part, note in enumerate(notes):
            pad = voice(note, phrase_seconds + 7.2, 'pad', index * 5 + part)
            add_note(mix, start, pad * (.012 + .013 * arc), (part - 2) * .24)
        bass = voice(root, phrase_seconds + 3.6, 'bass', index)
        add_note(mix, start, bass * (.030 + .012 * arc))
        # A rising-and-answering line grows from the same voicing as the harmony.
        if 2 <= index <= 26:
            melody = [notes[2] + 12, notes[3] + 12, notes[4] + 12, notes[3] + 12]
            if index % 2:
                melody = [notes[4] + 12, notes[3] + 12, notes[2] + 12, notes[1] + 12]
            for step, note in enumerate(melody):
                position = start + (step * 4 + 1) * BEAT_FRAMES
                lead = voice(note, 7.2, 'lead', index + step)
                add_note(mix, position, lead * (.008 + .008 * arc), .18 * np.sin(index + step))
        print(f'Arranged phrase {index + 1}/{len(PROGRESSION)}: {MOVEMENTS[index // PHRASES_PER_MOVEMENT]}', flush=True)
    # Quiet, filtered returns lend the harmonies depth; the long echoes repeat on whole beats.
    dry = sosfilt(butter(2, 2800, fs=RATE, output='sos'), mix, axis=0).astype(np.float32)
    for delay_seconds, gain in [(.071, .12), (.113, .09), (.173, .07), (2.0, .12), (4.0, .07), (6.0, .04)]:
        delay = round(delay_seconds * RATE)
        mix[delay:] += dry[:-delay, ::-1] * gain
    return mix


def score(entry: dict) -> dict:
    """Master the eight-minute arrangement and retain its source and measured delivery."""
    if entry.get('tempo_bpm') != BPM:
        raise ValueError('Prismatic catalog tempo must match the authored 60 BPM score')
    MASTERS.mkdir(parents=True, exist_ok=True)
    mix = sustained_harmony() + rhythm()
    fade_in = np.sin(np.linspace(0, np.pi / 2, 16 * RATE)) ** 2
    fade_out = np.sin(np.linspace(np.pi / 2, 0, 24 * RATE)) ** 2
    mix[:len(fade_in)] *= fade_in[:, None]
    mix[-len(fade_out):] *= fade_out[:, None]
    master = MASTERS / 'prismatic_transcendental60.wav'
    wavfile.write(master, RATE, mix)
    target = ROOT / entry['music']
    with tempfile.TemporaryDirectory() as directory:
        first = run(['ffmpeg', '-hide_banner', '-i', str(master), '-af',
                     'loudnorm=I=-20:TP=-2:LRA=10:print_format=json', '-f', 'null', '-'])
        measured = json.JSONDecoder().raw_decode(first.stderr[first.stderr.rfind('{'):])[0]
        normalization = (
            f"loudnorm=I=-20:TP=-2:LRA=10:measured_I={measured['input_i']}:"
            f"measured_TP={measured['input_tp']}:measured_LRA={measured['input_lra']}:"
            f"measured_thresh={measured['input_thresh']}:offset={measured['target_offset']}:"
            'linear=true,lowpass=f=6500'
        )
        normalized = Path(directory) / 'normalized.wav'
        run(['ffmpeg', '-v', 'error', '-y', '-i', str(master), '-af', normalization,
             '-ar', str(RATE), '-c:a', 'pcm_s24le', str(normalized)])
        pending = target.with_suffix('.pending.ogg')
        run(['oggenc', '-Q', '-q', '5', '-o', str(pending), str(normalized)])
        if abs(float(probe(pending)['format']['duration']) - SECONDS) >= .01:
            raise RuntimeError('Prismatic delivery must be exactly eight minutes')
        pending.replace(target)
    sources = [dict(file=master.name, sha256=hashlib.sha256(master.read_bytes()).hexdigest(),
                    origin='Authored deterministic synthesis, no sampled/generated backing recording')]
    result = dict(
        id=entry['id'], title=entry['title'], artist='Breathwork VR',
        model='authored electronic synthesis', duration=SECONDS, file=entry['music'],
        sha256=hashlib.sha256(target.read_bytes()).hexdigest(), delivery_bytes=target.stat().st_size,
        target_lufs=-20, tempo_bpm=BPM, beat_frames=BEAT_FRAMES, beat_count=BEAT_COUNT,
        arrangement=ARRANGEMENT, movements=[dict(title=name, start_seconds=index * 96)
                                           for index, name in enumerate(MOVEMENTS)],
        chord_progression=PROGRESSION, transitions=[float(index * 96) for index in range(1, len(MOVEMENTS))], sources=sources,
    )
    (ROOT / 'audio/prismatic_trance_provenance.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Mastered eight-minute 60 BPM transcendental Prismatic score', flush=True)
    return result


def main() -> None:
    """Replace only Prismatic Sanctuary and update the public suite provenance."""
    entry = next(e for e in json.loads((ROOT / 'experiences/catalog.json').read_text())
                 if e['id'] == 'prismatic_sanctuary')
    result = score(entry)
    path = ROOT / 'audio/suite_provenance.json'
    catalog = json.loads(path.read_text())
    catalog['tracks'] = [result if item['id'] == entry['id'] else item for item in catalog['tracks']]
    catalog['delivery_bytes'] = sum(item['delivery_bytes'] for item in catalog['tracks'])
    catalog['master_bytes'] = sum((MASTERS / source['file']).stat().st_size
                                  for item in catalog['tracks'] for source in item['sources']
                                  if (MASTERS / source['file']).exists())
    path.write_text(json.dumps(catalog, indent=2) + '\n')


if __name__ == '__main__':
    main()
