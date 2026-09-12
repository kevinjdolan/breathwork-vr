extends SceneTree
## Checks real XR tracker data uploads, recentering, loss and reacquisition.

const Fixture = preload("res://tests/hand_fixture.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var director: MeditationDirector = scene.get_node("Director")
    director.fade = 0.0
    check(ProjectSettings.get_setting("xr/openxr/extensions/hand_tracking"), "Native hand tracking enabled")
    check(scene.get_node("ParticleHands").get_child_count() == 2, "Both hands use particle emitters")
    for hand: GPUParticles3D in scene.get_node("ParticleHands").get_children():
        check(hand.amount == 768 and not hand.local_coords and hand.fixed_fps == 0, "Hand budget and render-frame world-space updates")
    var hand: XRHandTracker = Fixture.make_hand(0, Transform3D(Basis.IDENTITY, Vector3(-0.2, 1.3, -0.5)))
    XRServer.add_tracker(hand)
    var origin: XROrigin3D = director.camera.get_parent()
    origin.transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.1, 0.1, 0.2))
    XRServer.world_scale = 1.1
    var reference: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(-0.1, 0, 0.1))
    director._upload_hand(0, hand, origin.global_transform * reference, 0.1)
    check(director._hand_confidence[0][10] > 0.2 and director._hand_confidence[0][10] < 0.5, "Tracked hand materializes gently")
    director._upload_hand(0, hand, origin.global_transform * reference, 0.3)
    var expected: Vector3 = origin.global_transform * reference * (hand.get_hand_joint_transform(10).origin * 1.1)
    var actual: Vector4 = director._hand_joints[0][10]
    check(Vector3(actual.x, actual.y, actual.z).distance_to(expected) < 0.0001, "Finger positions match scaled, recentered tracking coordinates")
    check(director._hand_confidence[1][10] == 0, "Missing right hand remains invisible")
    hand.set_hand_joint_flags(10, 0)
    director._update_hands(0.08)
    check(is_equal_approx(director._hand_confidence[0][10], 0.5), "Invalid finger fades independently")
    check(director._hand_joints[0][10] == actual, "Invalid joint never snaps to origin")
    hand.has_tracking_data = false
    director._update_hands(0.2)
    check(director._hand_confidence[0][0] == 0 and director._hand_confidence[0][10] == 0, "Lost hand fully dissolves")
    hand.has_tracking_data = true
    hand.set_hand_joint_flags(10, XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID)
    director._update_hands(0.3)
    check(director._hand_confidence[0][10] == 1, "Tracking reacquires without rebuilding particles")
    var controller: XRPositionalTracker = XRPositionalTracker.new()
    controller.name = &"left_hand"
    controller.type = XRServer.TRACKER_CONTROLLER
    controller.hand = XRPositionalTracker.TRACKER_HAND_LEFT
    XRServer.add_tracker(controller)
    director._on_button_pressed(&"trigger_click", &"left_hand")
    check(director._held.is_empty(), "Optical hand gestures cannot accidentally exit")
    XRServer.remove_tracker(controller)
    XRServer.remove_tracker(hand)
    director._update_hands(0.2)
    check(director._hand_confidence[0][0] == 0, "Removed tracker fades out")
    XRServer.world_scale = 1.0
    print("HAND CONTRACTS: ", "PASS" if failures == 0 else str(failures) + " FAILURES")
    scene.free()
    quit(1 if failures else 0)
