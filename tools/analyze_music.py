"""Bake a track's loudness bands per frame, the way MilkDrop measured them.

MilkDrop took a 1024-point FFT of one channel each frame, summed the lower bins into
three bands, and divided each by its own long-running average, so 1.0 always meant
"about as loud as this track usually is". That normalisation is what let one preset look
right on any song, and it is what makes the reaction legible here too.

Analysing offline rather than through an audio bus keeps the result identical on every
render, which matters because the previews are captured frame by frame rather than in
real time.
"""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[1]
FPS = 30
SAMPLES = 1024
BANDS = 3


def decode(source: Path) -> tuple[int, np.ndarray]:
    """Decode any input to mono float32 at its own rate via ffmpeg."""
    with tempfile.TemporaryDirectory() as work:
        target = Path(work)/'decoded.wav'
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source),
                        '-ac', '1', '-c:a', 'pcm_s16le', str(target)], check=True)
        rate, data = wavfile.read(target)
    return rate, data.astype(np.float64)/32768.0


def bands(samples: np.ndarray, rate: int) -> np.ndarray:
    """Per-frame energy in MilkDrop's three bands, before normalisation."""
    total = int(len(samples)/rate*FPS)
    # A raised sine window and a log tilt that lifts the highs, as in fft.cpp.
    window = 0.5 + 0.5*np.sin(np.arange(SAMPLES)*2*np.pi/SAMPLES - np.pi/2)
    equalize = -0.02*np.log((SAMPLES/2 - np.arange(SAMPLES//2))/(SAMPLES/2))
    equalize[0] = equalize[1]
    out = np.zeros((total, BANDS))
    for frame in range(total):
        start = int(frame/FPS*rate)
        chunk = samples[start:start + SAMPLES]
        if len(chunk) < SAMPLES:
            chunk = np.pad(chunk, (0, SAMPLES - len(chunk)))
        spectrum = np.abs(np.fft.rfft(chunk*window))[:SAMPLES//2]*equalize
        # MilkDrop summed the bottom half of the spectrum in three equal spans.
        for band in range(BANDS):
            lo = SAMPLES//2*band//6
            hi = SAMPLES//2*(band + 1)//6
            out[frame, band] = spectrum[lo:hi].mean()
    return out


def normalize(raw: np.ndarray) -> dict:
    """Divide each band by its own long-term average and smooth it, as MilkDrop did."""
    total = len(raw)
    long_average = np.zeros(BANDS) + 1e-6
    average = np.zeros(BANDS)
    immediate_relative = np.zeros((total, BANDS))
    average_relative = np.zeros((total, BANDS))
    for frame in range(total):
        value = raw[frame]
        # 0.2 rising and 0.5 falling at 30 fps, then a slow 0.992 long-term follower.
        rate = np.where(value > average, 0.2, 0.5)
        average = average*(1.0 - rate) + value*rate
        slow = 0.9 if frame < 50 else 0.992
        long_average = long_average*slow + value*(1.0 - slow)
        safe = np.maximum(long_average, 1e-9)
        immediate_relative[frame] = value/safe
        average_relative[frame] = average/safe
    return dict(bass=immediate_relative[:, 0], mid=immediate_relative[:, 1],
                treb=immediate_relative[:, 2], bass_att=average_relative[:, 0],
                mid_att=average_relative[:, 1], treb_att=average_relative[:, 2])


def main() -> None:
    """Write the per-frame table and report the most dynamic stretch of the track."""
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--window', type=float, default=30.0)
    arguments = parser.parse_args()
    rate, samples = decode(arguments.source)
    raw = bands(samples, rate)
    table = normalize(raw)
    drive = (table['bass'] + table['mid'] + table['treb'])/3.0

    # Report the window with the most movement, which is the interesting excerpt.
    span = int(arguments.window*FPS)
    best, best_score = 0, -1.0
    for start in range(0, max(1, len(drive) - span), FPS):
        section = drive[start:start + span]
        score = float(section.std() + 0.5*section.mean())
        if score > best_score:
            best, best_score = start, score
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(dict(
        fps=FPS, frames=len(drive),
        seconds=len(drive)/FPS,
        suggested_start=best/FPS,
        drive=[round(float(v), 4) for v in drive],
        **{key: [round(float(v), 4) for v in value] for key, value in table.items()},
    )))
    print(f'{len(drive)} frames, {len(drive)/FPS:.1f}s')
    print(f'drive: mean {drive.mean():.2f} p95 {np.percentile(drive, 95):.2f} max {drive.max():.2f}')
    print(f'most dynamic {arguments.window:.0f}s window starts at {best/FPS:.1f}s')


if __name__ == '__main__':
    main()
