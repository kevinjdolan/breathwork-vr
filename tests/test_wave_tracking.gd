extends SceneTree
## Exercise real XRHandTracker-to-menu routing with Godot-converted joint axes.

var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    run.call_deferred()

func trial(side: int, reclined: bool, moving_head: bool, move_hand: bool, face_viewer: bool, occlude: bool) -> bool:
    var origin: XROrigin3D = XROrigin3D.new()
    root.add_child(origin)
    origin.position = Vector3(.3, .7, -.2)
    origin.rotation.y = .35
    var camera: XRCamera3D = XRCamera3D.new()
    origin.add_child(camera)
    camera.position = Vector3(.1, .2, .1)
    camera.rotation.x = deg_to_rad(80) if reclined else 0.0
    var menu: SessionMenu = SessionMenu.new()
    menu.camera = camera
    origin.add_child(menu)
    menu.set_process(false)
    menu.available = true
    var head_start: Transform3D = camera.global_transform
    var tracker: XRHandTracker = XRHandTracker.new()
    tracker.name = "/user/hand_tracker/left" if side == 0 else "/user/hand_tracker/right"
    tracker.hand = XRPositionalTracker.TRACKER_HAND_LEFT if side == 0 else XRPositionalTracker.TRACKER_HAND_RIGHT
    tracker.has_tracking_data = true
    tracker.hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
    XRServer.add_tracker(tracker)
    var tracking_to_world: Transform3D = origin.global_transform * XRServer.get_reference_frame()
    # Independently reproduce Godot 4.6's raw OpenXR-to-humanoid conversion.
    var adjustment: Basis = Basis(Quaternion(0, -sqrt(.5), sqrt(.5), 0))
    var raw_palm: Basis = Basis(Vector3.RIGHT, -PI/2.0)
    var godot_palm: Basis = raw_palm * adjustment
    if not face_viewer:
        godot_palm = Basis(Vector3.UP, PI) * godot_palm
    for frame: int in range(32):
        if moving_head:
            camera.rotation.y = -.012 * frame
        var x: float = (-.22 + frame*.014) * (1 if side == 0 else -1) if move_hand else 0.0
        var world: Transform3D = Transform3D(head_start.basis * godot_palm, head_start * Vector3(x,0,-.35))
        var tracking: Transform3D = tracking_to_world.affine_inverse() * world
        tracking.origin /= XRServer.world_scale
        tracker.set_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM, tracking)
        var flags: int = XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID
        if occlude and frame in [7,8,9,17,18]:
            flags = 0
        tracker.set_hand_joint_flags(XRHandTracker.HAND_JOINT_PALM, flags)
        menu._sample_hands(1.0/60.0)
    var opened: bool = menu.is_open
    XRServer.remove_tracker(tracker)
    origin.free()
    return opened

func run() -> void:
    for side: int in [0,1]:
        for reclined: bool in [false,true]:
            check(trial(side,reclined,false,true,true,false), "Both hands open the confirmation upright and reclined with Godot joint axes")
            check(trial(side,reclined,true,true,true,true), "Natural head following and brief occlusion preserve a genuine sweep")
            check(not trial(side,reclined,true,false,true,false), "Turning the head past a stationary palm never fakes a sweep")
            check(not trial(side,reclined,false,true,false,false), "Back-of-hand sweeps are rejected for both hands and poses")
    print("WAVE TRACKING: ", "PASS" if failures == 0 else "FAIL")
    quit(failures)
