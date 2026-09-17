extends Node3D
## Slow large-scale turbulence carrying short-trailed motes through open air.

const MOTES_SHADER = preload("res://experiences/pollen_weather/motes.gdshader")
## Must equal MD_TRAIL_STEPS in milkdrop.gdshaderinc.
const STEPS: int = 24
const LINES: int = 1150
var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
    _build_field()

func _build_field() -> void:
    var material := ShaderMaterial.new()
    material.shader = MOTES_SHADER
    material.set_shader_parameter("lines", float(LINES))
    material.set_shader_parameter("travel_speed", 1.45)
    material.set_shader_parameter("span", 30.0)
    material.set_shader_parameter("height", 12.0)
    material.set_shader_parameter("field_scale", 11.0)
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
    node.name = "PollenField"
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
