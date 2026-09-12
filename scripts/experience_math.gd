class_name ExperienceMath
extends RefCounted
## Stateless timing, device budgets, and contractive IFS transforms.

const DURATION: float = 480.0
const ORB_DISTANCE: float = 1.8288
const INHALE_SECONDS: float = 4.0
const PAUSE_SECONDS: float = 2.0
const EXHALE_START: float = INHALE_SECONDS + PAUSE_SECONDS
const CYCLE_SECONDS: float = 14.0

static func smooth_unit(value: float) -> float:
    var t: float = clampf(value, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

static func softer_unit(value: float) -> float:
    var t: float = clampf(value, 0.0, 1.0)
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

static func orb_drift(time: float) -> Vector3:
    var result: Vector3 = Vector3.ZERO
    for axis: int in range(3):
        var phase: float = time / (8.5 + float(axis) * 2.7)
        var step: float = floor(phase)
        var a: float = noise_seed(step + float(axis) * 93.0 + 417.0) * 2.0 - 1.0
        var b: float = noise_seed(step + float(axis) * 93.0 + 418.0) * 2.0 - 1.0
        result[axis] = lerpf(a, b, softer_unit(fposmod(phase, 1.0))) * [0.24, 0.18, 0.20][axis]
    return result * softer_unit(time / 6.0)

static func tier_for(model: String) -> Dictionary:
    var quest_three: bool = "quest 3" in model.to_lower() or "quest3" in model.to_lower()
    return {"name": "Quest 3" if quest_three else "Quest 2", "field_count": 30000 if quest_three else 12000, "sky_samples": 6 if quest_three else 4, "refresh_rate": 90.0 if quest_three else 72.0}

static func cycle_at(elapsed: float, ramp: bool = false) -> int:
    if ramp:
        return int(elapsed / 12.0) if elapsed < 120.0 else 10 + int((elapsed - 120.0) / 14.0)
    return int(elapsed / CYCLE_SECONDS)

static func inhale_gate(seconds: float) -> float:
    return inhale_visibility(seconds)

static func inhale_visibility(seconds: float, length: float = CYCLE_SECONDS) -> float:
    # Begin gathering near the orb before the audio cue, continuous across wrap.
    var lead_time: float = seconds - length if seconds >= length - 1.5 else seconds
    if lead_time >= INHALE_SECONDS:
        return 0.0
    return softer_unit((lead_time + 1.5) / 2.7) * (1.0 - softer_unit((lead_time - 2.65) / 1.35))

static func inhale_front(seconds: float, length: float = CYCLE_SECONDS) -> float:
    var lead_time: float = seconds - length if seconds >= length - 1.5 else seconds
    return 1.14 * smooth_unit((lead_time + 1.5) / 1.8) if lead_time < INHALE_SECONDS else 0.0

static func mote_cluster(time: float, cluster: int) -> Dictionary:
    var duration: float = 20.0 + float(cluster) * 2.3
    var shifted: float = time + float(cluster) * 4.7
    var epoch: int = int(floor(shifted / duration))
    var age: float = fposmod(shifted, duration)
    var seed: float = float(epoch * 139 + cluster * 47)
    var angle: float = TAU * noise_seed(seed + 1.0)
    var radius: float = 4.2 + noise_seed(seed + 7.0) * 5.8
    var visiting: bool = (epoch + cluster) % 3 == 0
    if visiting:
        radius = 4.2 + noise_seed(seed + 7.0) * 1.3
    # Three of the five pockets live overhead, including a near-zenith pocket.
    # This covers a reclined viewer without attaching the particles to their head.
    var elevation: float = 0.12 + noise_seed(seed + 13.0) * 0.32
    if cluster >= 2:
        elevation = 0.75 + noise_seed(seed + 13.0) * 0.45
    if cluster == 4:
        elevation = 1.30 + noise_seed(seed + 13.0) * 0.20
    var center: Vector3 = Vector3(sin(angle) * cos(elevation) * radius, 1.4 + sin(elevation) * radius, cos(angle) * cos(elevation) * radius)
    var drift_angle: float = TAU * noise_seed(seed + 23.0)
    var velocity: Vector3 = Vector3(cos(drift_angle) * 0.10, 0.025 + noise_seed(seed + 31.0) * 0.025, sin(drift_angle) * 0.10)
    var visibility: float = smooth_unit(age / 3.0) * (1.0 - smooth_unit((age - duration + 4.0) / 4.0))
    var position: Vector3 = center + velocity * (age - duration * 0.5)
    if visiting:
        var anchor: Vector3 = Vector3(0, 1.4, 0)
        var approach: float = pow(sin(PI * age / duration), 2.0)
        position = anchor + (position - anchor).normalized() * lerpf((position - anchor).length(), 2.1 + noise_seed(seed + 59.0) * 0.7, approach)
    var palette: Array[Color] = [Color(0.32, 0.82, 0.72), Color(0.65, 0.47, 0.95), Color(0.95, 0.49, 0.65), Color(0.97, 0.74, 0.35), Color(0.43, 0.73, 1.0)]
    var tint: Color = palette[(cluster + epoch) % palette.size()]
    var cue: int = 1 if visiting and age >= duration * 0.42 else 0
    var cue_age: float = age - duration * 0.42 if cue == 1 else age - 0.7
    return {"position": position, "age": age, "duration": duration, "visibility": visibility, "color": tint, "visiting": visiting, "cue_id": epoch * 2 + cue, "cue_age": cue_age}

static func noise_seed(seed: float) -> float:
    return fposmod(sin(seed * 12.9898 + 78.233) * 43758.5453, 1.0)

static func exhale_gate(seconds: float, length: float = CYCLE_SECONDS) -> float:
    return smooth_unit((seconds - EXHALE_START) / 0.45) * (1.0 - smooth_unit((seconds - length + 2.0) / 2.0)) if seconds >= EXHALE_START else 0.0

static func ifs_transforms(morph: float, immersion: float = 0.0) -> Array[Transform3D]:
    var result: Array[Transform3D] = []
    var offsets: Array[Vector3] = [Vector3(-0.58, 0.1, -0.45), Vector3(0.58, 0.1, -0.45), Vector3(0, 0.82, 0), Vector3(0, 0.16, 0.62)]
    for branch: int in range(4):
        if branch != 2:
            offsets[branch].y = lerpf(offsets[branch].y, -0.4 if branch < 2 else -0.2, immersion)
        var angle: float = morph * 0.11 + float(branch) * 1.37
        var axis: Vector3 = Vector3(sin(float(branch) + 0.4), 0.7, cos(float(branch))).normalized()
        var size: float = 0.58 + 0.035 * sin(angle * 0.7)
        var basis: Basis = Basis(axis, 0.5 * sin(angle)).scaled(Vector3.ONE * size)
        result.append(Transform3D(basis, offsets[branch] + Vector3(0.06 * sin(angle), 0.035 * cos(angle), 0.04 * sin(angle * 0.8))))
    return result

static func ifs_point(address: int, transforms: Array[Transform3D]) -> Vector3:
    var point: Vector3 = Vector3.ZERO
    for depth: int in range(12):
        point = transforms[(address >> (depth * 2)) & 3] * point
    return point
