extends Node3D
## A folded warp field repeated around a sixfold dihedral group into a turning dome.

const MANDALA_SHADER = preload("res://experiences/mandala_drift/mandala.gdshader")
## Must equal MD_TRAIL_STEPS in milkdrop.gdshaderinc.
const STEPS: int = 24
## Six rotations times their mirrors; must match COPIES in the shader.
const COPIES: int = 12
## Gates along the corridor; must match the `tiles` uniform.
const TILES: int = 6
const GATE_SPACING: float = 7.2
const WEDGES: int = 17
const LINES: int = COPIES * TILES * WEDGES
var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
    _build_field()

func _build_field() -> void:
    var material := ShaderMaterial.new()
    material.shader = MANDALA_SHADER
    material.set_shader_parameter("wedges", float(WEDGES))
    material.set_shader_parameter("tiles", float(TILES))
    material.set_shader_parameter("gate_spacing", GATE_SPACING)
    material.set_shader_parameter("travel_speed", 1.05)
    material.set_shader_parameter("field_scale", 5.6)
    _materials.append(material)
    var mesh := QuadMesh.new()
    mesh.size = Vector2.ONE
    mesh.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    # Every per-instance value is derived from the instance index, so no per-instance
    # buffer beyond the identity transform is needed.
    multi.instance_count = LINES * STEPS
    for i in range(LINES * STEPS):
        multi.set_instance_transform(i, Transform3D.IDENTITY)
    var node := MultiMeshInstance3D.new()
    node.name = "MandalaField"
    node.multimesh = multi
    node.material_override = material
    node.custom_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func update_experience(state: Dictionary) -> void:
    for material in _materials:
        material.set_shader_parameter("elapsed", float(state.get("elapsed", 0.0)))
        material.set_shader_parameter("visibility", float(state.get("intensity", 1.0)))
        material.set_shader_parameter("breath_fill", float(state.get("breath_fill", 0.0)))
        material.set_shader_parameter("head_position", state.get("head_position", Vector3(0, 1.4, 0)))
        material.set_shader_parameter("world_center", Vector3.ZERO)
