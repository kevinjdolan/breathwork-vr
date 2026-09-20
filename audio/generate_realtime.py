"""Superseded in version 2.9 by `audio.generate_lyria60`; kept for reference only.

Version 2.8 delivered Aurora Lake, Tidal Origami and Pilgrim Tides from this script. The beds kept their own pace under
the synthesized pulse, so the scores are now Lyria 3.5 movements that play their own 60 BPM beat. `master` refuses to
run so it cannot overwrite those deliveries; `probe` and `record` still work for experiments.

Regenerate the Lyria scores as continuous Lyria RealTime beds under a strict 60 BPM pulse.

Aurora Lake, Tidal Origami and Pilgrim Tides used to be three separate Lyria movements stitched with tempo changes and
crossfades that ignored any beat. Lyria RealTime does not follow its `bpm` setting in practice: takes requested at
60 BPM measured about 72 BPM, and a take requested at 90 BPM followed its prompt to about 128 BPM. A generated beat
therefore cannot be trusted to meet the breath ticks. Instead each score is:

- a beatless Lyria RealTime bed, steered through its three movements by blending weighted prompts inside the stream
  (so movements change without seams), recorded in two overlapping sessions because a session ends after about ten
  minutes, joined by a 24-second equal-power crossfade in the middle of the steady second movement;
- a sample-exact synthesized pulse on every whole second (felt mallet, water droplets or felt piano) whose pitch
  follows the bed's harmony, measured with librosa chroma, and which accents the start of each breath cycle.

The pulse is continuous across every movement change and the session join, and the delivery is verified with
`audio.beat_grid` before it replaces the runtime file.

    python -m audio.generate_realtime probe aurora_lake --seconds 40
    python -m audio.generate_realtime record [ids...]
    python -m audio.generate_realtime master [ids...]
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import os
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.ndimage import uniform_filter1d

from audio import beat_grid
from audio.generate_music import probe
from audio.stitch_music import RATE, run

ROOT = Path(__file__).resolve().parents[1]
MASTERS = ROOT / 'audio/masters/realtime'
MODEL = 'models/lyria-realtime-exp'
BPM = 60
SECONDS = 480
LEAD_IN = 8
CROSSFADE = 24.0
# Score-time spans of the two sessions and the crossfade that joins them.
SEGMENTS = [(-LEAD_IN, 256.0), (224.0, 488.0)]
JOIN = (232.0, 256.0)

TRACKS = {
    'aurora_lake': dict(
        file='assets/audio/music.ogg', provenance='audio/music_provenance.json', scale='D_MAJOR_B_MINOR', seed=1414, lufs=-18, true_peak=-1, lra=11, lowpass=None, quality=6, fade_in=12, fade_out=4,
        style='Warm beatless meditative ambient in D major: rounded analog pads, a deep soft D and A drone, distant glass harmonics, wide gentle stereo and generous dark reverb. Sustained and floating, no drums, no percussion, no rhythmic pulse, no vocals.',
        movements=[
            (0, 'Still water: sparse, intimate and reassuring; slowly breathing pad swells and a few luminous overtones.', .15, .32),
            (168, 'Curtains of light: gently widening suspended D major harmonies, richer upper harmonics, floating attention.', .24, .42),
            (336, 'Return to stillness: a full enveloping harmonic cloud that slowly thins back to the warm drone.', .15, .30),
        ],
        pulse=dict(voice='mallet', low_note=50, cycle=14, levels=(.22, .26, .30, .36, .45), pattern=(0, 0, 7, 0)),
    ),
    'tidal_origami': dict(
        file='assets/audio/tidal_origami.ogg', provenance='audio/suite_provenance.json', scale='A_MAJOR_G_FLAT_MINOR', seed=2626, lufs=-20, true_peak=-2, lra=10, lowpass=7000, quality=5, fade_in=12, fade_out=6,
        style='Beatless aquatic meditative ambient: low singing bowls, fluid glass resonances and deep rounded waterlike synth chords in a wide rippling space. Long warm suspended waves, soft edges, no drums, no percussion, no rhythmic pulse, no vocals.',
        movements=[
            (0, 'A quiet spacious welcome: a slowly opening watery chord.', .16, .34),
            (168, 'Deeper water: richer consonant overtones, restrained and stable.', .24, .40),
            (336, 'Resolving into stillness: the texture thins to a long warm chord.', .15, .30),
        ],
        pulse=dict(voice='droplet', low_note=69, cycle=16, levels=(.18, .22, .26, .32, .40), pattern=(12, 7, 0, 7)),
    ),
    'pilgrim_tides': dict(
        file='assets/audio/pilgrim_tides.ogg', provenance='audio/suite_provenance.json', scale='F_MAJOR_D_MINOR', seed=3838, lufs=-20, true_peak=-2, lra=10, lowpass=7000, quality=5, fade_in=12, fade_out=6,
        style='Beatless humanist minimalist ambient: distant warm chamber strings, soft low clarinet and sustained consonant tender harmony with patient communal motion. No drums, no percussion, no rhythmic pulse, no piano, no vocals.',
        movements=[
            (0, 'Setting out: a quiet string drone, spacious and tender.', .16, .34),
            (168, 'Walking together: slow call-and-response between clarinet and strings.', .26, .40),
            (336, 'Arriving: the ensemble settles into warm sustained harmony.', .16, .30),
        ],
        pulse=dict(voice='felt_piano', low_note=41, cycle=16, levels=(.20, .25, .30, .36, .45), pattern=(0, 7, 12, 7)),
    ),
}


def prompt_weights(track: dict, second: float) -> list[tuple[str, float]]:
    """The constant style prompt plus movement prompts crossfaded over 24 seconds around each movement start."""
    movements = track['movements']
    weights = [0.0] * len(movements)
    for index, (start, *_rest) in enumerate(movements):
        end = movements[index + 1][0] if index + 1 < len(movements) else float('inf')
        rise = 1.0 if index == 0 else float(np.clip((second - (start - CROSSFADE / 2)) / CROSSFADE, 0, 1))
        fall = 1.0 if end == float('inf') else float(np.clip(((end + CROSSFADE / 2) - second) / CROSSFADE, 0, 1))
        weights[index] = min(rise, fall)
    prompts = [(track['style'], 1.0)]
    prompts += [(movement[1], round(weight, 3)) for movement, weight in zip(movements, weights) if weight > .001]
    return prompts


def movement_config(track: dict, second: float) -> tuple[float, float]:
    starts = [movement[0] for movement in track['movements']]
    index = max(i for i, start in enumerate(starts) if start <= max(second, 0.0))
    return track['movements'][index][2], track['movements'][index][3]


async def record_span(identifier: str, start: float, end: float, label: str, overrides: dict | None = None) -> Path:
    """Record one Lyria RealTime session covering score time [start, end); partial audio survives a dropped session."""
    from google import genai
    from google.genai import types

    track = dict(TRACKS[identifier], **(overrides or {}))
    key = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
    if not key:
        raise RuntimeError('GEMINI_API_KEY or GOOGLE_API_KEY is required')
    client = genai.Client(api_key=key, http_options={'api_version': 'v1alpha'})
    target_bytes = int((end - start) * RATE) * 4
    received = bytearray()
    timeline = []
    chunks = 0
    guidance = track.get('guidance', 4.0)
    MASTERS.mkdir(parents=True, exist_ok=True)
    path = MASTERS / f'{identifier}_{label}.wav'

    def config(density: float, brightness: float):
        return types.LiveMusicGenerationConfig(bpm=BPM, scale=getattr(types.Scale, track['scale']), seed=track['seed'], density=density, brightness=brightness, guidance=guidance, temperature=1.0, top_k=40, mute_drums=True)

    async def steer(session, score_second: float, last: dict) -> None:
        prompts = prompt_weights(track, score_second)
        if prompts != last.get('prompts'):
            await session.set_weighted_prompts(prompts=[types.WeightedPrompt(text=text, weight=weight) for text, weight in prompts])
            last['prompts'] = prompts
            timeline.append(dict(score_second=round(score_second, 2), prompts=prompts))
        settings = movement_config(track, score_second)
        if settings != last.get('config'):
            if 'config' in last:
                await session.set_music_generation_config(config=config(*settings))
            last['config'] = settings
            timeline.append(dict(score_second=round(score_second, 2), density=settings[0], brightness=settings[1]))

    def save(complete: bool) -> None:
        usable = len(received) - len(received) % 4
        pcm = np.frombuffer(bytes(received[:min(usable, target_bytes)]), dtype='<i2').reshape(-1, 2)
        wavfile.write(path, RATE, pcm)
        evidence = dict(
            id=identifier, label=label, complete=complete, model=MODEL, requested_bpm=BPM, scale=track['scale'], seed=track['seed'], guidance=guidance, temperature=1.0, top_k=40, mute_drums=True,
            score_start=start, score_end=end, style_prompt=track['style'], movements=[dict(start_seconds=m[0], prompt=m[1], density=m[2], brightness=m[3]) for m in track['movements']],
            crossfade_seconds=CROSSFADE, recorded_seconds=round(len(pcm) / RATE, 3), chunks=chunks, wall_seconds=round(time.monotonic() - started, 1),
            steering=timeline, file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), created=datetime.now(timezone.utc).isoformat(timespec='seconds'),
        )
        path.with_suffix('.json').write_text(json.dumps(evidence, indent=2) + '\n')

    started = time.monotonic()
    try:
        async with client.aio.live.music.connect(model=MODEL) as session:
            last: dict = {}
            await steer(session, start, last)
            await session.set_music_generation_config(config=config(*last['config']))
            await session.play()
            next_steer = 2.0
            async for message in session.receive():
                content = getattr(message, 'server_content', None)
                if content is None or not getattr(content, 'audio_chunks', None):
                    continue
                for chunk in content.audio_chunks:
                    received.extend(chunk.data)
                    chunks += 1
                elapsed = len(received) / 4 / RATE
                if elapsed >= next_steer:
                    await steer(session, start + elapsed, last)
                    next_steer += 2.0
                if len(received) >= target_bytes:
                    break
            await session.stop()
    except Exception:
        save(False)
        raise
    save(True)
    print(f'{identifier} {label}: recorded {len(received) // 4 / RATE:.1f} s of score {start:.0f}-{end:.0f} in {time.monotonic() - started:.0f} s ({chunks} chunks)', flush=True)
    return path


async def record_track(identifier: str, attempts: int = 3) -> None:
    for index, (start, end) in enumerate(SEGMENTS):
        for attempt in range(attempts):
            try:
                await record_span(identifier, start, end, f'bed_{index}')
                break
            except Exception as error:  # A dropped or refused session is retried from the start of its span.
                print(f'{identifier} bed_{index}: attempt {attempt + 1} failed: {str(error)[:160]}', flush=True)
                if attempt == attempts - 1:
                    raise
                await asyncio.sleep(20)


def hz(note: float) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def pulse_voice(voice: str, note: float, accent: bool) -> np.ndarray:
    """One soft, sample-exact beat voice; accents add a low octave at the start of each breath cycle."""
    f = hz(note)
    if voice == 'mallet':
        t = np.arange(int(1.3 * RATE)) / RATE
        tone = np.sin(2 * np.pi * f * t) + .22 * np.sin(2 * np.pi * f * 3.98 * t) * np.exp(-t / .07) + .08 * np.sin(2 * np.pi * f * 10.2 * t) * np.exp(-t / .025)
        envelope = np.sin(np.clip(t / .004, 0, 1) * np.pi / 2) ** 2 * np.exp(-t / .42)
    elif voice == 'droplet':
        t = np.arange(int(.7 * RATE)) / RATE
        phase = 2 * np.pi * f * (t + .5 * .014 * (1 - np.exp(-t / .014)))
        tone = np.sin(phase) + .28 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t / .045)
        envelope = np.sin(np.clip(t / .002, 0, 1) * np.pi / 2) ** 2 * np.exp(-t / .13)
    else:
        t = np.arange(int(2.2 * RATE)) / RATE
        tone = sum(np.sin(2 * np.pi * f * k * (1 + .00035 * k * k) * t) * np.exp(-t * k * .32) / k ** 1.6 for k in range(1, 8))
        envelope = np.sin(np.clip(t / .007, 0, 1) * np.pi / 2) ** 2 * (.62 * np.exp(-t / .32) + .38 * np.exp(-t / 1.5))
    tone = tone * envelope
    if accent:
        low = pulse_voice(voice, note - 12, False)
        length = max(len(tone), len(low))
        tone = np.pad(tone, (0, length - len(tone))) * 1.25 + np.pad(low, (0, length - len(low))) * .45
    tone *= np.sin(np.clip((len(tone) / RATE - np.arange(len(tone)) / RATE) / .06, 0, 1) * np.pi / 2) ** 2
    return tone.astype(np.float32)


def harmony_roots(bed: np.ndarray, low_note: int) -> list[int]:
    """The bed's prevailing pitch class at every beat, with hysteresis so the pulse changes note only with the harmony."""
    import librosa

    mono = librosa.resample(bed.mean(axis=1).astype(np.float32), orig_sr=RATE, target_sr=22050)
    chroma = librosa.feature.chroma_cqt(y=mono, sr=22050, hop_length=2205)
    smooth = uniform_filter1d(chroma, size=41, axis=1, mode='nearest')
    roots = []
    current = int(np.argmax(smooth[:, 0]))
    for beat in range(SECONDS):
        frame = min(beat * 10, smooth.shape[1] - 1)
        candidate = int(np.argmax(smooth[:, frame]))
        if smooth[candidate, frame] > 1.15 * smooth[current, frame]:
            current = candidate
        roots.append(low_note + (current - low_note) % 12)
    return roots


def pulse_layer(bed: np.ndarray, spec: dict) -> tuple[np.ndarray, list[int]]:
    """The pulse at unit level; mastering scales it to the gentlest level that locks the grid."""
    roots = harmony_roots(bed, spec['low_note'])
    rms = np.sqrt(uniform_filter1d(bed.mean(axis=1) ** 2, size=4 * RATE, mode='nearest'))
    reference = np.median(rms[RATE * 20:-RATE * 20])
    layer = np.zeros_like(bed)
    for beat in range(SECONDS):
        accent = beat % spec['cycle'] == 0
        note = roots[beat] + spec['pattern'][beat % len(spec['pattern'])]
        voice = pulse_voice(spec['voice'], note, accent)
        # The pulse follows the bed's loudness gently, so it never dominates a sparse passage or vanishes in a full one.
        gain = float(np.clip(rms[beat * RATE] / max(reference, 1e-9), .6, 1.4))
        start = beat * RATE
        count = min(len(voice), len(layer) - start)
        pan = .18 * np.sin(beat * .9)
        layer[start:start + count, 0] += voice[:count] * gain * np.sqrt((1 - pan) * .5)
        layer[start:start + count, 1] += voice[:count] * gain * np.sqrt((1 + pan) * .5)
    return layer, roots


def join_bed(identifier: str) -> tuple[np.ndarray, list[dict]]:
    frames = SECONDS * RATE
    bed = np.zeros((frames, 2), dtype=np.float32)
    evidence = []
    fade = int((JOIN[1] - JOIN[0]) * RATE)
    for index, (start, end) in enumerate(SEGMENTS):
        path = MASTERS / f'{identifier}_bed_{index}.wav'
        record = json.loads(path.with_suffix('.json').read_text())
        if not record['complete']:
            raise RuntimeError(f'{identifier} bed_{index} is incomplete; record it again')
        _, pcm = wavfile.read(path)
        audio = pcm.astype(np.float32) / 32768.0
        if index == 0:
            # Score time t sits at sample (t - start) of the session; the lead-in before t = 0 is discarded.
            piece = audio[int(-start * RATE):int((JOIN[1] - start) * RATE)].copy()
            piece[-fade:] *= np.cos(np.linspace(0, np.pi / 2, fade))[:, None]
            bed[:len(piece)] += piece
        else:
            piece = audio[int((JOIN[0] - start) * RATE):int((SECONDS - start) * RATE)].copy()
            piece[:fade] *= np.sin(np.linspace(0, np.pi / 2, fade))[:, None]
            offset = int(JOIN[0] * RATE)
            bed[offset:offset + len(piece)] += piece[:frames - offset]
        evidence.append(record)
    return bed, evidence


def master(identifier: str) -> dict:
    track = TRACKS[identifier]
    bed, sessions = join_bed(identifier)
    unit, roots = pulse_layer(bed, track['pulse'])
    tick_ms = beat_grid.tick_reference_ms()
    transitions = [float(m[0]) for m in track['movements'][1:]] + [(JOIN[0] + JOIN[1]) / 2]
    fade = np.ones(len(bed), dtype=np.float32)
    fade[:track['fade_in'] * RATE] = np.linspace(0, 1, track['fade_in'] * RATE)
    fade[-track['fade_out'] * RATE:] = np.linspace(1, 0, track['fade_out'] * RATE)
    # Choose the gentlest pulse level at which the whole score locks to the ticks.
    trials = []
    chosen = None
    for level in track['pulse']['levels']:
        candidate = (bed + unit * level) * fade[:, None]
        with tempfile.TemporaryDirectory() as directory:
            trial = Path(directory) / 'trial.wav'
            wavfile.write(trial, RATE, candidate)
            report = beat_grid.analyze(trial, transitions, tick_ms)
        problems = beat_grid.verdict(report)
        trials.append(dict(level=level, beats_within_50ms=report['beats_within_50ms'], beat_peak=report['beat_peak'], problems=problems))
        print(f'{identifier}: pulse level {level}: ' + ('locks' if not problems else '; '.join(problems)), flush=True)
        if not problems:
            chosen = level
            mix = candidate
            break
    if chosen is None:
        raise RuntimeError(f'{identifier}: no pulse level in {track["pulse"]["levels"]} locks the grid')
    MASTERS.mkdir(parents=True, exist_ok=True)
    master_path = MASTERS / f'{identifier}_60bpm_master.wav'
    wavfile.write(master_path, RATE, mix)
    target = ROOT / track['file']
    with tempfile.TemporaryDirectory() as directory:
        loudness = f"loudnorm=I={track['lufs']}:TP={track['true_peak']}:LRA={track['lra']}"
        first = run(['ffmpeg', '-hide_banner', '-i', str(master_path), '-af', loudness + ':print_format=json', '-f', 'null', '-'])
        measured = json.JSONDecoder().raw_decode(first.stderr[first.stderr.rfind('{'):])[0]
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
        id=identifier, title=identifier.replace('_', ' ').title(), artist='Breathwork VR / Google Lyria RealTime', model=MODEL, duration=SECONDS, file=track['file'],
        sha256=hashlib.sha256(target.read_bytes()).hexdigest(), delivery_bytes=target.stat().st_size, target_lufs=track['lufs'], tempo_bpm=BPM, beat_frames=RATE,
        transitions=transitions, movement_crossfade_seconds=CROSSFADE, session_join_seconds=list(JOIN), fade_in_seconds=track['fade_in'], fade_out_seconds=track['fade_out'],
        pulse=dict(track['pulse'], pattern=list(track['pulse']['pattern']), levels=list(track['pulse']['levels']), chosen_level=chosen, level_trials=trials,
                   bed_to_pulse_db=round(float(20 * np.log10(np.sqrt(np.mean((unit * chosen) ** 2)) / np.sqrt(np.mean(bed ** 2)))), 1), roots=roots),
        beat_grid=dict(tick_reference_ms=tick_ms, librosa_tempo_bpm=report['librosa_tempo_bpm'], best_fold_period_s=report['best_fold_period_s'], beat_phase_ms=report['beat_phase_ms'], beat_peak=report['beat_peak'], beats_within_50ms=report['beats_within_50ms'], on_grid_fraction=report['on_grid_fraction'], transitions=report['transitions']),
        note='Lyria RealTime ignored requested BPM in probes (about 72 BPM at bpm=60, about 128 BPM at bpm=90), so the Lyria take is a beatless bed and the 60 BPM grid comes from the sample-exact pulse.',
        sources=[dict(file=s['file'], sha256=s['sha256'], score_start=s['score_start'], score_end=s['score_end'], recorded_seconds=s['recorded_seconds'], seed=s['seed'], scale=s['scale'], style_prompt=s['style_prompt'], movements=s['movements'], origin='Lyria RealTime session steered by weighted prompts') for s in sessions] + [dict(file=master_path.name, sha256=hashlib.sha256(master_path.read_bytes()).hexdigest(), origin='Joined bed plus synthesized 60 BPM pulse, before loudness normalization')],
    )


def publish(report: dict) -> None:
    track = TRACKS[report['id']]
    if track['provenance'] == 'audio/music_provenance.json':
        (ROOT / track['provenance']).write_text(json.dumps(dict(report, placeholder=False, vorbis_quality=track['quality']), indent=2) + '\n')
        return
    path = ROOT / track['provenance']
    provenance = json.loads(path.read_text())
    catalog = json.loads((ROOT / 'experiences/catalog.json').read_text())
    entry = next(e for e in catalog if e['id'] == report['id'])
    report = dict(report, title=entry['title'])
    provenance['tracks'] = [report if item['id'] == report['id'] else item for item in provenance['tracks']]
    provenance['delivery_bytes'] = sum(item['delivery_bytes'] for item in provenance['tracks'])
    path.write_text(json.dumps(provenance, indent=2) + '\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    probing = commands.add_parser('probe', help='record a short test span')
    probing.add_argument('id', choices=list(TRACKS))
    probing.add_argument('--seconds', type=float, default=40.0)
    probing.add_argument('--label', default='probe')
    probing.add_argument('--style', help='replace the style prompt')
    recording = commands.add_parser('record', help='record both bed sessions for each score, scores concurrently')
    recording.add_argument('ids', nargs='*')
    mastering = commands.add_parser('master', help='join, add the pulse, master, verify and publish')
    mastering.add_argument('ids', nargs='*')
    args = parser.parse_args()
    if args.command == 'probe':
        asyncio.run(record_span(args.id, 0.0, args.seconds, args.label, {'style': args.style} if args.style else None))
    elif args.command == 'record':
        async def everything() -> None:
            await asyncio.gather(*(record_track(identifier) for identifier in args.ids or TRACKS))

        asyncio.run(everything())
    else:
        raise SystemExit('audio.generate_realtime is superseded; master the Lyria scores with python -m audio.generate_lyria60 master')


if __name__ == '__main__':
    main()
