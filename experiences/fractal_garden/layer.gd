extends Node3D
## A three-dimensional conservatory grown from Barnsley's four affine fern maps.

const POINT_SHADER = preload("res://experiences/fractal_garden/points.gdshader")
const BRANCH_SHADER = preload("res://experiences/fractal_garden/branches.gdshader")
var _materials: Array[ShaderMaterial] = []
var _rng := RandomNumberGenerator.new()
var _points: Array[Transform3D] = []
var _colors: Array[Color] = []
var _attributes: Array[Color] = []
var _branches: Array[Transform3D] = []
var _seed_centers := PackedVector3Array([Vector3(-1.7, 0.45, -2.7), Vector3(1.8, 0.65, -3.0), Vector3(-1.35, 3.8, -0.8), Vector3(1.5, 4.4, -0.15), Vector3(-0.25, 5.1, 1.75)])

func _ready() -> void:
    _rng.seed = 621409
    # Different elevations, depths and inclinations preserve stereo structure.
    for i in range(9):
        var angle := TAU * float(i) / 9.0 + 0.18
        var radius := 4.3 + float(i % 3) * 2.2
        var origin := Vector3(sin(angle) * radius, -0.55, cos(angle) * radius)
        var basis := Basis(Vector3.UP, angle)
        if i >= 6:
            angle = TAU * float(i - 6) / 3.0 + 0.25
            radius = 3.8 + float(i - 6) * 1.1
            origin = Vector3(sin(angle) * radius, 4.0 + float(i - 6) * 0.6, cos(angle) * radius)
            basis = Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, -1.2)
        _fern(origin, basis, 0.53 + float(i % 3) * 0.065, i)
    for i in range(_seed_centers.size()):
        _seedpod(i)
    # A low recursive root lattice anchors the floating fern canopy.
    for i in range(7):
        var angle := TAU * float(i) / 7.0
        var origin := Vector3(sin(angle) * 5.8, -0.8, cos(angle) * 5.8)
        _branch(origin, Vector3(sin(angle) * 0.2, 1.0, cos(angle) * 0.2).normalized(), 0.96, 0.023, 5, i)
    _build_points()
    _build_branches()

func _fern(origin: Vector3, basis: Basis, scale_factor: float, index: int) -> void:
    var p := Vector2.ZERO
    for j in range(580):
        var r := _rng.randf()
        # Barnsley IFS: stem (1%), main leaflet (85%), left/right leaflet (7% each).
        if r < 0.01:
            p = Vector2(0.0, 0.16 * p.y)
        elif r < 0.86:
            p = Vector2(0.85 * p.x + 0.04 * p.y, -0.04 * p.x + 0.85 * p.y + 1.6)
        elif r < 0.93:
            p = Vector2(0.2 * p.x - 0.26 * p.y, 0.23 * p.x + 0.22 * p.y + 1.6)
        else:
            p = Vector2(-0.15 * p.x + 0.28 * p.y, 0.26 * p.x + 0.24 * p.y + 0.44)
        if j < 40:
            continue
        # Curl each mathematical lamina into a leaf with real depth.
        var local := Vector3(p.x, p.y, 0.14 * p.x * p.x + 0.24 * sin(p.y * 0.55)) * scale_factor
        var size := _rng.randf_range(0.022, 0.043) * clampf(scale_factor / 0.53, 0.45, 1.25)
        _points.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), origin + basis * local))
        var palette := [Color(0.34, 0.77, 0.47), Color(0.68, 0.82, 0.38), Color(0.32, 0.67, 0.64), Color(0.83, 0.65, 0.31)]
        var color: Color = palette[index % 4]
        color = color.lerp(Color(0.88, 0.94, 0.70), _rng.randf_range(0.0, 0.3))
        color.a = _rng.randf_range(0.59, 0.82)
        _colors.append(color)
        _attributes.append(Color(float(index) / 11.0, p.y / 10.0, _rng.randf(), 1.0))

func _seedpod(index: int) -> void:
    # A tetrahedral IFS has self-similar voids inside its compact 3D volume.
    var vertices := [Vector3(1, 1, 1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1)]
    var p := Vector3.ZERO
    for j in range(225):
        p = (p + vertices[_rng.randi_range(0, 3)]) * 0.5
        if j < 25:
            continue
        var size := _rng.randf_range(0.013, 0.022)
        var local := p * 0.30
        _points.append(Transform3D(Basis.from_scale(Vector3.ONE * size), _seed_centers[index] + local))
        var palette := [Color(0.49, 0.87, 0.63, 0.66), Color(0.93, 0.73, 0.36, 0.62), Color(0.51, 0.77, 0.81, 0.68)]
        _colors.append(palette[index % 3])
        _attributes.append(Color(float(index), _rng.randf(), _rng.randf(), 0.0))

func _branch(start: Vector3, direction: Vector3, length_value: float, width: float, depth: int, seed_value: int) -> void:
    var finish := start + direction * length_value
    var tangent := direction.cross(Vector3.FORWARD).normalized()
    if tangent.length_squared() < 0.01:
        tangent = Vector3.RIGHT
    var basis := Basis(tangent, direction, tangent.cross(direction)) * Basis.from_scale(Vector3(width, length_value, width))
    _branches.append(Transform3D(basis, (start + finish) * 0.5))
    if depth <= 0:
        return
    var axis := Vector3(sin(float(seed_value) * 2.399), 0.15, cos(float(seed_value) * 2.399)).normalized()
    for side in [-1.0, 1.0]:
        var child := direction.rotated(axis, side * 0.51).normalized()
        _branch(finish, child, length_value * 0.72, width * 0.69, depth - 1, seed_value + 3)

func _build_points() -> void:
    var material := ShaderMaterial.new()
    material.shader = POINT_SHADER
    material.set_shader_parameter("seed_centers", _seed_centers)
    _materials.append(material)
    var mesh := QuadMesh.new()
    mesh.size = Vector2.ONE
    mesh.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.use_custom_data = true
    multi.mesh = mesh
    multi.instance_count = _points.size()
    for i in range(_points.size()):
        multi.set_instance_transform(i, _points[i])
        multi.set_instance_color(i, _colors[i])
        multi.set_instance_custom_data(i, _attributes[i])
    var node := MultiMeshInstance3D.new()
    node.name = "BarnsleyFernCanopy"
    node.multimesh = multi
    node.custom_aabb = AABB(Vector3(-20, -4, -20), Vector3(40, 30, 40))
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _build_branches() -> void:
    var material := ShaderMaterial.new()
    material.shader = BRANCH_SHADER
    _materials.append(material)
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.7
    mesh.bottom_radius = 1.0
    mesh.height = 1.0
    mesh.radial_segments = 5
    mesh.rings = 1
    mesh.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = _branches.size()
    for i in range(_branches.size()):
        multi.set_instance_transform(i, _branches[i])
    var node := MultiMeshInstance3D.new()
    node.name = "RecursiveRootTrees"
    node.multimesh = multi
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func update_experience(state: Dictionary) -> void:
    for material in _materials:
        material.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", float(state.get("breath_fill", 0.0)))
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
