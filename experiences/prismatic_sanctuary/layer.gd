extends Node3D
## Slow forward optic flow through sixteen jewel families and a woven particle vault.

const ROOT: String = "res://experiences/prismatic_sanctuary/"
const SHAPES = preload("res://experiences/prismatic_sanctuary/shapes.gd")
const SPEED: float = 0.55
const SPAN: float = 64.0
const STAR_DISTANCE: float = 60.0
var _materials: Array[ShaderMaterial] = []
var _journey: Transform3D = Transform3D.IDENTITY
var _anchored: bool = false
var _aim: Quaternion = Quaternion.IDENTITY
var _last_time: float = -1.0
var _focal: Vector3 = Vector3(0,1.4,-60)
var _cue: Label3D
var _counts: Array[int] = []
var _source_index: int = -1
var _source_cycle: int = -1
var _source: Vector3
var _beams: MultiMeshInstance3D
var _outflow: MultiMeshInstance3D

func _ready() -> void:
    for kind: int in range(16):
        var mesh: ArrayMesh = SHAPES.build(kind)
        _counts.append(mesh.get_faces().size()/3)
        var material: ShaderMaterial = _material("journey_objects.gdshader")
        material.set_shader_parameter("family",float(kind))
        material.render_priority = -10
        var multimesh: MultiMesh = MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.use_custom_data = true
        multimesh.mesh = mesh
        multimesh.instance_count = 8
        for instance: int in range(8):
            var seed: float = float(kind*8+instance)
            multimesh.set_instance_transform(instance,Transform3D.IDENTITY)
            multimesh.set_instance_custom_data(instance,Color(fposmod(seed*.6180339,1.0),fposmod(seed*.75487766,1.0),fposmod(seed*.56984,1.0),fposmod(seed*.438579,1.0)))
        var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
        node.name = SHAPES.NAMES[kind].replace(" ","")
        node.multimesh = multimesh
        node.material_override = material
        node.custom_aabb = AABB(Vector3(-120,-120,-120),Vector3(240,240,240))
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(node)
    _points("DistantHaze",3,"journey_fog.gdshader")
    (get_node("DistantHaze").material_override as ShaderMaterial).render_priority = -20
    _points("ParticleVault",16384,"journey_vault.gdshader")
    _points("DistantStar",320,"journey_star.gdshader")
    _build_plasma()
    _points("BlueOutflow",512,"outflow.gdshader")
    _outflow = get_node("BlueOutflow")
    _cue = Label3D.new()
    _cue.font_size = 64
    _cue.pixel_size = .025
    _cue.outline_size = 0
    _cue.modulate = Color(.48,.68,.79)
    add_child(_cue)
    print("VRMED PRISMATIC families=16 objects=128 vault_points=16384 triangles=",_counts.reduce(func(a: int,b: int) -> int: return a+b,0)*8)

func _material(path: String) -> ShaderMaterial:
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = load(ROOT+path)
    _materials.append(material)
    return material

func _points(label: String,count: int,path: String) -> void:
    var multimesh: MultiMesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_custom_data = true
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2.ONE
    multimesh.mesh = quad
    multimesh.instance_count = count
    for i: int in range(count):
        multimesh.set_instance_transform(i,Transform3D.IDENTITY)
        multimesh.set_instance_custom_data(i,Color(float(i),fposmod(i*.6180339,1.0),fposmod(i*.75487766,1.0),fposmod(i*.438579,1.0)))
    var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = multimesh
    node.material_override = _material(path)
    node.custom_aabb = AABB(Vector3(-150,-150,-150),Vector3(300,300,300))
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

static func travel_distance(time: float) -> float:
    return SPEED*(time-5.0*(1.0-exp(-time/5.0)))

func reset_journey() -> void:
    _anchored = false
    _source_cycle = -1

func focal_position() -> Vector3:
    return _focal

func update_experience(state: Dictionary) -> void:
    var time: float = state.get("elapsed",0.0)
    var head: Vector3 = state.get("head_position",Vector3(0,1.4,0))
    var basis: Basis = state.get("head_basis",Basis.IDENTITY)
    if not _anchored:
        _journey = Transform3D(basis.orthonormalized(),head)
        _anchored = true
        _aim = basis.get_rotation_quaternion().normalized()
        _last_time = time
    var delta: float = clampf(time-_last_time,0.0,.1)
    _last_time = time
    # Two slow filters ease both onset and arrival; a 90-degree turn settles in ~16s.
    var target: Quaternion = basis.get_rotation_quaternion().normalized()
    var weight: float = 1.0-exp(-delta/3.2)
    _aim = _aim.slerp(target,weight).normalized()
    var rotation: Quaternion = _journey.basis.get_rotation_quaternion().normalized()
    _journey.basis = Basis(rotation.slerp(_aim,weight).normalized())
    _focal = head-_journey.basis.z*STAR_DISTANCE
    var fill: float = state.get("breath_fill",0.0)
    var phase: float = state.get("phase_seconds",fposmod(time,16.0))
    var visibility: float = state.get("intensity",1.0)
    var cycle: int = int(floor((time+1.5)/16.0))
    if cycle != _source_cycle:
        _source_index = select_source(time,head,basis,fill)
        _source_cycle = cycle
    if _source_index >= 0:
        _source = _journey*object_center(_source_index,time,fill)
    var nose: Vector3 = head+basis*Vector3(0,-.035,-.085)
    var lead: float = phase-16.0 if phase>=14.5 else phase
    var beam: float = smoothstep(-1.5,.35,lead)*(1.0-smoothstep(3.35,4.75,lead)) if lead<4.75 else 0.0
    if time>=478.5 or _source_index<0:
        beam = 0.0
    var beam_front: float = smoothstep(-1.5,.5,lead)*1.08
    var hold_glow: float = smoothstep(4.0,4.8,phase)*(1.0-smoothstep(7.2,8.0,phase))
    for material: ShaderMaterial in _materials:
        material.set_shader_parameter("source_position",_source)
        material.set_shader_parameter("source_family",float(_source_index/8))
        material.set_shader_parameter("source_seed",fposmod(float(_source_index)*.6180339,1.0))
        material.set_shader_parameter("nose_position",nose)
        material.set_shader_parameter("mouth_position",state.get("mouth_position",head+basis*Vector3(0,-.08,-.06)))
        material.set_shader_parameter("head_right",basis.x)
        material.set_shader_parameter("head_up",basis.y)
        material.set_shader_parameter("head_forward",-basis.z)
        material.set_shader_parameter("beam_visibility",beam)
        material.set_shader_parameter("beam_front",beam_front)
        material.set_shader_parameter("hold_glow",hold_glow)
        material.set_shader_parameter("star_radius",star_radius(phase))
    for material: ShaderMaterial in _materials:
        material.set_shader_parameter("elapsed",time)
        material.set_shader_parameter("travel",travel_distance(time))
        material.set_shader_parameter("journey_frame",Projection(_journey))
        material.set_shader_parameter("head_position",head)
        material.set_shader_parameter("star_position",_focal)
        material.set_shader_parameter("breath_fill",fill)
        material.set_shader_parameter("phase_seconds",phase)
        material.set_shader_parameter("intensity",visibility)
    var stage: int = mini(3,int(phase/4.0))
    _cue.text = ["Breathe in", "Hold gently", "Breathe out", "Rest"][stage]
    _cue.global_transform = Transform3D(_journey.basis,_focal+_journey.basis.y*(-3.4)+_journey.basis.z*1.0)
    var age: float = fposmod(phase,4.0)
    _cue.modulate.a = smoothstep(0.0,.45,age)*(1.0-smoothstep(3.55,4.0,age))*visibility*.76

static func star_radius(phase: float) -> float:
    if phase<4.0:
        return smoothstep(0.0,.5,phase)
    if phase<8.0:
        return 1.0+.9*smoothstep(4.0,4.5,phase)
    return 1.9*(1.0-smoothstep(8.0,8.5,phase))

static func object_center(index: int,time: float,fill: float) -> Vector3:
    var seed: float = fposmod(float(index)*.6180339,1.0)*TAU
    var z_seed: float = fposmod(float(index)*.56984,1.0)
    var w: float = fposmod(float(index)*.438579,1.0)
    var depth: float = fposmod(fposmod(float(index)*.75487766,1.0)*64.0+travel_distance(time),64.0)-56.0
    var near: bool = z_seed<=.27
    var radius: float = 1.22+w*.40 if near else 2.5+z_seed*2.8
    var size: float = .24+w*.14 if near else .48+w*.56
    size *= 1.0-fill*.40
    var shell: float = 4.19*(1.0-fill*.40)
    var extent: float = size*1.17*(1.0+fill*.075)
    radius = maxf(1.12 if near else 1.3,radius*(1.0-fill*.40))
    radius = maxf(radius,absf(depth)*.035+size*1.1)
    radius = minf(radius,shell-extent-.16)
    var angle: float = seed+.065*sin(time*.071+float(index/8))
    return Vector3(cos(angle)*radius+.10*sin(time*.18+seed),sin(angle)*radius+.10*cos(time*.13+seed*2.0),depth+.13*sin(time*.11+seed))

func select_source(time: float,head: Vector3,basis: Basis,fill: float) -> int:
    var best: int = -1
    var score: float = -1000.0
    for index: int in range(128):
        var point: Vector3 = _journey*object_center(index,time,fill)
        var future: Vector3 = _journey*object_center(index,time+6.0,1.0)
        var local: Vector3 = basis.inverse()*(point-head)
        var next: Vector3 = basis.inverse()*(future-head)
        if local.z > -4.0 or local.z < -17.0 or next.z > -2.5:
            continue
        var alignment: float = Vector3.FORWARD.dot(local.normalized())
        if alignment<.87 or Vector3.FORWARD.dot(next.normalized())<.82:
            continue
        var rank: float = alignment*4.0-absf(local.length()-11.0)*.035
        if rank>score:
            score = rank
            best = index
    return best

func _build_plasma() -> void:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for segment: int in range(96):
        for side: int in range(6):
            var a: float = TAU*side/6.0
            var b: float = TAU*(side+1)/6.0
            var p: Vector3 = Vector3(float(segment)/96.0,cos(a),sin(a))
            var q: Vector3 = Vector3(float(segment+1)/96.0,cos(a),sin(a))
            var r: Vector3 = Vector3(float(segment+1)/96.0,cos(b),sin(b))
            var t: Vector3 = Vector3(float(segment)/96.0,cos(b),sin(b))
            for point: Vector3 in [p,q,r,p,r,t]:
                st.add_vertex(point)
    var instances: MultiMesh = MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.use_custom_data = true
    instances.mesh = st.commit()
    instances.instance_count = 4
    for index: int in range(4):
        instances.set_instance_transform(index,Transform3D.IDENTITY)
        instances.set_instance_custom_data(index,Color(float(index%2),float(index/2),0,0))
    _beams = MultiMeshInstance3D.new()
    _beams.multimesh = instances
    _beams.material_override = _material("plasma.gdshader")
    _beams.custom_aabb = AABB(Vector3(-120,-120,-120),Vector3(240,240,240))
    add_child(_beams)
