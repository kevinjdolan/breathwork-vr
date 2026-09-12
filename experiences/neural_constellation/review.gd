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
    environment.environment.background_color = Color(0.007, 0.009, 0.023)
    scene.add_child(environment)
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.4, 0)
    camera.fov = 85
    scene.add_child(camera)
    layer = load("res://experiences/neural_constellation/layer.gd").new()
    scene.add_child(layer)

func _process(_delta: float) -> bool:
    ticks += 1
    if ticks == 1:
        var fibers := (layer.get_node("DendritesAndAxons") as MultiMeshInstance3D).multimesh.instance_count
        var points := (layer.get_node("SynapsesAndSignals") as MultiMeshInstance3D).multimesh.instance_count
        print("NEURAL_BUDGET fibers=", fibers, " points=", points)
        assert(points <= 6000)
    var phase_index := mini((ticks - 1) / 90, 5)
    var reclined := phase_index >= 2 and phase_index < 4
    camera.rotation_degrees.x = 78.0 if reclined else 0.0
    var fill := float(phase_index % 2)
    var elapsed := 102.0 if fill > 0.0 else 96.0
    if phase_index >= 4:
        elapsed = 34.5 if phase_index == 4 else 14.8
        fill = 0.5
    layer.update_experience({"elapsed": elapsed, "intensity": 1.0, "breath_fill": fill, "inhale_t": fill, "exhale_t": 1.0 - fill, "is_inhale": fill > 0.0})
    if ticks % 90 == 0:
        RenderingServer.force_draw(false, 0.0)
        var suffix := ("inhale" if fill > 0.0 else "exhale") + ("_reclined" if reclined else "_seated")
        if phase_index >= 4:
            suffix = "dissolving_seated" if phase_index == 4 else "gathered_seated"
        root.get_texture().get_image().save_png("res://verification/neural_constellation/" + suffix + ".png")
    if ticks >= 540:
        quit()
    return false
