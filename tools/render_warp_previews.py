"""Render thirty-second preview movies for the warp-field and echo-shell worlds."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get('GODOT_BIN', ROOT/'.tools/Godot_v4.6.3-stable_linux.x86_64'))
WORK = ROOT/'verification/warp_previews'
SECONDS = 30

WORLDS = [
    'spiral_aperture', 'mandala_drift', 'standing_tide', 'pollen_weather',
    'rosette_corridor', 'echo_atrium', 'vellum_veils', 'inversion_chapel',
]


def run(args: list[str], log: Path) -> None:
    """Run one bounded step and retain its complete output for diagnosis."""
    with log.open('w') as output:
        subprocess.run(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, check=True)


def render(item: tuple[int, str], output: Path, width: int, height: int) -> dict:
    """Capture a runtime half minute with its music and breath guide, then encode it."""
    number, identifier = item
    raw = WORK/f'{identifier}.avi'
    log = WORK/f'{identifier}_render.log'
    target = output/f'{number:02d}-{identifier}.mp4'
    # Movie Maker always captures at the project viewport, so the delivery size is set
    # when encoding rather than by asking the engine for a smaller window.
    run(['xvfb-run', '-a', str(GODOT), '--xr-mode', 'off', '--path', str(ROOT),
         '--fixed-fps', '30', '--disable-vsync',
         '--write-movie', str(raw), '--script', 'tests/render_preview.gd', '--',
         '--test', f'--experience={identifier}', f'--preview-duration={SECONDS + 2}'], log)
    text = log.read_text()
    if re.search(r'^(SCRIPT ERROR:|SHADER ERROR:|ERROR:)', text, re.MULTILINE):
        raise RuntimeError(f'{identifier}: Godot reported an error; see {log}')
    run(['ffmpeg', '-v', 'error', '-y', '-ss', '2', '-i', str(raw), '-t', str(SECONDS),
         '-vf', f'scale={width}:{height}:flags=lanczos,'
                f'fade=t=in:st=0:d=0.6,fade=t=out:st={SECONDS - 0.8:.1f}:d=0.8',
         '-af', f'afade=t=in:st=0:d=0.6,afade=t=out:st={SECONDS - 0.8:.1f}:d=0.8',
         '-c:v', 'libx264', '-preset', 'medium', '-crf', '24',
         '-maxrate', '4500k', '-bufsize', '9M', '-pix_fmt', 'yuv420p',
         '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', str(target)],
        WORK/f'{identifier}_encode.log')
    probe = json.loads(subprocess.check_output(
        ['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(target)]))
    video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
    audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
    duration = float(probe['format']['duration'])
    assert abs(duration - SECONDS) < 0.2, (identifier, duration)
    assert (video['width'], video['height']) == (width, height)
    assert audio['channels'] == 2
    raw.unlink()
    print(f'PREVIEW READY {number}: {identifier} '
          f'({target.stat().st_size/1048576:.1f} MiB)', flush=True)
    return dict(id=identifier, file=target.name, seconds=SECONDS,
                width=width, height=height, bytes=target.stat().st_size)


def main() -> None:
    """Render every warp world, two at a time so the software renderer keeps up."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT/'build/warp_previews')
    parser.add_argument('--width', type=int, default=1280)
    parser.add_argument('--height', type=int, default=800)
    parser.add_argument('--only', nargs='*', help='Render just these identifiers')
    parser.add_argument('--workers', type=int, default=2)
    arguments = parser.parse_args()
    arguments.output.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    chosen = [w for w in WORLDS if not arguments.only or w in arguments.only]
    with ThreadPoolExecutor(max_workers=arguments.workers) as pool:
        reports = list(pool.map(
            lambda item: render(item, arguments.output, arguments.width, arguments.height),
            [(WORLDS.index(w) + 1, w) for w in chosen]))
    (arguments.output/'manifest.json').write_text(json.dumps(reports, indent=2) + '\n')
    print(f'{len(reports)} previews in {arguments.output}')


if __name__ == '__main__':
    main()
