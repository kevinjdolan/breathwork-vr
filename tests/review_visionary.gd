extends SceneTree
## Render the integrated Visionary Temple session through its passages and breath phases.
var director: MeditationDirector
var scene: Node
var shots: Array = [
    [40.0, 2.0, 0.0, "eyes_inhale"], [40.0, 5.0, 0.0, "eyes_hold"], [40.0, 10.0, 0.0, "eyes_exhale"],
    [60.0, 15.0, 80.0, "eyes_reclined_rest"], [108.0, 2.0, 0.0, "dissolve_eyes_flames"],
    [170.0, 2.0, 0.0, "flames_inhale"], [170.0, 9.0, 0.0, "flames_exhale"], [200.0, 6.0, 80.0, "flames_reclined_hold"],
    [290.0, 2.0, 0.0, "rings_inhale"], [290.0, 12.0, 0.0, "rings_exhale"], [348.0, 6.0, 0.0, "dissolve_rings_temple"],
    [410.0, 2.0, 0.0, "temple_inhale"], [410.0, 5.0, 0.0, "temple_hold"], [410.0, 10.0, 0.0, "temple_exhale"], [440.0, 15.0, 80.0, "temple_reclined_rest"],
]
var index: int = 0
var frame: int = 0

func _initialize() -> void:
    root.size = Vector2i(1440, 900)
    DirAccess.make_dir_recursive_absolute("res://verification/visionary_temple")
    root.set_meta("experience_id", "visionary_temple")
    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    begin.call_deferred()

func begin() -> void:
    await process_frame
    director = scene.get_node("Director")
    director.camera.get_parent().position = Vector3(0, 1.4, 0)
    director.camera.position = Vector3.ZERO
    director.set_process(false)
    director.session_menu.set_process(false)

func _process(_delta: float) -> bool:
    if director == null:
        return false
    if index >= shots.size():
        quit()
        return true
    var shot: Array = shots[index]
    if frame == 0:
        director.camera.rotation = Vector3(deg_to_rad(float(shot[2])), 0, 0)
        director.experience_layer.reset_journey()
    director.elapsed = float(shot[0]) + float(frame) / 60.0
    director.clock.update_from_position(float(shot[1]) + float(frame) / 60.0, director.elapsed)
    director.arc.seek(director.elapsed, true)
    director.fade = 0.0
    director.breath_particles_enabled = 1.0
    director._gaze_direction = -director.camera.global_basis.z
    director._follow_orb(1.0 / 60.0)
    director._push_visuals(1.0 / 60.0)
    frame += 1
    if frame == 8:
        RenderingServer.force_draw(false, 0.0)
        root.get_texture().get_image().save_png("res://verification/visionary_temple/scene_" + str(shot[3]) + ".png")
        print("VISIONARY SCENE CAPTURE ", shot[3], " fps_sample_not_headset=true")
        index += 1
        frame = 0
    return false
