"""Create quiet mono water and airy spatial accents for the meditation scene."""
from pathlib import Path
import numpy as np
from scipy.io import wavfile

RATE = 48000
ROOT = Path(__file__).resolve().parents[1]


def write_water() -> None:
    """Synthesize a periodic, smoothly modulated water bed without transient splashes."""
    count = RATE * 32
    rng = np.random.default_rng(824)
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    spectrum = np.fft.rfft(rng.normal(size=count))
    spectrum *= (1 - np.exp(-(frequencies / 90) ** 2)) * np.exp(-(frequencies / 1900) ** 2)
    spectrum /= np.sqrt(np.maximum(frequencies, 1))
    signal = np.fft.irfft(spectrum, n=count)
    t = np.arange(count) / count
    envelope = 0.62 + 0.20 * np.sin(2 * np.pi * t * 3) + 0.12 * np.sin(2 * np.pi * t * 7 + 1.3)
    signal *= envelope
    signal *= 0.16 / np.max(np.abs(signal))
    wavfile.write(ROOT / 'assets/audio/water_ambient.wav', RATE, np.round(signal * 32767).astype(np.int16))


def write_accent() -> None:
    """Synthesize a soft breath-like shimmer with no sharp attack or pitched chime."""
    count = round(RATE * 2.4)
    rng = np.random.default_rng(153)
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    spectrum = np.fft.rfft(rng.normal(size=count))
    spectrum *= np.exp(-((frequencies - 1100) / 650) ** 2)
    signal = np.fft.irfft(spectrum, n=count)
    envelope = np.sin(np.linspace(0, np.pi, count)) ** 3
    signal *= envelope
    signal *= 0.10 / np.max(np.abs(signal))
    wavfile.write(ROOT / 'assets/audio/mote_air.wav', RATE, np.round(signal * 32767).astype(np.int16))


def main() -> None:
    """Write deterministic spatial ambience assets."""
    write_water()
    write_accent()


if __name__ == '__main__':
    main()
