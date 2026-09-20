class_name ThemeBreath
extends Node3D
## Theme-specific focal shapes, directed breath flow and surrounding particle ecologies.
const IDS: Array[String] = ["fractal_garden","tidal_origami","cloud_atelier","neural_constellation","circuit_garden","pilgrim_tides"]
var theme: int = 0
var inhale_offset: Vector3 = Vector3.ZERO
var exhale_offset: Vector3 = Vector3.ZERO
var rhythm: Vector4
var _materials: Array[ShaderMaterial] = []
var _origin: Vector3
var _anchored: bool = false

func _ready() -> void:
    _field("BreathingSculpture",3072,"focal.gdshader")
    _field("ThemedBreathFlow",1536,"flow.gdshader")
    _field("SurroundingEcology",12288,"ecology.gdshader")

func _field(label: String,count: int,shader: String) -> void:
    var multi: MultiMesh = MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_custom_data = true
    var quad: QuadMesh = QuadMesh.new()
    quad.size=Vector2.ONE
    multi.mesh=quad
    multi.instance_count=count
    for i: int in range(count):
        multi.set_instance_transform(i,Transform3D.IDENTITY)
        multi.set_instance_custom_data(i,Color(float(i),fposmod(i*.6180339,1.0),fposmod(i*.75487766,1.0),fposmod(i*.438579,1.0)))
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader=load("res://experiences/shared/"+shader)
    material.set_shader_parameter("theme",theme)
    material.set_shader_parameter("rhythm",rhythm)
    _materials.append(material)
    var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
    node.name=label
    node.multimesh=multi
    node.material_override=material
    node.custom_aabb=AABB(Vector3(-40,-40,-40),Vector3(80,80,80))
    add_child(node)

func update_experience(state: Dictionary) -> void:
    if not _anchored:
        _origin=state["head_position"]
        _anchored=true
    var basis: Basis = state["head_basis"]
    var center: Vector3 = BreathGeometry.from_state(state)
    for material: ShaderMaterial in _materials:
        material.set_shader_parameter("elapsed",state["elapsed"])
        material.set_shader_parameter("phase_seconds",state["phase_seconds"])
        material.set_shader_parameter("breath_fill",state["breath_fill"])
        material.set_shader_parameter("visibility",state["intensity"])
        material.set_shader_parameter("head_position",state["head_position"])
        material.set_shader_parameter("inhale_target",BreathGeometry.offset(center,basis,inhale_offset))
        material.set_shader_parameter("exhale_origin",BreathGeometry.offset(center,basis,exhale_offset))
        material.set_shader_parameter("focus_position",state["orb_position"])
        material.set_shader_parameter("world_center",_origin)
        material.set_shader_parameter("head_right",basis.x)
        material.set_shader_parameter("head_up",basis.y)
        material.set_shader_parameter("head_forward",-basis.z)
