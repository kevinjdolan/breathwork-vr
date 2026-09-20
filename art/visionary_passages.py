"""Generate the four AI-painted Visionary Temple passages and their relief maps.

Paintings come from gpt-image-2, wrap seams are repainted by gpt-image-2 under a mask, and every passage's
height map (including the four procedural passages) comes from Nano Banana Pro, which keeps its answer
pixel-aligned with the painting. Keys come from GEMINI_API_KEY/GOOGLE_API_KEY and OPENAI_API_KEY.

    python -m art.visionary_passages candidates [--only net,lotus] [--models gemini-3-pro-image,gpt-image-2]
    python -m art.visionary_passages seam net:gpt-image-2_a,peacock:gpt-image-2_a
    python -m art.visionary_passages place
    python -m art.visionary_passages relief eyes:experiences/visionary_temple/tiles/eyes.png --models gemini-3-pro-image
    python -m art.visionary_passages bake
    python -m art.visionary_passages sprites
"""
from __future__ import annotations

import argparse
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np
from PIL import Image

from art import imagegen

ROOT = Path(__file__).resolve().parents[1]
TILES = ROOT / 'experiences/visionary_temple/tiles'

STYLE = (
    'A seamless, repeating texture tile for the inner wall of a calm, slow-moving visionary-art tunnel experienced in virtual reality. '
    'Show the painted, sculpted surface flat and straight-on, like a scanned panel: no perspective, no vanishing point, no horizon, '
    'no cast shadows, no vignette, and even brightness from edge to edge. '
    'Style: luminous visionary sacred-geometry painting, ornate, harmonious and serene, with bold readable medium-to-large shapes, '
    'crisp dark outlines, fine gold detailing and saturated jewel colors over a deep dark ground. '
    'Every motif should read as carved bas-relief: clearly raised, rounded forms separated by darker recessed ground. '
    'Avoid fine high-contrast stripes, dense tiny repeats and noisy speckle that would shimmer in a headset. '
    'No text, letters, numbers, logos, signatures, watermarks, borders or frames; no people, faces, hands or creatures. '
    'The tile must wrap perfectly: anything leaving the right edge continues from the left edge and anything leaving the bottom '
    'continues from the top, so copies placed side by side form one continuous surface.'
)

REFERENCE_NOTE = (
    'The attached images are the neighbouring passages of the same tunnel. Match their color richness, outline weight and '
    'ornamental language so this passage clearly belongs to the same journey, but do not copy their motifs or layout.'
)

# Each new passage bridges the procedural passages on either side of it.
PASSAGES = {
    'net': dict(
        title="Indra's Net",
        neighbours=('eyes', 'flames'),
        subject=(
            "Subject: Indra's Net. Glowing golden cords form a regular diamond lattice, exactly two diamonds across and two down "
            'the tile. At every crossing sits a large round faceted jewel in a small gold filigree setting, alternating sapphire '
            'blue, ruby red, emerald green and moonstone white, each with a soft inner sparkle. Inside each diamond, a deep '
            'indigo and midnight-teal cosmic void with soft nebula veils, a few faint stars and one small eight-petaled golden '
            'lotus knot at the diamond center.'
        ),
    ),
    'peacock': dict(
        title='Peacock Vault',
        neighbours=('flames', 'rings'),
        subject=(
            'Subject: a vault of overlapping peacock feathers laid like roof tiles in staggered rows, three feathers across per '
            'row and three rows down the tile, every feather pointing the same way with its rounded tip toward the top. Each '
            'feather carries one large luminous eye-spot of concentric rings: a deep violet-blue center, then turquoise, emerald '
            'and a golden-bronze outer ring, framed by soft golden-green barbs fanning outward. The feathers overlap so that '
            'only slivers of the dark violet ground show between them.'
        ),
    ),
    'lotus': dict(
        title='Lotus Garden',
        neighbours=('rings', 'geode'),
        subject=(
            'Subject: a luminous lotus garden seen from directly above. Large open lotus blossoms with layered pointed petals in '
            'rose pink, coral and pearly white, each around a glowing golden seed-pod center, float among round jade-green lily '
            'pads with fine gold veins, on dark lapis-blue water with faint concentric ripples and tiny golden sparkles. '
            'Arrange three large blossoms per row in three staggered rows, with smaller closed buds between them.'
        ),
    ),
    'geode': dict(
        title='Crystal Geode',
        neighbours=('lotus', 'temple'),
        subject=(
            'Subject: the inside of a crystal geode arranged as a mandala. Two radiant golden sun-cores across and two down, in '
            'a staggered arrangement; from each core, clusters of sharp faceted amethyst and clear quartz crystal points radiate '
            'outward like petals, with citrine and rose-quartz points between them. Thin golden sacred-geometry lines connect '
            'the cores. Deep violet-black mineral ground with a gentle starry sparkle.'
        ),
    ),
}

MODELS = ('gemini-3-pro-image', 'gpt-image-2')

GEMINI_SEAM_PROMPT = (
    'This square texture tile was cut and re-joined, so a thin horizontal seam and a thin vertical seam now cross at the exact '
    'center of the image, where the ornament does not line up. Repair only a narrow cross-shaped band, about one seventh of '
    'the image wide, around those two center lines: redraw the shapes inside it so every jewel, cord, petal, feather, crystal '
    'and background detail flows continuously across the center as whole, natural forms, in exactly the same painting style, '
    'colors, outline weight and carved relief. Everything outside that band must stay exactly as it is, pixel for pixel, with '
    'the same framing and scale. No borders, text or new kinds of objects.'
)

SEAM_PROMPT = (
    'This square texture tile was cut and re-joined, so a thin horizontal seam and a thin vertical seam now cross at its center '
    'where the ornament does not line up. Repaint only the masked cross-shaped band so every shape flows continuously across '
    'it: complete any cut jewels, cords, petals, feathers or crystals as whole, natural forms at the same scale, in exactly '
    'the same painting style, colors, outline weight and carved relief as the rest of the tile. Keep the composition flat and '
    'straight-on, with no borders, text or new kinds of objects.'
)

RELIEF_PROMPT = (
    'Create the matching height map (displacement map) for this ornamental texture so it can be sculpted as 3D bas-relief on '
    'a tunnel wall. Output a grayscale image only: pure black is the deepest recessed ground and white is the highest raised '
    'surface. Preserve the exact composition: every shape at exactly the same position, size and outline as in the input, '
    'same framing, no crop, no zoom, no added or removed elements. Model natural rounded volumes: jewels, eyes and seed pods '
    'as smooth domes; cords, frames and outlines as rounded raised ridges with softly bevelled edges; petals, flames, '
    'feathers and crystals gently curved, with overlapping parts higher than the parts they cover; the open background as '
    'a low, even, dark plane with only very subtle variation. Encode height only: no lighting, shading, shadows, '
    'highlights, color or text.'
)


def reference_image(name: str) -> Image.Image | None:
    path = TILES / f'{name}.png'
    return Image.open(path).convert('RGB') if path.exists() else None


def generate_candidate(passage: str, model: str, use_references: bool, label: str) -> Path:
    spec = PASSAGES[passage]
    prompt = f"{STYLE}\n\n{spec['subject']}"
    references = []
    if use_references:
        references = [image for image in (reference_image(name) for name in spec['neighbours']) if image is not None]
        if references:
            prompt += f'\n\n{REFERENCE_NOTE}'
    if model.startswith('gemini'):
        image = imagegen.gemini(model, prompt, references=references, aspect='1:1', size='2K')
    elif references:
        image = imagegen.openai_edit(model, prompt, references, size='2048x2048', quality='high')
    else:
        image = imagegen.openai_generate(model, prompt, size='2048x2048', quality='high')
    record = dict(passage=passage, title=spec['title'], model=model, prompt=prompt, references=[f'tiles/{n}.png' for n in spec['neighbours']] if references else [])
    return imagegen.save_master(image, f'visionary_temple/candidates/{passage}/{label}', record)


def candidates(args: argparse.Namespace) -> None:
    passages = args.only.split(',') if args.only else list(PASSAGES)
    models = args.models.split(',') if args.models else list(MODELS)
    jobs = []
    for passage in passages:
        for model in models:
            jobs.append((passage, model, args.references, f"{model}{'_ref' if args.references else ''}_{args.tag}"))
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(generate_candidate, *job): job for job in jobs}
        for future in as_completed(futures):
            job = futures[future]
            try:
                print('saved', future.result().relative_to(ROOT), flush=True)
            except Exception as error:  # Report every failure but keep the rest of the batch.
                print('FAILED', job, error, flush=True)


def cross_weight(width: int, height: int, half: int, feather: int) -> np.ndarray:
    """1 on the central seam cross, easing to exactly 0 at the band edges."""
    x = np.abs(np.arange(width) + .5 - width / 2)
    y = np.abs(np.arange(height) + .5 - height / 2)
    wx = np.clip((half - x) / feather, 0.0, 1.0)
    wy = np.clip((half - y) / feather, 0.0, 1.0)
    wx = wx * wx * (3 - 2 * wx)
    wy = wy * wy * (3 - 2 * wy)
    return np.maximum(wx[None, :], wy[:, None])


def integer_shift(reference: np.ndarray, moved: np.ndarray, limit: int = 48) -> tuple[int, int]:
    """Phase correlation of luminance: the small roll that best maps `moved` back onto `reference`.

    Periodic ornament correlates equally well at whole-motif offsets, so only drifts within `limit` pixels count.
    """
    a = reference.mean(axis=-1) - reference.mean()
    b = moved.mean(axis=-1) - moved.mean()
    cross = np.fft.fft2(a) * np.conj(np.fft.fft2(b))
    peak = np.fft.fftshift(np.fft.ifft2(cross / (np.abs(cross) + 1e-9)).real)
    cy, cx = peak.shape[0] // 2, peak.shape[1] // 2
    window = peak[cy - limit:cy + limit + 1, cx - limit:cx + limit + 1]
    dy, dx = np.unravel_index(np.argmax(window), window.shape)
    return int(dy - limit), int(dx - limit)


def seam_ratio(pixels: np.ndarray) -> tuple[float, float]:
    """Wrap-edge difference relative to the typical neighbouring-pixel difference (about 1 when seamless)."""
    a = pixels.astype(float)
    horizontal = np.abs(a[:, 0] - a[:, -1]).mean() / np.abs(a[:, 1:] - a[:, :-1]).mean()
    vertical = np.abs(a[0] - a[-1]).mean() / np.abs(a[1:] - a[:-1]).mean()
    return float(horizontal), float(vertical)


def make_seamless(passage: str, candidate: str, model: str = 'gemini-3-pro-image', half: int = 150, feather: int = 60) -> Path:
    source = imagegen.MASTERS / 'visionary_temple/candidates' / passage / f'{candidate}.png'
    pixels = np.asarray(Image.open(source).convert('RGB'))
    height, width = pixels.shape[:2]
    rolled = np.roll(pixels, (height // 2, width // 2), axis=(0, 1))
    weight = cross_weight(width, height, half, feather)
    mask = np.full((height, width, 4), 255, np.uint8)
    mask[..., 3] = np.where(weight > 0, 0, 255)
    if model.startswith('gemini'):
        # Nano Banana keeps untouched regions aligned, so a feathered band composite does not ghost.
        prompt = GEMINI_SEAM_PROMPT
        edited = imagegen.gemini(model, prompt, references=[Image.fromarray(rolled)], aspect='1:1', size='2K')
    else:
        prompt = SEAM_PROMPT
        edited = imagegen.openai_edit(model, prompt, [Image.fromarray(rolled)], mask=Image.fromarray(mask), size=f'{width}x{height}', quality='high')
    record = dict(passage=passage, source=str(source.relative_to(imagegen.MASTERS)), model=model, prompt=prompt, band_half_width=half, feather=feather)
    imagegen.save_master(edited, f'visionary_temple/seam_edits/{passage}', record)
    repaired = np.asarray(edited.convert('RGB').resize((width, height), Image.LANCZOS)).astype(float)
    # Keep every pixel outside the band from the original; realign the edit if the model drifted.
    outside = weight == 0
    shift = integer_shift(np.where(outside[..., None], rolled, 0).astype(float), np.where(outside[..., None], repaired, 0))
    repaired = np.roll(repaired, shift, axis=(0, 1))
    blended = rolled * (1 - weight[..., None]) + repaired * weight[..., None]
    result = np.roll(np.uint8(np.clip(np.round(blended), 0, 255)), (-(height // 2), -(width // 2)), axis=(0, 1))
    image = Image.fromarray(result)
    drift = float(np.abs(repaired - rolled)[outside].mean())
    record.update(realigned_shift=list(shift), outside_band_drift=drift, seam_ratio_before=seam_ratio(pixels), seam_ratio_after=seam_ratio(result))
    return imagegen.save_master(image, f'visionary_temple/seamless/{passage}', record)


def seam(args: argparse.Namespace) -> None:
    jobs = [item.split(':') for item in args.picks.split(',')]
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(make_seamless, passage, candidate): passage for passage, candidate in jobs}
        for future in as_completed(futures):
            try:
                path = future.result()
                record = json.loads(path.with_suffix('.json').read_text())
                print('seamless', path.relative_to(ROOT), 'drift', round(record['outside_band_drift'], 1), 'seam ratio', [round(v, 2) for v in record['seam_ratio_after']], flush=True)
            except Exception as error:
                print('FAILED', futures[future], error, flush=True)


def relief_request(source: Path, model: str, label: str) -> Path:
    tile = Image.open(source).convert('RGB')
    width, height = tile.size
    record = dict(source=str(source.relative_to(ROOT)), model=model, prompt=RELIEF_PROMPT)
    if model.startswith('gemini'):
        request = tile
        if height == 2 * width:
            # Gemini has no 1:2 canvas; the tile wraps, so extend it to 9:16 and crop the answer back.
            padded = round(height * 9 / 16)
            request = Image.fromarray(np.take(np.asarray(tile), np.arange(padded) % width, axis=1))
            record['wrap_padded_width'] = padded
        aspect = '1:1' if width == height else '9:16'
        image = imagegen.gemini(model, RELIEF_PROMPT, references=[request], aspect=aspect, size='2K')
        if request is not tile:
            image = image.convert('L').resize(request.size, Image.LANCZOS).crop((0, 0, width, height))
    else:
        image = imagegen.openai_edit(model, RELIEF_PROMPT, [tile], size=f'{width}x{height}', quality='high')
    return imagegen.save_master(image, f'visionary_temple/relief/{label}/{model}', record)


def relief(args: argparse.Namespace) -> None:
    jobs = []
    for item in args.sources.split(','):
        label, _, path = item.partition(':')
        for model in args.models.split(','):
            jobs.append((ROOT / path, model, label))
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(relief_request, *job): job for job in jobs}
        for future in as_completed(futures):
            try:
                print('relief', future.result().relative_to(ROOT), flush=True)
            except Exception as error:
                print('FAILED', futures[future], error, flush=True)


def periodic_component(values: np.ndarray) -> np.ndarray:
    """Moisan's periodic-plus-smooth decomposition: removes wrap-edge jumps without touching interior detail."""
    height, width = values.shape
    boundary = np.zeros_like(values)
    boundary[0, :] += values[-1, :] - values[0, :]
    boundary[-1, :] += values[0, :] - values[-1, :]
    boundary[:, 0] += values[:, -1] - values[:, 0]
    boundary[:, -1] += values[:, 0] - values[:, -1]
    q = np.arange(height)[:, None]
    r = np.arange(width)[None, :]
    denominator = 2 * np.cos(2 * np.pi * q / height) + 2 * np.cos(2 * np.pi * r / width) - 4
    denominator[0, 0] = 1.0
    smooth = np.fft.fft2(boundary) / denominator
    smooth[0, 0] = 0.0
    return values - np.fft.ifft2(smooth).real


def relief_texture(height_source: Path, size: tuple[int, int], shift: tuple[int, int], seed: int) -> tuple[np.ndarray, dict]:
    """Height (R), per-texel slopes (G, B) and an equalised erosion order (A) that opens the ground first."""
    from scipy import ndimage

    gray = Image.open(height_source).convert('L').resize(size, Image.LANCZOS)
    h = np.asarray(gray).astype(np.float64) / 255.0
    h = np.roll(h, shift, axis=(0, 1))
    h = periodic_component(h)
    low, high = np.percentile(h, [.5, 99.7])
    h = np.clip((h - low) / max(high - low, 1e-6), 0.0, 1.0)
    h = ndimage.gaussian_filter(h, 1.0, mode='wrap')
    gy, gx = np.gradient(np.pad(h, 1, mode='wrap'))
    gx, gy = gx[1:-1, 1:-1], gy[1:-1, 1:-1]
    # Square-root companding keeps gentle domes smooth while steep bevels up to half a unit per texel still fit.
    slope_range = .5

    def encode(slope: np.ndarray) -> np.ndarray:
        return np.sign(slope) * np.sqrt(np.clip(np.abs(slope) / slope_range, 0.0, 1.0)) * .5 + .5

    # Erosion follows broad relief so holes open as coherent contour-shaped regions, ordered by height,
    # with gentle low-frequency variation breaking up the flat ground.
    rng = np.random.default_rng(seed)
    wander = ndimage.gaussian_filter(rng.standard_normal(h.shape), 10.0, mode='wrap')
    wander /= np.abs(wander).max() + 1e-9
    order = ndimage.gaussian_filter(h, 2.5, mode='wrap') + .06 * wander
    ranks = np.empty(order.size)
    ranks[np.argsort(order, axis=None, kind='stable')] = np.linspace(0.0, 1.0, order.size)
    erosion = ranks.reshape(order.shape)
    channels = np.stack([h, encode(gx), encode(gy), erosion], axis=-1)
    stats = dict(slope_clipped_fraction=float(np.mean((np.abs(gx) > slope_range) | (np.abs(gy) > slope_range))), mean_height=float(h.mean()))
    return np.uint8(np.round(channels * 255)), stats


ORDER = ('eyes', 'net', 'flames', 'peacock', 'rings', 'lotus', 'geode', 'temple')
# Chosen paintings for the AI passages, with the whole-texel roll that centres their ornament on the tunnel facets.
PICKS = {
    'net': dict(candidate='gpt-image-2_a', shift=(0, 0)),
    'peacock': dict(candidate='gpt-image-2_a', shift=(0, 0)),
    'lotus': dict(candidate='gpt-image-2_a', shift=(0, 0)),
    'geode': dict(candidate='gpt-image-2_a', shift=(0, 0)),
}
RELIEF_MODEL = 'gemini-3-pro-image'
SPRITE_MODEL = 'gpt-image-2'
# The sprite sheet holds one sigil per passage in a 4 x 2 grid, in passage order.
SPRITE_CELLS = {'net': 1, 'peacock': 3, 'lotus': 5, 'geode': 6}
SPRITE_SUBJECTS = {
    'net': 'a single round faceted moonstone jewel held in an ornate golden filigree setting with four short cord stubs',
    'peacock': 'a single peacock-feather eye-spot: concentric violet-blue, turquoise, emerald and golden-bronze rings inside soft golden-green barbs',
    'lotus': 'a single open lotus blossom seen from above, layered rose-pink and pearl petals around a glowing golden seed pod',
    'geode': 'a single radiant crystal mandala: amethyst and clear quartz points radiating from a small plain faceted golden citrine core',
}
SPRITE_PROMPT = (
    'One isolated emblem, {subject}, centered on a fully transparent background, used as a floating sigil in a calm '
    'visionary-art VR tunnel. Radially balanced, filling about 85% of the square canvas with a clear margin on every side, '
    'crisp clean silhouette, luminous jewel colors with fine gold detail, flat straight-on view. No faces, figures or '
    'creatures anywhere in it, no text, no drop shadow, no glow halo spilling outside the emblem, no background.'
)
TEXTURE_IMPORT = '''[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border={fix_alpha_border}
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
'''
PROVENANCE = Path(__file__).resolve().parent / 'visionary_passages_provenance.json'


def sidecar(relative: str) -> dict:
    return json.loads((imagegen.MASTERS / f'{relative}.json').read_text())


def sha256(path: Path) -> str:
    import hashlib

    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_import(texture: Path, data_alpha: bool) -> None:
    """Lossless, mipmapped and never auto-compressed; data alpha must not be border-fixed."""
    target = texture.with_name(texture.name + '.import')
    settings = TEXTURE_IMPORT.format(fix_alpha_border='false' if data_alpha else 'true')
    if not target.exists() or '[params]' not in target.read_text():
        target.write_text(settings)
        return
    # Keep Godot's generated uid and paths; replace only the import parameters.
    head = target.read_text().split('[params]')[0]
    target.write_text(head + '[params]' + settings.split('[params]')[1])


def place(args: argparse.Namespace) -> None:
    for passage, pick in PICKS.items():
        pixels = np.asarray(Image.open(imagegen.MASTERS / f'visionary_temple/seamless/{passage}.png').convert('RGB'))
        pixels = np.roll(pixels, pick['shift'], axis=(0, 1))
        target = TILES / f'{passage}.png'
        Image.fromarray(pixels).save(target, optimize=True)
        write_import(target, data_alpha=False)
        print('placed', target.relative_to(ROOT), flush=True)


def bake(args: argparse.Namespace) -> None:
    passages = args.only.split(',') if args.only else list(ORDER)
    for seed, passage in enumerate(ORDER):
        if passage not in passages:
            continue
        tile = Image.open(TILES / f'{passage}.png')
        width, height = tile.size
        # Relief resolution never exceeds 1024 on the short side; slopes stay per texel of this texture.
        scale = min(1.0, 1024 / min(width, height))
        size = (round(width * scale), round(height * scale))
        source = imagegen.MASTERS / f'visionary_temple/relief/{passage}/{RELIEF_MODEL}.png'
        pixels, stats = relief_texture(source, size, (0, 0), seed)
        target = TILES / f'{passage}_relief.png'
        Image.fromarray(pixels, 'RGBA').save(target, optimize=True)
        write_import(target, data_alpha=True)
        print('baked', target.relative_to(ROOT), size, stats, flush=True)
    write_provenance()


def write_provenance() -> None:
    passages = {}
    for passage in ORDER:
        entry = dict(order=ORDER.index(passage) + 1, tile=f'experiences/visionary_temple/tiles/{passage}.png')
        tile = TILES / f'{passage}.png'
        relief = TILES / f'{passage}_relief.png'
        if passage in PICKS:
            painting = sidecar(f"visionary_temple/candidates/{passage}/{PICKS[passage]['candidate']}")
            seam = sidecar(f'visionary_temple/seamless/{passage}')
            entry.update(
                title=PASSAGES[passage]['title'],
                painting=dict(model=painting['model'], prompt=painting['prompt'], master_sha256=painting['sha256'], created=painting['created']),
                seam_repair=dict(model=seam['model'], prompt=seam['prompt'], band_half_width=seam['band_half_width'], feather=seam['feather'], realigned_shift=seam['realigned_shift'], seam_ratio_before=seam['seam_ratio_before'], seam_ratio_after=seam['seam_ratio_after']),
                roll=list(PICKS[passage]['shift']),
            )
        else:
            entry['painting'] = dict(model='procedural', source='tools/bake_visionary_tiles.py')
        relief_path = imagegen.MASTERS / f'visionary_temple/relief/{passage}/{RELIEF_MODEL}.json'
        if relief_path.exists():
            height_map = json.loads(relief_path.read_text())
            entry['relief'] = dict(model=height_map['model'], prompt=height_map['prompt'], master_sha256=height_map['sha256'], created=height_map['created'], processing='periodic-plus-smooth wrap repair, 0.5-99.7 percentile stretch, 1-texel Gaussian, wrapped central-difference slopes square-root companded over +-0.5 per texel, equalised erosion order from 2.5-texel Gaussian height with low-frequency variation')
        if tile.exists():
            entry['tile_sha256'] = sha256(tile)
        if relief.exists():
            entry['relief_sha256'] = sha256(relief)
        passages[passage] = entry
    sprites = {}
    for passage, cell in SPRITE_CELLS.items():
        path = imagegen.MASTERS / f'visionary_temple/sprites/{passage}.json'
        if path.exists():
            sprite = json.loads(path.read_text())
            sprites[passage] = dict(cell=cell, model=sprite['model'], prompt=sprite['prompt'], master_sha256=sprite['sha256'], created=sprite['created'])
    sheet = TILES / 'sigils.png'
    PROVENANCE.write_text(json.dumps(dict(
        experience='visionary_temple',
        note='Untouched API masters stay local under art/masters; this record lists every prompt and model used for the bundled textures.',
        passages=passages,
        sprites=dict(sheet='experiences/visionary_temple/tiles/sigils.png', sheet_sha256=sha256(sheet) if sheet.exists() else None, procedural_cells=[0, 2, 4, 7], generated=sprites),
    ), indent=2) + '\n')
    print('wrote', PROVENANCE.relative_to(ROOT), flush=True)


def sprite_request(passage: str) -> Path:
    prompt = SPRITE_PROMPT.format(subject=SPRITE_SUBJECTS[passage])
    image = imagegen.openai_generate(SPRITE_MODEL, prompt, size='1024x1024', quality='high', background='transparent')
    return imagegen.save_master(image, f'visionary_temple/sprites/{passage}', dict(passage=passage, model=SPRITE_MODEL, prompt=prompt, background='transparent'))


def sprites(args: argparse.Namespace) -> None:
    if not args.compose_only:
        selected = args.only.split(',') if args.only else list(SPRITE_CELLS)
        with ThreadPoolExecutor(max_workers=4) as pool:
            for path in pool.map(sprite_request, selected):
                print('sprite', path.relative_to(ROOT), flush=True)
    sheet_path = TILES / 'sigils.png'
    sheet = Image.open(sheet_path).convert('RGBA')
    if sheet.size != (2048, 1024):
        raise SystemExit('Run tools/bake_visionary_tiles.py sigils first to lay out the 2048 x 1024 sheet.')
    for passage, cell in SPRITE_CELLS.items():
        sprite = Image.open(imagegen.MASTERS / f'visionary_temple/sprites/{passage}.png').convert('RGBA')
        if sprite.getextrema()[3][0] == 255:
            raise SystemExit(f'{passage} sprite has no transparency')
        sprite = sprite.resize((512, 512), Image.LANCZOS)
        box = ((cell % 4) * 512, (cell // 4) * 512)
        sheet.paste((0, 0, 0, 0), box + (box[0] + 512, box[1] + 512))
        sheet.alpha_composite(sprite, box)
    sheet.save(sheet_path, optimize=True)
    print('composed', sheet_path.relative_to(ROOT), flush=True)
    write_provenance()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    generate = commands.add_parser('candidates', help='generate candidate passage paintings')
    generate.add_argument('--only', help='comma-separated passage ids')
    generate.add_argument('--models', help='comma-separated model ids')
    generate.add_argument('--references', action='store_true', help='send the neighbouring passage tiles as style references')
    generate.add_argument('--tag', default='a', help='suffix that keeps repeated candidates apart')
    generate.add_argument('--workers', type=int, default=4)
    generate.set_defaults(run=candidates)
    seams = commands.add_parser('seam', help='repair the wrap seams of chosen candidates')
    seams.add_argument('picks', help='comma-separated passage:candidate pairs, e.g. net:gpt-image-2_a')
    seams.set_defaults(run=seam)
    heights = commands.add_parser('relief', help='ask image models for height maps of painted tiles')
    heights.add_argument('sources', help='comma-separated label:path pairs relative to the project')
    heights.add_argument('--models', default=','.join(MODELS))
    heights.add_argument('--workers', type=int, default=4)
    heights.set_defaults(run=relief)
    placing = commands.add_parser('place', help='write the chosen seamless paintings into the tunnel tiles')
    placing.set_defaults(run=place)
    baking = commands.add_parser('bake', help='bake relief textures from the height-map masters')
    baking.add_argument('--only', help='comma-separated passage ids')
    baking.set_defaults(run=bake)
    sigils = commands.add_parser('sprites', help='generate the four AI sigils and compose the sprite sheet')
    sigils.add_argument('--compose-only', action='store_true', help='reuse existing sprite masters')
    sigils.add_argument('--only', help='comma-separated passage ids to regenerate')
    sigils.set_defaults(run=sprites)
    args = parser.parse_args()
    args.run(args)


if __name__ == '__main__':
    main()
