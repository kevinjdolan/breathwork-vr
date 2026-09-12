extends Node3D
## Suspended water sculptures with slow breath-shaped folds and drifting droplets.

var _materials: Array[ShaderMaterial] = []
var _droplets: ShaderMaterial

func _ready() -> void:
    for index in range(7):
        var ribbon := MeshInstance3D.new()
        ribbon.name = "LiquidFold%d" % index
        ribbon.mesh = _ribbon_mesh()
        var material := ShaderMaterial.new()
        material.shader = load("res://experiences/tidal_origami/water.gdshader")
        material.set_shader_parameter("seed", float(index))
        material.set_shader_parameter("angle", float(index) * 1.029 + 0.22)
        material.set_shader_parameter("radius", 5.3 + float(index % 3) * 2.7)
        material.set_shader_parameter("arch_height", 3.5 + float(index % 4) * 0.8)
        material.set_shader_parameter("sheet_width", 0.44 + float(index % 3) * 0.15)
        ribbon.material_override = material
        ribbon.custom_aabb = AABB(Vector3(-22, -2, -22), Vector3(44, 24, 44))
        ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(ribbon)
        _materials.append(material)
    var drops := GPUParticles3D.new()
    drops.name = "SuspendedDroplets"
    drops.amount = 2800
    drops.lifetime = 600.0
    drops.explosiveness = 1.0
    drops.preprocess = 0.1
    drops.fixed_fps = 0
    drops.visibility_aabb = AABB(Vector3(-22, -2, -22), Vector3(44, 24, 44))
    _droplets = ShaderMaterial.new()
    _droplets.shader = load("res://experiences/tidal_origami/droplets.gdshader")
    drops.process_material = _droplets
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    var draw := ShaderMaterial.new()
    draw.shader = load("res://experiences/tidal_origami/droplet_draw.gdshader")
    quad.material = draw
    drops.draw_pass_1 = quad
    drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(drops)
    _add_liquid_lenses()
    # Three distant concentric basins provide depth without a flat lake surface.
    for index in range(3):
        var basin := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 13.5 + index * 5.0
        torus.outer_radius = torus.inner_radius + 0.13
        torus.rings = 80
        torus.ring_segments = 8
        basin.mesh = torus
        basin.position.y = -0.9 - index * 0.5
        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color = Color(0.025, 0.16, 0.20)
        basin.material_override = material
        add_child(basin)

func update_experience(state: Dictionary) -> void:
    var elapsed: float = state.get("elapsed", 0.0)
    var fill: float = state.get("breath_fill", 0.0)
    var visibility: float = state.get("intensity", 1.0)
    for material in _materials:
        material.set_shader_parameter("time", elapsed)
        material.set_shader_parameter("breath", fill)
        material.set_shader_parameter("visibility", visibility)
    _droplets.set_shader_parameter("time", elapsed)
    _droplets.set_shader_parameter("breath", fill)
    _droplets.set_shader_parameter("visibility", visibility)
    _droplets.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))

func _ribbon_mesh() -> ArrayMesh:
    var vertices := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    var longitudinal := 120
    var lateral := 10
    for row in range(longitudinal + 1):
        for column in range(lateral + 1):
            var uv := Vector2(float(row) / longitudinal, float(column) / lateral)
            vertices.append(Vector3(uv.x, uv.y, 0))
            uvs.append(uv)
    for row in range(longitudinal):
        for column in range(lateral):
            var a := row * (lateral + 1) + column
            indices.append_array(PackedInt32Array([a, a + 1, a + lateral + 1, a + 1, a + lateral + 2, a + lateral + 1]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _add_liquid_lenses() -> void:
    # Near sculptures stay to the sides; no pool intersects the orb-to-mouth lane.
    var centers := PackedVector3Array([
        Vector3(-2.2, 2.0, -3.4), Vector3(2.7, 2.8, -4.2),
        Vector3(-2.8, 4.0, -0.5), Vector3(1.1, 5.8, -1.1),
        Vector3(2.8, 2.7, 2.2), Vector3(-1.8, 5.1, 2.0),
    ])
    var pool_mesh := SphereMesh.new()
    pool_mesh.radius = 1.0
    pool_mesh.height = 2.0
    pool_mesh.radial_segments = 40
    pool_mesh.rings = 20
    for index in range(centers.size()):
        var pool := MeshInstance3D.new()
        pool.name = "FloatingLens%d" % index
        pool.mesh = pool_mesh
        pool.position = centers[index]
        pool.rotation = Vector3(0.36 + index * 0.08, index * 0.83, 0.2 * sin(index))
        pool.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
        pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var material := ShaderMaterial.new()
        material.shader = load("res://experiences/tidal_origami/liquid.gdshader")
        material.set_shader_parameter("seed", float(index))
        pool.material_override = material
        add_child(pool)
        _materials.append(material)
    var beads := MultiMeshInstance3D.new()
    beads.name = "GatheringLiquidBeads"
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh.radial_segments = 12
    mesh.rings = 6
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_custom_data = true
    multi.mesh = mesh
    multi.instance_count = centers.size() * 9
    for index in range(multi.instance_count):
        var cluster := index / 9
        var bead := index % 9
        multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, centers[cluster]))
        multi.set_instance_custom_data(index, Color(float(bead) / 9.0, float(cluster), 0.035 + float(bead % 4) * 0.017, 1))
    beads.multimesh = multi
    beads.custom_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 14, 16))
    beads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material := ShaderMaterial.new()
    material.shader = load("res://experiences/tidal_origami/liquid.gdshader")
    material.set_shader_parameter("bead_mode", true)
    beads.material_override = material
    add_child(beads)
    _materials.append(material)
