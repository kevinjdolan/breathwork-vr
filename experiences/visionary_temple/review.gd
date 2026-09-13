extends SceneTree
## Standalone renders of each passage, seated and reclined, without XR hardware or audio.
var _layer: Node3D
var _camera: Camera3D
var _frame: int = 0
var _shots: Array = [
    [40.0, 2.0, 0.0, "eyes_inhale"], [70.0, 6.0, 80.0, "eyes_reclined_hold"],
    [150.0, 10.0, 0.0, "flames_exhale"], [190.0, 2.0, 0.0, "flames_inhale"],
    [270.0, 2.0, 0.0, "rings_inhale"], [300.0, 10.0, 80.0, "rings_reclined_exhale"],
    [400.0, 2.0, 0.0, "temple_inhale"], [430.0, 6.0, 0.0, "temple_hold"], [430.0, 6.0, 80.0, "temple_reclined"],
    [232.0, 12.0, 0.0, "dissolve_flames_to_rings"],
]

func _initialize() -> void:
    root.size = Vector2i(1440, 900)
    DirAccess.make_dir_recursive_absolute("res://verification/visionary_temple")
    var world: Node3D = Node3D.new()
    root.add_child(world)
    var environment: WorldEnvironment = WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.012, 0.004, 0.022)
    world.add_child(environment)
    _camera = Camera3D.new()
    _camera.position = Vector3(0, 1.4, 0)
    _camera.fov = 90.0
    world.add_child(_camera)
    _layer = load("res://experiences/visionary_temple/layer.gd").new()
    world.add_child(_layer)

func _process(_delta: float) -> bool:
    var shot: int = _frame / 12
    if shot >= _shots.size():
        quit()
        return true
    var spec: Array = _shots[shot]
    _camera.rotation.x = deg_to_rad(float(spec[2]))
    var phase: float = float(spec[1])
    var fill: float = smoothstep(0.0, 4.0, phase) if phase < 8.0 else 1.0 - smoothstep(8.0, 14.0, phase)
    if _frame % 12 == 0:
        _layer.reset_journey()
    _layer.update_experience({"elapsed": float(spec[0]) + float(_frame % 12) / 60.0, "phase_seconds": phase, "intensity": 1.0, "breath_fill": fill, "head_position": _camera.position, "head_basis": _camera.global_basis, "mouth_position": _camera.position + _camera.global_basis * Vector3(0, -.08, -.06)})
    if _frame % 12 == 11:
        _capture(str(spec[3]))
    _frame += 1
    return false

func _capture(label: String) -> void:
    if DisplayServer.get_name() == "headless":
        return
    RenderingServer.force_draw(false, 0.0)
    root.get_texture().get_image().save_png("res://verification/visionary_temple/" + label + ".png")
    print("VISIONARY CAPTURE ", label)
