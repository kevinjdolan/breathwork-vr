extends Node3D
## A quiet, suspended cathedral of folded chromatic geometry.

const ROOT := "res://experiences/prismatic_sanctuary/"
var _materials: Array[ShaderMaterial] = []
var _flowers: Array[Node3D] = []
var _fill := 0.0
var _lanterns: Array[Node3D] = []
var _lantern_centers: Array[Vector3] = []

func _ready() -> void:
    var shell := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 80.0
    sphere.height = 160.0
    shell.mesh = sphere
    shell.material_override = _material("dome.gdshader")
    add_child(shell)
    var positions: Array[Vector3] = [Vector3(0, 3.8, -10), Vector3(-7, 3, -5), Vector3(7, 3, -5), Vector3(-8, 5, 5), Vector3(8, 5, 5), Vector3(0, 11, 0), Vector3(0, 5, 12)]
    for index in positions.size():
        var flower := Node3D.new()
        flower.position = positions[index]
        add_child(flower)
        flower.look_at(Vector3(0, 1.4, 0), Vector3.FORWARD if index == 5 else Vector3.UP)
        var mesh := MeshInstance3D.new()
        mesh.mesh = _rosette(index)
        var shader := _material("geometry.gdshader")
        shader.set_shader_parameter("seed", float(index))
        mesh.material_override = shader
        flower.add_child(mesh)
        _flowers.append(flower)
    _make_lanterns()
    _make_sparks()

func _material(shader_file: String) -> ShaderMaterial:
    var result := ShaderMaterial.new()
    result.shader = load(ROOT + shader_file)
    _materials.append(result)
    return result

func _rosette(index: int) -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_normal(Vector3.FORWARD)
    var colors: Array[Color] = [Color(0.15, 0.9, 1.0), Color(1.0, 0.43, 0.14), Color(0.63, 0.25, 1.0)]
    # Three folded planes create actual stereoscopic depth, rather than a flat mandala.
    for tier in 3:
        var count := 144
        var radius := 1.65 + float(tier) * 0.52
        var previous := Vector3.ZERO
        for step in count + 1:
            var angle := TAU * float(step) / count
            var petal := 1.0 + 0.16 * cos(angle * float(9 + index % 4) + float(tier) * 0.4)
            var point := Vector3(cos(angle) * radius * petal, sin(angle) * radius * petal, sin(angle * 6.0 + tier) * 0.34 + float(tier) * 0.27)
            if step > 0:
                _bar(surface, previous, point, 0.011 if tier < 2 else 0.008, colors[(tier + index) % 3])
            previous = point
        for spoke in 12:
            var a := TAU * float(spoke) / 12.0
            var b := a + TAU * 5.0 / 12.0
            var start := Vector3(cos(a) * radius, sin(a) * radius, tier * 0.27)
            var end := Vector3(cos(b) * radius, sin(b) * radius, tier * 0.27)
            _bar(surface, start, end, 0.005, colors[(tier + index + 1) % 3] * 0.7)
            if tier == 1:
                var root := Vector3(cos(a) * 0.92, sin(a) * 0.92, -0.25)
                var tip := Vector3(cos(a) * 2.6, sin(a) * 2.6, 0.35)
                var left := Vector3(cos(a - 0.12) * 1.9, sin(a - 0.12) * 1.9, 0.1)
                var right := Vector3(cos(a + 0.12) * 1.9, sin(a + 0.12) * 1.9, 0.1)
                _triangle(surface, root, left, tip, colors[(spoke + index) % 3] * 0.11)
                _triangle(surface, root, tip, right, colors[(spoke + index) % 3] * 0.045)
    return surface.commit()

func _bar(surface: SurfaceTool, start: Vector3, end: Vector3, width: float, color: Color) -> void:
    var tangent := (end - start).normalized()
    var side := tangent.cross(Vector3.UP if abs(tangent.z) > 0.9 else Vector3.FORWARD).normalized() * width
    surface.set_color(color)
    for point in [start - side, start + side, end + side, start - side, end + side, end - side]:
        surface.add_vertex(point)

func _make_sparks() -> void:
    var particles := GPUParticles3D.new()
    particles.name = "PrismaticDust"
    particles.amount = 2800
    particles.lifetime = 600.0
    particles.explosiveness = 1.0
    particles.local_coords = true
    particles.fixed_fps = 0
    particles.visibility_aabb = AABB(Vector3(-35, -20, -35), Vector3(70, 60, 70))
    particles.process_material = _material("sparks.gdshader")
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    quad.material = _material("spark_draw.gdshader")
    particles.draw_pass_1 = quad
    add_child(particles)

func update_experience(state: Dictionary) -> void:
    var time := float(state.get("elapsed", 0.0))
    # Continuous breath fill; holds are a settling moment with no discrete shape switch.
    _fill = float(state.get("breath_fill", 0.0))
    for material in _materials:
        material.set_shader_parameter("elapsed", time)
        material.set_shader_parameter("intensity", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", _fill)
    for index in _flowers.size():
        var flower := _flowers[index]
        # Absolute animation is deterministic and cannot accumulate frame-rate-dependent motion.
        var basis_base := Basis.looking_at(Vector3(0, 1.4, 0) - flower.position, Vector3.FORWARD if index == 5 else Vector3.UP)
        flower.basis = basis_base * Basis(Vector3.FORWARD, sin(time * 0.027 + index * 1.9) * 0.12)

    for index in _lanterns.size():
        var lantern := _lanterns[index]
        var phase := float(index) * 2.39996
        lantern.position = _lantern_centers[index] + Vector3(sin(time * 0.043 + phase), cos(time * 0.031 + phase), sin(time * 0.027 + phase * 2.0)) * 0.16
        lantern.rotation = Vector3(time * 0.012 + phase, time * 0.019, sin(time * 0.03 + phase) * 0.2)

func _make_lanterns() -> void:
    var points: Array[Vector3] = []
    var golden := (1.0 + sqrt(5.0)) / 2.0
    for a in [-1.0, 1.0]:
        for b in [-golden, golden]:
            points.append(Vector3(0, a, b).normalized())
            points.append(Vector3(a, b, 0).normalized())
            points.append(Vector3(b, 0, a).normalized())
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_normal(Vector3.FORWARD)
    var face_index := 0
    for a in points.size():
        for b in range(a + 1, points.size()):
            if points[a].distance_to(points[b]) < 1.1:
                _bar(surface, points[a], points[b], 0.012, Color(0.1, 0.48, 0.65))
                for c in range(b + 1, points.size()):
                    if points[a].distance_to(points[c]) < 1.1 and points[b].distance_to(points[c]) < 1.1:
                        var center := (points[a] + points[b] + points[c]) / 3.0
                        var outer: Array[Vector3] = []
                        var inner: Array[Vector3] = []
                        for vertex in [points[a], points[b], points[c]]:
                            outer.append(center.lerp(vertex, 0.90))
                            inner.append(center.lerp(vertex, 0.40))
                        var palette: Array[Color] = [Color(0.012, 0.19, 0.29), Color(0.26, 0.065, 0.012), Color(0.13, 0.020, 0.24)]
                        var panel_color := palette[face_index % 3]
                        face_index += 1
                        # Open triangular windows reveal a separate, recessed inner crystal.
                        for edge in 3:
                            var next := (edge + 1) % 3
                            _triangle(surface, outer[edge], outer[next], inner[next], panel_color)
                            _triangle(surface, outer[edge], inner[next], inner[edge], panel_color)
                            _bar(surface, inner[edge], inner[next], 0.008, Color(0.70, 0.28, 0.055))
                        _triangle(surface, points[a] * 0.59, points[b] * 0.59, points[c] * 0.59, Color(0.085, 0.025, 0.22).lerp(Color(0.018, 0.15, 0.18), float((a + c) % 3) / 2.0))
    var geometry := surface.commit()
    for index in 18:
        var angle := float(index) * 2.39996
        var elevation := -0.22 + float(index % 6) * 0.30
        var distance := 3.3 + float(index % 4) * 1.1
        var pos := Vector3(cos(angle) * cos(elevation), sin(elevation), sin(angle) * cos(elevation)) * distance + Vector3(0, 1.4, 0)
        var lantern := MeshInstance3D.new()
        lantern.name = "FacetLantern%d" % index
        lantern.mesh = geometry
        if index == 0:
            pos = Vector3(-1.4, 2.0, -2.7)
        elif index == 1:
            pos = Vector3(2.5, 3.0, -4.5)
        lantern.position = pos
        lantern.scale = Vector3.ONE * (0.40 + float(index % 3) * 0.085)
        var shader := _material("facets.gdshader")
        shader.set_shader_parameter("seed", float(index) + 8.0)
        lantern.material_override = shader
        add_child(lantern)
        _lanterns.append(lantern)
        _lantern_centers.append(pos)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
    surface.set_color(color)
    surface.set_normal((a + b + c).normalized())
    for point in [a, b, c]:
        surface.add_vertex(point)
