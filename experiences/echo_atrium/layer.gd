extends Node3D
## Waveform rings at geometric radii: the listener's recent breathing, each phase
## standing at its own distance and climbing outward past them.

const RING_SHADER = preload("res://experiences/echo_atrium/ring.gdshader")
const SHELLS: int = 6
const BASE_RADIUS: float = 4.2
const RATIO: float = 1.44
## One inhale per shell, matching the catalog rhythm, so each ring is one phase older.
const DELAY: float = 4.0
## Seconds for a ring to travel the whole stack. The slowest of the four worlds: a
## record being read should drift, not stream.
const FLOW_SECONDS: float = 15.0
const RHYTHM := Vector4(4.0, 2.0, 8.0, 2.0)
var _materials: Array[ShaderMaterial] = []
var _shells: Array[MeshInstance3D] = []
var _outer_radius: float = BASE_RADIUS * pow(RATIO, float(SHELLS))

func _ready() -> void:
    for index in range(SHELLS):
        _build_shell(index)

func _build_shell(index: int) -> void:
    var material := ShaderMaterial.new()
    material.shader = RING_SHADER
    material.set_shader_parameter("shell_index", float(index))
    material.set_shader_parameter("shell_count", float(SHELLS))
    material.set_shader_parameter("shell_delay", DELAY)
    material.set_shader_parameter("rhythm", RHYTHM)
    _materials.append(material)
    # Built at the base radius once; the ring's distance is a per-frame scale.
    var sphere := SphereMesh.new()
    sphere.radius = BASE_RADIUS
    sphere.height = BASE_RADIUS * 2.0
    sphere.radial_segments = 48
    sphere.rings = 24
    var node := MeshInstance3D.new()
    node.name = "Ring%d" % index
    node.mesh = sphere
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.extra_cull_margin = _outer_radius
    node.position = Vector3(0, 1.5, 0)
    add_child(node)
    _shells.append(node)

func update_experience(state: Dictionary) -> void:
    var draw: float = float(state.get("breath_fill", 0.0))
    var elapsed: float = float(state.get("elapsed", 0.0))
    # Evenly spaced in log radius, all climbing the same ramp: a ring that leaves the
    # outer limit is the one that reappears at the centre.
    var phase: float = elapsed / FLOW_SECONDS
    var span: float = _outer_radius / BASE_RADIUS
    for index in range(_shells.size()):
        var s: float = fposmod(phase + float(index) / float(SHELLS), 1.0)
        var radius: float = BASE_RADIUS * pow(span, s)
        # The whole atrium draws in on the inhale, which reads as the history closing up.
        _shells[index].scale = Vector3.ONE * (radius / BASE_RADIUS) * (1.0 - 0.09 * draw)
        _materials[index].set_shader_parameter("shell_s", s)
    for material in _materials:
        material.set_shader_parameter("elapsed", elapsed)
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", draw)
        material.set_shader_parameter("phase_seconds", float(state.get("phase_seconds", 0.0)))
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
