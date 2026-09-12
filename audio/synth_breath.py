"""Synthesize sample-exact stereo breathing loops from filtered pink noise."""

from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

RATE = 48_000
ROOT = Path(__file__).resolve().parents[1]


def breath_segment(seconds: int, inhale: bool, rng: np.random.Generator, mellow: bool = False) -> np.ndarray:
    """Shape pink noise into one soft inhalation or exhalation with short reverb."""
    count = seconds * RATE
    spectrum = np.fft.rfft(rng.normal(size=count))
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    spectrum /= np.sqrt(np.maximum(frequencies, 1))
    noise = np.fft.irfft(spectrum, n=count)
    band = (1500, 3000) if inhale else (400, 1200)
    if inhale and mellow:
        band = (450, 1600)
    noise = sosfilt(butter(3, band, fs=RATE, btype="bandpass", output="sos"), noise)
    t = np.arange(count) / RATE
    attack, release = (1.2, 0.6) if inhale else (0.4, 0.7)
    if inhale and mellow:
        attack, release = 1.7, 1.45
    envelope = np.sin(np.minimum(t / attack, 1) * np.pi / 2) ** 2
    envelope *= np.sin(np.minimum((seconds - t) / release, 1) * np.pi / 2) ** 2
    if not inhale:
        envelope *= np.exp(-np.maximum(t - attack, 0) / (seconds * 0.45))
    dry = noise * envelope
    stereo = np.column_stack([dry, dry])
    for channel in range(2):
        for delay, gain in ((0.043, 0.11), (0.079, 0.07), (0.131, 0.04)):
            offset = round((delay + channel * 0.003) * RATE)
            stereo[offset:, channel] += dry[:-offset] * gain
    # A terminal taper includes the reverb tail, leaving an exactly silent seam.
    edge = np.minimum(t / 0.015, 1) * np.minimum((seconds - 1 / RATE - t) / 0.025, 1)
    return stereo * np.maximum(edge, 0)[:, None]


def main() -> None:
    """Write 4/2/8 and optional 4/2/6 loops as 48 kHz, 16-bit stereo WAVs."""
    directory = ROOT / "assets" / "audio"
    directory.mkdir(parents=True, exist_ok=True)
    for exhale in (8, 6):
        rng = np.random.default_rng(490)
        original_inhale = breath_segment(4, True, rng)
        original = np.concatenate([original_inhale, np.zeros((2 * RATE, 2)), breath_segment(exhale, False, rng)])
        soft_inhale = breath_segment(4, True, np.random.default_rng(490), mellow=True)
        soft_inhale *= 0.65 * np.sqrt(np.mean(original_inhale ** 2) / np.mean(soft_inhale ** 2))
        # Keep the established mastering gain and every exhale sample unchanged.
        samples = original.copy()
        samples[:4 * RATE] = soft_inhale
        samples *= 0.1 / np.max(np.abs(original))
        wavfile.write(directory / f"breath_{6 + exhale}s.wav", RATE, np.round(samples * 32767).astype(np.int16))
        print(f"breath_{6 + exhale}s.wav: {len(samples)} frames, peak −20 dBFS")


if __name__ == "__main__":
    main()
