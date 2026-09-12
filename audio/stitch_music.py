"""Master three movements into a 480-second, −18 LUFS meditation soundtrack."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import shutil
import tempfile

import numpy as np
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[1]
RATE = 48_000


def run(arguments: list[str]) -> subprocess.CompletedProcess:
    """Execute FFmpeg with checked status and retained diagnostic output."""
    result = subprocess.run(arguments, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr[-2000:])
    return result


def decode(path: Path, seconds: float) -> np.ndarray:
    """Conform source duration by gentle tempo adjustment, retaining full endings."""
    details = run(["ffprobe", "-v", "error", "-show_format", "-of", "json", str(path)])
    duration = float(json.loads(details.stdout)["format"]["duration"])
    ratio = duration / seconds
    if not 0.75 <= ratio <= 1.25:
        raise ValueError(f"{path.name} needs excessive time stretching: {duration}s → {seconds}s")
    result = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-af", f"atempo={ratio},apad,atrim=duration={seconds}", "-ar", str(RATE), "-ac", "2", "-f", "f32le", "-"], check=True, capture_output=True)
    return np.frombuffer(result.stdout, dtype="<f4").reshape(-1, 2).copy()


def placeholder() -> np.ndarray:
    """Produce an explicitly labeled D-major drone when Lyria is unavailable."""
    output = np.zeros((480 * RATE, 2), dtype=np.float32)
    for start in range(0, len(output), RATE * 12):
        t = (np.arange(min(RATE * 12, len(output) - start)) + start) / RATE
        swell = 0.8 + 0.2 * np.sin(2 * np.pi * t / 24) ** 2
        for channel in range(2):
            wave = sum(np.sin(2 * np.pi * freq * t + 0.07 * np.sin(t * 0.09 + channel)) / (index + 2) for index, freq in enumerate([73.416, 110.0, 146.832, 184.997, 220.0]))
            output[start:start + len(t), channel] = wave * swell * np.minimum(t / 12, 1) * np.clip((480 - t) / 4, 0, 1) * 0.12
    return output


def main() -> None:
    """Stitch at 168/336 seconds and apply measured two-pass loudness normalization."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--placeholder", action="store_true")
    args = parser.parse_args()
    sources = []
    if args.placeholder:
        mix = placeholder()
    else:
        mix = np.zeros((480 * RATE, 2), dtype=np.float32)
        for name, start, seconds in (("calm", 0, 178), ("deepening", 168, 178), ("peak_resolve", 336, 144)):
            evidence = json.loads((ROOT / "audio" / "masters" / f"{name}.json").read_text())
            samples = decode(ROOT / "audio" / "masters" / evidence["file"], seconds)
            sources.append({"id": name, "sha256": evidence["sha256"], "source_seconds": float(evidence["probe"]["format"]["duration"]), "conformed_seconds": seconds})
            ramp = np.linspace(0, np.pi / 2, 10 * RATE)
            if start:
                samples[:len(ramp)] *= np.sin(ramp)[:, None]
            if name != "peak_resolve":
                samples[-len(ramp):] *= np.cos(ramp)[:, None]
            mix[start * RATE:start * RATE + len(samples)] += samples
        mix[:12 * RATE] *= np.linspace(0, 1, 12 * RATE)[:, None]
        mix[-4 * RATE:] *= np.linspace(1, 0, 4 * RATE)[:, None]
    target = ROOT / "assets" / "audio" / "music.ogg"
    with tempfile.TemporaryDirectory() as temp:
        wav = Path(temp) / "mix.wav"
        wavfile.write(wav, RATE, mix)
        first = run(["ffmpeg", "-hide_banner", "-i", str(wav), "-af", "loudnorm=I=-18:TP=-1:LRA=11:print_format=json", "-f", "null", "-"])
        measured = json.JSONDecoder().raw_decode(first.stderr[first.stderr.rfind("{"):])[0]
        loudness = f"loudnorm=I=-18:TP=-1:LRA=11:measured_I={measured['input_i']}:measured_TP={measured['input_tp']}:measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}:offset={measured['target_offset']}:linear=true"
        normalized = Path(temp) / "normalized.wav"
        run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-af", loudness, "-ar", str(RATE), "-c:a", "pcm_s24le", "-t", "480", str(normalized)])
        if shutil.which("oggenc"):
            run(["oggenc", "-Q", "-q", "6", "-o", str(target), str(normalized)])
        else:
            run(["ffmpeg", "-v", "error", "-y", "-i", str(normalized), "-c:a", "libvorbis", "-q:a", "6", str(target)])
    report = {"placeholder": args.placeholder, "model": None if args.placeholder else "lyria-3.5", "duration": 480, "transition_starts": [168, 336], "crossfade_seconds": 10, "target_lufs": -18, "vorbis_quality": 6, "sources": sources}
    (ROOT / "audio" / "music_provenance.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Mastered {target}")


if __name__ == "__main__":
    main()
