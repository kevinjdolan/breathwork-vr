extends Node3D
## Fewer, larger, softer shells: translucent washes folding through one another and
## drifting outward past the listener.

const VEIL_SHADER = preload("res://experiences/vellum_veils/veil.gdshader")
const SHELLS: int = 4
const BASE_RADIUS: float = 5.2
const RATIO: float = 1.58
const DELAY: float = 2.6
## Seconds for one veil to cross the stack. Cloth drifts, so this is the loosest of
## the four.
const FLOW_SECONDS: float = 14.0
var _materials: Array[ShaderMaterial] = []
var _shells: Array[MeshInstance3D] = []
var _outer_radius: float = BASE_RADIUS * pow(RATIO, float(SHELLS))

func _ready() -> void:
    for index in range(SHELLS):
        _build_shell(index)

func _build_shell(index: int) -> void:
    var material := ShaderMaterial.new()
    material.shader = VEIL_SHADER
    material.set_shader_parameter("shell_index", float(index))
    material.set_shader_parameter("shell_count", float(SHELLS))
    material.set_shader_parameter("shell_delay", DELAY)
    _materials.append(material)
    var sphere := SphereMesh.new()
    sphere.radius = BASE_RADIUS
    sphere.height = BASE_RADIUS * 2.0
    sphere.radial_segments = 40
    sphere.rings = 20
    var node := MeshInstance3D.new()
    node.name = "Veil%d" % index
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
    var phase: float = elapsed / FLOW_SECONDS
    var span: float = _outer_radius / BASE_RADIUS
    for index in range(_shells.size()):
        var s: float = fposmod(phase + float(index) / float(SHELLS), 1.0)
        var radius: float = BASE_RADIUS * pow(span, s)
        # Cloth, not architecture: the veils breathe further than the rosette stack and
        # each one turns slowly at its own rate so folds keep crossing.
        _shells[index].scale = Vector3.ONE * (radius / BASE_RADIUS) * (1.0 - 0.12 * draw)
        _shells[index].rotation.y = elapsed * (0.010 + 0.006 * float(index))
        _materials[index].set_shader_parameter("shell_s", s)
    for material in _materials:
        material.set_shader_parameter("elapsed", elapsed)
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", draw)
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
