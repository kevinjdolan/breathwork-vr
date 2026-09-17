"""Render breathing guides for named rhythms without touching approved recordings."""

import json
from pathlib import Path
import sys

import numpy as np
from scipy.io import wavfile

from audio.synth_breath import RATE, breath_segment

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    """Render only the identifiers named on the command line."""
    wanted = set(sys.argv[1:])
    for entry in json.loads((ROOT/'experiences/catalog.json').read_text()):
        if entry['id'] not in wanted:
            continue
        incoming, hold, outgoing, rest = entry['rhythm']
        rng = np.random.default_rng(490)
        inhale = breath_segment(incoming, True, rng, mellow=True)
        exhale = breath_segment(outgoing, False, rng)
        inhale *= 0.65 * np.sqrt(np.mean(exhale**2) / np.mean(inhale**2))
        samples = np.concatenate([inhale, np.zeros((hold*RATE, 2)), exhale, np.zeros((rest*RATE, 2))])
        samples *= .1 / np.max(np.abs(samples))
        path = ROOT/'assets/audio'/f"breath_{entry['id']}.wav"
        wavfile.write(path, RATE, np.round(samples*32767).astype(np.int16))
        print(path.name, len(samples)/RATE)


if __name__ == '__main__':
    main()
