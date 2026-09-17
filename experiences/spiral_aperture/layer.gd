extends Node3D
## A still field wound into a slow spiral by MilkDrop's warp map, drawn as streamlines.

const FIELD_SHADER = preload("res://experiences/spiral_aperture/field.gdshader")
## Must equal MD_TRAIL_STEPS in milkdrop.gdshaderinc.
const STEPS: int = 24
const LINES: int = 700
var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
    _build_field()

func _build_field() -> void:
    var material := ShaderMaterial.new()
    material.shader = FIELD_SHADER
    material.set_shader_parameter("lines", float(LINES))
    _materials.append(material)
    var mesh := QuadMesh.new()
    mesh.size = Vector2.ONE
    mesh.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    # Every per-instance value is a function of the instance index, so the segments
    # need no per-instance buffers beyond the identity transform.
    multi.instance_count = LINES * STEPS
    for i in range(LINES * STEPS):
        multi.set_instance_transform(i, Transform3D.IDENTITY)
    var node := MultiMeshInstance3D.new()
    node.name = "SpiralField"
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
