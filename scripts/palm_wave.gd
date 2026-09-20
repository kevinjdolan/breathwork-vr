class_name PalmWave
extends RefCounted
## Recognize one deliberate lateral palm sweep, then require the hand to leave.

var armed: bool = true
var elapsed: float = 0.0
var absent: float = 0.0
var start: Vector3
var previous: Vector3
var direction: float = 0.0
var samples: int = 0
var tracking_gap: float = 0.0

const MAX_TRACKING_GAP: float = 0.12

func reset() -> void:
    elapsed = 0.0
    samples = 0
    direction = 0.0
    tracking_gap = 0.0

func disarm() -> void:
    armed = false
    absent = 0.0
    reset()

func sample(point: Vector3, facing: float, valid: bool, delta: float) -> bool:
    # Brief optical occlusion must not erase an otherwise continuous sweep.
    # No missing pose contributes motion, and reacquisition still obeys the jump bound.
    if not valid or not point.is_finite():
        absent += delta
        tracking_gap += delta
        if tracking_gap > MAX_TRACKING_GAP:
            reset()
        if absent >= 0.45:
            armed = true
        return false
    var missed_time: float = tracking_gap
    tracking_gap = 0.0
    var in_region: bool = facing > 0.35 and point.z < -0.12 and point.z > -0.85 and absf(point.x) < 0.65 and absf(point.y) < 0.42
    if not in_region:
        absent += delta
        reset()
        if absent >= 0.45:
            armed = true
        return false
    absent = 0.0
    if not armed:
        return false
    if samples == 0:
        start = point
        previous = point
        samples = 1
        return false
    elapsed += delta + missed_time
    # Reacquisition jumps, vertical gestures, and very slow repositioning cannot exit.
    if delta > 0.12 or point.distance_to(previous) > 0.12 or elapsed > 1.45 or absf(point.y - start.y) > 0.16 or absf(point.z - start.z) > 0.19:
        reset()
        return false
    previous = point
    samples += 1
    var lateral: float = point.x - start.x
    if absf(lateral) > 0.04:
        if direction != 0.0 and signf(lateral) != direction:
            reset()
            return false
        direction = signf(lateral)
    if elapsed >= 0.12 and samples >= 5 and absf(lateral) >= 0.20:
        disarm()
        return true
    return false
