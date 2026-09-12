extends Node3D
## An organic neural canopy where breath carries broad, quiet waves of light.

var _rng := RandomNumberGenerator.new()
var _materials: Array[ShaderMaterial] = []
var _segments: Array[Transform3D] = []
var _segment_colors: Array[Color] = []
var _segment_data: Array[Color] = []
var _points: Array[Transform3D] = []
var _point_colors: Array[Color] = []
var _point_data: Array[Color] = []
var _centers: Array[Vector3] = []
const PALETTE = [Color(0.35, 0.63, 0.68), Color(0.63, 0.48, 0.73), Color(0.79, 0.55, 0.41), Color(0.43, 0.64, 0.55)]

func _ready() -> void:
    _rng.seed = 85319
    # A canopy of actual volumes, with open breathing space directly at the face.
    for i in range(48):
        var theta := float(i) * 2.39996
        var elevation := lerpf(-0.90, 1.48, float(i) / 47.0)
        var radius := _rng.randf_range(4.0, 8.9)
        if i == 7 or i == 14:
            radius = 3.3
        var center := Vector3(sin(theta) * cos(elevation), sin(elevation), cos(theta) * cos(elevation)) * radius + Vector3(0, 1.0, 0)
        if i == 4:
            center = Vector3(-1.9, 1.8, -2.7)
        elif i == 7:
            center = Vector3(2.1, 2.3, -3.0)
        elif i == 14:
            center = Vector3(-1.2, 4.1, -1.6)
        _centers.append(center)
        _neuron(center, i)
    # Nearest-neighbor connections form a web rather than disconnected motifs.
    for i in range(_centers.size()):
        var neighbors: Array[int] = []
        for j in range(i + 1, _centers.size()):
            if _centers[i].distance_to(_centers[j]) < 5.6:
                neighbors.append(j)
        for j in neighbors.slice(0, 4):
            _axon(_centers[i], _centers[j], i, j)
    _build_instances()

func _neuron(center: Vector3, index: int) -> void:
    var color: Color = PALETTE[1] if index == 7 else PALETTE[index % PALETTE.size()]
    var grain_count := 240 if index in [4, 7, 14] else 160
    for i in range(grain_count):
        var theta := float(i) * 2.39996
        var y := 1.0 - 2.0 * (float(i) + 0.5) / float(grain_count)
        var radius := _rng.randf_range(0.065, 0.19)
        var direction := Vector3(sqrt(1.0 - y*y) * cos(theta), y, sqrt(1.0-y*y) * sin(theta))
        _point(center + direction * radius, _rng.randf_range(0.027, 0.049), color.lerp(Color(0.9, 0.81, 0.68), 0.24), Color(float(index) / 48.0, _rng.randf(), 0, 1))
    for arm in range(8):
        var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
        var length_value := _rng.randf_range(0.65, 1.2)
        var end := center + direction * length_value
        var bend := direction.cross(Vector3.UP).normalized() * 0.18
        _curve(center, end, bend, 0.011, color, index, 10)
        for side in [-1.0, 1.0]:
            var fork := end + (direction + Vector3(side * 0.55, 0.27, side * 0.2)).normalized() * length_value * 0.48
            _curve(end, fork, bend * side * 0.5, 0.005, color, index, 6)
            for p in range(4):
                _point(fork + Vector3(_rng.randf_range(-0.045, 0.045), _rng.randf_range(-0.045, 0.045), _rng.randf_range(-0.045, 0.045)), 0.014, color, Color(float(index)/48.0, _rng.randf(), 0.6, 1))

func _axon(start: Vector3, end: Vector3, i: int, j: int) -> void:
    var bend := (end - start).cross(Vector3.UP).normalized() * _rng.randf_range(-0.6, 0.6) + Vector3.UP * 0.3
    var color: Color = PALETTE[i % 4].lerp(PALETTE[j % 4], 0.5)
    _curve(start, end, bend, 0.011, color, i, 22)
    for k in range(36):
        var t := float(k) / 35.0
        var p := start.lerp(end, t) + bend * sin(PI*t)
        _point(p, 0.023, color.lerp(Color(0.8, 0.85, 0.81), 0.3), Color(float(i)/48.0, t, 1.0, 1))

func _curve(start: Vector3, end: Vector3, bend: Vector3, width: float, color: Color, index: int, steps: int) -> void:
    for i in range(steps):
        var a := float(i) / float(steps)
        var b := float(i + 1) / float(steps)
        var p := start.lerp(end, a) + bend * sin(PI*a)
        var q := start.lerp(end, b) + bend * sin(PI*b)
        var direction := (q-p).normalized()
        var right := direction.cross(Vector3.FORWARD).normalized()
        if right.length_squared() < 0.01:
            right = Vector3.RIGHT
        var basis := Basis(right, direction, right.cross(direction)).scaled_local(Vector3(width, p.distance_to(q), width))
        _segments.append(Transform3D(basis, (p+q)*0.5))
        _segment_colors.append(color)
        _segment_data.append(Color(float(index)/48.0, (a+b)*0.5, _rng.randf(), 1))

func _point(p: Vector3, size: float, color: Color, data: Color) -> void:
    _points.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), p))
    _point_colors.append(color)
    _point_data.append(data)

func _build_instances() -> void:
    var branch_mesh := CylinderMesh.new()
    branch_mesh.top_radius = 0.5
    branch_mesh.bottom_radius = 0.5
    branch_mesh.height = 1.0
    branch_mesh.radial_segments = 4
    branch_mesh.rings = 1
    _multimesh("DendritesAndAxons", branch_mesh, _segments, _segment_colors, _segment_data, "res://experiences/neural_constellation/fibers.gdshader")
    var point_mesh := QuadMesh.new()
    point_mesh.size = Vector2.ONE
    _multimesh("SynapsesAndSignals", point_mesh, _points, _point_colors, _point_data, "res://experiences/neural_constellation/synapses.gdshader")

func _multimesh(label: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], attributes: Array[Color], shader_path: String) -> void:
    var material := ShaderMaterial.new()
    material.shader = load(shader_path)
    if shader_path.ends_with("synapses.gdshader"):
        material.set_shader_parameter("neuron_centers", PackedVector3Array(_centers))
    _materials.append(material)
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.use_colors = true
    instances.use_custom_data = true
    instances.mesh = mesh
    instances.instance_count = transforms.size()
    for i in range(transforms.size()):
        instances.set_instance_transform(i, transforms[i])
        instances.set_instance_color(i, colors[i])
        instances.set_instance_custom_data(i, attributes[i])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = instances
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.custom_aabb = AABB(Vector3(-14,-5,-14), Vector3(28,25,28))
    add_child(node)

func update_experience(state: Dictionary) -> void:
    for material in _materials:
        material.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
        material.set_shader_parameter("breath_fill", float(state.get("breath_fill", 0.0)))
        var cycle_angle := PI * float(state.get("inhale_t", 0.0)) if bool(state.get("is_inhale", true)) else PI + PI * float(state.get("exhale_t", 0.0))
        material.set_shader_parameter("cycle_angle", cycle_angle)
        material.set_shader_parameter("intensity", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
