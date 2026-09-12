extends Node3D
## Tiny wanderers trace breathable paths through a still, three-dimensional night.

var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
    _build_people()
    _build_ribbons()

func _build_people() -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    _box(surface, Vector3(0.0, 0.61, 0.0), Vector3(0.33, 0.39, 0.20))
    _box(surface, Vector3(-0.10, 0.22, 0.0), Vector3(0.125, 0.44, 0.13))
    _box(surface, Vector3(0.10, 0.22, 0.0), Vector3(0.125, 0.44, 0.13))
    _box(surface, Vector3(-0.245, 0.60, 0.0), Vector3(0.12, 0.33, 0.12))
    _box(surface, Vector3(0.245, 0.60, 0.0), Vector3(0.12, 0.33, 0.12))
    var head := SphereMesh.new()
    head.radius = 0.145
    head.height = 0.29
    head.radial_segments = 6
    head.rings = 3
    surface.append_from(head, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.965, 0.0)))
    var mesh := surface.commit()
    var material := ShaderMaterial.new()
    material.shader = preload("res://experiences/pilgrim_tides/people.gdshader")
    mesh.surface_set_material(0, material)
    _materials.append(material)
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.use_custom_data = true
    multi.mesh = mesh
    multi.instance_count = 1920
    var rng := RandomNumberGenerator.new()
    rng.seed = 76213
    var palette := [Color(0.78, 0.83, 0.82), Color(0.61, 0.81, 0.76), Color(0.83, 0.69, 0.51), Color(0.65, 0.67, 0.85)]
    for i in range(1920):
        var group := i / 120
        multi.set_instance_transform(i, Transform3D.IDENTITY)
        multi.set_instance_custom_data(i, Color(float(group) / 16.0, (float(i % 120) + rng.randf() * 0.5) / 120.0, rng.randf(), rng.randf()))
        multi.set_instance_color(i, palette[(i / 7 + group) % 4])
    var node := MultiMeshInstance3D.new()
    node.name = "QuietProcessions1920"
    node.multimesh = multi
    node.custom_aabb = AABB(Vector3(-15, -4, -18), Vector3(30, 20, 36))
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _box(surface: SurfaceTool, center: Vector3, size: Vector3) -> void:
    var box := BoxMesh.new()
    box.size = size
    surface.append_from(box, 0, Transform3D(Basis.IDENTITY, center))

func _build_ribbons() -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for group in range(16):
        for step in range(192):
            for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
                surface.set_uv(Vector2((float(step) + corner.x) / 192.0, corner.y))
                surface.set_uv2(Vector2(float(group), 0.0))
                surface.add_vertex(Vector3.ZERO)
    var mesh := surface.commit()
    var material := ShaderMaterial.new()
    material.shader = preload("res://experiences/pilgrim_tides/ribbons.gdshader")
    mesh.surface_set_material(0, material)
    _materials.append(material)
    var node := MeshInstance3D.new()
    node.name = "FloatingPromenades"
    node.mesh = mesh
    node.custom_aabb = AABB(Vector3(-15, -4, -18), Vector3(30, 20, 36))
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func update_experience(state: Dictionary) -> void:
    for material in _materials:
        material.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
        material.set_shader_parameter("breath_fill", float(state.get("breath_fill", 0.0)))
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
