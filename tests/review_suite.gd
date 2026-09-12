extends SceneTree
## Render the actual integrated scenes in contrasting phases and reclined posture.

var scene: Node
var director: MeditationDirector
var index: int = -1
var frame: int = 0
var pose: int = 0
var entries: Array = ExperienceCatalog.all()

func _initialize() -> void:
    for arg: String in OS.get_cmdline_user_args():
        if arg == "--ready-only":
            entries = entries.filter(func(entry: Dictionary) -> bool: return ResourceLoader.exists("res://" + str(entry["music"])))
        elif arg.begins_with("--only="):
            var id: String = arg.get_slice("=", 1)
            entries = entries.filter(func(entry: Dictionary) -> bool: return entry["id"] == id)
    root.size = Vector2i(1440, 900)
    DirAccess.make_dir_recursive_absolute("res://verification/suite")
    _next.call_deferred()

func _next() -> void:
    if scene != null:
        root.remove_child(scene)
        scene.free()
    index += 1
    if index == entries.size():
        var menu: Node = load("res://scenes/startup.tscn").instantiate()
        root.add_child(menu)
        for wait: int in range(60):
            await process_frame
        RenderingServer.force_draw(false, 0.0)
        root.get_texture().get_image().save_png("res://verification/suite/menu.png")
        quit()
        return
    root.set_meta("experience_id", entries[index]["id"])
    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    director = scene.get_node("Director")
    director.camera.get_parent().position = Vector3(0, 1.4, 0)
    frame = 0
    pose = 0

func _process(_delta: float) -> bool:
    if director == null or index >= entries.size():
        return false
    frame += 1
    var rhythm: Array = entries[index]["rhythm"]
    var phase_time: float = float(rhythm[0]) * 0.75 if pose != 1 else float(rhythm[0]) + float(rhythm[1]) + float(rhythm[2]) * 0.65
    director.elapsed = director.clock.loop_seconds * 8.0 + phase_time + float(frame % 60) / 600.0
    director.clock.update_from_position(phase_time, director.elapsed)
    director.arc.seek(director.elapsed, true)
    director.fade = 0.0
    director.breath_particles_enabled = 1.0
    director._gaze_direction = -director.camera.global_basis.z
    director._follow_orb(10.0)
    director._push_visuals(1.0 / 60.0)
    if frame % 60 == 0:
        RenderingServer.force_draw(false, 0.0)
        var path: String = "res://verification/suite/" + str(entries[index]["id"]) + "_" + ["inhale", "exhale", "reclined"][pose] + ".png"
        root.get_texture().get_image().save_png(path)
        print("INTEGRATED CAPTURE ", path)
        pose += 1
        if pose == 2:
            director.camera.rotation.x = deg_to_rad(80)
            director.camera.get_parent().position.y = 0.65
        elif pose == 3:
            director = null
            _next.call_deferred()
    return false
