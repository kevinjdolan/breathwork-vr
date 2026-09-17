extends Node3D
## Fewer, larger, softer shells: translucent washes folding through one another.

const VEIL_SHADER = preload("res://experiences/vellum_veils/veil.gdshader")
const SHELLS: int = 4
const BASE_RADIUS: float = 5.2
const RATIO: float = 1.58
const DELAY: float = 2.6
var _materials: Array[ShaderMaterial] = []
var _shells: Array[MeshInstance3D] = []

func _ready() -> void:
    for index in range(SHELLS):
        _build_shell(index)

func _build_shell(index: int) -> void:
    var material := ShaderMaterial.new()
    material.shader = VEIL_SHADER
    material.set_shader_parameter("shell_index", float(index))
    material.set_shader_parameter("shell_count", float(SHELLS))
    material.set_shader_parameter("shell_delay", DELAY)
    material.set_shader_parameter("shell_scale", 1.0 + 0.26 * float(index))
    _materials.append(material)
    var sphere := SphereMesh.new()
    var radius: float = BASE_RADIUS * pow(RATIO, float(index))
    sphere.radius = radius
    sphere.height = radius * 2.0
    sphere.radial_segments = 40
    sphere.rings = 20
    var node := MeshInstance3D.new()
    node.name = "Veil%d" % index
    node.mesh = sphere
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.extra_cull_margin = radius
    node.position = Vector3(0, 1.5, 0)
    add_child(node)
    _shells.append(node)

func update_experience(state: Dictionary) -> void:
    var draw: float = float(state.get("breath_fill", 0.0))
    var elapsed: float = float(state.get("elapsed", 0.0))
    for index in range(_shells.size()):
        # Cloth, not architecture: the veils breathe further than the rosette stack and
        # each one turns slowly at its own rate so folds keep crossing.
        _shells[index].scale = Vector3.ONE * (1.0 - 0.12 * draw)
        _shells[index].rotation.y = elapsed * (0.010 + 0.006 * float(index))
    for material in _materials:
        material.set_shader_parameter("elapsed", elapsed)
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", draw)
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
