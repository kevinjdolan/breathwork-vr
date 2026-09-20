"""Generate the material-capture spheres that shade Visionary Temple's 3D relics.

Each matcap is one lit sphere; the relic shader looks up its colour by the view-space normal, so a single texture
fetch gives gold, gemstone or pearl surfaces real-looking highlights on mobile hardware.

    python -m art.visionary_relics matcaps [--only ruby,opal]
    python -m art.visionary_relics atlas
"""
from __future__ import annotations

import argparse
import hashlib
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np
from PIL import Image

from art import imagegen
from art.visionary_passages import write_import

ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / 'experiences/visionary_temple/tiles/matcaps.png'
PROVENANCE = Path(__file__).resolve().parent / 'visionary_relics_provenance.json'
MODEL = 'gemini-3-pro-image'
CELL = 256
# Atlas order is part of the runtime contract (relics.gd refers to these indices).
MATERIALS = (
    ('gold', 'polished warm 24-karat gold'),
    ('rose_gold', 'polished rose gold'),
    ('pearl', 'lustrous white pearl with soft pink and blue iridescent sheen'),
    ('ruby', 'deep glowing ruby gemstone, glossy, with warm light glowing through its red interior; the sphere edge stays dark red with no white rim or outline'),
    ('sapphire', 'deep royal-blue sapphire gemstone, glossy, with light glowing through its interior'),
    ('emerald', 'vivid emerald-green gemstone, glossy, with light glowing through its interior'),
    ('amethyst', 'violet amethyst crystal, glossy and translucent-looking'),
    ('citrine', 'golden-orange citrine crystal, glossy and luminous, with no white rim or outline around the sphere'),
    ('moonstone', 'milky moonstone with a floating blue adularescent glow'),
    ('opal', 'polished fire opal with rainbow play-of-color flashes'),
    ('jade', 'polished imperial green jade with soft translucent depth'),
    ('turquoise', 'polished robin-egg turquoise with faint golden veins'),
    ('lapis', 'polished lapis lazuli: deep ultramarine blue with tiny gold flecks'),
    ('obsidian', 'polished rainbow obsidian: glossy black with violet and green iridescent sheen'),
    ('rose_quartz', 'polished pale pink rose quartz, soft and translucent-looking'),
    ('crystal', 'clear rock crystal quartz refracting a bright soft studio environment of white and pale lilac light, so the whole sphere looks luminous and glassy rather than dark, with faint rainbow edges'),
)
PROMPT = (
    'A matcap (material capture) reference image: exactly one perfect smooth sphere of {material}, centered, filling the '
    'square frame almost edge to edge, on a pure black background. Lit by a large soft key light from the upper left, a '
    'gentle fill from the right and a faint rim light, with a crisp specular highlight and subtle environment reflections '
    'suited to the material. Straight-on orthographic view, no perspective distortion. No other objects, no ground, no '
    'shadow, no text, no border.'
)


def generate(name: str, material: str) -> Path:
    prompt = PROMPT.format(material=material)
    image = imagegen.gemini(MODEL, prompt, aspect='1:1', size='1K')
    return imagegen.save_master(image, f'visionary_temple/matcaps/{name}', dict(material=name, model=MODEL, prompt=prompt))


def sphere_cell(path: Path) -> tuple[np.ndarray, dict]:
    """Crop to the lit sphere, resample to one atlas cell and black out everything outside the disc."""
    pixels = np.asarray(Image.open(path).convert('RGB')).astype(np.float64)
    brightness = pixels.max(axis=-1)
    ys, xs = np.nonzero(brightness > 18)
    top, bottom, left, right = ys.min(), ys.max(), xs.min(), xs.max()
    size = max(bottom - top, right - left) + 1
    # Spheres that touch the frame need black padding so the square crop stays centred on the disc.
    pad = size
    padded = np.pad(pixels, ((pad, pad), (pad, pad), (0, 0)))
    cy, cx = (top + bottom) / 2 + pad, (left + right) / 2 + pad
    box = (cx - size / 2, cy - size / 2, cx + size / 2, cy + size / 2)
    cell = Image.fromarray(np.uint8(padded)).resize((CELL, CELL), Image.LANCZOS, box=box)
    out = np.asarray(cell).astype(np.float64)
    y, x = np.mgrid[:CELL, :CELL]
    distance = np.hypot(x + .5 - CELL / 2, y + .5 - CELL / 2) / (CELL / 2)
    out *= np.clip((1.0 - distance) * CELL / 2, 0.0, 1.0)[..., None]
    aspect = (right - left + 1) / (bottom - top + 1)
    return np.uint8(np.round(out)), dict(bounds=[int(left), int(top), int(right), int(bottom)], aspect=round(float(aspect), 3))


def matcaps(args: argparse.Namespace) -> None:
    selected = set(args.only.split(',')) if args.only else None
    jobs = [(name, material) for name, material in MATERIALS if selected is None or name in selected]
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(generate, *job): job[0] for job in jobs}
        for future in as_completed(futures):
            try:
                print('matcap', future.result().relative_to(ROOT), flush=True)
            except Exception as error:
                print('FAILED', futures[future], error, flush=True)


def atlas(args: argparse.Namespace) -> None:
    sheet = np.zeros((CELL * 4, CELL * 4, 3), np.uint8)
    record = {}
    for index, (name, _) in enumerate(MATERIALS):
        master = imagegen.MASTERS / f'visionary_temple/matcaps/{name}.png'
        cell, stats = sphere_cell(master)
        if not .9 <= stats['aspect'] <= 1.1:
            raise SystemExit(f'{name} matcap is not a centred sphere: {stats}')
        y, x = divmod(index, 4)
        sheet[y * CELL:(y + 1) * CELL, x * CELL:(x + 1) * CELL] = cell
        sidecar = json.loads(master.with_suffix('.json').read_text())
        record[name] = dict(index=index, model=sidecar['model'], prompt=sidecar['prompt'], master_sha256=sidecar['sha256'], created=sidecar['created'], **stats)
    Image.fromarray(sheet).save(ATLAS, optimize=True)
    write_import(ATLAS, data_alpha=False)
    PROVENANCE.write_text(json.dumps(dict(atlas='experiences/visionary_temple/tiles/matcaps.png', atlas_sha256=hashlib.sha256(ATLAS.read_bytes()).hexdigest(), cell=CELL, layout='4 x 4 in MATERIALS order', materials=record), indent=2) + '\n')
    print('wrote', ATLAS.relative_to(ROOT), 'and', PROVENANCE.relative_to(ROOT), flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    generate_parser = commands.add_parser('matcaps', help='generate matcap sphere masters')
    generate_parser.add_argument('--only', help='comma-separated material names')
    generate_parser.set_defaults(run=matcaps)
    commands.add_parser('atlas', help='compose the 4 x 4 runtime matcap atlas').set_defaults(run=atlas)
    args = parser.parse_args()
    args.run(args)


if __name__ == '__main__':
    main()
