extends Node3D
## Slow sculptural cloud rivers whose vaults gently open with each inhale.

const CLOUD_SHADER = preload("res://experiences/cloud_atelier/cloud.gdshader")
const PEARL_SHADER = preload("res://experiences/cloud_atelier/pearls.gdshader")
var _materials: Array[ShaderMaterial] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.seed = 510820
    _build_clouds()
    _build_pearls()

func _build_clouds() -> void:
    var material := ShaderMaterial.new()
    material.shader = CLOUD_SHADER
    _materials.append(material)
    var mesh := QuadMesh.new()
    mesh.size = Vector2.ONE
    mesh.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.use_custom_data = true
    multi.mesh = mesh
    multi.instance_count = 1434
    for river in range(7):
        var angle := TAU * float(river) / 7.0
        var basis := Basis(Vector3.UP, angle)
        var radius := 4.7 + float(river % 3) * 1.2
        for puff in range(90):
            var u := float(puff) / 89.0
            u += sin(u * TAU) * 0.075
            # A finite curling cloud bank: each river has an open inner edge.
            var sweep := lerpf(-1.45, 1.45, u)
            var center := Vector3(sin(sweep) * radius, 1.8 + cos(sweep) * (2.8 + float(river % 2)), -radius + cos(sweep) * 0.65)
            var thickness := 0.70 + 0.35 * sin(u * 9.0 + float(river))
            center += Vector3(_rng.randfn() * 0.44, _rng.randfn() * 0.39, _rng.randfn() * 0.48) * thickness
            center = basis * center
            if river >= 4:
                center.y += 2.4
                center.x *= 0.72
                center.z *= 0.72
            var size := _rng.randf_range(0.84, 1.65) * thickness
            multi.set_instance_transform(river * 90 + puff, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), center))
            var tint := Color(0.40, 0.56, 0.76).lerp(Color(0.88, 0.53, 0.49), float(river % 3) * 0.36)
            tint = tint.lerp(Color(0.72, 0.78, 0.85), u * 0.25)
            tint.a = _rng.randf_range(0.16, 0.24)
            multi.set_instance_color(river * 90 + puff, tint)
            multi.set_instance_custom_data(river * 90 + puff, Color(_rng.randf(), u, float(river) / 7.0, _rng.randf()))
    # Overlapping stratus islands replace a regularly spaced circular chain.
    var bank_centers := [Vector3(-4.0, -0.1, -7.0), Vector3(3.8, 0.05, -8.1), Vector3(0.1, -0.8, -10.5)]
    for bank in range(3):
        for puff in range(64):
            var u := _rng.randf_range(-1.0, 1.0)
            var thickness := sqrt(maxf(0.0, 1.0 - u * u))
            var local := Vector3(u * (3.8 + float(bank) * 0.35), _rng.randfn() * 0.20 * thickness, _rng.randfn() * 0.60 * thickness)
            local.y += 0.25 * sin(u * 4.0 + float(bank))
            local.z += 0.70 * sin(u * 2.4 + float(bank))
            var center: Vector3 = bank_centers[bank] + local
            var size := _rng.randf_range(0.78, 1.68) * (0.6 + 0.4 * thickness)
            var index := 630 + bank * 64 + puff
            multi.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), center))
            multi.set_instance_color(index, Color(0.43 + float(bank) * 0.035, 0.56, 0.72, 0.19))
            multi.set_instance_custom_data(index, Color(_rng.randf(), (u + 1.0) * 0.5, 0.5, _rng.randf()))
    # Small close whorls sit to the sides, leaving the mouth-to-orb corridor open.
    var close_centers := [Vector3(-2.9, 1.65, -2.2), Vector3(3.2, 2.25, -2.1), Vector3(-2.7, 4.0, 0.6)]
    for whorl in range(3):
        for puff in range(24):
            var u := float(puff) / 23.0
            var angle := u * TAU * 0.9
            var radius := 0.12 + 0.48 * u
            var center: Vector3 = close_centers[whorl] + Vector3(cos(angle) * radius, sin(angle) * radius * 0.62, u * 0.48)
            center += Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn()) * 0.08
            var size := _rng.randf_range(0.38, 0.72) * (1.0 - 0.35 * u)
            var index := 822 + whorl * 24 + puff
            multi.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), center))
            multi.set_instance_color(index, Color(0.70, 0.55 + float(whorl) * 0.035, 0.63, 0.17))
            multi.set_instance_custom_data(index, Color(_rng.randf(), u, 0.8, _rng.randf()))
    # Higher layered helical cloud islands fill the reclining dome with parallax.
    for island in range(9):
        var angle := float(island)*2.399963
        var anchor := Vector3(cos(angle)*4.3, 5.0 + float(island%3)*1.4, sin(angle)*4.3)
        for puff in range(60):
            var u := float(puff)/59.0
            var spin := u*TAU*1.4 + float(island)
            var offset := Vector3(cos(spin), sin(spin)*.55, (u-.5)*2.4) * (.45+.5*u)
            var size := _rng.randf_range(.35,.72)
            var index := 894 + island*60+puff
            multi.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),anchor+offset))
            multi.set_instance_color(index,Color(.65,.62+float(island%3)*.04,.79,.14))
            multi.set_instance_custom_data(index,Color(_rng.randf(),u,float(island)/9.0,_rng.randf()))
    _add_multi(multi, "SculptedCloudRivers")

func _build_pearls() -> void:
    var material := ShaderMaterial.new()
    material.shader = PEARL_SHADER
    _materials.append(material)
    var mesh := QuadMesh.new()
    mesh.size = Vector2.ONE
    mesh.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.use_custom_data = true
    multi.mesh = mesh
    multi.instance_count = 2520
    for i in range(2520):
        var shoal := i / 70
        var angle := float(shoal) * 2.399
        var elevation := asin(1.0 - 2.0*(float(shoal)+0.5)/36.0)
        var radius := 2.8 + float(shoal % 3) * 1.3
        var center := Vector3(sin(angle) * cos(elevation), sin(elevation), cos(angle) * cos(elevation)) * radius + Vector3(0, 1.4, 0)
        var t := float(i % 70) / 70.0 * TAU
        center += Vector3(cos(t) * 0.28, sin(t * 2.0) * 0.16, sin(t) * 0.28)
        var size := _rng.randf_range(0.009, 0.024)
        multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), center))
        multi.set_instance_color(i, Color(0.64, 0.76, 0.87, 0.5))
        multi.set_instance_custom_data(i, Color(float(shoal) / 36.0, t / TAU, _rng.randf(), 1.0))
    _add_multi(multi, "CondensationPearls")

func _add_multi(multi: MultiMesh, node_name: String) -> void:
    var node := MultiMeshInstance3D.new()
    node.name = node_name
    node.multimesh = multi
    node.custom_aabb = AABB(Vector3(-20, -4, -20), Vector3(40, 30, 40))
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func update_experience(state: Dictionary) -> void:
    for material in _materials:
        material.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", float(state.get("breath_fill", 0.0)))
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
