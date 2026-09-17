extends Node3D
## Waveform rings at geometric radii: the last six breath phases, each standing at its
## own distance, so the listener is inside their own recent breathing.

const RING_SHADER = preload("res://experiences/echo_atrium/ring.gdshader")
const SHELLS: int = 6
const BASE_RADIUS: float = 4.2
const RATIO: float = 1.44
## One inhale per shell, matching the catalog rhythm, so each ring is one phase older.
const DELAY: float = 4.0
const RHYTHM := Vector4(4.0, 2.0, 8.0, 2.0)
var _materials: Array[ShaderMaterial] = []
var _shells: Array[MeshInstance3D] = []

func _ready() -> void:
    for index in range(SHELLS):
        _build_shell(index)

func _build_shell(index: int) -> void:
    var material := ShaderMaterial.new()
    material.shader = RING_SHADER
    material.set_shader_parameter("shell_index", float(index))
    material.set_shader_parameter("shell_count", float(SHELLS))
    material.set_shader_parameter("shell_delay", DELAY)
    material.set_shader_parameter("shell_scale", 1.0 + 0.32 * float(index))
    material.set_shader_parameter("rhythm", RHYTHM)
    _materials.append(material)
    var sphere := SphereMesh.new()
    var radius: float = BASE_RADIUS * pow(RATIO, float(index))
    sphere.radius = radius
    sphere.height = radius * 2.0
    sphere.radial_segments = 48
    sphere.rings = 24
    var node := MeshInstance3D.new()
    node.name = "Ring%d" % index
    node.mesh = sphere
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.extra_cull_margin = radius
    node.position = Vector3(0, 1.5, 0)
    add_child(node)
    _shells.append(node)

func update_experience(state: Dictionary) -> void:
    var draw: float = float(state.get("breath_fill", 0.0))
    for index in range(_shells.size()):
        # The whole atrium draws in on the inhale, which reads as the history closing up.
        _shells[index].scale = Vector3.ONE * (1.0 - 0.09 * draw)
    for material in _materials:
        material.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", draw)
        material.set_shader_parameter("phase_seconds", float(state.get("phase_seconds", 0.0)))
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
