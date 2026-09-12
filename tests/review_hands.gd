extends SceneTree
## GPU preview with synthetic moving hands; never included in the Quest export.

const Fixture = preload("res://tests/hand_fixture.gd")
var director: MeditationDirector
var frame: int = 0
var folder: String = "res://verification/hands_seated"

func _initialize() -> void:
    setup.call_deferred()

func setup() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    director = scene.get_node("Director")
    director.set_process(false)
    director.fade = 0.0
    director.breath_particles_enabled = 1.0
    if "--recline" in OS.get_cmdline_user_args():
        director.camera.rotation.x = deg_to_rad(80.0)
        folder = "res://verification/hands_reclined"
    director._gaze_direction = -director.camera.global_basis.z
    director.orb.global_position = director.camera.global_position + director._gaze_direction * ExperienceMath.ORB_DISTANCE
    DirAccess.make_dir_recursive_absolute(folder)

func _process(delta: float) -> bool:
    if director == null:
        return false
    frame += 1
    var time: float = float(frame) / 60.0
    director.elapsed = 25.5 + time
    director.clock.update_from_position(fmod(director.elapsed, 14.0), director.elapsed)
    director._follow_orb(delta)
    director._push_visuals(delta)
    for side: int in range(2):
        var shift: float = -0.23 if side == 0 else 0.23
        var pose: Transform3D = director.camera.global_transform * Transform3D(Basis(Vector3.FORWARD, sin(time * 0.5) * 0.15), Vector3(shift, -0.16 + sin(time * 0.7) * 0.035, -0.47))
        var hand: XRHandTracker = Fixture.make_hand(side, pose, maxf(0.0, sin(time * 0.7)))
        hand.has_tracking_data = time < 7.0 or time > 8.5
        director._upload_hand(side, hand, Transform3D.IDENTITY, delta)
    if frame % 15 == 0:
        capture.call_deferred()
    if frame >= 600:
        director._finish_exit()
        director = null
    return false

func capture() -> void:
    RenderingServer.force_draw(false, 0.0)
    root.get_texture().get_image().save_png(folder.path_join("frame_%05d.png" % frame))
