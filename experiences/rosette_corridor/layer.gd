extends Node3D
## Nested rosette shells: MilkDrop's video echo rebuilt as real, parallaxing depth,
## and — as echo_zoom did every frame — flowing continuously outward past the listener.

const SHELL_SHADER = preload("res://experiences/rosette_corridor/shell.gdshader")
const SHELLS: int = 6
const BASE_RADIUS: float = 4.4
const RATIO: float = 1.46
## One shell per breath-step of history; the whole stack spans about ten seconds.
const DELAY: float = 1.6
## Seconds for one shell to travel the whole stack, innermost to outermost. Slow
## enough to read as drifting rather than flying.
const FLOW_SECONDS: float = 13.0
var _materials: Array[ShaderMaterial] = []
var _shells: Array[MeshInstance3D] = []
var _outer_radius: float = BASE_RADIUS * pow(RATIO, float(SHELLS))

func _ready() -> void:
    for index in range(SHELLS):
        _build_shell(index)

func _build_shell(index: int) -> void:
    var material := ShaderMaterial.new()
    material.shader = SHELL_SHADER
    material.set_shader_parameter("shell_index", float(index))
    material.set_shader_parameter("shell_count", float(SHELLS))
    material.set_shader_parameter("shell_delay", DELAY)
    material.set_shader_parameter("shell_phase", float(index) / float(SHELLS))
    _materials.append(material)
    # The mesh is built once at the base radius; its distance is a per-frame scale,
    # because the stack now sweeps outward continuously.
    var sphere := SphereMesh.new()
    sphere.radius = BASE_RADIUS
    sphere.height = BASE_RADIUS * 2.0
    sphere.radial_segments = 48
    sphere.rings = 24
    var node := MeshInstance3D.new()
    node.name = "Shell%d" % index
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
    # Log-radius phase: every shell climbs the same exponential ramp, evenly spaced, and
    # the one that leaves the outer limit is the one reborn at the centre.
    var phase: float = elapsed / FLOW_SECONDS
    var span: float = _outer_radius / BASE_RADIUS
    for index in range(_shells.size()):
        var s: float = fposmod(phase + float(index) / float(SHELLS), 1.0)
        var radius: float = BASE_RADIUS * pow(span, s)
        # Inhale draws the whole stack inward; exhale lets it settle back out.
        _shells[index].scale = Vector3.ONE * (radius / BASE_RADIUS) * (1.0 - 0.10 * draw)
        _materials[index].set_shader_parameter("shell_s", s)
        _materials[index].set_shader_parameter("world_center", Vector3(0, 1.5, 0) - Vector3(0, 0, radius))
    for material in _materials:
        material.set_shader_parameter("elapsed", elapsed)
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", draw)
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
