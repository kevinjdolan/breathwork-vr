extends Node3D
## A full-sphere, sculpted Mandelbrot kaleidoscope with floating recursive crystals.
const FIELD_PATH: String = "res://experiences/fractal_garden/fields/mandelbrot_%d.png"
var _material: ShaderMaterial
var _crystal_material: ShaderMaterial
var _fields: Array[Texture2D] = []
var _shell: MeshInstance3D
var _anchor_ready: bool = false
var _field_index: int = -1

func _ready() -> void:
    for index: int in range(4):
        _fields.append(load(FIELD_PATH % index))
    _material = ShaderMaterial.new()
    _material.shader = load("res://experiences/fractal_garden/kaleidoscope.gdshader")
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    sphere.radial_segments = 160
    sphere.rings = 96
    _shell = MeshInstance3D.new()
    _shell.name = "MandelbrotVault"
    _shell.mesh = sphere
    _shell.material_override = _material
    _shell.custom_aabb = AABB(Vector3(-16,-16,-16),Vector3(32,32,32))
    _shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_shell)
    _build_crystals()

func _build_crystals() -> void:
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = .018
    mesh.height = .036
    mesh.radial_segments = 4
    mesh.rings = 1
    var multi: MultiMesh = MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_custom_data = true
    multi.mesh = mesh
    multi.instance_count = 6144
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 314159
    var vertices: Array[Vector3] = [Vector3(1,1,1),Vector3(-1,-1,1),Vector3(-1,1,-1),Vector3(1,-1,-1)]
    var point: Vector3 = Vector3.ZERO
    for i: int in range(multi.instance_count):
        point=(point+vertices[rng.randi_range(0,3)])*.5
        var cluster: int = i/512
        var y: float = 1.0-2.0*(float(cluster)+.5)/12.0
        var angle: float = float(cluster)*2.399963
        var direction: Vector3 = Vector3(cos(angle)*sqrt(1-y*y),y,sin(angle)*sqrt(1-y*y))
        var center: Vector3 = direction*(4.1+float(cluster%3)*.9)
        multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,center+point*.65))
        multi.set_instance_custom_data(i,Color(float(cluster),point.x,point.y,point.z))
    _crystal_material = ShaderMaterial.new()
    _crystal_material.shader = load("res://experiences/fractal_garden/crystals.gdshader")
    var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
    node.name = "RecursiveCrystals"
    node.multimesh = multi
    node.material_override = _crystal_material
    node.custom_aabb = AABB(Vector3(-9,-9,-9),Vector3(18,18,18))
    add_child(node)

func update_experience(state: Dictionary) -> void:
    var time: float = state.get("elapsed",0.0)
    if not _anchor_ready:
        global_position = state.get("head_position",Vector3(0,1.4,0))
        _anchor_ready = true
    var passage: float = time/120.0
    var index: int = int(passage)%4
    if index!=_field_index:
        _material.set_shader_parameter("field_a",_fields[index])
        _material.set_shader_parameter("field_b",_fields[(index+1)%4])
        _field_index=index
    _material.set_shader_parameter("field_mix",smoothstep(.55,1.0,fposmod(passage,1.0)))
    for material: ShaderMaterial in [_material,_crystal_material]:
        material.set_shader_parameter("elapsed",time)
        material.set_shader_parameter("visibility",state.get("intensity",1.0))
        material.set_shader_parameter("breath_fill",state.get("breath_fill",0.0))
