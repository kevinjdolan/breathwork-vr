class_name BreathGeometry
extends RefCounted
## One headset-relative neck reference for every experience's incoming and outgoing breath.

const BREATH_CENTER_OFFSET: Vector3 = Vector3(0.0, -0.18, 0.0)

static func center(head_position: Vector3, head_basis: Basis) -> Vector3:
    return head_position + head_basis.orthonormalized() * BREATH_CENTER_OFFSET

static func from_state(state: Dictionary) -> Vector3:
    if state.has("breath_center"):
        return state["breath_center"]
    return center(state.get("head_position", Vector3(0, 1.4, 0)), state.get("head_basis", Basis.IDENTITY))

static func offset(center_position: Vector3, head_basis: Basis, local_offset: Vector3) -> Vector3:
    return center_position + head_basis.orthonormalized() * local_offset
