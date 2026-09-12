extends Node3D
## Open circuit constellations store the inhale and release a slow electric current.

const TRACE_SHADER = preload("res://experiences/circuit_garden/trace.gdshader")
var _materials: Array[ShaderMaterial] = []
var _surface := SurfaceTool.new()
var _chips: Array[Transform3D] = []
var _chip_colors: Array[Color] = []
var _rng := RandomNumberGenerator.new()
var _path_id := 0

func _ready() -> void:
    _rng.seed = 83215
    _surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Open, separated panels leave breathing space around the shared central orb.
    for i in range(8):
        var angle := TAU * float(i) / 8.0 + PI / 8.0
        var radius := 4.6 + float(i % 3) * 1.2
        var origin := Vector3(sin(angle) * radius, 1.8, -cos(angle) * radius)
        _panel(origin, Basis(Vector3.UP, -angle) * Basis(Vector3.FORWARD, sin(float(i) * 1.7) * 0.20), i, 1.0)
    # Suspended roof circuits remain present when the viewer is lying down.
    for i in range(4):
        var angle := TAU * float(i) / 4.0 + 0.3
        var origin := Vector3(sin(angle) * 2.6, 5.7 + float(i % 2), cos(angle) * 2.6)
        var basis := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, PI * 0.5)
        _panel(origin, basis, i + 8, 0.9)
    var material := ShaderMaterial.new()
    material.shader = TRACE_SHADER
    _materials.append(material)
    var trace_node := MeshInstance3D.new()
    trace_node.name = "FloatingCircuitLattices"
    trace_node.mesh = _surface.commit()
    trace_node.material_override = material
    trace_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(trace_node)
    _build_chips()
    _build_charge_seeds()

func _point(local: Vector2, origin: Vector3, basis: Basis, scale_factor: float) -> Vector3:
    return origin + basis * Vector3(local.x, local.y, -0.065 * local.x * local.x) * scale_factor

func _panel(origin: Vector3, basis: Basis, index: int, scale_factor: float) -> void:
    var palette := [Color(0.12, 0.72, 0.56), Color(0.14, 0.48, 0.85), Color(0.75, 0.50, 0.19)]
    var color: Color = palette[index % palette.size()]
    var centers: Array[Vector2] = []
    for j in range(9):
        centers.append(Vector2(-1.35 + float(j % 3) * 1.35, -1.35 + float(j / 3) * 1.35) + Vector2(_rng.randf_range(-0.13, 0.13), _rng.randf_range(-0.12, 0.12)))
    for j in range(9):
        var center := centers[j]
        var world_center := _point(center, origin, basis, scale_factor)
        var chip_scale := Vector3(0.22 + 0.08 * float(j % 3), 0.18 + 0.07 * float((j + index) % 3), 0.055)
        _chips.append(Transform3D(basis.scaled(chip_scale * scale_factor), world_center))
        _chip_colors.append(color.lerp(Color(0.76, 0.69, 0.36), 0.45))
        for link in [1, 3]:
            var target: int = j + link
            if target >= 9 or (link == 1 and j % 3 == 2):
                continue
            var end := centers[target]
            for lane in range(2 + j % 2):
                var offset := (float(lane) - 0.5) * 0.10
                var start_point := center + Vector2(0.0, offset)
                var end_point := end + Vector2(0.0, offset)
                var middle_x := lerpf(start_point.x, end_point.x, 0.45) + 0.15 + offset
                var points := [start_point, Vector2(middle_x - 0.09, start_point.y), Vector2(middle_x, start_point.y + 0.09), Vector2(middle_x, end_point.y - 0.09), Vector2(middle_x + 0.09, end_point.y), end_point]
                _trace(points, origin, basis, scale_factor, color, 0.010)
        # Sparse concentric capacitors vary the silhouette of the connected network.
        if j % 3 == index % 3:
            for ring_index in range(2):
                var ring: Array[Vector2] = []
                for k in range(33):
                    var angle := TAU * float(k) / 32.0
                    ring.append(center + Vector2(cos(angle), sin(angle)) * (0.29 + float(ring_index) * 0.075))
                _trace(ring, origin, basis, scale_factor, color.lerp(Color(0.76, 0.56, 0.24), 0.5), 0.006)
        # Short pins make the tiny components recognizably electronic.
        for pin in range(4):
            for direction in [-1.0, 1.0]:
                var x := (float(pin) - 1.5) * 0.055
                _trace([center + Vector2(x, direction * chip_scale.y * 0.5), center + Vector2(x, direction * (chip_scale.y * 0.5 + 0.10))], origin, basis, scale_factor, color, 0.008)

func _trace(points: Array, origin: Vector3, basis: Basis, scale_factor: float, color: Color, width: float) -> void:
    _path_id += 1
    var world: Array[Vector3] = []
    var length_value := 0.0
    for point: Vector2 in points:
        world.append(_point(point, origin, basis, scale_factor))
    for i in range(world.size() - 1):
        length_value += world[i].distance_to(world[i + 1])
    var traveled := 0.0
    var phase := fposmod(float(_path_id) * 0.618034, 1.0)
    for i in range(world.size() - 1):
        var segment_length := world[i].distance_to(world[i + 1])
        var direction := (world[i + 1] - world[i]).normalized()
        var side := direction.cross(basis.z).normalized() * width
        var depth := basis.z * width
        var offsets := [side, depth, -side, -depth]
        for edge in range(4):
            var next := (edge + 1) % 4
            var vertices := [world[i] + offsets[edge], world[i + 1] + offsets[edge], world[i + 1] + offsets[next], world[i] + offsets[edge], world[i + 1] + offsets[next], world[i] + offsets[next]]
            var coords := [traveled, traveled + segment_length, traveled + segment_length, traveled, traveled + segment_length, traveled]
            for k in range(6):
                _surface.set_color(Color(color.r, color.g, color.b, phase))
                _surface.set_uv(Vector2(float(coords[k]) / maxf(length_value, 0.001), phase))
                _surface.set_normal(basis.z)
                _surface.add_vertex(vertices[k])
        traveled += segment_length

func _build_chips() -> void:
    var material := ShaderMaterial.new()
    material.shader = load("res://experiences/circuit_garden/chip.gdshader")
    _materials.append(material)
    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    mesh.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = mesh
    multi.instance_count = _chips.size()
    for i in range(_chips.size()):
        multi.set_instance_transform(i, _chips[i])
        multi.set_instance_color(i, _chip_colors[i])
    var node := MultiMeshInstance3D.new()
    node.name = "BreathingCapacitorCores"
    node.multimesh = multi
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func update_experience(state: Dictionary) -> void:
    for material in _materials:
        material.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", float(state.get("breath_fill", 0.0)))
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))

func _build_charge_seeds() -> void:
    var material := ShaderMaterial.new()
    material.shader = load("res://experiences/circuit_garden/charge.gdshader")
    _materials.append(material)
    var mesh := QuadMesh.new()
    mesh.size = Vector2.ONE
    mesh.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.use_custom_data = true
    multi.mesh = mesh
    multi.instance_count = 864
    for i in range(864):
        var cluster := i / 108
        var angle := TAU * float(cluster) / 8.0 + 0.35
        var elevation := 0.2 if cluster < 4 else 1.12
        var center := Vector3(sin(angle) * cos(elevation), sin(elevation), -cos(angle) * cos(elevation)) * (3.1 + float(cluster % 2) * 0.8) + Vector3(0, 1.4, 0)
        var offset := Vector3(_rng.randfn(0, 0.15), _rng.randfn(0, 0.15), _rng.randfn(0, 0.15))
        multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, center + offset))
        multi.set_instance_color(i, Color(0.35, 0.75, 0.61) if cluster % 2 == 0 else Color(0.74, 0.54, 0.25))
        multi.set_instance_custom_data(i, Color(float(cluster) / 8.0, _rng.randf(), _rng.randf(), 1))
    var node := MultiMeshInstance3D.new()
    node.name = "DriftingChargeRegisters"
    node.multimesh = multi
    node.custom_aabb = AABB(Vector3(-8, -3, -8), Vector3(16, 15, 16))
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
