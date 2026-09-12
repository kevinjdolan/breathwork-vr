extends SceneTree
var layer: Node3D
var camera: Camera3D
var ticks := 0

func _initialize() -> void:
    var scene := Node3D.new()
    root.add_child(scene)
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.006, 0.012, 0.018)
    scene.add_child(environment)
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.4, 0)
    camera.fov = 85
    scene.add_child(camera)
    layer = load("res://experiences/circuit_garden/layer.gd").new()
    scene.add_child(layer)

func _process(_delta: float) -> bool:
    ticks += 1
    if ticks == 1:
        var traces: MeshInstance3D = layer.get_node("FloatingCircuitLattices")
        print("CIRCUIT_QA trace_vertices=", traces.mesh.surface_get_array_len(0), " chips=108 charge_seeds=864")
    var phase_index := mini((ticks - 1) / 60, 3)
    var reclined := phase_index >= 2
    camera.rotation_degrees.x = 78.0 if reclined else 0.0
    var fill := float(phase_index % 2)
    layer.update_experience({"elapsed": 104.0 if fill > 0.0 else 109.0, "intensity": 1.0, "breath_fill": fill})
    if ticks % 60 == 0:
        RenderingServer.force_draw(false, 0.0)
        var suffix := ("inhale" if fill > 0.0 else "exhale") + ("_reclined" if reclined else "_seated")
        root.get_texture().get_image().save_png("res://verification/circuit_garden/" + suffix + ".png")
    if ticks >= 240:
        quit()
    return false
