extends SceneTree
## Check deliberate gaze activation, quiet pause, cancellation, and return routing.
var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func aim(camera: Camera3D, point: Vector3) -> void:
    camera.look_at(point, camera.global_basis.y)

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    var director: MeditationDirector = scene.get_node("Director")
    director.music.play(30.0)
    director.breath.play(2.0)
    await create_timer(0.05).timeout
    var menu: SessionMenu = director.session_menu
    menu.set_process(false)
    menu.available = true
    director.camera.get_parent().position.y = 1.4
    menu._process(0.01)
    check(not menu.dialog.visible and not menu.cursor.visible, "No persistent exit control distracts during meditation")
    var tracker: XRHandTracker = XRHandTracker.new()
    tracker.name = "/user/hand_tracker/left"
    tracker.has_tracking_data = true
    tracker.hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
    XRServer.add_tracker(tracker)
    tracker.set_hand_joint_flags(XRHandTracker.HAND_JOINT_PALM, XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID)
    for step: int in range(20):
        # Godot's converted joint frame has +Y along the fingers and +Z out of the palm.
        var pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(-0.15 + step*0.016, 0, -0.45))
        # Camera is a child of the tracking origin; convert into tracker space.
        pose.origin.y = director.camera.position.y
        tracker.set_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM, pose)
        menu._process(1.0/30.0)
    check(menu.is_open and director.music.stream_paused and director.breath.stream_paused, "Tracked palm wave opens menu and pauses both audio clocks")
    check(menu.cursor.visible, "Confirmation renders the gaze pointer")
    XRServer.remove_tracker(tracker)
    check(is_zero_approx(float((director.inhale.process_material as ShaderMaterial).get_shader_parameter("inhale_visibility"))), "Pause hides incoming breath")
    director._on_focus()
    check(director.music.stream_paused, "Regaining headset focus does not dismiss pause")
    check(menu._target_at_ray() == -1, "Opening gaze lands between confirmation choices")
    aim(director.camera, menu.buttons[0].global_position)
    menu._process(1.9)
    check(not menu.is_open and not director.music.stream_paused and not director._exiting, "Continue resumes without ending")
    director.camera.rotation.x = deg_to_rad(80)
    menu.open_menu()
    var expected: Vector3 = director.camera.global_transform * Vector3(0, 0, -2)
    check(menu.dialog.global_position.distance_to(expected) < 0.001, "Confirmation supports a reclined gaze")
    aim(director.camera, menu.buttons[1].global_position)
    menu._process(0.5)
    check(not director._exiting, "Brief glance does not confirm ending")
    menu._process(1.4)
    check(director._exiting and director._return_to_menu and not menu.visible, "Deliberate End session begins fade back to selector")
    director._advance_exit(2.1)
    await create_timer(0.4).timeout
    await process_frame
    check(current_scene != null and current_scene.get_script().resource_path == "res://scripts/startup_menu.gd", "Exit completes at startup menu")
    print("SESSION MENU: ", "PASS" if failures == 0 else "FAIL")
    quit(failures)
