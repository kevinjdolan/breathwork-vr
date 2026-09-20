"""Measure how exactly each score follows the strict 60 BPM grid shared with the breath ticks.

Breath ticks sound on every whole second of session time, so every score must put its beats on whole seconds of its
own timeline, from the first beat to the last and through every transition. librosa supplies the onset strength
envelope, a tempo estimate, a beat tracker and onset detection:

- the tempo estimate must read 60 BPM;
- onset strength folded over candidate periods must cohere best at exactly 1.000 s (a few hundredths of a BPM);
- the beat-level onset peak must sit with the breath tick, measured the same way from the tick sample itself;
- librosa's beat tracker must put nine in ten beats within 50 ms of a tick;
- every 16-second window with a clear pulse, and the 24 seconds around every transition, must keep its strongest onset
  position on that grid: on the tick, or on a sixteenth of it where an arpeggio outweighs the beat.

The share of prominent onsets on the sixteenth-note grid is reported as a diagnostic.

    python -m audio.beat_grid [experience ids] [--report verification/beat_grid.json]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BPM = 60
BEAT_SECONDS = 60.0 / BPM
SAMPLE_RATE = 22050
HOP = 128
WINDOW_SECONDS = 16.0
GRID_STEP = BEAT_SECONDS / 4
GRID_TOLERANCE = .035
# A window has a clear beat when one position within the beat carries this multiple of the average onset strength.
CLEAR_BEAT = 1.6


def envelope_of(signal: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    import librosa

    # Mean aggregation keeps narrowband pulses (a glass pluck, a low bloom) that a median across bands would erase.
    envelope = librosa.onset.onset_strength(y=signal, sr=SAMPLE_RATE, hop_length=HOP, lag=1)
    times = librosa.frames_to_time(np.arange(len(envelope)), sr=SAMPLE_RATE, hop_length=HOP)
    return envelope, times


def onset_envelope(path: Path) -> tuple[np.ndarray, np.ndarray]:
    import librosa

    signal, _ = librosa.load(path, sr=SAMPLE_RATE, mono=True)
    return envelope_of(signal)


def folded_phase(envelope: np.ndarray, times: np.ndarray, period: float = BEAT_SECONDS) -> tuple[float, float, float]:
    """Where onsets gather within the beat, how coherently, and how clearly one position dominates.

    Returns the phase (seconds, in [-period/2, period/2)) at the peak of the folded onset histogram, the circular
    coherence (0..1) and the peak-to-mean ratio of the smoothed histogram. The peak, unlike a circular mean, cannot
    be pulled off the beat by eighth or sixteenth notes.
    """
    weights = np.maximum(envelope - np.median(envelope), 0.0)
    if weights.sum() <= 0:
        return 0.0, 0.0, 0.0
    fraction = np.mod(times, period) / period
    coherence = np.abs(np.sum(weights * np.exp(2j * np.pi * fraction))) / weights.sum()
    bins = 100
    histogram = np.bincount(np.minimum((fraction * bins).astype(int), bins - 1), weights=weights, minlength=bins)
    smoothed = np.convolve(np.concatenate([histogram[-2:], histogram, histogram[:2]]), np.ones(5) / 5, mode='valid')
    phase = (np.argmax(smoothed) + .5) / bins * period
    return float((phase + period / 2) % period - period / 2), float(coherence), float(smoothed.max() / max(smoothed.mean(), 1e-12))


def tick_reference_ms() -> float:
    """Measured beat phase of the breath tick itself placed on every whole second.

    Onset analysis reports a small latency after each attack. Scores are judged against the tick measured the same
    way, so agreement here means "lands with the tick", which is what the listener hears.
    """
    import librosa
    import soundfile

    tick, rate = soundfile.read(ROOT / 'assets/audio/breath_tick.wav', always_2d=True)
    tick = librosa.resample(tick.mean(axis=1), orig_sr=rate, target_sr=SAMPLE_RATE)
    signal = np.zeros(60 * SAMPLE_RATE)
    for second in range(60):
        start = second * SAMPLE_RATE
        signal[start:start + len(tick)] += tick[:len(signal) - start]
    envelope, times = envelope_of(signal)
    return round(folded_phase(envelope, times)[0] * 1000, 1)


def prominent_onsets(envelope: np.ndarray, times: np.ndarray, tick_seconds: float) -> np.ndarray:
    """Detected onsets at least half as strong as the typical onset on the beat."""
    import librosa

    onsets = librosa.onset.onset_detect(onset_envelope=envelope, sr=SAMPLE_RATE, hop_length=HOP, units='frames')
    if len(onsets) == 0:
        return onsets
    position = np.mod(times[onsets] - tick_seconds, BEAT_SECONDS)
    on_beat = np.minimum(position, BEAT_SECONDS - position) <= GRID_TOLERANCE
    reference = np.median(envelope[onsets[on_beat]]) if on_beat.any() else np.max(envelope[onsets])
    return onsets[envelope[onsets] >= .5 * reference]


def grid_fraction(envelope: np.ndarray, times: np.ndarray, tick_seconds: float, onsets: np.ndarray) -> float:
    """Strength-weighted share of the given onsets within 35 ms of the sixteenth-note grid anchored on the ticks."""
    if len(onsets) == 0:
        return 0.0
    weights = envelope[onsets]
    position = np.mod(times[onsets] - tick_seconds, GRID_STEP)
    distance = np.minimum(position, GRID_STEP - position)
    return float(weights[distance <= GRID_TOLERANCE].sum() / max(float(weights.sum()), 1e-12))


def analyze(path: Path, transitions: list[float] = (), tick_ms: float | None = None) -> dict:
    import librosa

    tick_ms = tick_reference_ms() if tick_ms is None else tick_ms
    tick_seconds = tick_ms / 1000
    envelope, times = onset_envelope(path)
    duration = float(times[-1])
    # Motifs that repeat every few beats can pull an unconstrained estimate to a sub-multiple, so the estimate is
    # centred on the beat level; the folding period below independently confirms the tempo.
    tempo = float(np.atleast_1d(librosa.feature.tempo(onset_envelope=envelope, sr=SAMPLE_RATE, hop_length=HOP, start_bpm=BPM, std_bpm=.5))[0])
    _, beats = librosa.beat.beat_track(onset_envelope=envelope, sr=SAMPLE_RATE, hop_length=HOP, bpm=tempo, tightness=400, units='time')
    offsets = (beats - tick_seconds + BEAT_SECONDS / 2) % BEAT_SECONDS - BEAT_SECONDS / 2
    periods = np.linspace(.98, 1.02, 401)
    coherence = np.array([folded_phase(envelope, times, period)[1] for period in periods])
    phase, clarity, peak = folded_phase(envelope, times)
    onsets = prominent_onsets(envelope, times, tick_seconds)

    def window(start: float, end: float) -> dict:
        mask = (times >= start) & (times < end)
        window_phase, _, window_peak = folded_phase(envelope[mask], times[mask])
        inside = onsets[(times[onsets] >= start) & (times[onsets] < end)]
        return dict(start=float(start), phase_ms=round(window_phase * 1000, 1), peak=round(window_peak, 2), on_grid=round(grid_fraction(envelope, times, tick_seconds, inside), 3))

    windows = [window(start, start + WINDOW_SECONDS) for start in np.arange(0.0, duration - WINDOW_SECONDS + .001, WINDOW_SECONDS)]
    transition_windows = [dict(window(moment - 12.0, moment + 12.0), at=float(moment)) for moment in transitions]
    return dict(
        file=str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path),
        duration=round(duration, 2),
        tick_reference_ms=tick_ms,
        librosa_tempo_bpm=round(tempo, 2),
        best_fold_period_s=round(float(periods[np.argmax(coherence)]), 4),
        beat_phase_ms=round(phase * 1000, 1),
        beat_peak=round(peak, 2),
        beat_coherence=round(clarity, 3),
        tracked_beats=int(len(beats)),
        beats_within_50ms=round(float(np.mean(np.abs(offsets) <= .05)) if len(beats) else 0.0, 3),
        prominent_onsets=int(len(onsets)),
        on_grid_fraction=round(grid_fraction(envelope, times, tick_seconds, onsets), 3),
        transitions=transition_windows,
        windows=windows,
    )


def verdict(report: dict, phase_tolerance_ms: float = 30.0) -> list[str]:
    """Human-readable failures against the strict grid; an empty list means the score locks to the ticks."""
    problems = []
    tick_ms = report['tick_reference_ms']

    def off(phase_ms: float) -> float:
        return phase_ms - tick_ms

    def off_grid(phase_ms: float) -> float:
        # Distance from the nearest sixteenth of a tick-aligned beat.
        step = GRID_STEP * 1000
        return abs((off(phase_ms) + step / 2) % step - step / 2)

    if not 59.0 <= report['librosa_tempo_bpm'] <= 61.0:
        problems.append(f"librosa tempo {report['librosa_tempo_bpm']} BPM")
    if abs(report['best_fold_period_s'] - BEAT_SECONDS) > .0005:
        problems.append(f"onsets cohere best at {report['best_fold_period_s']} s, not 1.000 s")
    if report['beat_peak'] < CLEAR_BEAT:
        problems.append(f"no clear beat (peak {report['beat_peak']})")
    if abs(off(report['beat_phase_ms'])) > phase_tolerance_ms:
        problems.append(f"beats peak {off(report['beat_phase_ms']):+.0f} ms from the ticks")
    if report['beats_within_50ms'] < .9:
        problems.append(f"only {report['beats_within_50ms']:.0%} of tracked beats land within 50 ms of a tick")
    clear = [w for w in report['windows'] if w['peak'] >= CLEAR_BEAT]
    if len(clear) < .75 * len(report['windows']):
        problems.append(f"only {len(clear)}/{len(report['windows'])} windows carry a clear beat")
    drifting = [w for w in clear if off_grid(w['phase_ms']) > phase_tolerance_ms]
    if drifting:
        problems.append(f"{len(drifting)} windows drift off the tick grid, first at {drifting[0]['start']:.0f} s ({off(drifting[0]['phase_ms']):+.0f} ms)")
    for transition in report['transitions']:
        if transition['peak'] < CLEAR_BEAT:
            problems.append(f"transition at {transition['at']:.0f} s loses the pulse")
        elif off_grid(transition['phase_ms']) > phase_tolerance_ms:
            problems.append(f"transition at {transition['at']:.0f} s sits {off(transition['phase_ms']):+.0f} ms off the tick grid")
    return problems


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('ids', nargs='*')
    parser.add_argument('--report', type=Path, default=ROOT / 'verification/beat_grid.json')
    args = parser.parse_args()
    catalog = json.loads((ROOT / 'experiences/catalog.json').read_text())
    provenance = {track['id']: track for track in json.loads((ROOT / 'audio/suite_provenance.json').read_text())['tracks']}
    provenance['aurora_lake'] = json.loads((ROOT / 'audio/music_provenance.json').read_text())
    tick_ms = tick_reference_ms()
    print(f'breath tick reference phase {tick_ms} ms', flush=True)
    reports = {'_tick_reference_ms': tick_ms}
    for entry in catalog:
        if args.ids and entry['id'] not in args.ids:
            continue
        report = analyze(ROOT / entry['music'], provenance.get(entry['id'], {}).get('transitions', []), tick_ms)
        report['problems'] = verdict(report)
        reports[entry['id']] = report
        status = 'LOCKED' if not report['problems'] else 'OFF GRID: ' + '; '.join(report['problems'])
        print(f"{entry['id']:22s} tempo {report['librosa_tempo_bpm']:6.2f}  period {report['best_fold_period_s']:.4f}  beat {report['beat_phase_ms']:6.1f} ms  peak {report['beat_peak']:5.2f}  tracked {report['beats_within_50ms']:.0%}  on grid {report['on_grid_fraction']:.0%}  {status}", flush=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(reports, indent=2) + '\n')


if __name__ == '__main__':
    main()
