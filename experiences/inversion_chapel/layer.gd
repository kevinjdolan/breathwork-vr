extends Node3D
## Alternating positive and negative shells: the same arcade, lit and unlit by turns,
## its bays advancing outward past the listener.

const BAY_SHADER = preload("res://experiences/inversion_chapel/bay.gdshader")
const SHELLS: int = 6
const BASE_RADIUS: float = 4.6
const RATIO: float = 1.42
const DELAY: float = 1.8
## Seconds for a bay to cross the arcade. A nave should be walked, not run.
const FLOW_SECONDS: float = 12.0
var _materials: Array[ShaderMaterial] = []
var _shells: Array[MeshInstance3D] = []
var _outer_radius: float = BASE_RADIUS * pow(RATIO, float(SHELLS))

func _ready() -> void:
    for index in range(SHELLS):
        _build_shell(index)

func _build_shell(index: int) -> void:
    var material := ShaderMaterial.new()
    material.shader = BAY_SHADER
    material.set_shader_parameter("shell_index", float(index))
    material.set_shader_parameter("shell_count", float(SHELLS))
    material.set_shader_parameter("shell_delay", DELAY)
    # Shells keep their order as they recycle, so the parity of the stack in depth is
    # always lit, unlit, lit — the alternation survives the flow.
    material.set_shader_parameter("inverted", float(index % 2))
    _materials.append(material)
    var sphere := SphereMesh.new()
    sphere.radius = BASE_RADIUS
    sphere.height = BASE_RADIUS * 2.0
    sphere.radial_segments = 48
    sphere.rings = 24
    var node := MeshInstance3D.new()
    node.name = "Bay%d" % index
    node.mesh = sphere
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.extra_cull_margin = _outer_radius
    node.position = Vector3(0, 1.5, 0)
    # Half a bay of yaw per shell, so a negative bay always stands behind the gap of the
    # positive one in front of it and the alternation is visible rather than aligned.
    node.rotation.y = float(index) * PI / 14.0
    add_child(node)
    _shells.append(node)

func update_experience(state: Dictionary) -> void:
    var draw: float = float(state.get("breath_fill", 0.0))
    var elapsed: float = float(state.get("elapsed", 0.0))
    var phase: float = elapsed / FLOW_SECONDS
    var span: float = _outer_radius / BASE_RADIUS
    for index in range(_shells.size()):
        var s: float = fposmod(phase + float(index) / float(SHELLS), 1.0)
        var radius: float = BASE_RADIUS * pow(span, s)
        _shells[index].scale = Vector3.ONE * (radius / BASE_RADIUS) * (1.0 - 0.08 * draw)
        _materials[index].set_shader_parameter("shell_s", s)
    for material in _materials:
        material.set_shader_parameter("elapsed", elapsed)
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", draw)
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
