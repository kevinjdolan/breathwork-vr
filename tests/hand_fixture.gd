extends RefCounted
## Synthetic tracking-space hands for pose contracts and GPU previews only.

static func make_hand(side: int, pose: Transform3D, curl: float = 0.0) -> XRHandTracker:
    var tracker: XRHandTracker = XRHandTracker.new()
    tracker.name = &"/user/hand_tracker/left" if side == 0 else &"/user/hand_tracker/right"
    tracker.hand = XRPositionalTracker.TRACKER_HAND_LEFT if side == 0 else XRPositionalTracker.TRACKER_HAND_RIGHT
    tracker.has_tracking_data = true
    tracker.hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
    var points: Array[Vector3] = [Vector3(0, 0.045, 0), Vector3.ZERO]
    var mirror: float = 1.0 if side == 0 else -1.0
    for segment: int in range(4):
        points.append(Vector3(mirror * (0.028 + float(segment) * 0.019), 0.025 + float(segment) * 0.012, 0.01))
    for finger: int in range(4):
        var x: float = (0.03 - float(finger) * 0.021) * mirror
        var length: float = [0.09, 0.105, 0.095, 0.07][finger]
        for segment: int in range(5):
            var part: float = maxf(0.0, float(segment - 1)) / 3.0
            var angle: float = curl * part * PI * 0.8
            var y: float = 0.025 if segment == 0 else 0.075 + cos(angle) * part * length
            var z: float = sin(angle) * part * length
            points.append(Vector3(x + part * x * 0.35, y, z))
    for joint: int in range(26):
        tracker.set_hand_joint_transform(joint, Transform3D(pose.basis, pose * points[joint]))
        tracker.set_hand_joint_flags(joint, XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED)
        tracker.set_hand_joint_radius(joint, 0.008 if joint > 1 else 0.02)
    return tracker
