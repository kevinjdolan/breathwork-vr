"""Bake original visionary ornament tiles and sigil sprites for the Visionary Temple tunnel."""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'experiences/visionary_temple/tiles'
TWO_PI = 2.0 * np.pi


class Canvas:
    """A tileable painting surface in unit coordinates with toroidal distances."""

    def __init__(self, width: int, height: int, wrap_x: bool = True, wrap_y: bool = True):
        self.width, self.height = width, height
        self.wrap_x, self.wrap_y = wrap_x, wrap_y
        y, x = np.mgrid[:height, :width].astype(np.float64)
        self.x = (x + .5) / width
        self.y = (y + .5) / height
        self.aa = 1.2 / max(width, height)
        self.rgb = np.zeros((height, width, 3))
        self.height_map = np.zeros((height, width))
        self.alpha = np.zeros((height, width))

    def delta(self, cx: float, cy: float, sx: float = 1.0, sy: float = 1.0):
        dx = self.x - cx
        dy = self.y - cy
        if self.wrap_x:
            dx = (dx + .5) % 1.0 - .5
        if self.wrap_y:
            dy = (dy + .5) % 1.0 - .5
        return dx / sx, dy / sy

    def fill(self, d: np.ndarray, soft: float = 1.0) -> np.ndarray:
        return np.clip(.5 - d / (self.aa * soft), 0.0, 1.0)

    def stroke(self, d: np.ndarray, width: float, soft: float = 1.0) -> np.ndarray:
        return self.fill(np.abs(d) - width, soft)

    def paint(self, mask: np.ndarray, color, height: float | np.ndarray | None = None) -> None:
        color = np.asarray(color, dtype=np.float64)
        if color.ndim == 1:
            color = color[None, None, :]
        m = mask[..., None]
        self.rgb = self.rgb * (1.0 - m) + color * m
        self.alpha = np.maximum(self.alpha, mask)
        if height is not None:
            self.height_map = self.height_map * (1.0 - mask) + np.asarray(height) * mask

    def glow(self, mask: np.ndarray, color, amount: float = 1.0) -> None:
        color = np.asarray(color, dtype=np.float64)[None, None, :]
        self.rgb = self.rgb + color * mask[..., None] * amount

    def save(self, name: str, store_height: bool = True) -> Path:
        ROOT.mkdir(parents=True, exist_ok=True)
        rgb = np.clip(self.rgb, 0.0, 1.0)
        alpha = .15 + .85 * np.clip(self.height_map, 0.0, 1.0) if store_height else np.clip(self.alpha, 0.0, 1.0)
        image = np.concatenate([rgb, alpha[..., None]], axis=-1)
        path = ROOT / name
        Image.fromarray(np.uint8(np.round(image * 255))).save(path)
        return path


def noise(canvas: Canvas, cells: int, seed: int, octaves: int = 4) -> np.ndarray:
    """Tileable value noise for painterly grain and slow domain warps."""
    rng = np.random.default_rng(seed)
    total = np.zeros((canvas.height, canvas.width))
    amplitude = 1.0
    norm = 0.0
    for octave in range(octaves):
        n = cells * 2 ** octave
        grid = rng.random((n, n))
        px = canvas.x * n
        py = canvas.y * n
        ix = np.floor(px).astype(int)
        iy = np.floor(py).astype(int)
        fx = px - ix
        fy = py - iy
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        a = grid[iy % n, ix % n]
        b = grid[iy % n, (ix + 1) % n]
        c = grid[(iy + 1) % n, ix % n]
        d = grid[(iy + 1) % n, (ix + 1) % n]
        total += amplitude * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
        norm += amplitude
        amplitude *= .5
    return total / norm


def sd_circle(dx, dy, r):
    return np.hypot(dx, dy) - r


def sd_almond(dx, dy, a, b):
    """Intersection of two circles: an eye lid shape with half-width a and half-height b."""
    r = (a * a + b * b) / (2 * b)
    k = r - b
    return np.maximum(np.hypot(dx, dy - k) - r, np.hypot(dx, dy + k) - r)


def sd_polygon(dx, dy, r, sides: int, rotation: float = 0.0):
    angle = np.arctan2(dy, dx) - rotation
    sector = TWO_PI / sides
    folded = np.abs((angle + sector / 2) % sector - sector / 2)
    return np.hypot(dx, dy) * np.cos(folded) - r * np.cos(sector / 2)


def sd_segment(dx, dy, ax, ay, bx, by):
    px, py = dx - ax, dy - ay
    vx, vy = bx - ax, by - ay
    t = np.clip((px * vx + py * vy) / (vx * vx + vy * vy), 0.0, 1.0)
    return np.hypot(px - vx * t, py - vy * t)


def sd_leaf(dx, dy, w, h, sharpness: float = 1.0):
    """A petal/flame outline: base at dy=0, tip at dy=h, with a curved width profile."""
    t = np.clip(dy / h, 0.0, 1.0)
    half = w * .5 * np.sin(np.pi * np.clip(t, 0, 1)) ** (.55 * sharpness) * (1 - .35 * t)
    inside = (dy > 0) & (dy < h)
    d = np.abs(dx) - half
    d = np.where(inside, d, np.maximum(np.abs(dx) - half, np.maximum(-dy, dy - h)))
    return d


def hue(color, k=1.0):
    return np.asarray(color) * k


def draw_eye(canvas: Canvas, cx: float, cy: float, a: float, b: float, iris, lid, sclera=(.93, .90, .99), height: float = 1.0, striation: int = 28, tilt: float = 0.0, scale_y: float = 1.0) -> np.ndarray:
    """Paint a visionary almond eye with a striated iris, gold lids and a raised height."""
    dx, dy = canvas.delta(cx, cy)
    if tilt:
        c, s = np.cos(tilt), np.sin(tilt)
        dx, dy = dx * c - dy * s, dx * s + dy * c
    dy = dy / scale_y
    lid_d = sd_almond(dx, dy, a, b)
    inner = canvas.fill(lid_d + a * .07)
    canvas.paint(canvas.fill(lid_d), np.asarray(lid) * .55, height * .55)
    canvas.paint(inner, np.asarray(sclera) * (1 - .35 * np.clip(np.hypot(dx / a, dy / b), 0, 1) ** 2)[..., None], height)
    r = np.hypot(dx, dy)
    theta = np.arctan2(dy, dx)
    iris_r = b * .92
    iris_mask = canvas.fill(r - iris_r) * inner
    rays = .5 + .5 * np.sin(theta * striation + r / iris_r * 9.0)
    ring = np.clip(r / iris_r, 0, 1)
    iris_color = np.asarray(iris)[None, None, :] * (.55 + .45 * rays)[..., None]
    iris_color = iris_color * (1.15 - .75 * ring ** 3)[..., None]
    iris_color += np.array([.05, .02, .09])[None, None, :] * (1 - ring)[..., None]
    canvas.paint(iris_mask, iris_color, height * 1.15)
    canvas.paint(canvas.stroke(r - iris_r, iris_r * .05) * inner, np.asarray(lid) * .35)
    canvas.paint(canvas.fill(r - iris_r * .40) * inner, (.02, .01, .04), height * 1.05)
    canvas.paint(canvas.fill(np.hypot(dx - iris_r * .25, dy - iris_r * .30) - iris_r * .12) * inner, (1.0, .98, .92))
    lid_rim = canvas.stroke(lid_d, a * .045)
    canvas.paint(lid_rim, lid, height * .8)
    canvas.paint(canvas.stroke(lid_d + a * .09, a * .012) * (dy > 0), np.asarray(lid) * .5 + .3)
    canvas.paint(canvas.stroke(lid_d - a * .06, a * .010), np.asarray(lid) * .35)
    return canvas.fill(lid_d - a * .10)


def draw_target(canvas: Canvas, cx: float, cy: float, r: float, colors, rings: int, height: float = 1.0, wobble: float = 0.0) -> np.ndarray:
    """Concentric painted rings, the visionary 'cellular eye' of kaleidoscope art."""
    dx, dy = canvas.delta(cx, cy)
    theta = np.arctan2(dy, dx)
    d = np.hypot(dx, dy) * (1 + wobble * np.sin(theta * 8))
    outer = canvas.fill(d - r)
    for index in range(rings):
        radius = r * (1 - index / rings)
        mask = canvas.fill(d - radius)
        color = np.asarray(colors[index % len(colors)])
        shade = 1 - .30 * ((d / radius) ** 5) * (index < rings - 1)
        canvas.paint(mask, color[None, None, :] * shade[..., None], height * (.4 + .6 * index / rings))
        canvas.paint(canvas.stroke(d - radius, r * .012), color * .25)
    return outer


def draw_flame(canvas: Canvas, cx: float, cy: float, w: float, h: float, seed: int, direction: float = 1.0, height: float = 1.0, warm=((1.0, .96, .72), (1.0, .68, .12), (.93, .30, .05)), rotation: float = 0.0) -> np.ndarray:
    """A painted flame with three licking tongues and a bright core."""
    dx, dy = canvas.delta(cx, cy)
    if rotation:
        cs, sn = np.cos(rotation), np.sin(rotation)
        dx, dy = dx * cs - dy * sn, dx * sn + dy * cs
    dy = dy * direction
    rng = np.random.default_rng(seed)
    warp = sum(np.sin(dy / h * (5 + 4 * k) + rng.random() * 6.28 + dx / w * (3 + 2 * k)) * w * .05 / (k + 1) for k in range(3))
    d = sd_leaf(dx + warp, dy, w, h * .78, 1.0)
    d = np.minimum(d, sd_leaf(dx + warp * 1.4 - w * .22, dy - h * .08, w * .55, h * .62, 1.5))
    d = np.minimum(d, sd_leaf(dx + warp * 1.4 + w * .24, dy - h * .12, w * .5, h * .70, 1.5))
    d = np.minimum(d, sd_leaf(dx * 1.6 + warp * 2.0, dy - h * .30, w * .45, h * .70, 2.0))
    t = np.clip(dy / h, 0, 1)
    edge = np.clip(-d / (w * .42), 0, 1)
    core = np.clip(edge * 1.5 - t * .8 - .05, 0, 1)
    color = np.asarray(warm[2])[None, None, :] * (1 - edge)[..., None] + np.asarray(warm[1])[None, None, :] * edge[..., None]
    color = color * (1 - core)[..., None] + np.asarray(warm[0])[None, None, :] * core[..., None]
    mask = canvas.fill(d, 1.5)
    canvas.paint(mask, color, height * (.5 + .5 * edge))
    canvas.paint(canvas.stroke(d, w * .016) * (t > .01), np.asarray(warm[2]) * .55)
    return mask


def draw_feather(canvas: Canvas, cx: float, cy: float, w: float, h: float, height: float = 1.0, direction: float = 1.0) -> np.ndarray:
    """A peacock-eye feather: violet plume with a cyan and gold eye spot."""
    dx, dy = canvas.delta(cx, cy)
    dy = dy * direction
    d = sd_leaf(dx, dy, w, h, .9)
    mask = canvas.fill(d, 1.5)
    t = np.clip(dy / h, 0, 1)
    barbs = .5 + .5 * np.sin((np.abs(dx) * 60 / w + dy * 30 / h) * 3.0)
    plume = np.array([.36, .12, .72])[None, None, :] * (.55 + .45 * barbs)[..., None]
    plume += np.array([.10, .26, .95])[None, None, :] * (t * .5)[..., None]
    canvas.paint(mask, plume, height * .5)
    canvas.paint(canvas.stroke(d, w * .02), (.16, .05, .38))
    spot_y = h * .56
    for radius, color in ((.34, (.98, .72, .20)), (.27, (.12, .34, .96)), (.19, (.10, .82, .90)), (.11, (.22, .04, .40)), (.05, (.98, .96, .90))):
        canvas.paint(canvas.fill(np.hypot(dx, (dy - spot_y) * 1.15) - w * radius) * mask, color, height * (.7 + radius))
    return mask


def draw_mushroom(canvas: Canvas, cx: float, cy: float, w: float, h: float, seed: int, height: float = 1.0) -> np.ndarray:
    """A small dotted visionary mushroom with a pale stem."""
    dx, dy = canvas.delta(cx, cy)
    cap = np.maximum(np.hypot(dx / w, (dy - h * .55) / (h * .45)) - 1.0, -(dy - h * .55) / h)
    stem = np.maximum(np.abs(dx) - w * .28, np.maximum(-dy, dy - h * .6))
    stem = stem + (np.abs(dx) - w * .28) * 0
    stem_mask = canvas.fill(stem)
    cap_mask = canvas.fill(cap * min(w, h))
    canvas.paint(stem_mask, (.92, .86, .96), height * .4)
    canvas.paint(canvas.stroke(stem * 1.0, w * .05) * (dy < h * .6), (.62, .40, .78))
    shade = 1 - .45 * np.clip((dy - h * .55) / (h * .45), 0, 1)
    canvas.paint(cap_mask, np.array([.98, .62, .70])[None, None, :] * shade[..., None], height)
    rng = np.random.default_rng(seed)
    for _ in range(9):
        px = (rng.random() - .5) * 1.6 * w
        py = h * .55 + rng.random() * h * .38
        dot = canvas.fill(np.hypot(dx - px, dy - py) - w * .09) * cap_mask
        canvas.paint(dot, (1.0, .97, .94), height * 1.05)
    canvas.paint(canvas.stroke(cap * min(w, h), w * .04), (.55, .18, .45))
    return np.maximum(cap_mask, stem_mask)


def draw_rosette(canvas: Canvas, cx: float, cy: float, r: float, petals: int, colors, height: float = 1.0, rotation: float = 0.0) -> np.ndarray:
    """A many-petalled painted rosette used on temple domes and spandrels."""
    dx, dy = canvas.delta(cx, cy)
    theta = np.arctan2(dy, dx) + rotation
    d = np.hypot(dx, dy)
    outer = canvas.fill(d - r)
    for layer in range(3):
        radius = r * (1 - layer * .28)
        scallop = radius * (1 + .12 * np.cos(theta * petals + layer * np.pi / petals))
        mask = canvas.fill(d - scallop)
        shade = .70 + .30 * np.cos(theta * petals * 2 + layer)
        canvas.paint(mask, np.asarray(colors[layer % len(colors)])[None, None, :] * shade[..., None], height * (.5 + .25 * layer))
        canvas.paint(canvas.stroke(d - scallop, r * .02), np.asarray(colors[(layer + 1) % len(colors)]) * .5)
    canvas.paint(canvas.fill(d - r * .12), colors[-1], height)
    return outer


def lattice(canvas: Canvas, families, width: float, soft: float = 1.0) -> np.ndarray:
    """Tileable straight-line families given as (a, b, count) integer directions."""
    mask = np.zeros((canvas.height, canvas.width))
    for a, b, count, phase in families:
        f = (a * canvas.x + b * canvas.y) * count + phase
        d = np.abs(f % 1.0 - .5) / (count * np.hypot(a, b))
        mask = np.maximum(mask, canvas.stroke(d - .5 / (count * np.hypot(a, b)) * 0 + 0.0, width, soft) * 0 + canvas.fill(d - width, soft))
    return mask


def bake_eyes() -> None:
    """Tile 0: rows of staring almond eyes woven by a golden sacred-geometry lattice."""
    c = Canvas(1024, 1024)
    grain = noise(c, 6, 11)
    cells = noise(c, 24, 12, 2)
    base = np.array([.10, .06, .34])[None, None, :] * (.7 + .5 * grain)[..., None] + np.array([.22, .10, .55])[None, None, :] * (cells ** 2)[..., None]
    c.paint(np.ones((c.height, c.width)), base, .05)
    # Scale texture behind everything, like a painted membrane.
    scales = np.abs(np.sin(c.x * TWO_PI * 18) * np.sin(c.y * TWO_PI * 18 + np.cos(c.x * TWO_PI * 9)))
    c.paint(np.clip((scales - .8) * 5, 0, 1) * .5, (.42, .30, .82), .10)
    gold = (.98, .72, .18)
    lines = lattice(c, [(1, 3, 2, 0.0), (1, -3, 2, 0.0), (3, 1, 2, .25), (3, -1, 2, .25), (0, 1, 8, .5), (1, 0, 6, .5)], .0016)
    c.paint(lines * .85, gold, .35)
    thin = lattice(c, [(1, 1, 6, .5), (1, -1, 6, .5)], .0007)
    c.paint(thin * .55, (.98, .48, .22), .25)
    rows = 4
    for row in range(rows):
        for column in range(3):
            cx = (column + .5 * (row % 2)) / 3
            cy = (row + .5) / rows
            draw_eye(c, cx, cy, .130, .066, (.36, .26, .92), gold, height=.95, striation=26)
            # Smaller sentinel eyes in the gaps hold the second visionary scale.
            gx = cx + 1 / 6
            gy = cy
            draw_eye(c, gx, gy, .046, .026, (.60, .26, .78), (.85, .55, .16), sclera=(.78, .80, .98), height=.55, striation=16)
            for sign in (-1, 1):
                draw_eye(c, cx + sign / 12, cy + 1 / (2 * rows), .032, .017, (.22, .60, .92), (.92, .40, .20), height=.4, striation=12)
    # Ruby and sapphire gems on lattice crossings.
    for i in range(6):
        for j in range(8):
            gx, gy = (i + .5) / 6, (j + .5) / 8
            dx, dy = c.delta(gx, gy)
            gem = c.fill(sd_polygon(dx, dy, .011, 6))
            color = (.95, .18, .22) if (i + j) % 2 else (.18, .48, .98)
            c.paint(gem, color, .75)
            c.paint(c.fill(sd_polygon(dx, dy, .005, 6)), (1.0, .92, .85), .8)
    c.save('eyes.png')


def bake_flames() -> None:
    """Tile 1: flame petals, peacock-eye feathers and dotted mushrooms of a mandala."""
    c = Canvas(1024, 1024)
    grain = noise(c, 5, 21)
    c.paint(np.ones((c.height, c.width)), np.array([.10, .03, .18])[None, None, :] * (.6 + .6 * grain)[..., None], .05)
    swirl = .5 + .5 * np.sin(c.x * TWO_PI * 3 + 3 * np.sin(c.y * TWO_PI * 2) + grain * 6)
    c.paint(swirl ** 3 * .7, (.30, .10, .52), .12)
    for column in range(3):
        cx = (column + .5) / 3
        # Feathers point ahead (toward smaller depth); flames lick back toward the viewer.
        draw_feather(c, cx + 1 / 6, .50, .13, .46, .6, direction=-1.0)
        draw_feather(c, cx, 1.0, .13, .46, .6, direction=-1.0)
        draw_feather(c, cx + 1 / 12, .52, .07, .24, .5, direction=-1.0)
        draw_feather(c, cx - 1 / 12, .52, .07, .24, .5, direction=-1.0)
    for column in range(3):
        cx = (column + .5) / 3
        draw_flame(c, cx, .04, .20, .50, 31 + column, height=.9)
        draw_flame(c, cx + 1 / 6, .54, .20, .50, 41 + column, height=.9)
    for column in range(3):
        cx = (column + .5) / 3
        draw_mushroom(c, cx + 1 / 6 + .085, .06, .038, .11, 51 + column, .8)
        draw_mushroom(c, cx + 1 / 6 - .085, .06, .038, .11, 71 + column, .8)
        draw_mushroom(c, cx + .085, .56, .038, .11, 61 + column, .8)
        draw_mushroom(c, cx - .085, .56, .038, .11, 81 + column, .8)
        draw_eye(c, cx + 1 / 6, .30, .050, .026, (.20, .50, .95), (.98, .62, .14), height=.7, striation=18)
        draw_eye(c, cx, .80, .050, .026, (.20, .50, .95), (.98, .62, .14), height=.7, striation=18)
    c.save('flames.png')


def bake_rings() -> None:
    """Tile 2: nested ring cells, octagonal frames and chevron bands in acid greens."""
    c = Canvas(1024, 1024)
    grain = noise(c, 8, 31)
    c.paint(np.ones((c.height, c.width)), np.array([.03, .06, .02])[None, None, :] * (.5 + grain)[..., None], .05)
    chevron = np.abs(((c.x * 6 + .35 * np.abs((c.y * 12) % 2 - 1)) % 1.0) - .5)
    stripes = c.fill(chevron - .10, 4)
    c.paint(stripes * (.55 + .45 * grain), (.60, .88, .14), .18)
    c.paint(c.fill(np.abs(((c.x * 6 + .35 * np.abs((c.y * 12) % 2 - 1) + .5) % 1.0) - .5) - .05, 4) * .8, (.10, .55, .60), .14)
    palette = [(1.0, .62, .68), (.12, .62, .34), (.98, .36, .60), (.06, .30, .26), (.98, .92, .62), (.20, .86, .90)]
    for column in range(2):
        for row in range(2):
            cx = (column + .5 + .5 * (row % 2)) / 2
            cy = (row + .5) / 2
            dx, dy = c.delta(cx, cy)
            frame = c.stroke(sd_polygon(dx, dy, .215, 8, np.pi / 8), .010)
            c.paint(frame, (.95, .74, .18), .55)
            c.paint(c.stroke(sd_polygon(dx, dy, .235, 8, np.pi / 8), .003), (.50, .22, .62), .3)
            draw_target(c, cx, cy, .19, palette, 9, 1.0, .015)
            for k in range(6):
                angle = k * TWO_PI / 6 + row
                draw_target(c, cx + .30 * np.cos(angle), cy + .30 * np.sin(angle), .062, [(.92, .30, .62), (.20, .84, .48), (.98, .90, .40), (.12, .10, .28)], 5, .7)
            for k in range(4):
                angle = k * TWO_PI / 4 + np.pi / 4 + row
                draw_target(c, cx + .17 * np.cos(angle), cy + .17 * np.sin(angle), .028, [(.98, .84, .82), (.90, .18, .55), (.22, .92, .70)], 3, .9)
    c.save('rings.png')


def bake_temple() -> None:
    """Tile 3: a painted temple arcade seen from inside; rows are angle, columns are depth."""
    c = Canvas(1024, 2048)
    grain = noise(c, 6, 41)
    orange = np.array([.98, .36, .06])
    red = np.array([.86, .16, .08])
    blue = np.array([.10, .22, .92])
    cyan = np.array([.20, .80, .92])
    green = np.array([.22, .86, .38])
    violet = np.array([.30, .06, .48])
    # Angle band layout (v): right wall 0, dome .25, left wall .5, floor .75.
    v = c.y
    floor_band = np.exp(-((v - .75) / .105) ** 6)
    dome_band = np.exp(-((v - .25) / .105) ** 6)
    wall_band = np.clip(1 - floor_band - dome_band, 0, 1)
    c.paint(np.ones((c.height, c.width)), orange[None, None, :] * (.75 + .35 * grain)[..., None], .05)
    # Blue-green floor tiles in a receding diamond lattice.
    tiles = np.abs(((c.x * 8) % 1) - .5) + np.abs(((c.y * 16) % 1) - .5)
    c.paint(floor_band, blue[None, None, :] * (.55 + .45 * grain)[..., None], .0)
    c.paint(floor_band * c.fill(tiles - .40, 3), green * .9, .05)
    c.paint(floor_band * c.fill(np.abs(tiles - .30) - .025, 3), (.04, .10, .36), .0)
    c.paint(floor_band * c.fill(np.abs(tiles - .46) - .02, 3), cyan, .08)
    c.paint(floor_band * c.fill(tiles - .12, 3), (.96, .92, .55), .1)
    # Dome: rosettes and eyes between blue lattice scales.
    scales = np.abs(np.sin(c.x * TWO_PI * 8 + np.cos((c.y - .25) * TWO_PI * 16)) * np.sin((c.y - .25) * TWO_PI * 16))
    c.paint(dome_band * c.fill(.55 - scales, 3), blue * .8, .06)
    c.paint(dome_band * c.fill(.90 - scales, 3), cyan * .9, .08)
    for column in range(2):
        draw_rosette(c, (column + .5) / 2, .25, .09, 12, [(.98, .58, .10), (.92, .20, .10), (.20, .84, .92), (1.0, .92, .60)], .9)
        draw_rosette(c, (column + .5) / 2, .125, .045, 8, [(.98, .58, .10), (.20, .84, .92), (.92, .20, .10)], .7)
        draw_rosette(c, (column + .5) / 2, .375, .045, 8, [(.98, .58, .10), (.20, .84, .92), (.92, .20, .10)], .7)
        draw_eye(c, column / 2, .25, .045, .022, (.12, .40, .95), (.98, .80, .30), height=.8, striation=18)
    # Walls: dark arched openings between fluted columns.
    for wall_center, direction in ((.0, 1), (.5, -1)):
        band = np.exp(-((((v - wall_center) + .5) % 1 - .5) / .155) ** 6)
        for column in range(2):
            cx = (column + .5) / 2
            dx, dy = c.delta(cx, wall_center)
            dy = dy * direction
            arch_body = np.maximum(np.abs(dx) - .135, np.maximum(-dy - .11, dy - .02))
            # A pointed gothic head: two offset circles meeting above the opening.
            arch_top = np.maximum(np.maximum(np.hypot(dx - .075, dy - .02) - .21, np.hypot(dx + .075, dy - .02) - .21), -(dy - .02))
            arch = np.minimum(arch_body, arch_top)
            opening = c.fill(arch * 1.0) * band
            depth_glow = np.clip((dy + .11) / .30, 0, 1)
            interior = violet[None, None, :] * (.55 + .45 * depth_glow)[..., None] + np.array([.02, .04, .18])[None, None, :] * (1 - depth_glow)[..., None]
            c.paint(opening, interior, .0)
            rng = np.random.default_rng(71 + column)
            for _ in range(28):
                sx = (rng.random() - .5) * .25
                sy = -.10 + rng.random() * .28
                star = c.fill(np.hypot(dx - sx, dy - sy) - .0025) * opening
                c.paint(star, (.75, .85, 1.0), .02)
            c.paint(c.stroke(arch, .012) * band, (.98, .70, .16), .55)
            c.paint(c.stroke(arch + .020, .004) * band, red * .8, .3)
            # Fluted columns run across the angle band beside each opening.
            for side in (-1, 1):
                px = cx + side * .215
                pdx, pdy = c.delta(px, wall_center)
                flute = .5 + .5 * np.cos(pdx * TWO_PI * 60)
                shaft = c.fill(np.abs(pdx) - .048) * band
                c.paint(shaft, (orange * (.65 + .35 * flute[..., None] ** 2)), .9 * (.7 + .3 * flute))
                c.paint(c.stroke(np.abs(pdx) - .048, .004) * band, red, .5)
                c.paint(c.fill(np.abs(pdx) - .060) * c.fill(np.abs(np.abs(pdy) - .150) - .012), (.98, .78, .22), 1.0)
            for side in (-1, 1):
                draw_eye(c, cx + side * .105, wall_center + direction * .170, .035, .018, (.10, .40, .95), (.98, .80, .30), height=.7, striation=16)
    c.save('temple.png')


def bake_sigils() -> None:
    """Four transparent sigil sprites: eye, flame lotus, ring cell and temple rosette."""
    c = Canvas(1024, 1024, wrap_x=False, wrap_y=False)
    draw_eye(c, .25, .25, .19, .10, (.36, .26, .92), (.98, .72, .18), height=1.0, striation=30)
    for k in range(10):
        angle = k * TWO_PI / 10
        draw_flame(c, .75 + .075 * np.cos(angle), .25 + .075 * np.sin(angle), .085, .155, 100 + k, height=.8, rotation=-(angle - np.pi / 2))
    # Rotate flames outward by drawing the lotus as a ring of leaves using local rotation.
    dx, dy = c.delta(.75, .25)
    theta = np.arctan2(dy, dx)
    r = np.hypot(dx, dy)
    petals = .5 + .5 * np.cos(theta * 10)
    lotus = c.fill(r - (.09 + .10 * petals ** 1.5), 2)
    c.paint(lotus, np.array([.98, .62, .10])[None, None, :] * (.7 + .3 * petals)[..., None], .8)
    c.paint(c.fill(r - (.05 + .05 * petals ** 2), 2), (1.0, .93, .70), .9)
    c.paint(c.stroke(r - (.09 + .10 * petals ** 1.5), .004, 2), (.60, .12, .30), .9)
    draw_target(c, .25, .75, .19, [(.98, .66, .72), (.16, .58, .30), (.94, .40, .58), (.08, .32, .28), (.86, .86, .58)], 9, 1.0, .02)
    draw_rosette(c, .75, .75, .21, 12, [(.98, .58, .10), (.92, .20, .10), (.20, .84, .92), (1.0, .92, .60)], 1.0)
    c.save('sigils.png', store_height=False)


def main() -> None:
    import sys
    bakers = dict(eyes=bake_eyes, flames=bake_flames, rings=bake_rings, temple=bake_temple, sigils=bake_sigils)
    selected = sys.argv[1:] or list(bakers)
    for name in selected:
        bakers[name]()
        print('Baked', name, flush=True)
    print('Baked visionary tiles into', ROOT)


if __name__ == '__main__':
    main()
