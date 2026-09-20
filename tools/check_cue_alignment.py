"""Confirm in Godot's own mix that every count tick, breath phase and score second sound together, for every experience.

tests/capture_cue_audio.gd records the score, the breath loop and the tick track of a session on separate capture
buses (sample-aligned), from 64 s into the session and through a pause. This script finds every tick by matching the
tick sample, then matches the delivered score and breath loop around each tick. A tick that starts session second S
must sound with score second S and breath-loop position S mod cycle, and ticks on phase boundaries must be the louder
ones. Together with audio.beat_grid, which puts every beat of every score on a whole second, this shows the counts,
the breath phases and the beats line up as heard.

    python tools/check_cue_alignment.py [experience ids] [--skip-capture]
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
OUTPUT = ROOT / 'verification/cue_alignment'
GODOT = Path(os.environ.get('GODOT_BIN', ROOT / '.tools/Godot.app/Contents/MacOS/Godot'))
TOLERANCE_MS = 1.0


def source(path: Path, rate: int) -> np.ndarray:
    import librosa

    signal, _ = librosa.load(path, sr=rate, mono=True, res_type='soxr_vhq')
    return signal


def lag_of(capture: np.ndarray, reference: np.ndarray, expected: int, search: int) -> float | None:
    """Sub-sample lag of `capture` within `reference` near `expected`, or None where the reference is silent."""
    from scipy.signal import correlate

    lo, hi = expected - search, expected + search + len(capture)
    if lo < 0 or hi > len(reference) or np.sqrt(np.mean(capture ** 2)) < 1e-4:
        return None
    window = reference[lo:hi]
    score = correlate(window, capture, mode='valid', method='fft')
    energy = np.sqrt(np.convolve(window ** 2, np.ones(len(capture)), mode='valid') * np.sum(capture ** 2)) + 1e-12
    score = score / energy
    best = int(np.argmax(score))
    if score[best] < .9:
        return None
    shift = 0.0
    if 0 < best < len(score) - 1:
        left, centre, right = score[best - 1], score[best], score[best + 1]
        curvature = left - 2 * centre + right
        shift = .5 * (left - right) / curvature if curvature < 0 else 0.0
    return lo + best + shift - expected


def analyze(identifier: str) -> dict:
    from scipy.signal import correlate, find_peaks

    report = json.loads((OUTPUT / f'{identifier}.json').read_text())
    rate = int(report['mix_rate'])
    stems = {stem: np.fromfile(OUTPUT / f'{identifier}_{stem}.f32', dtype='<f4').reshape(-1, 2).mean(axis=1) for stem in ('music', 'breath', 'ticks')}
    tick = source(ROOT / 'assets/audio/breath_tick.wav', rate)
    match = correlate(stems['ticks'], tick, mode='valid', method='fft')
    peaks, _ = find_peaks(match, height=.08 * match.max(), distance=int(.6 * rate))
    positions = []
    for peak in peaks:
        left, centre, right = match[peak - 1], match[peak], match[peak + 1]
        curvature = left - 2 * centre + right
        positions.append(peak + (.5 * (left - right) / curvature if curvature < 0 else 0.0))
    positions = np.array(positions)
    loud = match[peaks] > .6 * match[peaks].max()
    cycle = int(round(report['loop_seconds']))
    boundaries = {int(round(b)) % cycle for b in report['boundaries']}
    # Every stem starts on one mix step, so the score's first captured frame is session time `start`. While paused the
    # capture records exact silence and no stem advances, so session time skips that run of silent frames.
    audible = np.abs(stems['music']) > 1e-9
    started = int(np.flatnonzero(audible)[0])
    edges = np.flatnonzero(np.diff(audible[started:].astype(np.int8))) + started + 1
    runs = [(edges[i], edges[i + 1]) for i in range(0, len(edges) - 1, 2) if not audible[edges[i]]]
    gap = max(runs, key=lambda run: run[1] - run[0]) if runs else (len(audible), len(audible))
    pauses = sum(1 for a, b in runs if b - a > .3 * rate)

    def session(position: float) -> float:
        return report['start'] + (position - started - (gap[1] - gap[0] if position >= gap[1] else 0)) / rate

    times = np.array([session(p) for p in positions])
    seconds = np.round(times).astype(int)
    tick_errors = (times - seconds) * 1000
    segments = [positions < gap[0], positions >= gap[1]]
    steady = np.concatenate([np.diff(positions[segment]) / rate for segment in segments])
    score = source(ROOT / report['music'], rate)
    breath = source(ROOT / report['breath'].removeprefix('res://'), rate)
    # The loop repeats: lay enough cycles end to end to cover the capture.
    breath = np.tile(breath, int(np.ceil((report['start'] + 40) / report['loop_seconds'])) + 1)
    score_lags, breath_lags = [], []
    for position, second in zip(positions, seconds):
        start = int(round(position))
        excerpt = slice(start, start + int(1.5 * rate))
        if excerpt.stop > len(stems['music']):
            continue
        # The excerpt starts `fraction` samples before the tick, so it belongs at second * rate - fraction.
        fraction = position - start
        lag = lag_of(stems['music'][excerpt], score, int(round(second * rate)), int(.05 * rate))
        if lag is not None:
            score_lags.append((lag + fraction) / rate * 1000)
        lag = lag_of(stems['breath'][excerpt], breath, int(round(second * rate)), int(.05 * rate))
        if lag is not None:
            breath_lags.append((lag + fraction) / rate * 1000)
    # The first tick sounds while the players' first mix step ramps their gain up from silence; judge accents after it.
    settled = positions - started > .05 * rate
    accents_match = bool(np.all(loud[settled] == np.isin(seconds[settled] % cycle, list(boundaries))))
    result = dict(
        id=identifier, ticks=len(positions), pauses_seen=pauses, tick_period_error_ms=round(float(np.max(np.abs(steady - 1.0))) * 1000, 3) if len(steady) else None,
        tick_session_error_ms=round(float(np.max(np.abs(tick_errors))), 3),
        score_matches=len(score_lags), score_offset_ms=round(float(np.max(np.abs(score_lags))), 3) if score_lags else None,
        breath_matches=len(breath_lags), breath_offset_ms=round(float(np.max(np.abs(breath_lags))), 3) if breath_lags else None,
        accents_on_boundaries=accents_match, first_tick_second=int(seconds[0]) if len(seconds) else None, discarded_frames=report['discarded_frames'], runtime_offsets_ms=report['offsets_ms_before_pause_and_at_end'],
    )
    problems = []
    if len(positions) < 20 or pauses != 1:
        problems.append(f'expected 20+ ticks around one pause, found {len(positions)} ticks and {pauses} pauses')
    if result['tick_session_error_ms'] > TOLERANCE_MS:
        problems.append(f"ticks start {result['tick_session_error_ms']} ms away from whole seconds of session time")
    if result['tick_period_error_ms'] is None or result['tick_period_error_ms'] > TOLERANCE_MS:
        problems.append(f"ticks are not exactly one second apart ({result['tick_period_error_ms']} ms)")
    if len(score_lags) < 15 or result['score_offset_ms'] > TOLERANCE_MS:
        problems.append(f"ticks sit {result['score_offset_ms']} ms from the score's whole seconds ({len(score_lags)} matched)")
    if len(breath_lags) < 8 or result['breath_offset_ms'] > TOLERANCE_MS:
        problems.append(f"ticks sit {result['breath_offset_ms']} ms from the breath loop ({len(breath_lags)} matched)")
    if not result['accents_on_boundaries']:
        problems.append('louder ticks do not fall exactly on the breath phase boundaries')
    if any(result['discarded_frames'].values()):
        problems.append(f"capture dropped frames {result['discarded_frames']}")
    result['problems'] = problems
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('ids', nargs='*')
    parser.add_argument('--skip-capture', action='store_true')
    args = parser.parse_args()
    catalog = json.loads((ROOT / 'experiences/catalog.json').read_text())
    identifiers = args.ids or [entry['id'] for entry in catalog]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if not args.skip_capture:
        # Godot plays its imported copy of each score; reimport first so a replaced delivery is what gets captured.
        subprocess.run([str(GODOT), '--headless', '--xr-mode', 'off', '--editor', '--path', str(ROOT), '--quit'], capture_output=True, text=True, check=True)
    results = []
    for identifier in identifiers:
        if not args.skip_capture:
            log = subprocess.run([str(GODOT), '--headless', '--xr-mode', 'off', '--path', str(ROOT), '--script', 'tests/capture_cue_audio.gd', '--', '--test', f'--experience={identifier}', f'--output={OUTPUT}'], capture_output=True, text=True)
            if log.returncode or 'CUE CAPTURE' not in log.stdout:
                raise SystemExit(f'{identifier}: capture failed\n{log.stdout[-2000:]}\n{log.stderr[-2000:]}')
        result = analyze(identifier)
        results.append(result)
        status = 'ALIGNED' if not result['problems'] else 'MISALIGNED: ' + '; '.join(result['problems'])
        print(f"{identifier:22s} ticks {result['ticks']:3d}  tick period ±{result['tick_period_error_ms']} ms  score ±{result['score_offset_ms']} ms ({result['score_matches']})  breath ±{result['breath_offset_ms']} ms ({result['breath_matches']})  accents {'on boundaries' if result['accents_on_boundaries'] else 'WRONG'}  {status}", flush=True)
    (OUTPUT / 'report.json').write_text(json.dumps(results, indent=2) + '\n')
    if any(result['problems'] for result in results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
