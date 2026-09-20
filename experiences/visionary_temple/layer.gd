extends Node3D
## A gaze-following painted tunnel that travels through eight visionary passages, one per minute.

const INHALE_OFFSET: Vector3 = Vector3.ZERO
const EXHALE_OFFSET: Vector3 = Vector3.ZERO
const ROOT: String = "res://experiences/visionary_temple/"
const SPEED: float = 0.55
const STAR_DISTANCE: float = 60.0
const LOOP: float = 16.0
const PASSAGE: float = 60.0
## Each passage dissolves into the next over the final half of its minute.
const TRANSITION: float = 30.0
const RADIUS: float = 5.6
const CONTRACTION: float = 0.35
const Relics = preload("res://experiences/visionary_temple/relics.gd")
## The tube: a fine near section and a coarse far section that meet on a shared static ring.
const AROUND: int = 320
const NEAR_SEGMENT: float = 0.125
const FAR_SEGMENT: float = 0.75
const NEAR_END: float = 6.0
const BOUNDARY: float = -14.0
const FAR_END: float = -59.0
## The arriving shell starts this much wider than its resting radius.
const ARRIVAL_WIDTH: float = 0.55
const PASSAGE_NAMES: Array[String] = ["eyes", "net", "flames", "peacock", "rings", "lotus", "geode", "temple"]
## Angular repeats, depth length in meters, swapped axes, and rotation in turns per second.
## Neighbouring passages turn differently so each dissolve shows two motions at once.
const TILE_MAPS: Array[Vector4] = [Vector4(5, 7.0, 0, 0), Vector4(6, 5.9, 0, -.007), Vector4(4, 8.0, 0, .011), Vector4(6, 5.9, 0, 0), Vector4(4, 8.8, 0, -.009), Vector4(5, 7.0, 0, 0), Vector4(4, 8.8, 0, .008), Vector4(1, 6.0, 1, 0)]
## Cross-section: superellipse exponent, width, height and polygon sides.
const SHAPES: Array[Vector4] = [Vector4(2, 1, 1, 0), Vector4(2, 1, 1, 6), Vector4(2, 1, 1, 0), Vector4(2, 1, 1, 0), Vector4(2, 1, 1, 0), Vector4(2, .92, 1.08, 0), Vector4(2, 1.03, 1.03, 8), Vector4(5, 1, .8, 0)]
## Polygon blend, lobes per turn, lobe depth, and relief height in meters.
const SHAPE_DETAILS: Array[Vector4] = [Vector4(0, 0, 0, .55), Vector4(.75, 0, 0, .6), Vector4(0, 0, 0, .5), Vector4(0, 6, .045, .55), Vector4(0, 0, 0, .5), Vector4(0, 0, 0, .7), Vector4(1, 0, 0, .75), Vector4(0, 0, 0, .45)]
const GLOW: Array[Color] = [Color(1.0, .93, .78), Color(.88, .95, 1.0), Color(1.0, .95, .84), Color(.86, 1.0, .90), Color(.93, 1.0, .82), Color(1.0, .90, .90), Color(.95, .88, 1.0), Color(1.0, .84, .58)]
const HAZE: Array[Color] = [Color(.11, .05, .26), Color(.03, .08, .22), Color(.24, .06, .20), Color(.03, .14, .12), Color(.04, .15, .08), Color(.16, .05, .12), Color(.14, .05, .24), Color(.22, .08, .03)]
const MOTES: Array[Color] = [Color(1.0, .85, .45), Color(.55, .85, 1.0), Color(1.0, .60, .25), Color(.45, 1.0, .75), Color(.62, 1.0, .42), Color(1.0, .70, .80), Color(.85, .65, 1.0), Color(.42, .88, 1.0)]

var _materials: Array[ShaderMaterial] = []
var _tiles: Array[Texture2D] = []
var _reliefs: Array[Texture2D] = []
var _solid_material: ShaderMaterial
var _eroding_material: ShaderMaterial
var _incoming_material: ShaderMaterial
var _front: MeshInstance3D
var _incoming: MeshInstance3D
## Each relic type draws as one MultiMesh holding only the relics that can currently be visible.
var _relic_nodes: Array[MultiMeshInstance3D] = []
var _relic_members: Array = []
var _relic_drawn: Array = []
var _mandala_material: ShaderMaterial
var _journey: Transform3D = Transform3D.IDENTITY
var _anchored: bool = false
var _aim: Quaternion = Quaternion.IDENTITY
var _last_time: float = -1.0
var _focal: Vector3 = Vector3(0, 1.4, -60)
var _source_index: int = -1
var _source_cycle: int = -1
var _source: Vector3
var _passage_index: int = -1

func _ready() -> void:
    for name: String in PASSAGE_NAMES:
        _tiles.append(load(ROOT + "tiles/" + name + ".png"))
        _reliefs.append(load(ROOT + "tiles/" + name + "_relief.png"))
    var sprites: Texture2D = load(ROOT + "tiles/sigils.png")
    _build_tunnel()
    _build_relics(sprites, load(ROOT + "tiles/matcaps.png"))
    _points("DistantHaze", 3, "haze.gdshader").render_priority = -20
    _points("DriftingMotes", 3072, "motes.gdshader")
    _points("DestinationLight", 320, "destination.gdshader")
    _mandala_material = _points("DistantMandala", 2, "mandala.gdshader")
    _mandala_material.set_shader_parameter("sprite_sheet", sprites)
    _mandala_material.render_priority = -18
    _build_paths()
    print("VRMED VISIONARY passages=", PASSAGE_NAMES.size(), " tunnel_triangles=", _front.mesh.get_faces().size() / 3, " relics=", Relics.COUNT, " relic_types=", _relic_nodes.size(), " motes=3072")

func _material(path: String) -> ShaderMaterial:
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = load(ROOT + path)
    _materials.append(material)
    return material

func _build_tunnel() -> void:
    # Two shells share one tube: the current passage in front and, during a dissolve, the next one behind it.
    var mesh: ArrayMesh = tunnel_mesh()
    _solid_material = _material("tunnel.gdshader")
    _eroding_material = _material("tunnel_eroding.gdshader")
    _incoming_material = _material("tunnel_incoming.gdshader")
    # The arriving shell draws first among transparent layers so haze, sigils and sparks blend over it.
    _incoming_material.render_priority = -30
    _front = _tunnel_node("PaintedTunnel", mesh, _solid_material)
    _incoming = _tunnel_node("IncomingTunnel", mesh, _incoming_material)
    _incoming.visible = false

func _tunnel_node(label: String, mesh: ArrayMesh, material: ShaderMaterial) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.material_override = material
    node.custom_aabb = AABB(Vector3(-150, -150, -150), Vector3(300, 300, 300))
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
    return node

static func tunnel_rings() -> Array[Vector2]:
    ## Rest depth and conveyor segment of every ring; a negative segment marks the static shared ring.
    var rings: Array[Vector2] = []
    var far_count: int = roundi((BOUNDARY - FAR_END) / FAR_SEGMENT)
    for ring: int in range(far_count):
        rings.append(Vector2(FAR_END + float(ring) * FAR_SEGMENT, FAR_SEGMENT))
    rings.append(Vector2(BOUNDARY, -1.0))
    var near_count: int = roundi((NEAR_END - BOUNDARY) / NEAR_SEGMENT)
    for ring: int in range(1, near_count + 1):
        rings.append(Vector2(BOUNDARY + float(ring) * NEAR_SEGMENT, NEAR_SEGMENT))
    return rings

static func tunnel_mesh() -> ArrayMesh:
    # Vertices ride the travelling surface one segment at a time, so the relief never swims across the grid.
    var rings: Array[Vector2] = tunnel_rings()
    var vertices: PackedVector3Array = PackedVector3Array()
    var uvs: PackedVector2Array = PackedVector2Array()
    var conveyor: PackedVector2Array = PackedVector2Array()
    var indices: PackedInt32Array = PackedInt32Array()
    for ring: Vector2 in rings:
        var segment: float = absf(ring.y)
        for step: int in range(AROUND + 1):
            var u: float = float(step) / float(AROUND)
            vertices.append(Vector3(cos(u * TAU), sin(u * TAU), ring.x))
            uvs.append(Vector2(u, 0.0))
            conveyor.append(Vector2(FAR_SEGMENT if ring.y < 0.0 else segment, 1.0 if ring.y < 0.0 else 0.0))
    for ring: int in range(rings.size() - 1):
        for step: int in range(AROUND):
            var i: int = ring * (AROUND + 1) + step
            indices.append_array(PackedInt32Array([i, i + AROUND + 1, i + 1, i + 1, i + AROUND + 1, i + AROUND + 2]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_TEX_UV2] = conveyor
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _build_relics(sprites: Texture2D, matcaps: Texture2D) -> void:
    for type: int in range(Relics.TYPES.size()):
        _relic_members.append([])
        _relic_drawn.append([])
    for g: int in range(Relics.COUNT):
        _relic_members[Relics.type_of(g)].append(g)
    for type: int in range(Relics.TYPES.size()):
        var spec: Dictionary = Relics.TYPES[type]
        var multimesh: MultiMesh = MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.use_custom_data = true
        multimesh.mesh = Relics.build_mesh(str(spec["name"]))
        multimesh.instance_count = _relic_members[type].size()
        multimesh.visible_instance_count = 0
        for instance: int in range(multimesh.instance_count):
            multimesh.set_instance_transform(instance, Transform3D.IDENTITY)
        var material: ShaderMaterial = _material("relic.gdshader")
        material.set_shader_parameter("matcaps", matcaps)
        material.set_shader_parameter("sprite_sheet", sprites)
        material.set_shader_parameter("size_scale", float(spec["scale"]))
        material.set_shader_parameter("sprite_cell", float(spec["sprite"]))
        material.set_shader_parameter("sprite_cutout", bool(spec.get("cutout", false)))
        var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
        node.name = "Relic_" + str(spec["name"])
        node.multimesh = multimesh
        node.material_override = material
        node.custom_aabb = AABB(Vector3(-150, -150, -150), Vector3(300, 300, 300))
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.visible = false
        add_child(node)
        _relic_nodes.append(node)

func _refresh_relics(time: float) -> void:
    # Only relics inside their drawing window occupy instance slots; the shader derives everything from the index.
    for type: int in range(_relic_nodes.size()):
        var drawn: Array = []
        for g: int in _relic_members[type]:
            var span: Vector2 = Relics.window(g)
            if time >= span.x and time <= span.y:
                drawn.append(g)
        if drawn == _relic_drawn[type]:
            continue
        _relic_drawn[type] = drawn
        var multimesh: MultiMesh = _relic_nodes[type].multimesh
        for slot: int in range(drawn.size()):
            var materials: Vector2 = Relics.materials_of(drawn[slot])
            multimesh.set_instance_custom_data(slot, Color(float(drawn[slot]), materials.x, materials.y, 0.0))
        multimesh.visible_instance_count = drawn.size()
        _relic_nodes[type].visible = not drawn.is_empty()

func drawn_relics() -> int:
    var total: int = 0
    for drawn: Array in _relic_drawn:
        total += drawn.size()
    return total

func relic_nodes() -> Array[MultiMeshInstance3D]:
    return _relic_nodes

func _points(label: String, count: int, path: String) -> ShaderMaterial:
    var multimesh: MultiMesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_custom_data = true
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2.ONE
    multimesh.mesh = quad
    multimesh.instance_count = count
    for i: int in range(count):
        multimesh.set_instance_transform(i, Transform3D.IDENTITY)
        multimesh.set_instance_custom_data(i, Color(float(i), fposmod(i * .6180339, 1.0), fposmod(i * .75487766, 1.0), fposmod(i * .438579, 1.0)))
    var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = multimesh
    var material: ShaderMaterial = _material(path)
    node.material_override = material
    node.custom_aabb = AABB(Vector3(-150, -150, -150), Vector3(300, 300, 300))
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
    return material

func _build_paths() -> void:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for segment: int in range(96):
        for side: int in range(6):
            var a: float = TAU * side / 6.0
            var b: float = TAU * (side + 1) / 6.0
            var p: Vector3 = Vector3(float(segment) / 96.0, cos(a), sin(a))
            var q: Vector3 = Vector3(float(segment + 1) / 96.0, cos(a), sin(a))
            var r: Vector3 = Vector3(float(segment + 1) / 96.0, cos(b), sin(b))
            var t: Vector3 = Vector3(float(segment) / 96.0, cos(b), sin(b))
            for point: Vector3 in [p, q, r, p, r, t]:
                st.add_vertex(point)
    var tube: ArrayMesh = st.commit()
    for spec: Array in [["InhalePlasma", 4, 2, "plasma.gdshader"], ["VioletOutflow", 32, 16, "outflow.gdshader"]]:
        var instances: MultiMesh = MultiMesh.new()
        instances.transform_format = MultiMesh.TRANSFORM_3D
        instances.use_custom_data = true
        instances.mesh = tube
        instances.instance_count = int(spec[1])
        for index: int in range(int(spec[1])):
            instances.set_instance_transform(index, Transform3D.IDENTITY)
            instances.set_instance_custom_data(index, Color(float(index % int(spec[2])), float(index / int(spec[2])), 0, 0))
        var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
        node.name = str(spec[0])
        node.multimesh = instances
        node.material_override = _material(str(spec[3]))
        node.custom_aabb = AABB(Vector3(-120, -120, -120), Vector3(240, 240, 240))
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(node)

static func travel_distance(time: float) -> float:
    return SPEED * (time - 5.0 * (1.0 - exp(-time / 5.0)))

static func star_radius(phase: float) -> float:
    # Grows over the first 500 ms of the full hold, collapses over the first 500 ms of exhale.
    if phase < 4.0:
        return smoothstep(0.0, .5, phase)
    if phase < 8.0:
        return 1.0 + .9 * smoothstep(4.0, 4.5, phase)
    return 1.9 * (1.0 - smoothstep(8.0, 8.5, phase))

static func passage_state(time: float) -> Dictionary:
    # Eight one-minute passages; each dissolves into the next over its final thirty seconds.
    var count: int = PASSAGE_NAMES.size()
    var index: int = clampi(int(floor(time / PASSAGE)), 0, count - 1)
    var next: int = mini(index + 1, count - 1)
    var progress: float = 0.0
    if index < count - 1:
        progress = clampf((time - float(index) * PASSAGE - (PASSAGE - TRANSITION)) / TRANSITION, 0.0, 1.0)
    return {"index": index, "next": next, "progress": progress, "mix": smoothstep(0.0, 1.0, progress)}

static func erosion_amount(progress: float) -> float:
    # The outgoing shell opens along its contours, ground first, and is gone by 60% of the dissolve.
    return smoothstep(.02, .60, progress)

static func arrival_scale(progress: float) -> float:
    # The next passage waits wider than its resting radius, then settles once the outgoing shell has gone.
    return 1.0 + ARRIVAL_WIDTH * (1.0 - smoothstep(.45, 1.0, progress))

static func arrival_brightness(progress: float) -> float:
    return lerpf(.5, 1.0, smoothstep(.05, .85, progress))

static func profile(passage: int, angle: float, turn: float) -> float:
    ## Mirrors the tunnel vertex shader's cross-section so tests can check shell clearances.
    var shape: Vector4 = SHAPES[passage]
    var detail: Vector4 = SHAPE_DETAILS[passage]
    var r: float = pow(pow(absf(cos(angle)) / shape.y, shape.x) + pow(absf(sin(angle)) / shape.z, shape.x), -1.0 / shape.x)
    if shape.w > 2.5:
        var sector: float = TAU / shape.w
        var folded: float = fposmod(turn * TAU, sector) - .5 * sector
        r *= lerpf(1.0, cos(.5 * sector) / cos(folded), detail.x)
    return r * (1.0 + detail.z * cos(detail.y * turn * TAU))

static func journey_basis(head_basis: Basis) -> Basis:
    # The journey keeps the hall floor toward the ground unless the gaze is nearly vertical.
    var forward: Vector3 = -head_basis.z.normalized()
    if absf(forward.y) < .985:
        return Basis.looking_at(forward, Vector3.UP)
    return head_basis.orthonormalized()

func reset_journey() -> void:
    _anchored = false
    _source_cycle = -1

func focal_position() -> Vector3:
    return _focal

func update_experience(state: Dictionary) -> void:
    var time: float = state.get("elapsed", 0.0)
    var head: Vector3 = state.get("head_position", Vector3(0, 1.4, 0))
    var basis: Basis = state.get("head_basis", Basis.IDENTITY)
    if not _anchored:
        _journey = Transform3D(journey_basis(basis), head)
        _anchored = true
        _aim = journey_basis(basis).get_rotation_quaternion().normalized()
        _last_time = time
    var delta: float = clampf(time - _last_time, 0.0, .1)
    _last_time = time
    var target: Quaternion = journey_basis(basis).get_rotation_quaternion().normalized()
    var weight: float = 1.0 - exp(-delta / 3.2)
    _aim = _aim.slerp(target, weight).normalized()
    var rotation: Quaternion = _journey.basis.get_rotation_quaternion().normalized()
    _journey.basis = Basis(rotation.slerp(_aim, weight).normalized())
    _journey.origin = head
    _focal = head - _journey.basis.z * STAR_DISTANCE
    var fill: float = state.get("breath_fill", 0.0)
    var phase: float = state.get("phase_seconds", fposmod(time, LOOP))
    var visibility: float = state.get("intensity", 1.0)
    var cycle: int = int(floor((time + 1.5) / LOOP))
    if cycle != _source_cycle:
        _source_index = select_source(time, head, basis, fill)
        _source_cycle = cycle
    _refresh_relics(time)
    if _source_index >= 0:
        _source = _journey * Relics.object_center(_source_index, time, fill)
    var center: Vector3 = BreathGeometry.from_state(state)
    var inhale_target: Vector3 = BreathGeometry.offset(center, basis, INHALE_OFFSET)
    var exhale_origin: Vector3 = BreathGeometry.offset(center, basis, EXHALE_OFFSET)
    var lead: float = phase - LOOP if phase >= LOOP - 1.5 else phase
    var beam: float = smoothstep(-1.5, .35, lead) * (1.0 - smoothstep(3.35, 4.75, lead)) if lead < 4.75 else 0.0
    if time >= 478.5 or _source_index < 0:
        beam = 0.0
    var beam_front: float = smoothstep(-1.5, .5, lead) * 1.08
    var hold_glow: float = smoothstep(4.0, 4.8, phase) * (1.0 - smoothstep(7.2, 8.0, phase))
    var passage: Dictionary = passage_state(time)
    var index: int = passage["index"]
    var next: int = passage["next"]
    if index != _passage_index:
        _passage_index = index
        _apply_passage(_solid_material, index)
        _apply_passage(_eroding_material, index)
        _apply_passage(_incoming_material, next)
        _mandala_material.set_shader_parameter("sprite_a", float(index))
        _mandala_material.set_shader_parameter("sprite_b", float(next))
    var progress: float = passage["progress"]
    var dissolving: bool = progress > 0.0
    var front_material: ShaderMaterial = _eroding_material if dissolving else _solid_material
    if _front.material_override != front_material:
        _front.material_override = front_material
    _incoming.visible = dissolving
    _eroding_material.set_shader_parameter("erosion", erosion_amount(progress))
    _incoming_material.set_shader_parameter("shell_scale", arrival_scale(progress))
    _incoming_material.set_shader_parameter("brightness", arrival_brightness(progress))
    var mix: float = passage["mix"]
    var glow: Color = GLOW[index].lerp(GLOW[next], mix)
    var haze: Color = HAZE[index].lerp(HAZE[next], mix)
    var mote: Color = MOTES[index].lerp(MOTES[next], mix)
    for material: ShaderMaterial in _materials:
        material.set_shader_parameter("elapsed", time)
        material.set_shader_parameter("travel", travel_distance(time))
        material.set_shader_parameter("journey_frame", Projection(_journey))
        material.set_shader_parameter("head_position", head)
        material.set_shader_parameter("star_position", _focal)
        material.set_shader_parameter("breath_fill", fill)
        material.set_shader_parameter("phase_seconds", phase)
        material.set_shader_parameter("intensity", visibility)
        material.set_shader_parameter("hold_glow", hold_glow)
        material.set_shader_parameter("star_radius", star_radius(phase))
        material.set_shader_parameter("source_position", _source)
        material.set_shader_parameter("source_index", float(_source_index))
        material.set_shader_parameter("inhale_target", inhale_target)
        material.set_shader_parameter("exhale_origin", exhale_origin)
        material.set_shader_parameter("head_right", basis.x)
        material.set_shader_parameter("head_up", basis.y)
        material.set_shader_parameter("head_forward", -basis.z)
        material.set_shader_parameter("beam_visibility", beam)
        material.set_shader_parameter("beam_front", beam_front)
        material.set_shader_parameter("passage_mix", mix)
        material.set_shader_parameter("glow_color", Vector3(glow.r, glow.g, glow.b))
        material.set_shader_parameter("haze_color", Vector3(haze.r, haze.g, haze.b))
        material.set_shader_parameter("mote_color", Vector3(mote.r, mote.g, mote.b))

func _apply_passage(material: ShaderMaterial, passage: int) -> void:
    material.set_shader_parameter("surface", _tiles[passage])
    material.set_shader_parameter("relief", _reliefs[passage])
    material.set_shader_parameter("map", TILE_MAPS[passage])
    material.set_shader_parameter("shape", SHAPES[passage])
    material.set_shader_parameter("shape_detail", SHAPE_DETAILS[passage])

func select_source(time: float, head: Vector3, basis: Basis, fill: float) -> int:
    # Choose a relic that stays ahead in view for the whole six-second lead-in and inhale.
    var best: int = -1
    var score: float = -1000.0
    for g: int in range(Relics.COUNT):
        var span: Vector2 = Relics.window(g)
        if time < span.x or time + 6.0 > span.y or Relics.envelope(g, time) < .95 or Relics.envelope(g, time + 6.0) < .95:
            continue
        var point: Vector3 = _journey * Relics.object_center(g, time, fill)
        var future: Vector3 = _journey * Relics.object_center(g, time + 6.0, 1.0)
        var local: Vector3 = basis.inverse() * (point - head)
        var next: Vector3 = basis.inverse() * (future - head)
        if local.z > -4.0 or local.z < -17.0 or next.z > -2.5:
            continue
        var alignment: float = Vector3.FORWARD.dot(local.normalized())
        if alignment < .87 or Vector3.FORWARD.dot(next.normalized()) < .82:
            continue
        var rank: float = alignment * 4.0 - absf(local.length() - 11.0) * .035
        if rank > score:
            score = rank
            best = g
    return best
