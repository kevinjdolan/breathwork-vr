extends Node3D
## A gaze-following painted tunnel that travels through four visionary passages.

const ROOT: String = "res://experiences/visionary_temple/"
const SPEED: float = 0.55
const STAR_DISTANCE: float = 60.0
const LOOP: float = 16.0
const PASSAGE: float = 120.0
const SEGMENT: float = 0.5
const RADIUS: float = 5.6
const CONTRACTION: float = 0.35
const SIGIL_COUNT: int = 96
const PASSAGE_NAMES: Array[String] = ["eyes", "flames", "rings", "temple"]
## Angular repeats, depth length in meters, swapped axes, and rotation rate per tile.
const TILE_MAPS: Array[Vector4] = [Vector4(5, 7.0, 0, 0), Vector4(4, 8.0, 0, .011), Vector4(4, 8.8, 0, -.009), Vector4(1, 6.0, 1, 0)]
const GLOW: Array[Color] = [Color(1.0, .93, .78), Color(1.0, .95, .84), Color(.93, 1.0, .82), Color(1.0, .84, .58)]
const HAZE: Array[Color] = [Color(.11, .05, .26), Color(.24, .06, .20), Color(.04, .15, .08), Color(.22, .08, .03)]
const MOTES: Array[Color] = [Color(1.0, .85, .45), Color(1.0, .60, .25), Color(.62, 1.0, .42), Color(.42, .88, 1.0)]

var _materials: Array[ShaderMaterial] = []
var _tiles: Array[Texture2D] = []
var _tunnel_material: ShaderMaterial
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
    var sprites: Texture2D = load(ROOT + "tiles/sigils.png")
    _build_tunnel()
    _points("Sigils", SIGIL_COUNT, "sigils.gdshader").set_shader_parameter("sprite_sheet", sprites)
    _points("DistantHaze", 3, "haze.gdshader").render_priority = -20
    _points("DriftingMotes", 3072, "motes.gdshader")
    _points("DestinationLight", 320, "destination.gdshader")
    _mandala_material = _points("DistantMandala", 2, "mandala.gdshader")
    _mandala_material.set_shader_parameter("sprite_sheet", sprites)
    _mandala_material.render_priority = -18
    _build_paths()
    print("VRMED VISIONARY passages=4 tunnel_vertices=", (get_node("PaintedTunnel") as MeshInstance3D).mesh.get_faces().size() / 3, " sigils=", SIGIL_COUNT, " motes=3072")

func _material(path: String) -> ShaderMaterial:
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = load(ROOT + path)
    _materials.append(material)
    return material

func _build_tunnel() -> void:
    # A connected tube whose ornament rides material coordinates as it slides past.
    var around: int = 256
    var rings: int = 129
    var vertices: PackedVector3Array = PackedVector3Array()
    var uvs: PackedVector2Array = PackedVector2Array()
    var indices: PackedInt32Array = PackedInt32Array()
    for ring: int in range(rings):
        var slot: float = -56.0 + float(ring) * SEGMENT
        for step: int in range(around + 1):
            var u: float = float(step) / float(around)
            var angle: float = u * TAU
            vertices.append(Vector3(cos(angle), sin(angle), slot))
            uvs.append(Vector2(u, float(ring) / float(rings - 1)))
    for ring: int in range(rings - 1):
        for step: int in range(around):
            var i: int = ring * (around + 1) + step
            indices.append_array(PackedInt32Array([i, i + around + 1, i + 1, i + 1, i + around + 1, i + around + 2]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    _tunnel_material = _material("tunnel.gdshader")
    _tunnel_material.render_priority = -15
    var node: MeshInstance3D = MeshInstance3D.new()
    node.name = "PaintedTunnel"
    node.mesh = mesh
    node.material_override = _tunnel_material
    node.custom_aabb = AABB(Vector3(-150, -150, -150), Vector3(300, 300, 300))
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

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
    # Each two-minute passage dissolves into the next over its final 24 seconds.
    var progress: float = time / PASSAGE
    var index: int = clampi(int(floor(progress)), 0, 3)
    var next: int = mini(index + 1, 3)
    var mix: float = smoothstep(.8, 1.0, progress - float(index)) if index < 3 else 0.0
    var weights: Vector4 = Vector4.ZERO
    weights[index] += 1.0 - mix
    weights[next] += mix
    return {"index": index, "next": next, "mix": mix, "weights": weights}

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
    if _source_index >= 0:
        _source = _journey * object_center(_source_index, time, fill)
    var nose: Vector3 = head + basis * Vector3(0, -.035, -.085)
    var lead: float = phase - LOOP if phase >= LOOP - 1.5 else phase
    var beam: float = smoothstep(-1.5, .35, lead) * (1.0 - smoothstep(3.35, 4.75, lead)) if lead < 4.75 else 0.0
    if time >= 478.5 or _source_index < 0:
        beam = 0.0
    var beam_front: float = smoothstep(-1.5, .5, lead) * 1.08
    var hold_glow: float = smoothstep(4.0, 4.8, phase) * (1.0 - smoothstep(7.2, 8.0, phase))
    var passage: Dictionary = passage_state(time)
    if int(passage["index"]) != _passage_index:
        _passage_index = int(passage["index"])
        _tunnel_material.set_shader_parameter("tile_a", _tiles[_passage_index])
        _tunnel_material.set_shader_parameter("tile_b", _tiles[int(passage["next"])])
        _tunnel_material.set_shader_parameter("map_a", TILE_MAPS[_passage_index])
        _tunnel_material.set_shader_parameter("map_b", TILE_MAPS[int(passage["next"])])
        _mandala_material.set_shader_parameter("sprite_a", float(_passage_index))
        _mandala_material.set_shader_parameter("sprite_b", float(int(passage["next"])))
    var mix: float = passage["mix"]
    var glow: Color = GLOW[int(passage["index"])].lerp(GLOW[int(passage["next"])], mix)
    var haze: Color = HAZE[int(passage["index"])].lerp(HAZE[int(passage["next"])], mix)
    var mote: Color = MOTES[int(passage["index"])].lerp(MOTES[int(passage["next"])], mix)
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
        material.set_shader_parameter("nose_position", nose)
        material.set_shader_parameter("mouth_position", state.get("mouth_position", head + basis * Vector3(0, -.08, -.06)))
        material.set_shader_parameter("head_right", basis.x)
        material.set_shader_parameter("head_up", basis.y)
        material.set_shader_parameter("head_forward", -basis.z)
        material.set_shader_parameter("beam_visibility", beam)
        material.set_shader_parameter("beam_front", beam_front)
        material.set_shader_parameter("passage_mix", mix)
        material.set_shader_parameter("phase_weights", passage["weights"])
        material.set_shader_parameter("glow_color", Vector3(glow.r, glow.g, glow.b))
        material.set_shader_parameter("haze_color", Vector3(haze.r, haze.g, haze.b))
        material.set_shader_parameter("mote_color", Vector3(mote.r, mote.g, mote.b))

static func object_center(index: int, time: float, fill: float) -> Vector3:
    # Mirrors the sigil vertex shader so the plasma source and its sprite coincide.
    var seed: float = fposmod(float(index) * .6180339, 1.0) * TAU
    var z_seed: float = fposmod(float(index) * .56984, 1.0)
    var w: float = fposmod(float(index) * .438579, 1.0)
    var depth: float = fposmod(fposmod(float(index) * .75487766, 1.0) * 64.0 + travel_distance(time), 64.0) - 56.0
    var near: bool = z_seed <= .27
    var radius: float = 1.15 + w * .35 if near else 2.3 + z_seed * 1.4
    var size: float = .26 + w * .12 if near else .55 + w * .55
    size *= 1.0 - fill * CONTRACTION
    var shell: float = 3.05 * (1.0 - fill * CONTRACTION)
    var extent: float = size * .55
    radius = maxf(1.05 if near else 1.3, radius * (1.0 - fill * CONTRACTION))
    radius = maxf(radius, absf(depth) * .035 + size * .6)
    radius = minf(radius, shell - extent - .16)
    var angle: float = seed + .07 * sin(time * .061 + float(index))
    return Vector3(cos(angle) * radius + .10 * sin(time * .17 + seed), sin(angle) * radius + .10 * cos(time * .12 + seed * 2.0), depth + .12 * sin(time * .10 + seed))

static func object_extent(index: int, fill: float) -> float:
    var z_seed: float = fposmod(float(index) * .56984, 1.0)
    var w: float = fposmod(float(index) * .438579, 1.0)
    var size: float = .26 + w * .12 if z_seed <= .27 else .55 + w * .55
    return size * (1.0 - fill * CONTRACTION) * .55

func select_source(time: float, head: Vector3, basis: Basis, fill: float) -> int:
    var best: int = -1
    var score: float = -1000.0
    for index: int in range(SIGIL_COUNT):
        var point: Vector3 = _journey * object_center(index, time, fill)
        var future: Vector3 = _journey * object_center(index, time + 6.0, 1.0)
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
            best = index
    return best
