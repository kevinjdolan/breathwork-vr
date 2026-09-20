extends RefCounted
## Visionary Temple relics: modelled 3D ornaments that tumble along varied paths through the tunnel.
## Every passage has its own pool whose members reach the viewer during that passage. Motion here
## mirrors relic.gdshader exactly so an inhale can lock its plasma onto a moving relic.

const PASSAGE: float = 60.0
const PASSAGES: int = 8
const PER_PASSAGE: int = 48
const COUNT: int = PASSAGES * PER_PASSAGE
const SPEED: float = 0.55
const CONTRACTION: float = 0.35
## Relics stay inside this radius (scaled by the breath) so they never meet the displaced tunnel walls.
const SHELL: float = 3.4
const MIN_NEAR_RADIUS: float = 1.05
const MIN_FAR_RADIUS: float = 1.3

## Matcap atlas cells, in art/visionary_relics.py MATERIALS order.
enum Mat { GOLD, ROSE_GOLD, PEARL, RUBY, SAPPHIRE, EMERALD, AMETHYST, CITRINE, MOONSTONE, OPAL, JADE, TURQUOISE, LAPIS, OBSIDIAN, ROSE_QUARTZ, CRYSTAL }

## Surface parts are stored in vertex alpha and chosen in the shader.
const PART_PRIMARY: float = 1.0
const PART_SECONDARY: float = .5
const PART_SPRITE: float = .25
const PART_GLOW: float = 0.0

## Each type belongs to one passage. Weight sets its share of the pool; sprite is a sigil-sheet cell or -1,
## and a cutout type discards its sprite-painted surface wherever the painting is transparent.
const TYPES: Array[Dictionary] = [
    {"name": "eye_orb", "passage": 0, "weight": 3, "scale": 1.0, "primary": [Mat.PEARL, Mat.MOONSTONE], "secondary": [Mat.GOLD], "sprite": 0},
    {"name": "brilliant_gem", "passage": 0, "weight": 2, "scale": .8, "primary": [Mat.RUBY, Mat.SAPPHIRE], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "icosa_lattice", "passage": 0, "weight": 2, "scale": 1.15, "primary": [Mat.GOLD], "secondary": [Mat.RUBY, Mat.SAPPHIRE], "sprite": -1},
    {"name": "jewel_setting", "passage": 1, "weight": 3, "scale": 1.0, "primary": [Mat.MOONSTONE, Mat.OPAL, Mat.EMERALD, Mat.RUBY], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "pearl_cluster", "passage": 1, "weight": 2, "scale": .9, "primary": [Mat.PEARL, Mat.MOONSTONE], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "torus_knot", "passage": 1, "weight": 2, "scale": 1.05, "primary": [Mat.GOLD, Mat.ROSE_GOLD], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "flame_drop", "passage": 2, "weight": 3, "scale": 1.0, "primary": [Mat.CITRINE, Mat.RUBY], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "mushroom", "passage": 2, "weight": 2, "scale": .95, "primary": [Mat.ROSE_QUARTZ, Mat.OPAL], "secondary": [Mat.PEARL], "sprite": -1},
    {"name": "flame_lotus", "passage": 2, "weight": 2, "scale": 1.1, "primary": [Mat.CITRINE, Mat.ROSE_GOLD], "secondary": [Mat.RUBY], "sprite": -1},
    {"name": "peacock_feather", "passage": 3, "weight": 3, "scale": 1.25, "primary": [Mat.TURQUOISE], "secondary": [Mat.GOLD], "sprite": 3, "cutout": true},
    {"name": "opal_egg", "passage": 3, "weight": 2, "scale": .9, "primary": [Mat.OPAL, Mat.MOONSTONE, Mat.OBSIDIAN], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "teardrop_gem", "passage": 3, "weight": 2, "scale": .8, "primary": [Mat.TURQUOISE, Mat.EMERALD, Mat.SAPPHIRE], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "armillary", "passage": 4, "weight": 3, "scale": 1.15, "primary": [Mat.GOLD, Mat.ROSE_GOLD], "secondary": [Mat.JADE, Mat.TURQUOISE], "sprite": -1},
    {"name": "ring_medallion", "passage": 4, "weight": 2, "scale": 1.0, "primary": [Mat.GOLD], "secondary": [Mat.GOLD], "sprite": 4},
    {"name": "nested_tori", "passage": 4, "weight": 2, "scale": 1.0, "primary": [Mat.JADE, Mat.ROSE_QUARTZ, Mat.TURQUOISE], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "lotus_flower", "passage": 5, "weight": 3, "scale": 1.2, "primary": [Mat.ROSE_QUARTZ, Mat.PEARL], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "lotus_bud", "passage": 5, "weight": 2, "scale": .95, "primary": [Mat.ROSE_QUARTZ], "secondary": [Mat.JADE], "sprite": -1},
    {"name": "seed_pod", "passage": 5, "weight": 2, "scale": .85, "primary": [Mat.JADE, Mat.GOLD], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "crystal_cluster", "passage": 6, "weight": 3, "scale": 1.15, "primary": [Mat.AMETHYST, Mat.CRYSTAL, Mat.ROSE_QUARTZ], "secondary": [Mat.OBSIDIAN], "sprite": -1},
    {"name": "quartz_point", "passage": 6, "weight": 2, "scale": 1.0, "primary": [Mat.CRYSTAL, Mat.AMETHYST, Mat.CITRINE], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "step_cut_gem", "passage": 6, "weight": 2, "scale": .8, "primary": [Mat.CITRINE, Mat.AMETHYST], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "merkaba", "passage": 7, "weight": 2, "scale": 1.1, "primary": [Mat.LAPIS, Mat.GOLD], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "temple_bell", "passage": 7, "weight": 2, "scale": 1.0, "primary": [Mat.GOLD, Mat.ROSE_GOLD], "secondary": [Mat.GOLD], "sprite": -1},
    {"name": "stupa", "passage": 7, "weight": 2, "scale": 1.1, "primary": [Mat.GOLD], "secondary": [Mat.TURQUOISE, Mat.LAPIS], "sprite": -1},
    {"name": "rosette_medallion", "passage": 7, "weight": 2, "scale": 1.0, "primary": [Mat.GOLD], "secondary": [Mat.GOLD], "sprite": 7},
]

# --- Deterministic per-relic parameters (float hashes are identical on CPU and GPU to well below a millimetre).

static func h(g: float, a: float) -> float:
    return fposmod(g * a, 1.0)

static func travel_at(time: float) -> float:
    if time < 0.0:
        return SPEED * time
    return SPEED * (time - 5.0 * (1.0 - exp(-time / 5.0)))

static func arrival_time(g: int) -> float:
    var passage: int = g / PER_PASSAGE
    var slot: int = g % PER_PASSAGE
    return PASSAGE * float(passage) - 15.0 + (float(slot) + .5 + .8 * (h(g, .6180339) - .5)) * PASSAGE / float(PER_PASSAGE)

static func type_of(g: int) -> int:
    var passage: int = g / PER_PASSAGE
    var total: float = 0.0
    for type: Dictionary in TYPES:
        if int(type["passage"]) == passage:
            total += float(type["weight"])
    var pick: float = h(g, .0901699) * total
    var last: int = -1
    for index: int in range(TYPES.size()):
        if int(TYPES[index]["passage"]) != passage:
            continue
        last = index
        pick -= float(TYPES[index]["weight"])
        if pick < 0.0:
            return index
    return last

static func materials_of(g: int) -> Vector2:
    var type: Dictionary = TYPES[type_of(g)]
    var primary: Array = type["primary"]
    var secondary: Array = type["secondary"]
    return Vector2(primary[int(h(g, .8541020) * primary.size())], secondary[int(h(g, .6457513) * secondary.size())])

## Along-tunnel motion: 0 approaches with the travel, 1 lingers ahead, 2 overtakes from behind and recedes.
static func z_kind(g: int) -> int:
    var kind: float = h(g, .7548777)
    return 2 if kind < .12 else (1 if kind < .24 else 0)

static func envelope(g: int, time: float) -> float:
    var dt: float = time - arrival_time(g)
    match z_kind(g):
        1:
            return smoothstep(-75.0, -68.0, dt)
        2:
            return smoothstep(-20.0, -12.0, dt) * (1.0 - smoothstep(55.0, 65.0, dt))
    return 1.0

static func depth_of(g: int, time: float) -> float:
    var arrival: float = arrival_time(g)
    var speed: float
    match z_kind(g):
        1:
            speed = -(.40 + .04 * h(g, .5698403))
        2:
            speed = -(.95 + .10 * h(g, .5698403))
        _:
            speed = -.06 + .24 * h(g, .5698403)
    var surge: float = .4 + h(g, .4385790)
    var rate: float = .12 + .18 * h(g, .3247179)
    var phase: float = h(g, .8793852) * TAU
    return travel_at(time) - travel_at(arrival) + speed * (time - arrival) + surge * (sin(rate * time + phase) - sin(rate * arrival + phase))

static func near_lane(g: int) -> bool:
    return h(g, .2451223) <= .27

static func size_of(g: int, fill: float) -> float:
    var w: float = h(g, .1673097)
    var size: float = (.26 + w * .12) if near_lane(g) else (.6 + w * .55)
    return size * float(TYPES[type_of(g)]["scale"]) * (1.0 - fill * CONTRACTION)

static func object_extent(g: int, fill: float) -> float:
    return size_of(g, fill) * .6

static func object_center(g: int, time: float, fill: float) -> Vector3:
    var depth: float = depth_of(g, time)
    var squeeze: float = 1.0 - fill * CONTRACTION
    var theta: float = h(g, .9212563) * TAU
    var lane: float = h(g, .6823278)
    var r0: float = (1.15 + .35 * lane) if near_lane(g) else (1.4 + .8 * lane)
    var omega: float = (.04 + .16 * h(g, .1319764)) * (-1.0 if h(g, .3819660) < .5 else 1.0)
    var phase_a: float = h(g, .5436890) * TAU
    var phase_b: float = h(g, .7071068) * TAU
    var wave: float = h(g, .2360680)
    var xy: Vector2
    match int(h(g, .4142136) * 6.0):
        0:
            # Orbit around the tunnel axis.
            xy = r0 * Vector2(cos(theta + omega * time), sin(theta + omega * time))
        1:
            # A breathing spiral.
            var r: float = r0 + .45 * sin(.21 * time + phase_a)
            xy = r * Vector2(cos(theta + omega * time), sin(theta + omega * time))
        2:
            # A figure of eight around a resting point.
            var rate: float = .10 + .08 * wave
            xy = r0 * Vector2(cos(theta), sin(theta)) + Vector2(.75 * sin(rate * time + phase_a), .55 * sin(2.0 * rate * time + phase_b))
        3:
            # A chord across the tunnel that keeps clear of the central sightline.
            var normal: Vector2 = Vector2(cos(theta), sin(theta))
            var across: Vector2 = Vector2(-normal.y, normal.x)
            xy = (1.05 + .45 * lane) * normal + 1.4 * sin((.06 + .07 * wave) * time + phase_a) * across
        4:
            # Rising and falling while slowly circling.
            var angle: float = theta + .35 * omega * time
            xy = r0 * Vector2(cos(angle), sin(angle)) + Vector2(0.0, .8 * sin(.15 * time + phase_a))
        _:
            # A meander.
            var angle: float = theta + .7 * sin(.07 * time + phase_a) + .35 * sin(.19 * time + phase_b)
            xy = (r0 + .35 * sin(.11 * time + phase_b)) * Vector2(cos(angle), sin(angle))
    xy *= squeeze
    var size: float = size_of(g, fill)
    var lowest: float = maxf(MIN_NEAR_RADIUS if near_lane(g) else MIN_FAR_RADIUS, absf(depth) * .035 + size * .6)
    var highest: float = SHELL * squeeze - size * .6 - .16
    var radius: float = xy.length()
    xy *= minf(maxf(radius, lowest), highest) / maxf(radius, .0001)
    return Vector3(xy.x, xy.y, depth)

## A conservative interval outside which the relic is certainly invisible.
static func window(g: int) -> Vector2:
    var arrival: float = arrival_time(g)
    # The surge can shift a relic up to 2.8 m along the tunnel, so each end keeps a margin for it.
    match z_kind(g):
        1:
            return Vector2(arrival - 76.0, arrival + 95.0)
        2:
            return Vector2(arrival - 21.0, arrival + 66.0)
    var speed: float = -.06 + .24 * h(g, .5698403)
    return Vector2(arrival - 44.0 / (SPEED + speed) - 20.0, arrival + 30.0)

static func visible_at(g: int, time: float) -> bool:
    if envelope(g, time) < .5:
        return false
    var depth: float = depth_of(g, time)
    return depth > -38.0 and depth < 3.0

## How far a relic has grown in: zero before it emerges from the far glow or after it passes behind the viewer.
static func growth(g: int, time: float) -> float:
    var depth: float = depth_of(g, time)
    return envelope(g, time) * smoothstep(-44.0, -34.0, depth) * (1.0 - smoothstep(4.0, 7.0, depth))

# --- Meshes. All shapes are modelled around the origin at roughly unit size with outward normals.

static func build_mesh(type_name: String) -> ArrayMesh:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    match type_name:
        "eye_orb":
            _sphere(st, Vector3.ZERO, .45, 12, 18, Color(1, 1, 1, PART_SPRITE), true)
            _torus(st, Vector3(0, 0, .26), Basis.IDENTITY, .33, .035, 24, 5, Color(1, 1, 1, PART_SECONDARY))
        "brilliant_gem":
            _brilliant(st, 1.0, Color(1, 1, 1, PART_PRIMARY))
        "icosa_lattice":
            var points: Array[Vector3] = _icosahedron(.5)
            for a: int in range(points.size()):
                for b: int in range(a + 1, points.size()):
                    if absf(points[a].distance_to(points[b]) - .5257) < .02:
                        _tube(st, [points[a], points[b]], .03, 6, false, Color(1, 1, 1, PART_PRIMARY))
                _sphere(st, points[a], .075, 4, 6, Color(1, 1, 1, PART_SECONDARY))
        "jewel_setting":
            _brilliant(st, .8, Color(1, 1, 1, PART_PRIMARY))
            _torus(st, Vector3.ZERO, Basis(Vector3.RIGHT, PI / 2), .42, .045, 32, 6, Color(1, 1, 1, PART_SECONDARY))
            for prong: int in range(4):
                var angle: float = TAU * prong / 4.0 + PI / 4
                _tube(st, [Vector3(cos(angle) * .42, -.05, sin(angle) * .42), Vector3(cos(angle) * .3, .22, sin(angle) * .3)], .025, 5, false, Color(1, 1, 1, PART_SECONDARY))
        "pearl_cluster":
            for p: Vector3 in [Vector3(0, .18, 0), Vector3(.24, -.08, .1), Vector3(-.2, -.1, .16), Vector3(.02, -.06, -.26)]:
                _sphere(st, p, .22 + .04 * p.y, 7, 12, Color(1, 1, 1, PART_PRIMARY))
            _torus(st, Vector3(0, -.02, 0), Basis(Vector3.RIGHT, PI / 2), .25, .02, 24, 5, Color(1, 1, 1, PART_SECONDARY))
        "torus_knot":
            var knot: Array[Vector3] = []
            for step: int in range(72):
                var phi: float = TAU * step / 72.0
                var ring: float = .34 + .15 * cos(3.0 * phi)
                knot.append(Vector3(ring * cos(2.0 * phi), .15 * sin(3.0 * phi), ring * sin(2.0 * phi)))
            _tube(st, knot, .065, 7, true, Color(1, 1, 1, PART_PRIMARY))
        "flame_drop":
            _flame(st)
        "mushroom":
            _lathe(st, [Vector2(0, .36), Vector2(.2, .33), Vector2(.36, .24), Vector2(.46, .1), Vector2(.44, .05), Vector2(.3, .06), Vector2(.1, .04)], 24, Color(1, 1, 1, PART_PRIMARY))
            _lathe(st, [Vector2(.1, .04), Vector2(.09, -.12), Vector2(.12, -.3), Vector2(.14, -.4), Vector2(0, -.42)], 14, Color(1, .96, .9, PART_SECONDARY))
            for dot: int in range(7):
                var angle: float = TAU * dot / 7.0 + .4
                var tilt: float = .45 + .25 * float(dot % 2)
                _sphere(st, Vector3(cos(angle) * sin(tilt) * .4, .08 + cos(tilt) * .27, sin(angle) * sin(tilt) * .4), .045, 4, 6, Color(1, 1, 1, PART_SECONDARY))
        "flame_lotus":
            for petal: int in range(10):
                var angle: float = TAU * petal / 10.0
                _petal(st, Vector3(0, -.05, 0), Vector3(cos(angle), .45, sin(angle)).normalized(), .56, .26, .22, .12, Color(1.0, .75 + .05 * float(petal % 2), .5, PART_PRIMARY))
            for petal: int in range(7):
                var angle: float = TAU * (petal + .5) / 7.0
                _petal(st, Vector3(0, -.02, 0), Vector3(cos(angle) * .45, 1.0, sin(angle) * .45).normalized(), .4, .18, .12, .08, Color(1.0, .9, .6, PART_PRIMARY))
            _sphere(st, Vector3(0, .02, 0), .14, 7, 12, Color(1, .8, .4, PART_GLOW))
        "peacock_feather":
            _feather(st)
        "opal_egg":
            var egg: Array[Vector2] = []
            for step: int in range(13):
                var y: float = lerpf(-.46, .56, float(step) / 12.0)
                var t: float = (y - .04) / .51
                egg.append(Vector2(.4 * sqrt(maxf(0.0, 1.0 - t * t)) * (1.0 - .16 * t), y))
            egg[0].x = 0.0
            egg[12].x = 0.0
            egg.reverse()
            _lathe(st, egg, 20, Color(1, 1, 1, PART_PRIMARY))
            _torus(st, Vector3(0, -.08, 0), Basis(Vector3.RIGHT, PI / 2), .41, .025, 30, 5, Color(1, 1, 1, PART_SECONDARY))
        "teardrop_gem":
            _lathe(st, [Vector2(0, .56), Vector2(.14, .34), Vector2(.26, .12), Vector2(.3, -.08), Vector2(.22, -.3), Vector2(0, -.46)], 8, Color(1, 1, 1, PART_PRIMARY), 0.0, true)
        "armillary":
            _torus(st, Vector3.ZERO, Basis.IDENTITY, .5, .03, 32, 5, Color(1, 1, 1, PART_PRIMARY))
            _torus(st, Vector3.ZERO, Basis(Vector3.UP, PI / 2), .44, .03, 30, 5, Color(1, 1, 1, PART_PRIMARY))
            _torus(st, Vector3.ZERO, Basis(Vector3.RIGHT, PI / 2) * Basis(Vector3.FORWARD, .5), .38, .03, 28, 5, Color(1, 1, 1, PART_PRIMARY))
            _sphere(st, Vector3.ZERO, .16, 7, 10, Color(1, 1, 1, PART_SECONDARY))
        "ring_medallion":
            _coin(st, .5, .07, 40)
        "nested_tori":
            for ring: int in range(3):
                _torus(st, Vector3(0, 0, .03 * (ring - 1)), Basis(Vector3.UP, .25 * ring), .5 - .14 * ring, .055, 32 - 6 * ring, 6, Color(1.0 - .1 * ring, 1, 1.0 - .05 * ring, PART_PRIMARY))
            _sphere(st, Vector3.ZERO, .09, 6, 10, Color(1, 1, 1, PART_SECONDARY))
        "lotus_flower":
            for layer: Array in [[8, 18.0, .56, .3, 0.0], [8, 42.0, .48, .28, 22.5], [6, 68.0, .38, .24, 0.0]]:
                for petal: int in range(int(layer[0])):
                    var angle: float = deg_to_rad(float(layer[4]) + 360.0 * petal / float(layer[0]))
                    var lift: float = deg_to_rad(float(layer[1]))
                    var shade: float = .9 + .1 * float(layer[1]) / 70.0
                    _petal(st, Vector3(0, -.06, 0), Vector3(cos(angle) * cos(lift), sin(lift), sin(angle) * cos(lift)), float(layer[2]), float(layer[3]), .14, .12, Color(1, shade, shade, PART_PRIMARY))
            _lathe(st, [Vector2(0, .06), Vector2(.11, .06), Vector2(.12, .0), Vector2(.07, -.1), Vector2(0, -.1)], 14, Color(1, 1, 1, PART_SECONDARY))
        "lotus_bud":
            for petal: int in range(6):
                var angle: float = TAU * petal / 6.0
                _petal(st, Vector3(0, -.3, 0), Vector3(cos(angle) * .22, 1.0, sin(angle) * .22).normalized(), .66, .2, .12, .09, Color(1, .92 + .04 * float(petal % 2), .95, PART_PRIMARY))
            _tube(st, [Vector3(0, -.3, 0), Vector3(.03, -.5, .02)], .04, 6, false, Color(1, 1, 1, PART_SECONDARY))
        "seed_pod":
            _lathe(st, [Vector2(0, .22), Vector2(.36, .22), Vector2(.38, .18), Vector2(.3, -.05), Vector2(.14, -.3), Vector2(0, -.36)], 22, Color(1, 1, 1, PART_PRIMARY))
            for seed: int in range(7):
                var at: Vector3 = Vector3.ZERO if seed == 0 else Vector3(cos(TAU * seed / 6.0) * .2, 0, sin(TAU * seed / 6.0) * .2)
                _sphere(st, at + Vector3(0, .23, 0), .06, 4, 8, Color(1, 1, 1, PART_SECONDARY))
        "crystal_cluster":
            var directions: Array[Vector3] = [Vector3(0, 1, 0), Vector3(.5, .8, .1), Vector3(-.4, .85, .3), Vector3(.1, .75, -.6), Vector3(-.55, .6, -.35), Vector3(.6, .55, .5), Vector3(-.1, .7, .7)]
            for index: int in range(directions.size()):
                var length: float = .62 - .06 * index
                _prism(st, Vector3(0, -.32, 0), directions[index].normalized(), .09 - .006 * index, length, .16, 6, true, Color(1, 1, 1, PART_PRIMARY))
            _sphere(st, Vector3(0, -.34, 0), .18, 5, 8, Color(1, 1, 1, PART_SECONDARY), false, true)
        "quartz_point":
            _prism(st, Vector3(0, -.28, 0), Vector3.UP, .15, .56, .2, 6, false, Color(1, 1, 1, PART_PRIMARY))
            _prism(st, Vector3(0, -.28, 0), Vector3.DOWN, .15, .01, .2, 6, true, Color(1, 1, 1, PART_PRIMARY))
        "step_cut_gem":
            _step_cut(st)
        "merkaba":
            _merkaba(st)
        "temple_bell":
            _lathe(st, [Vector2(0, .58), Vector2(.06, .57), Vector2(.07, .5), Vector2(.05, .46), Vector2(.2, .44), Vector2(.28, .36), Vector2(.3, .2), Vector2(.31, 0), Vector2(.36, -.2), Vector2(.46, -.34), Vector2(.52, -.4), Vector2(.48, -.43), Vector2(.38, -.38), Vector2(.28, -.2), Vector2(.24, .1), Vector2(0, .3)], 26, Color(1, 1, 1, PART_PRIMARY))
            _sphere(st, Vector3(0, -.32, 0), .07, 5, 8, Color(1, 1, 1, PART_SECONDARY))
        "stupa":
            _lathe(st, [Vector2(.36, -.3), Vector2(.36, -.34), Vector2(.43, -.34), Vector2(.43, -.42), Vector2(.52, -.42), Vector2(.52, -.5), Vector2(0, -.5)], 24, Color(1, 1, 1, PART_SECONDARY), 0.0, true)
            var dome: Array[Vector2] = []
            for step: int in range(8, -1, -1):
                var angle: float = PI / 2 * float(step) / 8.0
                dome.append(Vector2(.36 * cos(angle), -.3 + .36 * sin(angle)))
            _lathe(st, dome, 24, Color(1, 1, 1, PART_PRIMARY))
            _lathe(st, [Vector2(0, .5), Vector2(.025, .4), Vector2(.05, .34), Vector2(.04, .32), Vector2(.062, .28), Vector2(.05, .26), Vector2(.075, .22), Vector2(.06, .2), Vector2(.08, .16), Vector2(.1, .13), Vector2(.1, .06), Vector2(0, .06)], 16, Color(1, 1, 1, PART_PRIMARY), 0.0, true)
        "rosette_medallion":
            _coin(st, .5, .07, 40)
        _:
            push_error("Unknown relic type " + type_name)
    st.index()
    return st.commit()

static func _add(st: SurfaceTool, point: Vector3, normal: Vector3, color: Color, uv: Vector2 = Vector2(-1, -1)) -> void:
    st.set_color(color)
    st.set_normal(normal)
    st.set_uv(uv)
    st.add_vertex(point)

static func _flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, inside: Vector3) -> void:
    var normal: Vector3 = (b - a).cross(c - a).normalized()
    if normal.dot((a + b + c) / 3.0 - inside) < 0.0:
        normal = -normal
    for point: Vector3 in [a, b, c]:
        _add(st, point, normal, color)

static func _sphere(st: SurfaceTool, center: Vector3, radius: float, rings: int, segments: int, color: Color, eye_uv: bool = false, lower_half: bool = false) -> void:
    for ring: int in range(rings / 2 if lower_half else 0, rings):
        for segment: int in range(segments):
            var corners: Array[Vector3] = []
            for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
                var polar: float = PI * float(ring + offset.y) / float(rings)
                var azimuth: float = TAU * float(segment + offset.x) / float(segments)
                corners.append(Vector3(sin(polar) * cos(azimuth), cos(polar), sin(polar) * sin(azimuth)))
            for index: int in [0, 1, 2, 0, 2, 3]:
                var direction: Vector3 = corners[index]
                # The eye looks along +Z: its front hemisphere carries the sprite as a planar projection.
                var uv: Vector2 = Vector2(direction.x * .5 + .5, .5 - direction.y * .5) if eye_uv and direction.z > -.05 else Vector2(-1, -1)
                _add(st, center + direction * radius, direction, color, uv)

static func _torus(st: SurfaceTool, center: Vector3, basis: Basis, major: float, minor: float, segments: int, sides: int, color: Color) -> void:
    for segment: int in range(segments):
        for side: int in range(sides):
            var points: Array[Vector3] = []
            var normals: Array[Vector3] = []
            for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
                var u: float = TAU * float(segment + offset.x) / float(segments)
                var v: float = TAU * float(side + offset.y) / float(sides)
                var radial: Vector3 = Vector3(cos(u), sin(u), 0.0)
                var normal: Vector3 = radial * cos(v) + Vector3(0, 0, sin(v))
                points.append(center + basis * (radial * major + normal * minor))
                normals.append((basis * normal).normalized())
            for index: int in [0, 1, 2, 0, 2, 3]:
                _add(st, points[index], normals[index], color)

static func _tube(st: SurfaceTool, path: Array, radius: float, sides: int, closed: bool, color: Color) -> void:
    var count: int = path.size()
    var frames: Array = []
    var reference: Vector3 = Vector3.UP
    for index: int in range(count):
        var ahead: Vector3 = path[(index + 1) % count] if closed or index < count - 1 else path[index]
        var behind: Vector3 = path[(index - 1 + count) % count] if closed or index > 0 else path[index]
        var tangent: Vector3 = (ahead - behind).normalized()
        if absf(tangent.dot(reference)) > .95:
            reference = Vector3.RIGHT
        var normal: Vector3 = tangent.cross(reference).normalized()
        reference = normal.cross(tangent).normalized()
        frames.append([normal, tangent.cross(normal).normalized()])
    var spans: int = count if closed else count - 1
    for index: int in range(spans):
        var next: int = (index + 1) % count
        for side: int in range(sides):
            var corners: Array[Vector3] = []
            var normals: Array[Vector3] = []
            for pick: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
                var ring: int = index if pick.x == 0 else next
                var angle: float = TAU * float(side + pick.y) / float(sides)
                var normal: Vector3 = frames[ring][0] * cos(angle) + frames[ring][1] * sin(angle)
                corners.append(path[ring] + normal * radius)
                normals.append(normal)
            for pick: int in [0, 1, 2, 0, 2, 3]:
                _add(st, corners[pick], normals[pick], color)

static func _lathe(st: SurfaceTool, profile: Array, segments: int, color: Color, twist: float = 0.0, faceted: bool = false) -> void:
    ## Revolves (radius, height) points around +Y. Profiles run from the top down along the outside surface,
    ## so the outward normal is always the slope turned toward +radius. Faceted lathes use flat normals.
    for index: int in range(profile.size() - 1):
        var a: Vector2 = profile[index]
        var b: Vector2 = profile[index + 1]
        var slope: Vector2 = (b - a).normalized()
        var outward: Vector2 = Vector2(-slope.y, slope.x)
        for segment: int in range(segments):
            var angles: Array[float] = [TAU * segment / float(segments), TAU * (segment + 1) / float(segments)]
            var ring: Array[Vector3] = []
            var normals: Array[Vector3] = []
            for pick: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
                var point: Vector2 = a if pick.y == 0 else b
                var angle: float = angles[pick.x] + twist * point.y
                ring.append(Vector3(cos(angle) * point.x, point.y, sin(angle) * point.x))
                normals.append(Vector3(cos(angle) * outward.x, outward.y, sin(angle) * outward.x).normalized())
            for tri: Array in [[0, 1, 2], [0, 2, 3]]:
                if faceted:
                    _flat(st, ring[tri[0]], ring[tri[1]], ring[tri[2]], color, Vector3(0, (a.y + b.y) * .5, 0))
                else:
                    for pick: int in tri:
                        _add(st, ring[pick], normals[pick], color)

static func _petal(st: SurfaceTool, base: Vector3, direction: Vector3, length: float, width: float, curl: float, cup: float, color: Color) -> void:
    ## A cupped, curling petal grid with analytic-enough normals; double-sided through the material.
    var along: Vector3 = direction.normalized()
    var side: Vector3 = along.cross(Vector3.UP)
    if side.length() < .01:
        side = Vector3.RIGHT
    side = side.normalized()
    var lift: Vector3 = side.cross(along).normalized()
    if lift.y < 0.0:
        lift = -lift
    var grid: Array = []
    for i: int in range(7):
        var s: float = float(i) / 6.0
        var row: Array[Vector3] = []
        for j: int in range(5):
            var w: float = float(j) / 4.0 * 2.0 - 1.0
            var half: float = width * pow(sin(PI * clampf(s * .92 + .04, 0.0, 1.0)), .75) * (1.0 - .25 * s)
            row.append(base + along * (s * length) + lift * (curl * s * s + cup * w * w * (1.0 - s * .4)) + side * (w * half))
        grid.append(row)
    for i: int in range(6):
        for j: int in range(4):
            var quad: Array[Vector3] = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
            var normal: Vector3 = (quad[1] - quad[0]).cross(quad[3] - quad[0]).normalized()
            if normal.dot(lift) < 0.0:
                normal = -normal
            var tip: float = float(i) / 6.0
            var shaded: Color = Color(color.r, color.g * (1.0 - .08 * tip), color.b * (1.0 - .15 * tip), color.a)
            for pick: int in [0, 1, 2, 0, 2, 3]:
                _add(st, quad[pick], normal, shaded)

static func _prism(st: SurfaceTool, base: Vector3, direction: Vector3, radius: float, length: float, tip: float, sides: int, pointed_base: bool, color: Color) -> void:
    var axis: Vector3 = direction.normalized()
    var reference: Vector3 = Vector3.RIGHT if absf(axis.x) < .9 else Vector3.FORWARD
    var u: Vector3 = axis.cross(reference).normalized()
    var v: Vector3 = axis.cross(u).normalized()
    var bottom: Array[Vector3] = []
    var top: Array[Vector3] = []
    for side: int in range(sides):
        var angle: float = TAU * side / float(sides)
        var offset: Vector3 = (u * cos(angle) + v * sin(angle)) * radius
        bottom.append(base + offset)
        top.append(base + axis * length + offset)
    var apex: Vector3 = base + axis * (length + tip)
    var center: Vector3 = base + axis * (length * .5)
    for side: int in range(sides):
        var next: int = (side + 1) % sides
        _flat(st, bottom[side], bottom[next], top[next], color, center)
        _flat(st, bottom[side], top[next], top[side], color, center)
        _flat(st, top[side], top[next], apex, color, center)
        if pointed_base:
            _flat(st, bottom[next], bottom[side], base - axis * tip * .6, color, center)
        else:
            _flat(st, bottom[next], bottom[side], base, color, center)

static func _icosahedron(radius: float) -> Array[Vector3]:
    var phi: float = (1.0 + sqrt(5.0)) * .5
    var points: Array[Vector3] = []
    for a: float in [-1.0, 1.0]:
        for b: float in [-phi, phi]:
            points.append(Vector3(0, a, b).normalized() * radius)
            points.append(Vector3(a, b, 0).normalized() * radius)
            points.append(Vector3(b, 0, a).normalized() * radius)
    return points

static func _brilliant(st: SurfaceTool, scale: float, color: Color) -> void:
    var table: Array[Vector3] = []
    var girdle: Array[Vector3] = []
    for index: int in range(8):
        var angle: float = TAU * (index + .5) / 8.0
        table.append(Vector3(cos(angle) * .3, .2, sin(angle) * .3) * scale)
    for index: int in range(16):
        var angle: float = TAU * index / 16.0
        girdle.append(Vector3(cos(angle) * .5, 0, sin(angle) * .5) * scale)
    var culet: Vector3 = Vector3(0, -.45, 0) * scale
    var inside: Vector3 = Vector3(0, -.05, 0) * scale
    for index: int in range(8):
        var next: int = (index + 1) % 8
        _flat(st, table[index], table[next], Vector3(0, .2, 0) * scale, color, inside)
        var g0: Vector3 = girdle[(2 * index + 1) % 16]
        var g1: Vector3 = girdle[(2 * index + 2) % 16]
        var g2: Vector3 = girdle[(2 * index + 3) % 16]
        _flat(st, table[index], g0, g1, color, inside)
        _flat(st, table[index], g1, table[next], color, inside)
        _flat(st, table[next], g1, g2, color, inside)
    for index: int in range(16):
        _flat(st, girdle[index], girdle[(index + 1) % 16], culet, color, inside)

static func _step_cut(st: SurfaceTool) -> void:
    ## An emerald-cut stone: a chamfered rectangular table, two crown steps and a pavilion keel.
    var rings: Array = []
    for level: Array in [[.2, .16, .2], [.36, .26, .1], [.44, .32, 0.0], [.3, .2, -.18], [.12, .06, -.34]]:
        var ring: Array[Vector3] = []
        var half_x: float = float(level[0])
        var half_z: float = float(level[1])
        var chamfer: float = half_z * .35
        for corner: Vector2 in [Vector2(half_x - chamfer, half_z), Vector2(-half_x + chamfer, half_z), Vector2(-half_x, half_z - chamfer), Vector2(-half_x, -half_z + chamfer), Vector2(-half_x + chamfer, -half_z), Vector2(half_x - chamfer, -half_z), Vector2(half_x, -half_z + chamfer), Vector2(half_x, half_z - chamfer)]:
            ring.append(Vector3(corner.x, float(level[2]), corner.y))
        rings.append(ring)
    var inside: Vector3 = Vector3(0, -.02, 0)
    for index: int in range(8):
        _flat(st, rings[0][index], rings[0][(index + 1) % 8], Vector3(0, .2, 0), Color(1, 1, 1, PART_PRIMARY), inside)
    for level: int in range(4):
        for index: int in range(8):
            var next: int = (index + 1) % 8
            _flat(st, rings[level][index], rings[level + 1][index], rings[level + 1][next], Color(1, 1, 1, PART_PRIMARY), inside)
            _flat(st, rings[level][index], rings[level + 1][next], rings[level][next], Color(1, 1, 1, PART_PRIMARY), inside)
    for index: int in range(8):
        _flat(st, rings[4][index], rings[4][(index + 1) % 8], Vector3(0, -.36, 0), Color(1, 1, 1, PART_PRIMARY), inside)

static func _merkaba(st: SurfaceTool) -> void:
    ## Two interlocking tetrahedra with gilded edges.
    for sign: float in [1.0, -1.0]:
        var corners: Array[Vector3] = [Vector3(1, 1, 1) * sign, Vector3(1, -1, -1) * sign, Vector3(-1, 1, -1) * sign, Vector3(-1, -1, 1) * sign]
        for index: int in range(4):
            corners[index] *= .32
        for face: Array in [[0, 1, 2], [0, 3, 1], [0, 2, 3], [1, 3, 2]]:
            _flat(st, corners[face[0]], corners[face[1]], corners[face[2]], Color(1, 1, 1, PART_PRIMARY), Vector3.ZERO)
        for edge: Array in [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]:
            _tube(st, [corners[edge[0]], corners[edge[1]]], .018, 5, false, Color(1, 1, 1, PART_SECONDARY))
    _sphere(st, Vector3.ZERO, .1, 5, 8, Color(1, .85, .5, PART_GLOW))

static func _flame(st: SurfaceTool) -> void:
    ## A twisting teardrop whose three lobes spiral upward like a licking flame.
    var rings: int = 14
    var segments: int = 18
    var grid: Array = []
    for ring: int in range(rings + 1):
        var s: float = float(ring) / float(rings)
        var y: float = lerpf(-.42, .58, s)
        var radius: float = .3 * pow(sin(PI * clampf(s, 0.0, 1.0)), .8) * (1.0 - .45 * s)
        var row: Array[Vector3] = []
        for segment: int in range(segments):
            var angle: float = TAU * segment / float(segments)
            var lobe: float = 1.0 + .18 * cos(3.0 * angle + 7.0 * s) * sin(PI * s)
            row.append(Vector3(cos(angle + 2.4 * s) * radius * lobe, y, sin(angle + 2.4 * s) * radius * lobe))
        grid.append(row)
    for ring: int in range(rings):
        for segment: int in range(segments):
            var next: int = (segment + 1) % segments
            var quad: Array[Vector3] = [grid[ring][segment], grid[ring][next], grid[ring + 1][next], grid[ring + 1][segment]]
            var center: Vector3 = Vector3(0, quad[0].y, 0)
            var warm: Color = Color(1.0, .55 + .4 * float(ring) / float(rings), .25 + .2 * float(ring) / float(rings), PART_PRIMARY)
            _flat(st, quad[0], quad[1], quad[2], warm, center)
            _flat(st, quad[0], quad[2], quad[3], warm, center)
    _sphere(st, Vector3(0, -.12, 0), .12, 6, 10, Color(1, .75, .35, PART_GLOW))

static func _feather(st: SurfaceTool) -> void:
    ## A curved, slightly twisted vane carrying the peacock eye-spot, on a golden shaft.
    var rows: int = 12
    var columns: int = 6
    var grid: Array = []
    for row: int in range(rows + 1):
        var s: float = float(row) / float(rows)
        var line: Array = []
        for column: int in range(columns + 1):
            var w: float = float(column) / float(columns) * 2.0 - 1.0
            var point: Vector3 = Vector3(w * .32, lerpf(-.2, .62, s), .18 * s * s + .06 * w * w)
            point = Basis(Vector3.UP, .35 * s) * point
            line.append([point, Vector2(w * .5 + .5, 1.0 - s)])
        grid.append(line)
    for row: int in range(rows):
        for column: int in range(columns):
            var quad: Array = [grid[row][column], grid[row][column + 1], grid[row + 1][column + 1], grid[row + 1][column]]
            var normal: Vector3 = (quad[1][0] - quad[0][0]).cross(quad[3][0] - quad[0][0]).normalized()
            for pick: int in [0, 1, 2, 0, 2, 3]:
                _add(st, quad[pick][0], normal, Color(1, 1, 1, PART_SPRITE), quad[pick][1])
    var shaft: Array[Vector3] = []
    for step: int in range(9):
        var s: float = float(step) / 8.0
        shaft.append(Basis(Vector3.UP, .35 * maxf(s, 0.0)) * Vector3(0, lerpf(-.5, .55, s), .18 * maxf(s * 1.1 - .1, 0.0) * maxf(s * 1.1 - .1, 0.0) - .012))
    _tube(st, shaft, .018, 5, false, Color(1, 1, 1, PART_SECONDARY))

static func _coin(st: SurfaceTool, radius: float, thickness: float, sides: int) -> void:
    ## A medallion: sprite-painted faces over gold, a rounded gold rim.
    for face: float in [1.0, -1.0]:
        var normal: Vector3 = Vector3(0, 0, face)
        for side: int in range(sides):
            var a: float = TAU * side / float(sides)
            var b: float = TAU * (side + 1) / float(sides)
            var center: Vector3 = Vector3(0, 0, face * thickness * .5)
            var points: Array[Vector3] = [center, center + Vector3(cos(a), sin(a), 0) * radius, center + Vector3(cos(b), sin(b), 0) * radius]
            for point: Vector3 in points:
                var uv: Vector2 = Vector2(point.x / radius * .5 * face + .5, .5 - point.y / radius * .5)
                _add(st, point, normal, Color(1, 1, 1, PART_SPRITE), uv)
    _torus(st, Vector3.ZERO, Basis.IDENTITY, radius, thickness * .55, sides, 6, Color(1, 1, 1, PART_SECONDARY))
