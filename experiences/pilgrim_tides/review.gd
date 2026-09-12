extends SceneTree
## Render both breath extrema and an overhead view using the real mobile renderer.
var _layer: Node3D
var _camera: Camera3D
var _frame := 0

func _initialize() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.006, 0.012, 0.023)
    world.add_child(environment)
    _camera = Camera3D.new()
    _camera.position = Vector3(0, 1.4, 0)
    _camera.fov = 90.0
    world.add_child(_camera)
    _layer = load("res://experiences/pilgrim_tides/layer.gd").new()
    world.add_child(_layer)

func _process(_delta: float) -> bool:
    _frame += 1
    if _frame == 1:
        var people: MultiMeshInstance3D = _layer.get_node("QuietProcessions640")
        print("PILGRIM_REVIEW people=", people.multimesh.instance_count, " triangles_per_person=", people.multimesh.mesh.get_faces().size() / 3)
    var fill := 0.0 if _frame <= 60 else 1.0
    _layer.update_experience({"elapsed": 120.0 + float(_frame) / 60.0, "intensity": 1.0, "breath_fill": fill})
    if _frame == 60:
        _capture("seated_exhale")
    if _frame == 120:
        _capture("seated_hold")
        _camera.rotation.x = deg_to_rad(80.0)
    if _frame == 180:
        _capture("reclined_hold")
        quit()
    return false

func _capture(label: String) -> void:
    if DisplayServer.get_name() == "headless":
        return
    RenderingServer.force_draw(false, 0.0)
    root.get_texture().get_image().save_png("res://verification/pilgrim_tides/" + label + ".png")
